#!/usr/bin/env zsh
# header {
# vim: set foldmarker={,} foldlevel=0 foldmethod=marker :
# ----------------------------------------------------------------------------- #
#         File: zfm.zsh
#  Description: file/dir browser/navigator using hotkeys
#       Author: rkumar http://github.com/rkumar/rbcurse/
#         Date: 2012-12-17 - 19:21
#      License: GPL
#  Last update: 2013-01-23 01:07
#   This is the new kind of file browser that allows selection based on keys
#   either chose 1-9 or drill down based on starting letters
#
#   In memory of my dear child Gabbar missing since Nov 13th, 2012.
# ----------------------------------------------------------------------------- #
#   Copyright (C) 2012-2013 rahul kumar

# TODO some keys are valid in a patter such as hyphen but can be shortcuts if no pattern.
# TODO what if user wants to send in some args suc as folder to start in, or resume where one left off.
# TODO If user does not use z/j/autojmp etc then we should have option to build dir database and save it
# Same for file edit list
# header }
ZFM_DIR=${ZFM_DIR:-~/bin}
export ZFM_DIR
export EDITOR=$VISUAL
source ${ZFM_DIR}/zfm_menu.zsh
source $ZFM_DIR/zfm_viewoptions.zsh
setopt MARK_DIRS
#ZFM_VERBOSE=
export M_FULL_INDEXING=
export TAB=$'\t'
set_auto_view
# for printing details 2012-12-30 - 16:57 
zmodload zsh/stat
zmodload -F zsh/stat b:zstat
PAGESZ=59     # used for incrementing while paging
#[[ -n "$M_FULL_INDEXING" ]] && PAGESZ=61
(( PAGESZ1 = PAGESZ + 1 ))

