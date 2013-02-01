#!/usr/bin/env zsh
# header {
# vim: set foldmarker={,} foldlevel=0 foldmethod=marker :
# ----------------------------------------------------------------------------- #
#         File: zfm.zsh
#  Description: file/dir browser/navigator using hotkeys
#       Author: rkumar http://github.com/rkumar/rbcurse/
#         Date: 2012-12-17 - 19:21
#      License: GPL
#  Last update: 2013-02-01 13:24
#   This is the new kind of file browser that allows selection based on keys
#   either chose 1-9 or drill down based on starting letters
#
#   In memory of my dear child Gabbar missing since Nov 13th, 2012.
# ----------------------------------------------------------------------------- #
#   Copyright (C) 2012-2013 rahul kumar

# header }
ZFM_DIR=${ZFM_DIR:-~/bin}
export ZFM_DIR
export EDITOR=${EDITOR:-vi}
source ${ZFM_DIR}/zfm_menu.zsh
source $ZFM_DIR/zfm_viewoptions.zsh
setopt MARK_DIRS
## color of current line: use from autocolors red blue white black cyan magenta yellow
CURSOR_COLOR="red"

export M_FULL_INDEXING=
export TAB=$'\t'
set_auto_view
## We need C-c for mappings, so we disable it 
stty intr '^-'
# this is strangely eating up C-o
stty flush '^-'

#
# for printing details 
zmodload zsh/stat
zmodload -F zsh/stat b:zstat
PAGESZ=59     # used for incrementing while paging
M_SCROLL=${M_SCROLL:-10}
export M_SCROLL

(( PAGESZ1 = PAGESZ + 1 ))