# list_printer {
#  list_printer "Directory Listing" ./*
#    param 1 title
#    rest is files to list
list_printer() {
    selection="" # contains return value if anything chosen
    #integer ZFM_COLS=$(tput cols) # it was here since it could change if resize, but not getting passed
    #integer ZFM_LINES=$(tput lines)
    #export ZFM_COLS ZFM_LINES
    local width=30
    local title=$1
    shift
    #local viewport vpa fin
    myopts=("${(@f)$(print -rl -- $@)}")
    #local cols=3
    # using cols to calculate cursor movement right
    cols=3
    local tot=$#myopts
    local sta=1
    #local patt="."
    #local patt=""
    # 2012-12-26 - 00:49 trygin this out so after a selection i don't lose what's filtered
    # but changing dirs must clear this, so it's dicey
    patt=${patt:-""}
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
            #  We are now using grep to filter based on what user types
            #  However, this means that our index is wrong since we don't save this new array
            #  Saving this array doesn't make sense since we truncate file name and add numbers and mnem
            #  to it - maybe caller should do this
            # THIS WORKS FINE but trying to avoid external commands
            #viewport=$(print -rl -- $myopts  | grep "$patt" | sed "$sta,${fin}"'!d')
            # this line replace grep and searches from start. if we plae a * after
            # the '#' then the match works throughout filename
            ic=${ZFM_IGNORE_CASE+i}
            approx=${ZFM_APPROX_MATCH+a1}
            # in case other programs need to display or account for, put in round bracks
            globflags="$ic$approx"
            # we keep filtering, not refreshing so deleted moved files still show up
            # the caller queries, and that sucks
            if [[ -z $M_MATCH_ANYWHERE ]]; then
                viewport=(${(M)myopts:#(#${ic}${approx})$patt*})
                mark="^"
            else
                viewport=(${(M)myopts:#(${ic}${approx})*$patt*})
                mark="*"
            fi
            let tot=$#viewport  # store the size of matching rows prior to paging it. 2013-01-09 - 01:37 
            [[ $fin -gt $tot ]] && fin=$tot
            # this line replaces the sed filter
            viewport=(${viewport[$sta, $fin]})
            vpa=("${(@f)$(print -rl -- $viewport)}")
            #vpa=("${(f)=viewport}")
            local ttcount=$#vpa
            ZFM_LS_L=
            if (( $ttcount <  (ZFM_LINES -2 ) )); then
                # need to account for title and read lines at least and message line
                cols=1
                # this could have the entire listing which contains TABS !!!
                (( width= ZFM_COLS - 2 ))
                ZFM_LS_L=1
            elif [[ $ttcount -lt 40 ]]; then
                cols=2
                (( width = (ZFM_COLS / cols) - 2 ))
            else
                cols=3
                # i can use 1 instead of 2, it touches the end, 2 to be safe for other widths
                (( width = (ZFM_COLS / cols) - 2 ))
            fi
            # NO, vpa is not entire thing, its grepped and filtered, so it can't be more than page size=
            #let tot=$#vpa
            [[ $fin -gt $tot ]] && fin=$tot
            local sortorder=""
            [[ -n $ZFM_SORT_ORDER ]] && sortorder="o=$ZFM_SORT_ORDER"
            (( CURSOR == -1 || CURSOR > $tot )) && CURSOR=$tot
            print_title "$title $sta to $fin of $tot ${COLOR_GREEN}$sortorder $ZFM_STRING ${globflags}${COLOR_DEFAULT}  "

            #print -rC$cols "${(@f)$(print -rl -- $viewport | numberlines -p "$patt" -w $width)}"
            numberlines -p "$patt" -w $width $viewport
            print -rC$cols "${(@f)$(print -l -- $OUTPUT)}"

            #print -n "> $patt"
            mode=
            [[ -n $M_SELECTION_MODE ]] && mode="[SEL $#selectedfiles] "
        fi # M_NO_REPRINT
        M_NO_REPRINT=
        #print -n "$mode${mark}$patt > "
        print -n "\r$mode${mark}$patt > "
        # prompt for key PROMPT
        #read -k -r ans
        _read_keys
        #M_MESSAGE=
        if [[ $? != 0 ]]; then
            # maybe ^C
            pdebug "Got C-c ? $reply, $key"
            key=''
            ans=''
            #break
        else
            [[ -n $ckey ]] && reply=$ckey
            ans="${reply}"
            #pdebug "Got ($reply)"
        fi
        #print 2013-01-21 - 00:09 due to \r in print
        #clear # trying this out # commenting out, if we don't reprint then clearing was wrong
        [[ $ans = $'\t' ]] && pdebug "Got a TAB XXX"
        [[ $ans = "C-i" ]] && ans=$'\t'
        [[ $ans = "" ]] && pdebug "Got a ESC XXX"
        case $ans in
            "")
                # BLANK blank
                (( sta = 1 ))
                patt="."
                patt=""
                ;;
            $ZFM_PAGE_KEY)
                # SPACE space, however may change to ENTER due to spaces in filenames
                (( sta += $PAGESZ1 ))
                [[ $fin -gt $tot ]] && fin=$tot
                ;;
            [1-9])
                # KEY PRESS key
                if [[ -n "$M_FULL_INDEXING" ]]; then
                    iix=$MFM_NLIDX[(i)$ans]
                    pinfo "got iix $iix for $ans"
                    [[ -n "$iix" ]] && selection=$vpa[$iix]
                    pinfo "selection was $selection"
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
                [[ -n $ZFM_VERBOSE ]] && pdebug "files shown $#vpa "
                if [[ $ttcount -gt 9 ]]; then
                    if [[ $patt = "" ]]; then
                        npatt="${ans}*"
                    else
                        npatt="$patt$ans"
                    fi
                    lines=
                    if [[ -n "$M_SWITCH_OFF_DUPL_CHECK" ]]; then
                        lines=$(check_patt $npatt)
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
                        patt=$npatt
                    fi
                else
                    # there are only 9 or less so just use mnemonics, don't check
                    # earlier
                    # XXX THIS will not work with spaces
                    #print " selected $viewport[(w)$ix] "
                    #selection=$viewport[(w)$ix]
                    selection=$vpa[$ans]
                    #selection=$myopts[$ix]
                    print " 1. selected $selection"
                fi
            fi # M_FULL
                [[ -n "$selection" ]] && break
                ;;
            "q")
                break
                ;;
            [a-zA-Z_0\.\ ])
                ## UPPER CASE upper section alpha characters
                (( sta = 1 ))

                if [[ -n "$M_FULL_INDEXING" ]]; then
                    iix=$MFM_NLIDX[(i)$ans]
                    pdebug "iix was $iix for $ans"
                    [[ -n "$iix" ]] && { selection=$vpa[$iix]; break }
                    pdebug "selection was $selection"

                else

                    if [[ $patt = "" ]]; then
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
                        patt="${ans}"
                    else
                        [[ -n $ZFM_VERBOSE ]] && pdebug "comes here 1"

                        patt="$patt$ans"
                    fi
                    #[[ $ans = '.' && $patt = '' ]] && patt="^\."
                    #pdebug "Pattern is $patt "
                    #[[ -n $ZFM_VERBOSE ]] && print "Pattern is :$patt:"
                    #[[ -n $ZFM_VERBOSE ]] && pdebug "sending $patt to chcek"
                    # if there's only one file for that char then just jump to it
                    lines=$(check_patt $patt)
                    ct=$(print -rl -- $lines | wc -l)
                    if [[ $ct -eq 1 ]]; then
                        [[ -n "$lines" ]] && { selection=$lines; break }
                    fi
                fi # M_FULL
                ;;
            $ZFM_REFRESH_KEY)
                pdebug "refreshing rescanning"
                zfm_refresh
                # why is next line not in post_cd 
                #myopts=("${(@f)$(print -rl -- $param)}")
                #break
                ;;
            "$ZFM_RESET_PATTERN_KEY")
                patt=""
                ;;
            "$ZFM_POPD_KEY")
                break
                ;; 
            "$ZFM_ACCEPT_FIRST_KEY")
                # Accept the first option shown, default is ENTER key
                # but if no files shown then what happens ?
                selection=$vpa[1]
                [[ -n "$selection" ]] && break
                ;; 
                # commenting out this on 2013-01-22 - 15:57 as it required
                # checking bindings here and in caller
            #","|"+"|"~"|":"|"\`"|"/"|"@"|"%"|"#"|"?"|'*'|$'\t')
            #","|"+"|"~"|":"|"/"|"@"|"%"|"#"|"?"|'*'|$'\t')
                # we break these keys so caller can handle them, other wise they
                # get unhandled PLACE SWALLOWED keys here to handle
                # go down to MARK1 section to put in handling code
                #[[ -n $ZFM_VERBOSE ]] && pdebug "breaking here with $ans , sel: $selection"
                #break
                #;;


            *) pdebug "default got :$ans:"
                (( sta = 1 ))
                ## a case within a case for the same var -- how silly
                case $ans in
                    "")
                        # BACKSPACE backspace if we are filtering, if blank and still backspace then put start of line char
                        if [[ $patt = "" ]]; then
                            #patt=""
                            M_NO_REPRINT=1
                        else
                            # backspace if we are filtering, remove last char from pattern
                            patt=${patt[1,${#patt}-1]}
                        fi
                        ;;
                    ".")
                        # reset the patter when pressing ,
                        patt=""
                        ;;
                    *)
                        # lets check if user or we have bound something to the key
                        # Now we should use this and bind everything, so its more modular
                        zfm_get_key_binding $ans
                        if [[ -n $binding ]]; then
                            $binding
                            ans=
                            break
                        else
                            #[[ "$ans" == "[" ]] && pdebug "got ["
                            #[[ "$ans" == "{" ]] && pdebug "got {"
                            pdebug "Key $ans unhandled and swallowed, pattern cleared. Use ? for key help"
                           #pinfo "? for key help"
                            #  put key in SWALLOW section to pass to caller
                            if [[ -n $patt ]]; then
                                patt=""
                            else
                                M_NO_REPRINT=1
                            fi
                            ## added on 2013-01-22 - 16:33 so caller can capture
                            break
                        fi
                        ;;
                esac
                [[ -n $ZFM_VERBOSE ]] && print "Pattern is :$patt:"
        esac
        [[ $sta -ge $tot ]] && break
        # break takes control back to MARK1 section below

    done
}
# }