# list_printer {
#  list_printer "Directory Listing" ./*
#    param 1 title
#    rest is files to list
function list_printer() {
    selection="" # contains return value if anything chosen
    #integer ZFM_COLS=$(tput cols) # it was here since it could change if resize, but not getting passed
    #integer ZFM_LINES=$(tput lines)
    #export ZFM_COLS ZFM_LINES
    local width=30
    local title=$1
    shift
    #local viewport vpa fin
    myopts=("${(@f)$(print -rl -- $@)}")
    #restore_exoanded_state

    # using cols to calculate cursor movement right
    LIST_COLS=3
    local tot=$#myopts
    #local sta=1


    # 2012-12-26 - 00:49 trygin this out so after a selection i don't lose what's filtered
    # but changing dirs must clear this, so it's dicey
    PATT=${PATT:-""}
    local mark ic approx
    globflags=
    ic=
    approx=
    while (true)
    do
        if [[ -z $M_NO_REPRINT ]]; then
            clear
            print -l -- ${M_MESSAGE:-"  $M_HELP"}
            (( fin = sta + $PAGESZ )) # 60

            # THIS WORKS FINE but trying to avoid external commands
            #viewport=$(print -rl -- $myopts  | grep "$PATT" | sed "$sta,${fin}"'!d')
            # this line replace grep and searches from start. if we plae a * after
            # the '#' then the match works throughout filename
            ic=${ZFM_IGNORE_CASE:+"-i"}
            approx=${ZFM_APPROX_MATCH+a1}
            # in case other programs need to display or account for, put in round bracks
            globflags="$ic$approx"
            # we keep filtering, not refreshing so deleted moved files still show up
            # the caller queries, and that sucks

            # I am fed up of this crazy crap. Things were great when i used grep and sed
            # I am giong back even though it will cause various changes
            if [[ -z $M_MATCH_ANYWHERE ]]; then
                #viewport=(${(M)myopts:#(#${ic}${approx})$PATT*})
                mark="^"
                prefix="^"
            else
                #viewport=(${(M)myopts:#(${ic}${approx})*$PATT*})
                mark=" "
                prefix=""
            fi
            viewport=("${(@f)$(print -rl -- $myopts | grep $ic "${prefix}$PATT" )}")

            ## testing out 
            #if [[ $#viewport -eq 0 ]]; then
            ## Ifwe don't get any results lets take the last entered pattern
            ## and place a .* before it so its a little more helpful. This is since
            ## sometimes there are too many common characters in file names.
            #
            ## This was nice but can be confusing esp when you backspace
            #
            if [[ -n "$M_SMART_FUZZY" ]]; then
                if [[ -z $viewport ]]; then
                    if [[ $#PATT -ge 2 ]]; then
                        local testpatt=$PATT
                        testpatt[-2]+='.*'
                        ## we repeat the above command, so make sure it is identical
                        viewport=("${(@f)$(print -rl -- $myopts | grep "${prefix}$testpatt" )}")
                        [[ ! -z $viewport ]] && PATT=$testpatt
                    fi
                fi
            fi


            ## Run a filter entered by the user on the existing data
            #
            if [[ -n "$M_CFILTER" ]]; then
                viewport=("${(@f)$(print -rl -- $viewport | eval "$M_CFILTER" )}")
            fi

            ## these lines must come after any filtering, othewise totals displayed
            ## are wrong
            let tot=$#viewport  # store the size of matching rows prior to paging it. 2013-01-09 - 01:37 
            [[ $fin -gt $tot ]] && fin=$tot
            
            ## this line replaces the sed filter
            viewport=(${viewport[$sta, $fin]})
            vpa=("${(@f)$(print -rl -- $viewport)}")
            #vpa=("${(f)=viewport}")
            VPACOUNT=$#vpa
            ZFM_LS_L=
            if (( $VPACOUNT <  (ZFM_LINES -2 ) )); then
                # need to account for title and read lines at least and message line
                LIST_COLS=1
                # this could have the entire listing which contains TABS !!!
                (( width= ZFM_COLS - 2 ))
                ZFM_LS_L=1
            elif [[ $VPACOUNT -lt 40 ]]; then
                LIST_COLS=2
                (( width = (ZFM_COLS / LIST_COLS) - 2 ))
            else
                LIST_COLS=3
                # i can use 1 instead of 2, it touches the end, 2 to be safe for other widths
                (( width = (ZFM_COLS / LIST_COLS) - 2 ))
            fi
            # NO, vpa is not entire thing, its grepped and filtered, so it can't be more than page size=
            #let tot=$#vpa
            [[ $fin -gt $tot ]] && fin=$tot
            local sortorder=""
            [[ -n $ZFM_SORT_ORDER ]] && sortorder="o=$ZFM_SORT_ORDER"

            ## This relates to the new cursor functionality. Arrow keys allow us to
            ## move around the file list and press ENTER
            #
            (( CURSOR == -1 || CURSOR > tot )) && CURSOR=$tot
            #
            # If user presses down at last file, and there are more we should
            #  page down, but that's not working at present, some glitches, so we just
            #  bring cursor back to 1
            #(( CURSOR > $VPACOUNT && CURSOR < $tot )) && { sta=$CURSOR ; CURSOR=1 }
            # this is fine but does not redraw the page until cursor moves
            (( CURSOR > VPACOUNT && CURSOR < tot )) && { zfm_next_page  }
            ## if there are no rows then CURSOR gets set to 0 and remains there forever, check
            (( CURSOR == 0 )) && CURSOR=1


            print_title "$title $sta to $fin of $tot ${COLOR_GREEN}$sortorder $ZFM_STRING ${globflags}${COLOR_DEFAULT} "

            ## This is the original line, which had a pipeline. I had to break this up
            ## since it updates a cache of file details and this cache is lost each
            ## time a call is made, since it is in another process
            #
            #print -rC$LIST_COLS "${(@f)$(print -rl -- $viewport | numberlines -p "$PATT" -w $width)}"
            numberlines -p "$PATT" -w $width $viewport
            print -rC$LIST_COLS "${(@f)$(print -l -- $OUTPUT)}"

            mode=
            [[ -n $M_SELECTION_MODE ]] && mode="[SEL $#selectedfiles] "
        fi # M_NO_REPRINT
        M_NO_REPRINT=
        #print -n "$mode${mark}$PATT > "
        print -n "\r$mode${mark}$PATT > "
        # prompt for key PROMPT
        #read -k -r ans
        # see zfm_menu.zsh for _read moved there
        _read_keys
        #M_MESSAGE=
        if [[ $? != 0 ]]; then
            # maybe ^C
            pdebug "Got C-c ? $reply, $key"
            key=''
            ans=''
            #break
        else
            #[[ -n $ckey ]] && reply=$ckey
            ans="${reply}"
            #pdebug "Got ($reply)"
        fi
        #print 2013-01-21 - 00:09 due to \r in print
        #clear # trying this out # commenting out, if we don't reprint then clearing was wrong
        #[[ $ans = "C-i" ]] && ans="TAB" # 2013-01-28 - 13:07 
        #[[ $ans = "C-j" ]] && ans="ENTER" # 2013-01-28 - 13:07 
        #[[ $ans = " " ]] && ans="SPACE" # 2013-01-28 - 13:07 , so that they show up on help clearly
        ### giving names so easier to find and use
        #[[ $ans = "" ]] && ans="ESCAPE"
        #[[ $ans = "" ]] && ans="BACKSPACE"
        case $ans in
            "")
                # BLANK blank
                (( sta = 1 ))
                PATT=""
                ;;
            $ZFM_EDIT_REGEX_KEY)
                ## character like number cause automatic selection, but if your file name
                ## contains or starts with numbers then this key allows you to enter a key
                ## which will get added to search pattern 2013-01-28
                #
                vared -p "Edit pattern (valid regex): " PATT
                ;;
            $ZFM_FORWARD_KEY)
                # SPACE space, however may change to ENTER due to spaces in filenames
                (( sta += $PAGESZ1 ))
                [[ $fin -gt $tot ]] && fin=$tot
                ;;
            $ZFM_BACKWARD_KEY)
                (( sta -= $PAGESZ1 ))
                [[ $sta -lt 1 ]] && sta=1
                ;;
            [1-9])
                # KEY PRESS key
                if [[ -n "$M_FULL_INDEXING" ]]; then
                    iix=$MFM_NLIDX[(i)$ans]
                    pdebug "got iix $iix for $ans"
                    [[ -n "$iix" ]] && selection=$vpa[$iix]
                    pdebug "selection was $selection"
                else

                # actix needs to be consistent in 2 cases:
                #   - when paging - correct is from myopts
                #   - when filtering. (in this case the correct is from viewport/vpa
                #   - there is a third case of paging after filtering GAAH
                (( ix = sta + $ans - 1))
                #
                # NEW now check if 2 files satisfy this key (edge case but
                # could happen alot if you keep numbered files)

                selection=""
                if [[ $VPACOUNT -gt 9 ]]; then
                    if [[ $PATT = "" ]]; then
                        npatt="${ans}*"
                    else
                        npatt="$PATT$ans"
                    fi
                    lines=
                    if [[ -n "$M_SWITCH_OFF_DUPL_CHECK" ]]; then
                        lines=$(check_patt $npatt)
                        ## XXX why not ct=$#lines 2013-01-24 - 20:05 
                        ct=$(print -rl -- $lines | wc -l)
                    else
                        ct=0
                    fi
                    [[ -n $lines ]] || ct=0
                    [[ -n $ZFM_VERBOSE ]] && pdebug "comes here $ct , ($lines)"
                    if [[ $ct -eq 1 ]]; then
                        [[ -n "$lines" ]] && { selection=$lines; break }
                    elif [[ $ct -eq 0 ]]; then
                        selection=$vpa[$ans]
                        #selection=$myopts[$ix] # fails on filtering
                        [[ -n $ZFM_VERBOSE ]] && print " selected $selection"
                    else
                        PATT=$npatt
                    fi
                else
                    # there are only 9 or less so just use mnemonics, don't check
                    # earlier
                    selection=$vpa[$ans]
                    print " 1. selected $selection"
                fi
            fi # M_FULL
                [[ -n "$selection" ]] && break
                ;;
            $ZFM_QUIT_KEY)
                break
                ;;
            [a-zA-Z_0\.\ \*])
                ## UPPER CASE upper section alpha characters
                (( sta = 1 ))

                if [[ -n "$M_FULL_INDEXING" ]]; then
                    iix=$MFM_NLIDX[(i)$ans]
                    pdebug "iix was $iix for $ans"
                    [[ -n "$iix" ]] && { selection=$vpa[$iix]; break }
                    pdebug "selection was $selection"

                else

                    if [[ $PATT = "" ]]; then
                        [[ $ans = '.' ]] && { 
                            # i will be doing this each time dot is pressed
                            # ad changing setting for calling shell too ! XXX
                            pdebug "I should only set and do this if nothing is showing or glob dots is off"
                            #pbold "Setting glob_dots ..."
                            #setopt GLOB_DOTS
                            show_hidden_toggle
                            #setopt globdots
                            param=$(eval "print -rl -- ${pattern}(${MFM_LISTORDER}$filterstr)")
                            myopts=("${(@f)$(print -rl -- $param)}")
                            pbold "count is $#myopts"
                        }
                        PATT="${ans}"
                    else
                        [[ -n $ZFM_VERBOSE ]] && pdebug "comes here 1"

                        ## Fpatt is either unset or contains .*
                        PATT+="${FPATT}$ans"
                    fi
                    ## if there's only one file for that char then just jump to it
                    lines=$(check_patt $PATT)
                    ct=$(print -rl -- $lines | wc -l)
                    if [[ $ct -eq 1 ]]; then
                        [[ -n "$lines" ]] && { selection=$lines; break }
                    fi
                fi # M_FULL
                ;;
            $ZFM_REFRESH_KEY)
                zfm_refresh
                ;;
            "$ZFM_RESET_PATTERN_KEY")
                PATT=""
                ;;
                # I think this overrides what cursor defines
            "$ZFM_OPEN_FILES_KEY")
                ## Open either selected files or what's under cursor
                if [[ -n $selectedfiles ]];then 
                    call_fileoptions $selectedfiles
                else
                    selection=$vpa[$CURSOR]
                fi
                [[ -n "$selection" ]] && break
                ;; 
            BACKSPACE)
                # BACKSPACE backspace if we are filtering, if blank and still backspace then put start of line char
                if [[ $PATT = "" ]]; then
                    M_NO_REPRINT=1
                else
                    # backspace if we are filtering, remove last char from pattern
                    #patt=${patt[1,${#patt}-1]}
                    PATT[-1]=
                    PATT=${PATT%.*}
                fi
                ;;


            *) 
                # commented 2013-01-31 - 01:25  key reverts back to top after C-n
                #(( sta = 1 ))
                # 2013-01-24 - 20:38 moved backspace up

                        # check something bound to the key
                        # Now we should use this and bind everything, so its more modular
                        zfm_get_key_binding $ans
                        if [[ -n $binding ]]; then
                            $binding
                            ans=
                            break
                        else
                            
                            pdebug "Key $ans unhandled and swallowed, pattern cleared. Use ? for key help"
                           
                            #  put key in SWALLOW section to pass to caller
                            if [[ -n $PATT ]]; then
                                # if ans has been used then don't clear
                                #PATT=""  # commented on 2013-01-28 - 00:03 often gets reset
                                # when it should not like ? or @
                            else
                                # this could be a problem since list won't reprint
                                # after handled in caller. XXX
                                # I am putting this down to caller if no action done
                                #M_NO_REPRINT=1
                            fi
                            ## added on 2013-01-22 - 16:33 so caller can capture
                            break
                        fi
        esac

        ## 2013-01-24 - 20:24 thre break in the next line without clearing ans
        ## was causing the unused error to keep popping up when no rows were returned
        [[ $sta -ge $tot ]] && { sta=1; ans= ;  pinfo "...Wrapping around"; break }
        # break takes control back to MARK1 section below

    done
}
# }
function zfm_next_page () {
    local oldsta=$sta
    (( sta += $PAGESZ1 ))
    #[[ $sta -ge $tot ]] && { sta=$oldsta; }
    [[ $sta -ge $tot ]] && { sta=$oldsta; CURSOR=$VPACOUNT; return }
    ## something wrong with cursor setting to 1 each time, this is only if pagin has happened.
    CURSOR=1
}
function zfm_prev_page () {
    (( sta -= $PAGESZ1 ))
    [[ $sta -lt 1 ]] && sta=1
}
function zfm_scroll_down () {
    (( CURSOR += M_SCROLL ))
}
function zfm_scroll_up () {
    (( CURSOR -= M_SCROLL ))
    (( CURSOR < 1 && sta > 1 )) && { 
        zfm_prev_page ;
        ## the next vpa count deals with current page which can be less than
        # files on prev page
        (( CURSOR = VPACOUNT ))
        #(( CURSOR = VPACOUNT - M_SCROLL ))
    }
    (( CURSOR < 1 )) && CURSOR=1
}
function patt_toggle() {
    local gpatt=$1
    gpatt=${gpatt:gs/*//}
    gpatt="${gpatt}"
    if [[ -z "$ZFM_FUZZY_MATCH_DIR" ]]; then
    else
        gpatt=$(print $gpatt | sed 's/\(.\)/\1\*/g')
    fi
    print "$gpatt"
}

function toggle_match_from_start() {
    # default is unset, it matches what you type from start
    if [[ -z "$M_MATCH_ANYWHERE" ]]; then
        M_MATCH_ANYWHERE=1
    else
        M_MATCH_ANYWHERE=
    fi
    export M_MATCH_ANYWHERE
}
# utility functions {
# check if there is only one file for this pattern, then straight go for it
# with some rare cases the next char is a number, so then don't jump.
function check_patt() {
    #local p=${1:s/^//}  # obsolete, refers to earlier grep version
    local p=$1
    local approx
    local ic=
    ic=${ZFM_IGNORE_CASE+i}
    approx=${ZFM_APPROX_MATCH+a1}
    ## XXX TODO needs to be checked sicne we have moved back to grep
    if [[ -z $M_MATCH_ANYWHERE ]]; then
        # match from start - default
        lines=$(print -rl -- (#$ic${approx})${p}*)
    else
        lines=$(print -rl -- (#$ic${approx})*${p}*)
    fi
    # need to account for match from start
    print $lines
}
function subcommand() {
    dcommand=${dcommand:-""}
    vared -p "Enter command (? - help): " dcommand
    [[ "$dcommand" = "q" || $dcommand = "quit" ]] && { QUITTING=1 ; break }
    case "$dcommand" in
        "S"|"save")
            print "Saving $PWD to bookmarks"
            push_pwd
            print "Bookmarks: $ZFM_DIR_STACK"
            pause
        ;;
        "P"|"pop")
            pop_pwd
        ;;
        "a"|"ack")
            zfm_ack
        ;;
        "l"|"locate")
            zfm_locate
        ;;
        "f"|"file")
            if [[ -n $selectedfiles ]]; then
                pdebug "selected files: $#selectedfiles"

                M_NO_AUTO=1
                call_fileoptions $selectedfiles
            else
                selection=${selection:-$vpa[$CURSOR]}
                if [[ -n "$selection" ]]; then
                    M_NO_AUTO=1
                    fileopt $selection
                    selection=
                else
                    perror "Please select a file first. Use $ZFM_SELECTION_MODE_KEY key to toggle selection mode"
                fi
            fi
        ;;
        "?"|"h"|"help")
            print "Commands are save (S), pop (P), help (h)"
            print ""
            print "'S' 'save' - save this dir in stack for later returning"
            print "'P' 'pop'  - revert to saved dir"
            print "'f' 'file' - file operations on selected file"
            print "     helpful if you have auto-actions on but want to execute"
            print "     another action on selected file"
            print "'a'  ack (search string) in files"
            print "'q' 'quit' - quit application"
            print "You may enter any other command too such as 'git status'"
            print
        ;;
    "pipe")
        # accept a command and pass the result to selectrows
        command_select
        ;;
    "l"|"locate")
        zfm_locate
        ;;
    *)
        eval "$dcommand"
        ;;
    esac
    M_SELECTION_MODE=
    [[ "$dcommand" = "q" || $dcommand = "quit" ]] && QUITTING=1
    pause
}

#  add current dir to stack so we can pop back
#  We add it backwards so i can shift 
#  Currently aclled only from GOTO_DIR and :S
function push_pwd() {
    local dir
    dir=${1:-$PWD}
    ZFM_DIR_STACK+=( $dir:q )
    #print $ZFM_DIR_STACK 
}
## this is only called from :P not from pop, see popd
#  This does not remove dirs when popping so we always have all visited dirs with us
function pop_pwd() {
    # remove from end
    newd=$ZFM_DIR_STACK[-1]
    ZFM_DIR_STACK[-1]=()
    # put it back on top (first)
    ZFM_DIR_STACK[1]+=( $newd:q )
    # XXX maybe should cd to new top dir, not removed one.
    cd $newd
    pwd
    post_cd
}
#  executed when dir changed
function post_cd() {
    PATT=""
    filterstr=${filterstr:-M}
    param=$(eval "print -rl -- ${pattern}${M_EXCLUDE_PATTERN}(${MFM_LISTORDER}$filterstr)")
    [[ $#param -eq 0 ]] && {
        M_MESSAGE="$#param files, use UP or ZFM_GOTO_PARENT_KEY to go to parent folder, LEFT to popd"
    }
    # clear hash of file details to avoid recomp
    FILES_HASH=()
    execute_hooks "chdir"
    CURSOR=1
    sta=1
}
function zfm_refresh() {
    filterstr=${filterstr:-M}
    param=$(eval "print -rl -- ${pattern}${M_EXCLUDE_PATTERN}(${MFM_LISTORDER}$filterstr)")
    restore_exoanded_state
    myopts=("${(@f)$(print -rl -- $param)}")
}

## This will ensure that when you return to the directory where
# some dirs were exploded, they will be exploded again
function restore_exoanded_state() {
local td
    for d in $ZFM_EXPANDED_DIRS ; do
        if [[ -d "$d" ]]; then
            td=$d:t
            _files=("${(@f)$(print -rl -- $td/*)}")
            for f in $_files ; do
                param+=( $f )
            done
        else
            # This happens when we move to another dir, so don't worry
            perror "$d not a directory: [$ZFM_EXPANDED_DIRS[1]]"
        fi
    done
}
function print_help_keys() {

    print
    str="$fg_bold[white]$ZFM_APP_NAME some keys$reset_color"
    str+=" \n"
    str+=$(cat <<EndHelp

    $ZFM_MENU_KEY	- Invoke menu (default: backtick)
    $ZFM_FORWARD_KEY	- Paging of output (default C-n)
    $ZFM_BACKWARD_KEY	- Previous page of listing (default C-p)
    ^	- toggle match from start of filename
    $ZFM_GOTO_DIR_KEY	- Enter directory name to jump to
    $ZFM_SELECTION_MODE_KEY	- Toggle selection mode
    $ZFM_EDIT_REGEX_KEY	- Edit pattern (should be valid grep regex)
    $ZFM_GOTO_PARENT_KEY	- Goto parent of existing dir (cd ..)
    $ZFM_POPD_KEY	- popd (go back to previously visited dirs)
    :	- Command key
        	* S - Save current dir in list
        	* P - Pop dirs from list
    $ZFM_RESET_PATTERN_KEY	- Clear existing search pattern    **
    $ZFM_REFRESH_KEY	- refresh/rescan dir listing     **
    $ZFM_SORT_KEY	- change sort order (pref. use menu) **
    $ZFM_FILTER_KEY	- change filter criteria (pref. use menu) **
    $ZFM_SIBLING_DIR_KEY	- view/select sibling directories **
    $ZFM_CD_OLD_NEW_KEY	- cd OLD NEW functionality (visit second cousins) **
    $ZFM_OPEN_FILES_KEY - open file/s (selected) or under cursor

    Most keys are likely to change after getting feedback, the ** ones definitely will
    
EndHelp
)
    str+=" \n"
for key in ${(k)zfm_keymap} ; do
    #print $key  : $zfm_keymap[$key]
    str+=$(print "    $key  : $zfm_keymap[$key]")"\n"
done
print -l -- "$str" | $PAGER
#pbold "Key mappings"
}

# utility }
# main {
#   alias this to some single letter after sourcing this file in .zshrc
function myzfm() {
##  global section
ZFM_APP_NAME="zfm"
ZFM_VERSION="0.1.7-c"
M_TITLE="$ZFM_APP_NAME $ZFM_VERSION 2013/02/01"
#  Array to place selected files
typeset -U selectedfiles
# hash of file details to avoid recomp each time while inside a dir
typeset -Ag FILES_HASH

selectedfiles=()

#  directory stack for jumping back, opened fies, and expanded dirs
typeset -U ZFM_DIR_STACK ZFM_FILE_STACK ZFM_EXPANDED_DIRS
ZFM_DIR_STACK=()
ZFM_FILE_STACK=()
ZFM_EXPANDED_DIRS=()
ZFM_CD_COMMAND="pushd" # earlier cd lets see if dirs affected
export ZFM_CD_COMMAND
ZFM_START_DIR="$PWD"
ZFM_FILE_SELECT_FUNCTION=fuzzyselectrow
export ZFM_FILE_SELECT_FUNCTION
export last_viewed_files

#  defaults KEYS
#ZFM_PAGE_KEY=$'\n'  # trying out enter if files have spaces and i need to type a space
ZFM_FORWARD_KEY=${ZFM_FORWARD_KEY:-'C-n'}  # trying out enter if files have spaces and i need to type a space
ZFM_BACKWARD_KEY=${ZFM_BACKWARD_KEY:-'C-p'}  # trying out enter if files have spaces and i need to type a space
ZFM_OPEN_FILES_KEY=${ZFM_OPEN_FILES_KEY:-'C-o'}  # pressing selects whatever cursor is on
ZFM_MENU_KEY=${ZFM_MENU_KEY:-$'\`'}  # trying out enter if files have spaces and i need to type a space
ZFM_GOTO_PARENT_KEY=${ZFM_GOTO_PARENT_KEY:-','}  # goto parent of this dir 
ZFM_GOTO_DIR_KEY=${ZFM_GOTO_DIR_KEY:-'+'}  # goto parent of this dir 
#ZFM_RESET_PATTERN_KEY=${ZFM_RESET_PATTERN_KEY:-'\'}  # reset the pattern, use something else
ZFM_POPD_KEY=${ZFM_POPD_KEY:-"<"}  # goto previously visited dir
ZFM_SELECTION_MODE_KEY=${ZFM_SELECTION_MODE_KEY:-"@"}  # toggle selection mode
ZFM_SORT_KEY=${ZFM_SORT_KEY:-"%"}  # change sort options
ZFM_FILTER_KEY=${ZFM_FILTER_KEY:-"#"}  # change filter options
ZFM_TOGGLE_MENU_KEY=${ZFM_TOGGLE_MENU_KEY:-"="}  # change toggle options
ZFM_TOGGLE_FILE_KEY=${ZFM_TOGGLE_FILE_KEY:-"C-SPACE"}  # change toggle options
ZFM_SIBLING_DIR_KEY=${ZFM_SIBLING_DIR_KEY:-"["}  # change to sibling dirs
ZFM_CD_OLD_NEW_KEY=${ZFM_CD_OLD_NEW_KEY:-"]"}  # change to second cousins
ZFM_QUIT_KEY=${ZFM_QUIT_KEY:-'q'}  # quit application
#ZFM_SELECT_ALL_KEY=${ZFM_SELECT_ALL_KEY:-'*'}  # select all files on screen
ZFM_SELECT_ALL_KEY=${ZFM_SELECT_ALL_KEY:-"M-a"}  # select all files on screen
ZFM_EDIT_REGEX_KEY=${ZFM_EDIT_REGEX_KEY:-"/"}  # edit PATT used to filter
export ZFM_REFRESH_KEY=${ZFM_REFRESH_KEY:-'"'}  # refresh the listing
ZFM_MAP_LEADER=${ZFM_MAP_LEADER:-'\'}
#export ZFM_NO_COLOR   # use to swtich off color in selection
M_SWITCH_OFF_DUPL_CHECK=
MFM_LISTORDER=${MFM_LISTORDER:-""}
M_EXCLUDE_PATTERN=
pattern='*' # this is separate from patt which is a temp filter based on hotkeys
filterstr="M"
M_PRINT_COMMAND_DESC=1
MFM_NLIDX="123456789abcdefghijklmnoprstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
ZFM_STRING="${pattern}(${MFM_LISTORDER}$filterstr)"
integer ZFM_COLS=$(tput cols)
integer ZFM_LINES=$(tput lines)
integer CURSOR=1
export ZFM_COLS ZFM_LINES CURSOR
export ZFM_STRING
init_key_function_map
init_menu_options
init_file_menus
source_addons
# at this point read up users bindings
#print "$ZFM_TOGGLE_MENU_KEY Toggle | $ZFM_MENU_KEY menu | ? help"
aa=( "?" Help  "$ZFM_MENU_KEY" Menu "$ZFM_TOGGLE_MENU_KEY" Toggle "$ZFM_SELECTION_MODE_KEY" "Selection Mode")
M_HELP=$( print_hash $aa )
#print $M_HELP
M_MESSAGE="$M_HELP    $M_TITLE"
param=$(print -rl -- *(M))
# sta was local in list_printer, tring out belove
sta=1
    while (true)
    do
        list_printer "${PWD} " $param
        [[ -n $QUITTING ]] && break
        # MARK1 section comes back when list_p breaks from SWALLOW
        [[ -n $selection ]] && pdebug "returned with $selection"
        # value selected is in selection, key pressed in ans
        [[ -z "$selection" ]] && {
            [[ "$ans" == $ZFM_QUIT_KEY ]] && break
            case $ans in 
                "~")
                    selection=$HOME
                    ;;
                *)
                    [[ "$ans" == $ZFM_REFRESH_KEY ]] && { perror "breaking";  break }
            
                    [[ -n $ans ]] && { 
                        M_MESSAGE="$ans unused. $M_HELP"
                        M_NO_REPRINT=1
                    }
                    ## NOTE messages will only be refreshed if key had some
                    #  effect, else unused key warning won't do anything since we dont
                    #  redraw.
                    #
                    ;;
            esac
            }

        if [[ -d "$selection" ]]; then
            [[ -n $ZFM_VERBOSE ]] && print "got a directory $selection"
            $ZFM_CD_COMMAND $selection
            post_cd
        elif [[ -f "$selection" ]]; then
            # although nice to immediately open, but what if its not a text file
            # and what if i want to do something else
            #vim $selection
            if [[ -n "$M_SELECTION_MODE" ]]; then
                selection=$PWD/$selection
                zfm_toggle_file $selection
            else
                fileopt $selection
                #pause 2012-12-26 - 00:01 pauses after vim which is irritating
                # but pause could be required after cat or similar command
            fi
        else
            [[ -n "$selection" ]] && {
            # sometimes comes here on a link (esp broken) and fileopt will check for -f and reject
                pbold "Don't know how to handle $selection"
                file $selection
                fileopt $selection
                pause
            }
        fi
    done
    print "bye"
    # do this only if is different from invoking dir
    [[ "$PWD" == "$ZFM_START_DIR" ]] || {
        print "sending $PWD to pbcopy"
        print "$PWD" | pbcopy
    }
} # myzfm