toggle_match_from_start() {
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
check_patt() {
    local p=${1:s/^//}  # obsolete, refers to earlier grep version
    local ic=
    ic=${ZFM_IGNORE_CASE+i}
    approx=${ZFM_APPROX_MATCH+a1}
    if [[ -z $M_MATCH_ANYWHERE ]]; then
        # match from start - default
        lines=$(print -rl -- (#$ic${approx})${p}*)
    else
        lines=$(print -rl -- (#$ic${approx})*${p}*)
    fi
    # need to account for match from start
    print $lines
}
subcommand() {
    dcommand=${dcommand:-""}
    vared -p "Enter command (? - help): " dcommand
    [[ "$dcommand" = "q" || $dcommand = "quit" ]] && break
    case "$dcommand" in
        "S"|"save")
            push_pwd
            print "$ZFM_DIR_STACK"
        ;;
        "P"|"pop")
            pop_pwd
        ;;
        "f"|"file")
            if [[ -n $selectedfiles ]]; then
                pdebug "selected files: $#selectedfiles"

                if [[ $#selectedfiles -gt 1 ]]; then
                    multifileopt $selectedfiles
                else
                    fileopt_noauto $selectedfiles[1]
                fi
            else
                pinfo "No selected files. About $#vpa files on screen"
                if [[ $#vpa -eq 1 ]]; then
                    selection=${selection:-$vpa[1]}
                else
                    #pinfo "Please try selecting one or more files"
                fi
                if [[ -n "$selection" ]]; then
                    fileopt_noauto $selection
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
            print "'q' 'quit' - quit application"
            print "You may enter any other command too such as 'git status'"
            print
        ;;
        *)
        eval "$dcommand"
        ;;
    esac
    M_SELECTION_MODE=
    [[ "$dcommand" = "q" || $dcommand = "quit" ]] && quitting=1
    pause
}

#  add current dir to stack so we can pop back
#  We add it backwards so i can shift 
push_pwd() {
    ZFM_DIR_STACK=(
    $ZFM_DIR_STACK
    $PWD:q
    )
}
pop_pwd() {
    # remove from end
    newd=$ZFM_DIR_STACK[-1]
    ZFM_DIR_STACK[-1]=()
    # put it back on top (first)
    ZFM_DIR_STACK=(
    $newd:q
    $ZFM_DIR_STACK
    )
    # XXX maybe should cd to new top dir, not removed one.
    cd $newd
    pwd
    post_cd
}
#  executed when dir changed
post_cd() {
    patt=""
    filterstr=${filterstr:-M}
    param=$(eval "print -rl -- ${pattern}${M_EXCLUDE_PATTERN}(${MFM_LISTORDER}$filterstr)")
    [[ $#param -eq 0 ]] && {
        M_MESSAGE="$#param files, use UP or ZFM_GOTO_PARENT_KEY to go to parent folder, LEFT to popd"
    }
    CURSOR=1
    # clear hash of file details to avoid recomp
    FILES_HASH=()
}
zfm_refresh() {
    filterstr=${filterstr:-M}
    #param=$(eval "print -rl -- ${pattern}(${MFM_LISTORDER}$filterstr)")
    param=$(eval "print -rl -- ${pattern}${M_EXCLUDE_PATTERN}(${MFM_LISTORDER}$filterstr)")
    myopts=("${(@f)$(print -rl -- $param)}")
}
print_help_keys() {

    pbold "$ZFM_APP_NAME some keys"
    sed -e 's/^    //' <<EndHelp

    $ZFM_MENU_KEY	- Invoke menu (default: backtick)
    $ZFM_PAGE_KEY	- Paging of output (default SPACE)
    ^	- toggle match from start of filename
    $ZFM_GOTO_DIR_KEY	- Enter directory name to jump to
    $ZFM_FFIND_KEY	- Find a file for a pattern
    $ZFM_SELECTION_MODE_KEY	- Toggle selection mode
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

    Most keys are likely to change after getting feedback, the ** ones definitely will

EndHelp
pause
for key in ${(k)zfm_keymap} ; do
    print $key  : $zfm_keymap[$key]
done
#pbold "Key mappings"
print
pause
}

# utility }
# main {
#   alias this to some signle letter after sourceing this file in .zshrc
myzfm() {
##  global section
ZFM_APP_NAME="zfm"
ZFM_VERSION="0.1.2"
M_TITLE="$ZFM_APP_NAME $ZFM_VERSION 2013/01/22"
#print $M_TITLE
#  Array to place selected files
typeset -U selectedfiles
# hash of file details to avoid recomp each time while inside a dir
typeset -Ag FILES_HASH
#export FILES_HASH
selectedfiles=()
#export selectedfiles  # for nl.sh
#  directory stack for jumping back
typeset -U ZFM_DIR_STACK
ZFM_DIR_STACK=()
ZFM_CD_COMMAND="pushd" # earlier cd lets see if dirs affected
export ZFM_CD_COMMAND
ZFM_START_DIR="$PWD"
ZFM_FILE_SELECT_FUNCTION=fuzzyselectrow
export ZFM_FILE_SELECT_FUNCTION
export last_viewed_files

#  defaults KEYS
#ZFM_PAGE_KEY=$'\n'  # trying out enter if files have spaces and i need to type a space
ZFM_PAGE_KEY=${ZFM_PAGE_KEY:-' '}  # trying out enter if files have spaces and i need to type a space
ZFM_ACCEPT_FIRST_KEY=${ZFM_ACCEPT_FIRST_KEY:-$'\n'}  # pressing ENTER selects first
ZFM_MENU_KEY=${ZFM_MENU_KEY:-$'\`'}  # trying out enter if files have spaces and i need to type a space
ZFM_GOTO_PARENT_KEY=${ZFM_GOTO_PARENT_KEY:-','}  # goto parent of this dir 
ZFM_GOTO_DIR_KEY=${ZFM_GOTO_DIR_KEY:-'+'}  # goto parent of this dir 
ZFM_RESET_PATTERN_KEY=${ZFM_RESET_PATTERN_KEY:-'\'}  # reset the pattern, use something else
ZFM_POPD_KEY=${ZFM_POPD_KEY:-"<"}  # goto previously visited dir
ZFM_SELECTION_MODE_KEY=${ZFM_SELECTION_MODE_KEY:-"@"}  # toggle selection mode
ZFM_SORT_KEY=${ZFM_SORT_KEY:-"%"}  # change sort options
ZFM_FILTER_KEY=${ZFM_FILTER_KEY:-"#"}  # change filter options
ZFM_TOGGLE_MENU_KEY=${ZFM_TOGGLE_MENU_KEY:-"="}  # change toggle options
ZFM_SIBLING_DIR_KEY=${ZFM_SIBLING_DIR_KEY:-"["}  # change to sibling dirs
ZFM_CD_OLD_NEW_KEY=${ZFM_CD_OLD_NEW_KEY:-"]"}  # change to second cousins
ZFM_FFIND_KEY=${ZFM_FFIND_KEY:-'/'}  # reset the pattern, use something else
export ZFM_REFRESH_KEY=${ZFM_REFRESH_KEY:-'"'}  # refresh the listing
#export ZFM_NO_COLOR   # use to swtich off color in selection
M_SWITCH_OFF_DUPL_CHECK=
MFM_LISTORDER=${MFM_LISTORDER:-""}
M_EXCLUDE_PATTERN=
pattern='*' # this is separate from patt which is a temp filter based on hotkeys
filterstr="M"
MFM_NLIDX="123456789abcdefghijklmnoprstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
ZFM_STRING="${pattern}(${MFM_LISTORDER}$filterstr)"
integer ZFM_COLS=$(tput cols)
integer ZFM_LINES=$(tput lines)
integer CURSOR=1
export ZFM_COLS ZFM_LINES
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
    while (true)
    do
        list_printer "Directory Listing ${PWD} " $param
        # MARK1 section comes back when list_p breaks from SWALLOW
        [[ -n $selection ]] && print "returned with $selection"
        # value selected is in selection, key pressed in ans
        [[ -z "$selection" ]] && {
            [[ "$ans" = "q" || "$ans" = "" ]] && break
            case $ans in 
                "~")
                    selection=$HOME
                    ;;
                "$ZFM_SELECTION_MODE_KEY")
                    # maybe we could toggle
                    #  This switches on selection so files will be added to a list
                    if [[ -n "$M_SELECTION_MODE" ]]; then
                        M_SELECTION_MODE=
                        pinfo "array has $selectedfiles"
                        [[ $#selectedfiles -gt 1 ]] && multifileopt $selectedfiles
                        [[ $#selectedfiles -eq 1 ]] && fileopt_noauto $selectedfiles
                        selectedfiles=()
                        pbold "selection mode is off"
                    else
                        M_SELECTION_MODE=1
                        pinfo "selection mode is on. After selecting files, use same key to toggle off and operate on files"
                        pinfo "Use '*' to select all, $ZFM_MENU_KEY for selection menu"
                    fi
                    ;; 
                $ZFM_FFIND_KEY)
                    # find files with string in filename, uses zsh (ffind)
                        searchpattern=${searchpattern:-""}
                        vared -p "Filename to search for (enter > 2 characters): " searchpattern
                        # recurse and match filename only
                        #files=$( print -rl -- **/*(.) | grep -P $searchpattern'[^/]*$' )
                        # find is more optimized acco to zsh users guide
                        # this won't work if user puts * in pattern.
                        files=$( print -rl -- **/*$searchpattern*(.) )
                        if [[ $#files -eq 0 ]]; then
                            perror "trying with find"
                            files=$( find . -iname $searchpattern )
                        fi
                        if [[ $#files -gt 0 ]]; then
                            files=$( print $files | xargs ls -t )
                            ZFM_FUZZY_MATCH_DIR="1" fuzzyselectrow $files
                            # XXX careful we shold only use the array if one file
                            if [[ $#selected_files -eq 1 ]]; then
                                fileopt "$selected_file"
                            elif [[ $#selected_files -gt 1 ]]; then
                                multifileopt $selected_files
                            elif [[ -n "$selected_file" ]]; then
                                fileopt "$selected_file"
                            fi

                    else
                        perror "No files matching $searchpattern"
                    fi
                    ;;
                "?") 
                    print_help_keys
                    ;;
                '*')
                    for line in $vpa
                    do
                        print "line $line"
                        selected_row=("${(s/	/)line}")
                        selected_file=$selected_row[-1]
                        selectedfiles+=( $PWD/$selected_file )
                        #selectedfiles=(
                        #$selectedfiles
                        #$selected_file
                        #)
                    done
                    pinfo "selected files $#selectedfiles"
                    if [[ -n "$M_SELECTION_MODE" ]]; then
                        pbold "Press $ZFM_SELECTION_MODE_KEY when done selecting"
                    else
                        # this is outside of selection mode
                        [[ $#selectedfiles -gt 1 ]] && multifileopt $selectedfiles
                        [[ $#selectedfiles -eq 1 ]] && fileopt_noauto $selectedfiles
                        selectedfiles=()
                    fi
                    ;;
                *)
                    [[ "$ans" == $ZFM_REFRESH_KEY ]] && { perror "breaking";  break }
                    M_MESSAGE=
                    [[ -n $ans ]] && M_MESSAGE="$ans unused. $M_HELP"
                    ## NOTE messages will only be refreshed if key had some
                    #  effect, else unused key warning won't do anything since we dont
                    #  redraw.
                    #
                    #
                    # why repeat it here too, just do this once in top level
                    #  2013-01-22 - 16:04 removing second get_key
                    #zfm_get_key_binding $ans
                    #if [[ -n $binding ]]; then
                        ##perror "2 calling binding for $ans"
                        ##$binding
                    #else
                        # this sometimes is triggered even when a key has been
                        # used such as BACKSPACE
                        #pdebug "unhandled key $ans, type ? for key help"
                    #fi
                    ;;
            }

            #print "Blank selection"
            #read -k

        }
        if [[ -d "$selection" ]]; then
            [[ -n $ZFM_VERBOSE ]] && print "got a directory $selection"
            $ZFM_CD_COMMAND $selection
            post_cd
            #patt="" # 2012-12-26 - 00:54 
            #filterstr=${filterstr:-M}
            #param=$(eval "print -rl -- ${pattern}(${MFM_LISTORDER}$filterstr)")
        elif [[ -f "$selection" ]]; then
            # although nice to immediately open, but what if its not a text file
            # and what if i want to do something else
            #vim $selection
            if [[ -n "$M_SELECTION_MODE" ]]; then
                selection=$PWD/$selection
                if [[ -n  ${selectedfiles[(re)$selection]} ]]; then
                    pinfo "File $selection already selected, removing ..."
                    i=$selectedfiles[(ie)$selection]
                    selectedfiles[i]=()
                    pinfo "File $selection unselected"
                    pause
                else
                    selectedfiles=(
                    $selectedfiles
                    $selection
                    )
                    pinfo "Adding $selection to array, $#selectedfiles "
                fi
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
        #case $selection in 
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
numberlines() {
    let c=1
    local patt='.'
    if [[ -n "$ZFM_NO_COLOR" ]]; then
        BOLD='*'
        BOLD_OFF=''
    else
        BOLD=$COLOR_BOLD
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
    #for line in $viewport; do
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
                else
                    _detail="(deleted?)"
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
            ##perror "matching $#selct, ($line) , $selectedfiles[$c]" # XXX
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
        ### 2013-01-21 - 21:09 trying to do this in same process so hash be updated
        #print -l -- $_line
        OUTPUT+="$_line\n"
        let c++
    done
    #print -l -- $OUTPUT
} # numberlines

selection_menu() {
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
            local vp
            # this whole string quoting thing sucks so bad
            #vp=${viewport:q}
            vp=($PWD/${^viewport}) # prepend PWD to each element 2013-01-10 - 00:17
            selectedfiles=( ${vp:|selectedfiles} )
            #selectedfiles=( ${(Q)selectedfiles:q} )
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

function _read_keys() {

    local key key2 key3 key4
    integer ret
    ckey=

    ## 2013-01-21 - 00:19 trying out -s with M_NO_REPRINT
    read -k -s key
    ret=$?
    reply="${key}"
    if [[ '#key' -eq '#\\e' ]]; then
        # M-...
        read -t $(( KEYTIMEOUT / 1000 )) -k -s key2
        ret=$?
        if [[ "${key2}" == '[' ]]; then
            # cursor keys
            read -k -s key3
            ret=$?
            if [[ "${key3}" == [0-9] ]]; then
                # Home, End, PgUp, PgDn ...
                # F5 etc take a fifth key, so a loop
                #read -k -s key4
                #ret=$?
                #reply="${key}${key2}${key3}${key4}"
                reply="${key}${key2}${key3}"
                while (true); do
                    read -t $(( KEYTIMEOUT / 1000 )) -k -s key4
                    if [[ $? -eq 0 ]]; then
                        reply+="$key4"
                    else
                        break
                    fi
                done
            else
                # arrow keys
                reply="${key}${key2}${key3}"
            fi
            resolve_key_codes
        elif [[ $ret == "1" ]]; then
            # we have an escape
            ret=0
        elif [[ "${key2}" == 'O' ]]; then
            read -t $(( KEYTIMEOUT / 1000 )) -k -s key3
            if [[ $? -eq 0 ]]; then
                reply="${key}${key2}${key3}"
                resolve_key_codes
            fi
        else
            # alt keys
            reply="${key}${key2}"
            if (( key = 27 )); then
                x=$((#key2))
                y=${(#)x}
                ckey="M-$y"
            fi
        fi
    else
        reply="${key}"
        ascii=$((#key))
        # ctrl keys
        (( ascii >= 0 && ascii < 27 )) && { (( x = ascii + 96 ));  y=${(#)x}; ckey="C-$y"; }
    fi
    return $ret
}
# this is for those cases with 3 or 4 keys
resolve_key_codes() {
    typeset -A kh;
    kh[(27 91 54 126)]="PgDn"
    kh[(27 91 53 126)]="PgUp"
    kh[(27 91 65)]="UP"
    kh[(27 91 66)]="DOWN"
    kh[(27 91 67)]="RIGHT"
    kh[(27 91 68)]="LEFT"
    kh[(27 91 70)]="End"
    kh[(27 79 80)]="F1"
    kh[(27 79 81)]="F2"
    kh[(27 79 82)]="F3"
    kh[(27 79 83)]="F4"
    kh[(27 91 49 53 126)]="F5"
    kh[(27 91 49 55 126)]="F6"
    kh[(27 91 49 56 126)]="F7"
    kh[(27 91 49 57 126)]="F8"
    kh[(27 91 50 48 126)]="F9"
    kh[(27 91 50 49 126)]="F10"

    keyarr=()
    for (( i = 1; i <= $#reply; i++ )); do
        j=$reply[$i]
        k=$((#j))
        keyarr+=($k)
    done
    ckey=$kh[($keyarr)]
}
# this is the main menu used in the list when pressing MENU_KEY
# The purpose of initializing this is to make it configurable or modifiable through
# a config file
init_menu_options() {
    typeset -gA main_menu_command_hash
    main_menu_options=("f) File Listings" "r) Recursive Listings" "z|k) dirjump" "d) Dirs (child)" "v|l) filejump" "x) Exclude Pattern" "F) Filter options" "s) Sort Options" "c) Commands" "o) Options and Settings" "_) Last viewed file")
    main_menu_command_hash=(
        o settingsmenu
        f nonrecviewoptions
        r recviewoptions
        d m_child_dirs
        z m_dirstack
        k m_dirstack
        v m_recentfiles
        l m_recentfiles
        F filteroptions
        x get_exclude_pattern
        s sortoptions
        c mycommands
        _ edit_last_file
        )
}
init_key_function_map() {
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
                $'\t'
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
                $ZFM_SIBLING_DIR_KEY
                    sibling_dir
                $ZFM_CD_OLD_NEW_KEY
                    cd_old_new
                    )
    zfm_bind_key "M-x" "zfm_views"
    #zfm_bind_key "C-x" "zfm_views"
    zfm_bind_key "M-o" "settingsmenu"
    zfm_bind_key "M-s" "sortoptions"
    zfm_bind_key "M-f" "filteroptions"
    zfm_bind_key "F1" "print_help_keys"
    zfm_bind_key "F2" "goto_dir"
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
    FT_COMMON="open cmd mv trash auto clip"
    
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
    FT_OPTIONS[ZIP]="view zless unzip zipgrep $FT_COMMON"
    FT_OPTIONS[SWAP]="vim cmd"
    ## in addiition to other commands for pdf's
    FT_OPTIONS[PDF]="pdftohtml pdfgrep"
    FT_OPTIONS[VIDEO]="open vlc mplayer ffmp ${FT_COMMON}"
    FT_OPTIONS[AUDIO]="open mpg321 afplay ${FT_COMMON}"
    FT_OPTIONS[HTML]="html2text w3m elvis sgrep"
    # now we need to define what constitutes markdown files such as MD besides MARKDOWN extension
    FT_OPTIONS[MARKDOWN]="Markdown.pl w3m1 multimarkdown"
    FT_OPTIONS[BIN]="od bgrep strings"
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
    #COMMANDS[head]="head -25"
    #COMMANDS[tail]='tail -${lines} %%'
    COMMANDS[pdftohtml]='vim =(pdftohtml %%)'
    COMMANDS[Markdown.pl]='Markdown.pl %% | $PAGER'
    COMMANDS[w3m1]='w3m -T text/html =(Markdown.pl %%)'
    COMMANDS[gitadd]='git add'
    COMMANDS[gitcom]='git commit'
    ## convert selected flv file to m4a using ffmpeg
    COMMANDS[ffmp]='ffmpeg -i %% -vn ${${:-%%}:r}.m4a'
    COMMANDS[clip]='print %% | pbcopy && print "Copied filename to clipboard"'
    # pdftohtml -stdout %% | links -stdin
    #FT_DEFAULT_PDF="pdftohtml"
    #export FT_TXT FT_ZIP FT_OTHERS COMMANDS COMMAND_HOTKEYS
}
function get_command_for_title() {
    print $COMMANDS[$1]
}
zfm_bind_key() {
    # should we check for existing and refuse ?
    zfm_keymap[$1]=$2
}
zfm_unbind_key() {
    zfm_keymap[$1]=()
}
zfm_get_key_binding() {
    binding=$zfm_keymap[$1]
    ret=1
    [[ -n $binding ]] && ret=0
    return $ret
}
toggle_options_menu() {
    toggle_menu_last_choice=FullIndexing
    ML_COLS=2 menu_loop "Toggle Options" "FullIndexing HiddenFiles FuzzyMatch IgnoreCase ApproxMatchToggle AutoView" "ihfcxa${ZFM_TOGGLE_MENU_KEY}"
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
zfm_popd() {
    dirs
    popd && post_cd
    selection=
}
zfm_show_menu() {
    if [[ -n "$M_SELECTION_MODE" ]]; then
        selection_menu
    else
        local olddir=$PWD
        view_menu
        [[ $olddir == $PWD ]] || {
            # dir has changed
            post_cd
            #patt=""
            #filterstr=${filterstr:-M}
            #param=$(eval "print -rl -- ${pattern}(${MFM_LISTORDER}$filterstr)")
        }
    fi
}
function goto_parent_dir() {
    #cd ..
    $ZFM_CD_COMMAND ..
    post_cd
    #patt="" # 2012-12-26 - 00:54 
    #filterstr=${filterstr:-M}
    #param=$(eval "print -rl -- ${pattern}(${MFM_LISTORDER}$filterstr)")
}
function goto_dir() {
    push_pwd
    #GOTO_PATH="/"
    GOTO_PATH=${GOTO_PATH:-"$HOME/"}
    #stty erase 
    # FIXME backspace etc issues in vared here, hist not working
    vared -h -p "Enter path: " GOTO_PATH
    selection=${(Q)GOTO_PATH}  # in case space got quoted, -d etc will all give errors
    patt="" # 2012-12-26 - 00:54 
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

# comment out next line if sourcing .. sorry could not find a cleaner way
myzfm
#if [ "$(basename $0)" = "m.sh" ]
#then
    #myzfm
    ## this is running a as a command, run myfunc
#else
    #print "This is being sourced"
    #alias m=myzfm
    ## this is being sourced, make aliases
#fi