## line numbering function, also takes care of widths and coloring since these are interdependent
#  and can clobber one another.
## Earlier this acted as a filter and read lines and printed back output, But now we cache
# file details to avoid screen flicker, so the hash must be in the same shell/process, thus 
# it stored details in OUTPUT string. And reads from viewport.
function numberlines() {
    let c=1
    local patt='.'
    if [[ -n "$ZFM_NO_COLOR" ]]; then
        BOLD='*'
        BOLD_OFF=
        COLOR_STANDOUT=
        COLOR_STANDOUTOFF=
    else
        BOLD=$COLOR_BOLD
        COLOR_STANDOUT="\\033[7m"
        COLOR_STANDOUTOFF="\\033[27m"
        BOLD_OFF=$COLOR_DEFAULT
    fi
    OUTPUT=""
    ##local defpatt='.'
    local defpatt=""
    local selct=$#selectedfiles
    [[ $1 = "-p" ]] && { shift; patt="$1"; shift }
    [[ $1 = "-w" ]] && { shift; width="$1"; shift }
    # since string searching in zsh isn;t on regular expressions and ^ is not respected
    # i am taking width of match after removing ^ and using next char as next shortcut
    # # no longer required as i don't use grep, but i wish i still were since it allows better
    # matching
    #patt=${patt:s/^//}
    local w=$#patt
    #let w++
    nlidx="123456789abcdefghijklmnoprstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    #while IFS= read -r line; do
    for line in $*; do
        # read from viewport now TODO
        cc=' '
        (( c == CURSOR )) && cc=$CURSOR_MARK
        if [[ -n "$M_FULL_INDEXING" ]]; then
            sub=$nlidx[$c]
        else
            sub=$c

            [[ $c -gt 9 ]] && {
                #sub=$line[$w,$w] ;  
                # in the beginning since the patter is . we show first char
                # otherwise this will match the dot
                if [[ $patt = "$defpatt" ]]; then
                    sub=$line[1,1]
                else
                    # after removing the ^ we find match and get the character after the pattern
                    # NOTE: that if the match is at end of filename there is no next character i can show.
                    ix=$line[(i)$patt]
                    (( ix += w ))
                    sub=$line[$ix,$ix] ;  
                fi
            }
        fi
        link=
        _detail=
        if [[ -n "$ZFM_LS_L" ]]; then
            if [[ -n "$line" ]]; then
                if [[ -e "$line" ]]; then
                    # check cache for file details
                    get_file_details "$line"
                    # above call updates _detail and the hash, so has to be in current process
                else
                    _detail="(deleted? $PWD)"
                    # file does not exist so it could be deleted ?
                fi
            fi
        fi
        # only if there are selections we check against the array and color
        # otherwise no check, remember that the cut that comes later can cut the 
        # escape chars
        _line=
        boldflag=0
        # 2013-01-09 - 19:33 I am trying out only highlighting the number or else
        # its becoming too confusing, and even now the trunc is taking size of 
        # ANSI codes which are not displayed, so a little less is shown that cold be
        if [[ $selct -gt 0 ]]; then
            # quoted spaces causing failure in matching,
            # however if i don't quote then other programs fail such as ls and tar
            if [[ $selectedfiles[(ie)$PWD/${line}] -gt $selct ]]; then
                #_line="$sub) $_detail $line $link"
            else
                #_line="$sub) $_detail ${BOLD}$line${BOLD_OFF}"
                #sub="${BOLD}$sub${BOLD_OFF}"
                boldflag=1
            fi
        else
            #_line="$sub) $_detail $line $link"
        fi
        _line="$sub)$cc $_detail $line $link"
        (( $#_line > width )) && _line=$_line[1,$width] # cut here itself so ANSI not truncated
        (( boldflag == 1 )) && _line="${BOLD}$_line${BOLD_OFF}"
        #(( c == CURSOR )) && _line="${COLOR_STANDOUT}$_line${COLOR_STANDOUTOFF}"
        (( c == CURSOR )) && _line="${bg_bold[$CURSOR_COLOR]}$_line${reset_color}"
        ### 2013-01-21 - 21:09 trying to do this in same process so hash be updated
        #print -l -- $_line
        OUTPUT+="$_line\n"
        let c++
    done
    #print -l -- $OUTPUT
} # numberlines

## 
# updates file details in _detail and also updates hash/cache
# this cannot be called in new process, must be called and then _detail used
function get_file_details() {
    local line=$1
    local sz link
    _detail=$FILES_HASH[$line]
    if [[ -z $_detail ]]; then
        mtime=$(zstat -L -F "%Y-%m-%d %H:%M" +mtime $line)
        zstat -L -H hash $line
        sz=$hash[size]
        if [[ $sz -gt 1048576 ]]; then
            (( sz = sz / 1048576 )) ; sz="${sz}M" 
            # statements
        elif [[ $sz -gt 9999 ]]; then
            (( sz = sz / 1024 )) ; sz="${sz}k" 
        fi
        sz=$( print ${(l:6:)sz} )
        #[[ $sz -gt 9999 ]] && {  (( sz = sz / 1024 )) ; sz="${sz}k" }
        link=$hash[link]
        [[ -n $link ]] && link=" -> $link"
        _detail="${TAB}$sz${TAB}$mtime${TAB}"
        # cache details of file
        FILES_HASH[$line]=$_detail
    else
        #_detail="$_detail +"
    fi

}

function selection_menu() {
    local mode="remove_mode"
    local mmode="Selection"
    [[ $#selectedfiles -eq 0 ]] && ZFM_REMOVE_MODE=
    if [[ -n $ZFM_REMOVE_MODE ]]; then
        mode="add_mode"
        mmode="Unselection "
    fi
    menu_loop "$mmode Options ($#selectedfiles)" "today extn ack invert $mode" "txaim"
    files=
    case $menu_text in
        "today")
            # finding common rows between what's visible and today's files
            files=("${(@f)$(print -rl -- *(.m0))}")
            pdebug "files $#files : $files"
            ;;
        "extn")
            # finding common rows between what's visible and today's files
            print -n "Enter extensions to select (space delim *.c *.h): "
            read extns
            files=("${(@f)$(eval print -rl -- $extns)}")
            ;;
        "ack")
            # files containing some text
            print -n "Enter pattern to search : "
            read cpattern
            files=("${(@f)$(eval ack -l $M_ACK_REC_FLAG $cpattern)}")
            pdebug "file $#files : $files"
            ;;
        "remove_mode")
            if [[ $#selectedfiles -eq 0 ]]; then
                perror "There are no files to unselect"
            else
                ZFM_REMOVE_MODE=1
                pinfo "Files selected will be removed from selection"
            fi
            ;;
            #(( ZFM_REMOVE_FLAG =  ZFM_REMOVE_MODE * -1 ))
        "add_mode")
            ZFM_REMOVE_MODE=
            pinfo "Files selected will be added to selection (normal mode)"
            ;;
            #(( ZFM_REMOVE_FLAG =  ZFM_REMOVE_MODE * -1 ))
        "invert")
            ## This is resulting in directories getting selected, avoid that
            local vp
            vp=($PWD/${^viewport}) # prepend PWD to each element 2013-01-10 - 00:17
            selectedfiles=( ${vp:|selectedfiles} )
            ;;


    esac
    if [[ -n $files ]]; then
        files=($PWD/${^files}) # prepend PWD to each element
        # don't quote files again in common loop or spaced files will not get added
        if [[ -n $ZFM_REMOVE_MODE ]]; then
            #files=( $files:q )
            selectedfiles=(${selectedfiles:|files})
        else

            # i think viewport has only file names, no details
            # so we can just do a one line operation
            vp=($PWD/${^viewport})
            common=( ${vp:*files} )
            for line in $common
            do
                pdebug "line $line"
                selected_row=("${(s/	/)line}")
                selected_file=$selected_row[-1]
                selectedfiles+=( $selected_file )
            done
        fi
    fi
    pdebug "selected files $#selectedfiles"
}
# }

# this is the main menu used in the list when pressing MENU_KEY
# The purpose of initializing this is to make it configurable or modifiable through
# a config file
function init_menu_options() {
    typeset -gA main_menu_command_hash
    main_menu_options+=("Directory" "zk dirjump" "d children" "[ Siblings" "] cd OLD NEW" "M mkdir" "% New File" "." "\n")
    main_menu_options+=("Commands" "a ack" "/ ffind" "v filejump" "l locate" "u User Commands" "_ Last viewed file" "\n")
    main_menu_options+=("Settings"  "x Exclude Pattern" "F Filter options" "s Sort Options" "o General"  "\n")
    main_menu_options+=("Listings" "f File Listings" "r Recursive Listings" "\n")
    main_menu_command_hash=(
        o settingsmenu
        f nonrecviewoptions
        r recviewoptions
        d m_child_dirs
        z m_dirstack
        k m_dirstack
        v m_recentfiles
        F filteroptions
        x zfm_exclude_pattern
        s sortoptions
        u mycommands
        a zfm_ack
        l zfm_locate
        M zfm_newdir
        % zfm_newfile
        / zfm_ffind
        [ sibling_dir
        ] cd_old_new
        _ edit_last_file
        )
}
function init_key_function_map() {
    typeset -gA zfm_hook
    add_hook "chdir" chdir_message
    add_hook "chdir" restore_exoanded_state
    add_hook "fileopen" fileopen_hook

    typeset -gA zfm_keymap
    # testing out key mappings with different kinds of keys
    zfm_keymap=("$ZFM_GOTO_PARENT_KEY"
                    goto_parent_dir
                "$ZFM_GOTO_DIR_KEY"
                    goto_dir
                $ZFM_SORT_KEY
                    sortoptions
                $ZFM_FILTER_KEY
                    filteroptions
                "TAB"
                    zfm_views
                "$ZFM_POPD_KEY"
                    zfm_popd
                ":"
                    subcommand
                "$ZFM_MENU_KEY"
                    zfm_show_menu
                "^"
                    toggle_match_from_start
                $ZFM_TOGGLE_MENU_KEY
                    toggle_options_menu
                "$ZFM_SIBLING_DIR_KEY"
                    sibling_dir
                $ZFM_CD_OLD_NEW_KEY
                    cd_old_new
                "?"
                    print_help_keys
                $ZFM_SELECT_ALL_KEY
                    zfm_select_all_rows
                $ZFM_SELECTION_MODE_KEY
                    zfm_selection_mode_toggle
                $ZFM_TOGGLE_FILE_KEY
                    zfm_toggle_file
                "'"
                    full_indexing_toggle
                "C-x"
                    cx_map
                $ZFM_MAP_LEADER
                    cx_map
                "C-x d"
                    zfm_toggle_expanded_state
                "C-d"
                    zfm_scroll_down
                "C-b"
                    zfm_scroll_up
                    )
    zfm_bind_key "M-x" "zfm_views"
    zfm_bind_key "M-o" "settingsmenu"
    zfm_bind_key "M-s" "sortoptions"
    zfm_bind_key "M-f" "filteroptions"
    zfm_bind_key "F1" "print_help_keys"
    zfm_bind_key "F2" "goto_dir"
    zfm_bind_key "|" "zfm_filter_list"
    zfm_bind_key "C-e" "zfm_edit_pattern"
    zfm_bind_key "M-e" "zfm_exclude_pattern"
    zfm_bind_key "M-/" "zfm_ffind"
    zfm_bind_key "ML '" "visited_dirs"
    #zfm_bind_key "C-x '" "visited_dirs"
    zfm_bind_key "ML v" "visited_files"
    zfm_bind_key "$ZFM_SIBLING_DIR_KEY" sibling_dir
}
function init_file_menus() {
    # edit these or override in ENV
    ZFM_ZIP_COMMAND=${ZFM_ZIP_COMMAND:-'tar zcvf ${archive} %%'}
    ZFM_RM_COMMAND=${ZFM_RM_COMMAND:-rmtrash}
    ZFM_UNZIP_COMMAND=${ZFM_UNZIP_COMMAND:-dtrx}
    #
    ## Apps used for text files, will be used in menus on file selection
    #FT_TEXT=(vim cmd less 'mv % ${target}' ${ZFM_RM_COMMAND} archive tail head open auto)
    #FT_DEFAULT_PDF=("vim =(pdf2html %)" htmlize h)
    #
    ## Applications used for text files -- currently only executable names in path
    ##  will be difficult to remove from both arrays, better to use a hash
    ##  However, a hash won't gaurantee positions in menu each time!
    typeset -Ag FT_EXTNS FT_ALIAS FT_OPTIONS
    typeset -Ag FT_ALIAS
    typeset -Ag FT_ALL_APPS FT_ALL_HK
    ## THis way could get long and tedious for some types like zip and others
    FT_ALIAS[md]="MARKDOWN"
    FT_ALIAS[htm]="HTML"
    FT_ALIAS[zsh]="TXT"   # lets me jump there rather than go through extns  NOOO
    FT_ALIAS[rb]="TXT"   # lets me jump there rather than go through extns
    FT_EXTNS[TXT]=" txt rb pl py java js c cpp cc css mk h Makefile Rakefile gemspec zsh sh rc conf md markdown TXT html htm"
    FT_EXTNS[ZIP]=" zip jar tgz bz2 arj gz Z "
    FT_EXTNS[BIN]=" o a class pyc lib "
    FT_EXTNS[SWAP]=" ~ swp "    # ends with ~ not an extension
    FT_EXTNS[IMAGE]=" png jpg jpeg gif "    # ends with ~ not an extension
    FT_EXTNS[VIDEO]=" flv mp4 "    # ends with ~ not an extension
    FT_EXTNS[AUDIO]=" mp3 m4a aiff aac ogg "    # ends with ~ not an extension
    FT_COMMON="open cmd mv trash auto clip chdir"
    
    ## options displayed when you select multiple files
    ##  Sadly, this is not taking into account filetypes selected, thatcould be helpful
    FT_OPTIONS[MULTI]="zip grep gitadd gitcom vim vimdiff ${FT_COMMON}"

    # These were variables like FT_TXT which allowded me to use an array inside if
    # i wanted but complicated programs since i need to derive the name. Since I am
    # using a string, might as well just use a hash, we can loop it then. 2013-01-18 - 19:27 
    PAGER=${PAGER:-less}
    FT_OPTIONS[TXT]="vim $PAGER archive tail head ${FT_COMMON}"
    FT_OPTIONS[OTHER]="$FT_COMMON od stat vim"
    FT_OPTIONS[IMAGE]="${FT_COMMON}"
    FT_OPTIONS[ZIP]="view tvf zless unzip zipgrep $FT_COMMON"
    FT_OPTIONS[SWAP]="vim cmd"
    ## in addiition to other commands for pdf's
    FT_OPTIONS[PDF]="pdftohtml pdfgrep w3mpdf"
    FT_OPTIONS[VIDEO]="open vlc mplayer ffmp ${FT_COMMON}"
    FT_OPTIONS[AUDIO]="open mpg321 afplay ${FT_COMMON}"
    FT_OPTIONS[HTML]="html2text w3m elvis sgrep"
    # now we need to define what constitutes markdown files such as MD besides MARKDOWN extension
    FT_OPTIONS[MARKDOWN]="Markdown.pl w3mmd multimarkdown"
    FT_OPTIONS[BIN]="od bgrep strings"
    #
    ## options for when a directory is selected
    # This doesn't allow us to do stuff inside a dir like mkdir or newfile since 
    #  we are not inside a dir
    # added 2013-01-23 - 20:46 
    FT_OPTIONS[DIR]="chdir archive trash du dush ncdu cmd"

    ## -- how to specify a space, no mnemonic?
    #FT_TEXT=(v vim : cmd l less # mv D ${ZFM_RM_COMMAND} z archive t tail h head o open a auto)
    typeset -Ag COMMAND_HOTKEYS
    COMMAND_HOTKEYS=(vim v cmd : mv \# trash D archive z zless l clip Y)

    typeset -Ag COMMANDS
    # remember that in such cases we have to check for file existing, overwriting etc
    # so it is not advisable unless you call a file, in viewing cases it is fine
    #COMMANDS[mv]='mv %% ${target}'
    COMMANDS[trash]="$ZFM_RM_COMMAND"
    COMMANDS[archive]="$ZFM_ZIP_COMMAND"
    COMMANDS[unzip]="$ZFM_UNZIP_COMMAND"
    #COMMANDS[chdir]="$ZFM_CD_COMMAND %% && post_cd"
    COMMANDS[dush]="du -sh"
    #COMMANDS[head]="head -25"
    #COMMANDS[tail]='tail -${lines} %%'
    COMMANDS[pdftohtml]='vim =(pdftohtml -stdout %%)'
    COMMANDS[w3mpdf]='w3m -T text/html =(pdftohtml -stdout %%)'
    COMMANDS[Markdown.pl]='Markdown.pl %% | $PAGER'
    COMMANDS[w3mmd]='w3m -T text/html =(Markdown.pl %%)'
    COMMANDS[gitadd]='git add'
    COMMANDS[gitcom]='git commit'
    ## convert selected flv file to m4a using ffmpeg
    COMMANDS[ffmp]='ffmpeg -i %% -vn ${${:-%%}:r}.m4a'
    COMMANDS[clip]='print %% | pbcopy && print "Copied filename to clipboard"'
    COMMANDS[tvf]='tar ztvf'
    # pdftohtml -stdout %% | links -stdin
    #FT_DEFAULT_PDF="pdftohtml"
    #export FT_TXT FT_ZIP FT_OTHERS COMMANDS COMMAND_HOTKEYS
}
function get_command_for_title() {
    print $COMMANDS[$1]
}
function zfm_bind_key() {
    # should we check for existing and refuse ?
    zfm_keymap[$1]=$2
    if (( ${+zfm_keymap[$1]} )); then
    else
        perror "Unable to bind $1 to keymap "
        pause
    fi
}
function zfm_unbind_key() {
    zfm_keymap["$1"]=()
}
function zfm_get_key_binding() {
    binding=$zfm_keymap[$1]
    ret=1
    [[ -n $binding ]] && ret=0
    [[ -z $binding ]] && pdebug "Nothing bound for $1"
    return $ret
}
## A separate mapping namespace
# If we use a separate hash we can print out mappings for C-x or prompt easily
# Generalized this for C-x and mapleader
#
function cx_map() {
    local kp=$ans
    local anskey mapkey
    anskey=$ans
    mapkey=$ans
    [[ $ans == '\' ]] && { anskey='\\' ; mapkey="ML"; }
    print -n "$anskey awaiting a key: "
    _read_keys
    #[[ -n $ckey ]] && reply=$ckey
    local key
    key="$mapkey $reply"
    binding=$zfm_keymap[$key]
    M_MESSAGE="$anskey $reply => $binding"
    ret=1
    [[ -n $binding ]] && { $binding ; ret=0 }
    [[ -z $binding ]] && { 
        perror "could not find [$key] in keymap" ;
        #for f ( ${(k)zfm_keymap}) print -l "[$f] ==> $zfm_keymap[$f]"
        #print -l "${(k)zfm_keymap}"
    }
    return $ret
}
#
## add a function to call on an event
#  Events are chdir 
#  Should be check event passed in or let it be open?
#  $1 - event
#  $2 - function to call when even happens
function add_hook() {
    zfm_hook[$1]+=" $2 "
}
function execute_hooks() {
    local event=$1
    shift
    local params
    params="$@"
    local hooks
    hooks=$zfm_hook[$event]
    hooks=("${(s/ /)hooks}")
    #perror "Executing $hooks..."
    for ev in $hooks; do
        #pinfo "  :: executing $ev"
        if [[ -x "$ev" ]]; then
            $ev $params
        else
            eval "$ev $params"
        fi
    done
}
function chdir_message() {
    [[ $#param -gt 0 ]] && M_MESSAGE="$M_HELP   <LEFT>: popd   <UP>: Parent dir"
}
function fileopen_hook () {
    [[ -z $1 ]] && { perror "fileopen_hook got no files. Check caller"; pause; }
    [[ -d $1 ]] && perror "$0 called with directory"
    local files
    files=($@)
    if [[ ${files[1][1]} == '/' ]]; then
    else
        files=($PWD/${^files}) # prepend PWD to each element
    fi
    ZFM_FILE_STACK+=($files)
}
function toggle_options_menu() {
    ## by default or first time pressing toggle key twice will toggle full-indexing
    # After that it toggles whatever the last toggle was. If that is too confusing
    # maybe i can set it to one option whatever is the most used.

    toggle_menu_last_choice=FullIndexing
    #ML_COLS=2 menu_loop "Toggle Options" "FullIndexing HiddenFiles FuzzyMatch IgnoreCase ApproxMatchToggle AutoView" "ihfcxa${ZFM_TOGGLE_MENU_KEY}"
    ML_COLS=2 menu_loop "Toggle Options" "FullIndexing HiddenFiles FuzzyMatch IgnoreCase MatchFromStart AutoView" "ihfcsa${ZFM_TOGGLE_MENU_KEY}"
    [[ $menu_text == $ZFM_TOGGLE_MENU_KEY ]] && { menu_text=$toggle_menu_last_choice }
    case "$menu_text" in
        "FullIndexing")
            full_indexing_toggle
            ;;
        "HiddenFiles")
            show_hidden_toggle
            ;;
        "FuzzyMatch")
            fuzzy_match_toggle
            ;;
        "IgnoreCase")
            ignore_case_toggle
            ;;
        "ApproxMatchToggle")
            approx_match_toggle
            ;;
        "MatchFromStart")
            toggle_match_from_start
            ;;
        "AutoView")
            pinfo "Autoview determines whether file selection automatically opens files for viewing or allow user to decide action"
            toggle_auto_view
            if [[ "$ZFM_AUTOVIEW_TOGGLE_KEY" == "1" ]]; then
                pinfo "Files will be viewed upon selection"
            else
                pinfo "Files will NOT be viewed upon selection. Other actions may be performed"
            fi
            ;;
        *)
            [[ -n $menu_text ]] && {
                perror "Wrong option [$menu_text]"
            }
    esac
    toggle_menu_last_choice=$menu_text
}
## called by POPD_KEY to pop back to previous dirs
#
function zfm_popd() {
    dirs
    popd && post_cd
    selection=
}
function zfm_show_menu() {
    if [[ -n "$M_SELECTION_MODE" ]]; then
        selection_menu
    else
        local olddir=$PWD
        view_menu
        [[ $olddir == $PWD ]] || {
            # dir has changed
            post_cd
        }
    fi
}
function goto_parent_dir() {
    #cd ..
    $ZFM_CD_COMMAND ..
    post_cd
}
function goto_dir() {
    # push directory before changing
    push_pwd
    #GOTO_PATH="/"
    GOTO_PATH=${GOTO_PATH:-"$HOME/"}
    # FIXME backspace etc issues in vared here, hist not working
    vared -h -p "Enter path: " GOTO_PATH
    selection=${(Q)GOTO_PATH}  # in case space got quoted, -d etc will all give errors
    PATT="" # 2012-12-26 - 00:54 
    push_pwd $selection
}
##
# directories user has visited in this session
# These are not all the dirs, only those specifically selected through some options
# We could save them on exit and read them up
#
function visited_dirs() {
    print
    menu_loop "Select a dir: " "$ZFM_DIR_STACK"
    [[ -n "$menu_text" ]] && { 
        $ZFM_CD_COMMAND $menu_text
        post_cd
    }
}
function visited_files() {
    print
    menu_loop "Select a file: " "$ZFM_FILE_STACK"
    [[ -n "$menu_text" ]] && { 
        fileopt $menu_text
    }
}
## 
## find files in current directory
#
function zfm_ffind() {
    # find files with string in filename, uses zsh (ffind)
    searchpattern=${searchpattern:-""}
    vared -p "Filename to search for (enter > 2 characters): " searchpattern
    [[ -z $searchpattern ]] && return 1
    # recurse and match filename only
    #files=$( print -rl -- **/*(.) | grep -P $searchpattern'[^/]*$' )
    # find is more optimized acco to zsh users guide
    # this won't work if user puts * in pattern.
    #files=$( print -rl -- **/*$searchpattern*(.) )
    files=("${(@f)$(print -rl -- **/*$searchpattern*(.) )}")
    #I get a blank returned so it passed and does not use find
    #Earlier it worked but failed on spaces in fiel name
    if [[ $#files -eq 0 || $files == "" ]]; then
        perror "Trying with find -iname, press a key"
        pause
        files=("${(@f)$(noglob find . -iname *$searchpattern*  )}")
        #files=$( find . -iname $searchpattern )
    else
    fi
    if [[ $#files -gt 0 ]]; then
        ## sort so latest come on top
        #files=$( print -N -- $files | xargs -0 ls -t )
        files=$( print -N $files | xargs -0 ls -t )
        handle_files $files
        #ZFM_FUZZY_MATCH_DIR="1" fuzzyselectrow $files
        selected_files=
        selected_file=
    else
        perror "No files matching $searchpattern"
    fi
}
function cd_old_new() {
    #$ZFM_CD_OLD_NEW_KEY)
    pbold "This implements the: cd OLD NEW metaphor"
    print "Part to change :"
    parts=(${(s:/:)PWD})
    menu_loop "Parts" "$(print $parts )"
    [[ -z "$menu_text" ]] && return 1
    pbold "Replace $menu_text"
    parts[$menu_index]='*'
    local newpath pp
    newpath=""
    ## join path with * in appropriate place
    for pp in $parts
    do
        newpath="${newpath}/${pp}"
    done
    newpath+="(/)"
    menu_loop "Select target ($newpath): " "$(eval print  $newpath)"
    [[ -n "$menu_text" ]] && { 
        $ZFM_CD_COMMAND $menu_text
        post_cd
    }
}
function sibling_dir() {
    # This should only have search and drill down functionality
    # so it can be reused by other parts such as viewoptions
    # to drill down, should be minimal and keep local stuff
    #
    # siblings (find a better place to put this, and what if there
    # are too many options)
    print "Siblings of this dir:"
    menu_loop "Siblings" "$(print ${PWD:h}/*(/) )"
    [[ -z "$menu_text" ]] && return 1
    [[ -d "$menu_text" ]] || {
        perror "$menu_text not a directory"
        return 1
    }
    print "selected $menu_text"
    $ZFM_CD_COMMAND $menu_text
    post_cd
}

## load any addons that might be present in addons folder
#
function source_addons() {
    local _d
    _d=${ZFM_DOTDIR:-$HOME/.zfm}
    _d=$_d/addons
    if [[ -d "$_d" ]]; then
        for exe ( $_d/*(xN) ) { 
            pdebug "sourcing $exe"
            source $exe
        }
    fi

}
## 
## Apply a filter to the list displayed.
#
function zfm_filter_list() {
    print
    print  "Add a command to filter file list, e.g. head / grep foo/ "
    vared -c -p "Enter filter: " M_CFILTER
}

## selects all visible rows
## Should only select files not dirs, since you can't deselect a dir
#
function zfm_select_all_rows() {
    for line in $vpa
    do
        pdebug "line $line"
        selected_row=("${(s/	/)line}")
        selected_file=$selected_row[-1]
        ## reject directories 
        if [[ -n "$M_SELECT_ALL_NO_DIRS" ]]; then
            [[ -d $selected_file ]] || selectedfiles+=( $PWD/$selected_file )
        fi
    done
    pinfo "selected files $#selectedfiles. "
    if [[ -n "$M_SELECTION_MODE" ]]; then
        pbold "Press $ZFM_SELECTION_MODE_KEY when done selecting"
    else
        # this is outside of selection mode

        M_NO_AUTO=1
        call_fileoptions $selectedfiles
        # This deals with a separate array -- doesn't have underscore
        #[[ $#selectedfiles -gt 1 ]] && multifileopt $selectedfiles
        #M_NO_AUTO=1
        #[[ $#selectedfiles -eq 1 ]] && fileopt $selectedfiles
        selectedfiles=()
        M_MESSAGE=
    fi
}
## Go into selection mode, so files selected will be added to list
#
function zfm_selection_mode_toggle() {
    #  This switches on selection so files will be added to a list
    if [[ -n "$M_SELECTION_MODE" ]]; then
        M_SELECTION_MODE=
        pinfo "Selected $#selectedfiles files"
        M_NO_AUTO=1
        call_fileoptions $selectedfiles
        #[[ $#selectedfiles -gt 1 ]] && multifileopt $selectedfiles
        #[[ $#selectedfiles -eq 1 ]] && fileopt $selectedfiles
        selectedfiles=()
        pbold "selection mode is off"
    else
        M_SELECTION_MODE=1
        pinfo "selection mode is on. After selecting files, use same key to toggle off and operate on files"
        pinfo "$ZFM_SELECT_ALL_KEY to select all, $ZFM_MENU_KEY for selection menu, $ZFM_TOGGLE_FILE_KEY to toggle file"
        aa=( Mode: "[Select]" $ZFM_SELECT_ALL_KEY "Select All" $ZFM_MENU_KEY "Selection Menu" $ZFM_TOGGLE_FILE_KEY "Toggle File"  $ZFM_SELECTION_MODE_KEY "Exit Mode")

        M_MESSAGE=$( print_hash $aa )
    fi
}
function zfm_toggle_file() {
    #selection=$PWD/$selection
    local selection="$1"
    ## if the user interactively selected then advance cursor like memacs does
    [[ -z $selection ]] && { selection=$PWD/$vpa[$CURSOR]; (( CURSOR++ )) ; }

    if [[ -n  ${selectedfiles[(re)$selection]} ]]; then
        pinfo "File $selection already selected, removing ..."
        i=$selectedfiles[(ie)$selection]
        selectedfiles[i]=()
        pinfo "File $selection unselected"
    else
        selectedfiles+=( $selection )
        pinfo "Adding $selection to array, $#selectedfiles "
    fi
}
## This expands dir under cursor, actually toggles expanded state
#  This places dir name in an array, however, it keeps only final part of dir not complete
#  path, so if "lib" is expanded in one dir, it will be expanded in others, and toggle off. XXX
function zfm_toggle_expanded_state() {
    local d _files fd
    d=$myopts[$CURSOR]
    fd=$PWD/$d
    # if exists, remove it
    if [[ $ZFM_EXPANDED_DIRS[(i)$fd] -le $#ZFM_EXPANDED_DIRS ]]; then
        ZFM_EXPANDED_DIRS[(i)$fd]=()
        zfm_refresh
        return
    fi
    ZFM_EXPANDED_DIRS+=($fd)
    if [[ -d "$fd" ]]; then
        _files=("${(@f)$(print -rl -- $d/*)}")
        for f in $_files ; do
            param+=( $f )
        done
    fi
}

# comment out next line if sourcing .. sorry could not find a cleaner way
myzfm
