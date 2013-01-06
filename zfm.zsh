#!/usr/bin/env zsh
# header {
# vim: set foldmarker={,} foldlevel=0 foldmethod=marker spell:
# ----------------------------------------------------------------------------- #
#         File: zfm.zsh
#  Description: file/dir browser/navigator using hotkeys
#       Author: rkumar http://github.com/rkumar/rbcurse/
#         Date: 2012-12-17 - 19:21
#      License: GPL
#  Last update: 2013-01-06 15:43
#   This is the new kind of file browser that allows selection based on keys
#   either chose 1-9 or drill down based on starting letters
#
#   In memory of my dear child Gabbar missing since Nov 13th, 2012.
# ----------------------------------------------------------------------------- #
#   Copyright (C) 2012-2013 rahul kumar

#  TODO cut erases BOLD face chars in long file names, need to trunc while printing in numberlines
#  TODO multiple selection
#    TODO select all
#    TODO invert selection
#    TODO maybe some spec *.txt etc
#    TODO select deselect ranges
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
ZFM_VERBOSE=1
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
    local width=30
    local title=$1
    shift
    #local viewport vpa fin
    myopts=("${(@f)$(print -rl -- $@)}")
    local cols=3
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
        (( fin = sta + $PAGESZ )) # 60
        [[ $fin -gt $tot ]] && fin=$tot
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
        # this line replaces the sed filter
        viewport=(${viewport[$sta, $fin]})
        vpa=("${(@f)$(print -rl -- $viewport)}")
        #vpa=("${(f)=viewport}")
        local ttcount=$#vpa
        ZFM_LS_L=
        if [[ $ttcount -lt 15 ]]; then
            cols=1
            width=80
            ZFM_LS_L=1
        elif [[ $ttcount -lt 40 ]]; then
            cols=2
            width=50
        else
            cols=3
            width=30
        fi
        # NO, vpa is not entire thing, its grepped and filtered
        #let tot=$#vpa
        [[ $fin -gt $tot ]] && fin=$tot
        local sortorder=""
        [[ -n $ZFM_SORT_ORDER ]] && sortorder="o=$ZFM_SORT_ORDER"
        print_title "$title $sta to $fin of $tot ${COLOR_GREEN}$sortorder $ZFM_STRING ${globflags}${COLOR_DEFAULT}"
        #print -rC$cols $(print -rl -- $viewport | numberlines -p "$patt" | cut -c-$width | tr "[ \t]" "?"  ) | tr -s "" |  tr "" " " 
        #print -rC$cols $(print -rl -- $viewport | numberlines -p "$patt" | cut -c-$width | tr " " ""  ) | tr -s "" |  tr "" " " 
        print -rC$cols $(print -rl -- $viewport | numberlines -p "$patt" | cut -c-$width | tr " \t" ""  ) | tr -s "" |  tr "" " \t" 
        #print -rC3 $(print -rl -- $myopts  | grep "$patt" | sed "$sta,${fin}"'!d' | nl.sh | cut -c-30 | tr "[ \t]" ""  ) | tr -s "" |  tr "" " " 

        #echo -n "> $patt"
        echo -n "${mark}$patt > "
        bindkey -s "OD" ","
        bindkey -s "OA" "~"
        read -k -r ans
        echo
        clear # trying this out
        [[ $ans = $'\t' ]] && pdebug "Got a TAB XXX"
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

                # FIXME XXX actix needs to be consistent in 2 cases:
                #   - when paging - correct is from myopts
                #   - when filtering. (in this case the correct is from viewport/vpa
                #   - there is a third case of paging after filtering GAAH
                (( ix = sta + $ans - 1))
                #[[ -n $ZFM_VERBOSE ]] && echo "actual ix $ix"
                #[[ -n $ZFM_VERBOSE ]] && echo "OLD selected $myopts[$ix] "
                #perror " vpa $ans : $vpa[$ans]  "
                #perror " vpa $ix : $vpa[$ix]  "
                #
                # NEW now check if 2 files satisfy this key (edge case but
                # could happen alot of you keep numbered files)
                selection=""
                #vpa=( $(print -rl -- $viewport) )
                [[ -n $ZFM_VERBOSE ]] && pdebug "files shown $#vpa "
                if [[ $ttcount -gt 9 ]]; then
                    if [[ $patt = "" ]]; then
                        npatt="${ans}*"
                    else
                        npatt="$patt$ans"
                    fi
                    if [[ -n "$M_SWITCH_OFF_DUPL_CHECK" ]]; then
                        lines=$(check_patt $npatt)
                        ct=$(print -rl -- $lines | wc -l)
                    else
                        ct=0
                    fi
                    [[ -n $lines ]] || ct=0
                    [[ -n $ZFM_VERBOSE ]] && pdebug "comes here $ct , $lines"
                    if [[ $ct -eq 1 ]]; then
                        [[ -n "$lines" ]] && { selection=$lines; break }
                    elif [[ $ct -eq 0 ]]; then
                        selection=$vpa[$ans]
                        #selection=$myopts[$ix] # fails on filtering
                        [[ -n $ZFM_VERBOSE ]] && echo " selected $selection"
                    else
                        patt=$npatt
                    fi
                else
                    # there are only 9 or less so just use mnemonics, don't check
                    # earlier
                    # XXX THIS will not work with spaces
                    #echo " selected $viewport[(w)$ix] "
                    #selection=$viewport[(w)$ix]
                    selection=$vpa[$ans]
                    #selection=$myopts[$ix]
                    echo " 1. selected $selection"
                fi
            fi # M_FULL
                [[ -n "$selection" ]] && break
                ;;
            ","|"+"|"~"|":"|"\`"|"/"|"@"|"%"|"#"|"?"|'*')
                # we break these keys so caller can handle them, other wise they
                # get unhandled PLACE SWALLOWED keys here to handle
                # go down to MARK1 section to put in handling code
                [[ -n $ZFM_VERBOSE ]] && pdebug "breaking here with $ans , sel: $selection"
                break
                ;;
            "^")
                # if you press this anywhere while typing it will toggle ^
                toggle_match_from_start
                ;;
            "q"|"")
                break
                ;;
            [a-zA-Z_0\.\ ])
                ## UPPER CASE upper section alpha characters
                (( sta = 1 ))

                if [[ -n "$M_FULL_INDEXING" ]]; then
                    iix=$MFM_NLIDX[(i)$ans]
                    pinfo "iix was $iix for $ans"
                    [[ -n "$iix" ]] && { selection=$vpa[$iix]; break }
                    pinfo "selection was $selection"

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
                    #[[ -n $ZFM_VERBOSE ]] && echo "Pattern is :$patt:"
                    #[[ -n $ZFM_VERBOSE ]] && pdebug "sending $patt to chcek"
                    # if there's only one file for that char then just jump to it
                    lines=$(check_patt $patt)
                    ct=$(print -rl -- $lines | wc -l)
                    if [[ $ct -eq 1 ]]; then
                        [[ -n "$lines" ]] && { selection=$lines; break }
                    fi
                fi # M_FULL
                ;;
            $ZFM_TOGGLE_MENU_KEY)
                menu_loop "Toggle Options" "FullIndexing HiddenFiles FuzzyMatch IgnoreCase ApproxMatchToggle AutoView" "ihfcxa"
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
                esac
                ;;
            $ZFM_REFRESH_KEY)
                pbold "refreshing rescanning"
                post_cd
                # why is next line not in post_cd 
                myopts=("${(@f)$(print -rl -- $param)}")
                #break
                ;;
            $ZFM_SIBLING_DIR_KEY)
                # XXX FIXME TODO sibling and next should move to caller
                # This should only have search and drill down functionality
                # so it can be reused by other parts such as viewoptions
                # to drill down, should be minimal and keep local stuff
                #
                # siblings (find a better place to put this, and what if there
                # are too many options)
                echo "Siblings of this dir:"
                menu_loop "Siblings" "$(print ${PWD:h}/*(/) )"
                echo "selected $menu_text"
                $ZFM_CD_COMMAND $menu_text
                patt="" # 2012-12-26 - 00:54 
                filterstr=${filterstr:-M}
                param=$(eval "print -rl -- ${pattern}(${MFM_LISTORDER}$filterstr)")
                break
                ;;
            $ZFM_CD_OLD_NEW_KEY)
                # XXX FIXME TODO this and next should move to caller
                # siblings (find a better place to put this, and what if there
                # are too many options)
                pbold "This implements the: cd OLD NEW metaphor"
                echo "Part to change :"
                parts=(${(s:/:)PWD})
                menu_loop "Parts" "$(print $parts )"
                pbold "Replace $menu_text"
                parts[$menu_index]='*'
                local newpath pp
                newpath=""
                for pp in $parts
                do
                    newpath="${newpath}/${pp}"
                done
                menu_loop "Select target" "$(eval print  $newpath)"
                [[ -n "$menu_text" ]] && { 
                    $ZFM_CD_COMMAND $menu_text
                    patt="" # 2012-12-26 - 00:54 
                    filterstr=${filterstr:-M}
                    param=$(eval "print -rl -- ${pattern}(${MFM_LISTORDER}$filterstr)")
                }
                break
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


            *) echo "default got :$ans:"
                (( sta = 1 ))
                ## a case within a case for the same var -- how silly
                case $ans in
                    "")
                        # backspace if we are filtering, if blank and still backspace then put start of line char
                        if [[ $patt = "" ]]; then
                            patt=""
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
                        [[ "$ans" == "[" ]] && echo "got ["
                        [[ "$ans" == "{" ]] && echo "got {"
                        pdebug "Key $ans unhandled and swallowed, pattern cleared. Use ? for key help"
                        pinfo "? for key help"
                        #  put key in SWALLOW section to pass to caller
                        patt=""
                        ;;
                esac
                [[ -n $ZFM_VERBOSE ]] && echo "Pattern is :$patt:"
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
# TODO needs to be aware of case 
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
    echo $lines
}
subcommand() {
    dcommand=${dcommand:-""}
    vared -p "Enter command (? - help): " dcommand
    [[ "$dcommand" = "q" || $dcommand = "quit" ]] && break
    case "$dcommand" in
        "S"|"save")
            push_pwd
            echo "$ZFM_DIR_STACK"
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
            echo
        ;;
        *)
        eval "$dcommand"
        ;;
    esac
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
    patt="" # 2012-12-26 - 00:54 
    filterstr=${filterstr:-M}
    param=$(eval "print -rl -- ${pattern}(${MFM_LISTORDER}$filterstr)")
}
zfm_refresh() {
    post_cd
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
}

# utility }
# main {
#   alias this to some signle letter after sourceing this file in .zshrc
myzfm() {
##  global section
ZFM_APP_NAME="zfm"
ZFM_VERSION="0.0.1zc"
echo "$ZFM_APP_NAME $ZFM_VERSION 2013/01/06"
#  Array to place selected files
typeset -U selectedfiles
selectedfiles=()
#export selectedfiles  # for nl.sh
#  directory stack for jumping back
typeset -U ZFM_DIR_STACK
ZFM_DIR_STACK=()
ZFM_CD_COMMAND="pushd" # earlier cd lets see if dirs affected
export ZFM_CD_COMMAND
ZFM_START_DIR="$PWD"

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
pattern='*' # this is separate from patt which is a temp filter based on hotkeys
filterstr="M"
MFM_NLIDX="123456789abcdefghijklmnoprstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
ZFM_STRING="${pattern}(${MFM_LISTORDER}$filterstr)"
export ZFM_STRING
param=$(print -rl -- *(M))
    while (true)
    do
        list_printer "Directory Listing ${PWD} " $param
        # MARK1 section comes back when list_p breaks from SWALLOW
        [[ -n $selection ]] && echo "returned with $selection"
        # value selected is in selection, key pressed in ans
        [[ -z "$selection" ]] && {
            [[ "$ans" = "q" || "$ans" = "" ]] && break
            case $ans in 
                "$ZFM_GOTO_PARENT_KEY")
                    cd ..
                    patt="" # 2012-12-26 - 00:54 
                    filterstr=${filterstr:-M}
                    param=$(eval "print -rl -- ${pattern}(${MFM_LISTORDER}$filterstr)")
                    ;;
                "$ZFM_GOTO_DIR_KEY")
                    push_pwd
                    #ppath="/"
                    ppath=${ppath:-"$HOME/"}
                    #stty erase 
                    # FIXME backspace etc issues in vared here, hist not working
                    vared -h -p "Enter path: " ppath
                    selection=${(Q)ppath}  # in case space got quoted, -d etc will all give errors
                    patt="" # 2012-12-26 - 00:54 
                    ;;
                "~")
                    selection=$HOME
                    ;;
                ":")
                    # COMMAND SECTION on directory level
                    # This could be made into something much more
                    #
                    subcommand
                    M_SELECTION_MODE=
                    [[ "$dcommand" = "q" || $dcommand = "quit" ]] && break
                    ;;
                "$ZFM_MENU_KEY")
                    if [[ -n "$M_SELECTION_MODE" ]]; then
                        selection_menu
                    else
                        local olddir=$PWD
                        view_menu
                        [[ $olddir == $PWD ]] || {
                        # dir has changed
                        patt=""
                        filterstr=${filterstr:-M}
                        param=$(eval "print -rl -- ${pattern}(${MFM_LISTORDER}$filterstr)")
                    }
                fi
                    #pause
                    ;; 
                "$ZFM_POPD_KEY")
                    dirs
                    popd && post_cd
                    selection=
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
                $ZFM_SORT_KEY)
                    sortoptions
                    ;;
                $ZFM_FILTER_KEY)
                    filteroptions
                    # FILTER filter section (think of a better key)
                    ;;
                $ZFM_FFIND_KEY)
                        # find files with string in filename, uses perl expressions and requires GNU grep (coreutils)
                        searchpattern=${searchpattern:-""}
                        vared -p "Filename to search for (enter 3 characters): " searchpattern
                        # recurse and match filename only
                        #files=$( print -rl -- **/*(.) | grep -P $searchpattern'[^/]*$' )
                        # find is more optimized acco to zsh users guide
                        files=$( print -rl -- **/*$searchpattern*(.) )
                        if [[ $#files -gt 0 ]]; then
                            files=$( echo $files | xargs ls -t )
                            ZFM_FUZZY_MATCH_DIR="1" fuzzyselectrow $files
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
                        echo "line $line"
                        selected_row=("${(s/	/)line}")
                        selected_file=$selected_row[-1]
                        selectedfiles=(
                        $selectedfiles
                        $selected_file
                        )
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
                    [[ "$ans" == $ZFM_REFRESH_KEY ]] && { break }
                    perror "unhandled key $ans, type ? for key help"
                    ;;
            }

            #echo "Blank selection"
            #read -k

        }
        if [[ -d "$selection" ]]; then
            [[ -n $ZFM_VERBOSE ]] && echo "got a directory $selection"
            $ZFM_CD_COMMAND $selection
            patt="" # 2012-12-26 - 00:54 
            filterstr=${filterstr:-M}
            param=$(eval "print -rl -- ${pattern}(${MFM_LISTORDER}$filterstr)")
        elif [[ -f "$selection" ]]; then
            # although nice to immediately open, but what if its not a text file
            # and what if i want to do something else
            #vim $selection
            if [[ -n "$M_SELECTION_MODE" ]]; then
                if [[ -n  ${selectedfiles[(r)$selection]} ]]; then
                    pinfo "File $selection already selected, removing ..."
                    i=$selectedfiles[(i)$selection]
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
    echo "bye"
    # do this only if is different from invoking dir
    [[ "$PWD" == "$ZFM_START_DIR" ]] || {
        echo "sending $PWD to pbcopy"
        echo "$PWD" | pbcopy
    }
} # myzfm
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
    ##local defpatt='.'
    local defpatt=""
    local selct=$#selectedfiles
    [[ $1 = "-p" ]] && { shift; patt="$1"; shift }
    # since string searching in zsh isn;t on regular expressions and ^ is not respected
    # i am taking width of match after removing ^ and using next char as next shortcut
    # # no longer required as i don't use grep, but i wish i still were since it allows better
    # matching
    patt=${patt:s/^//}
    local w=$#patt
    #let w++
    nlidx="123456789abcdefghijklmnoprstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    while IFS= read -r line; do
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
                mtime=$(zstat -L -F "%Y/%m/%d %H:%M" +mtime $line)
                zstat -L -H hash $line
                sz=$hash[size]
                link=$hash[link]
                [[ -n $link ]] && link=" -> $link"
                _detail="${TAB}$sz${TAB}$mtime${TAB}"
            else
                _detail="(deleted?)"
                # file does not exist so it could be deleted ?
            fi
        fi
    fi
    # only if there are selections we check against the array and color
    # otherwise no check, remember that the cut that comes later can cut the 
    # escape chars
    if [[ $selct -gt 0 ]]; then
        ##perror "matching $#selct, ($line) , $selectedfiles[$c]" # XXX
        # quoted spaces causing failure in matching,
        # however if i don't quote then other programs fail such as ls and tar
        if [[ $selectedfiles[(i)${line}] -gt $selct ]]; then
            print -r -- "$sub) $_detail $line"
        else
            print -- "$sub) $_detail ${BOLD}$line${BOLD_OFF}"
        fi
    else
        print -r -- "$sub) $_detail $line $link"
    fi
    let c++
done
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
            selectedfiles=( ${viewport:|selectedfiles} )
            #selectedfiles=( ${(Q)selectedfiles:q} )
            ;;


    esac
    if [[ -n $files ]]; then
        # don't quote files again in common loop or spaced files will not get added
        if [[ -n $ZFM_REMOVE_MODE ]]; then
            #files=( $files:q )
            selectedfiles=(${selectedfiles:|files})
        else

            # i think viewport has only file names, no details
            # so we can just do a one line operation
            common=( ${viewport:*files} )
            for line in $common
            do
                pdebug "line $line"
                selected_row=("${(s/	/)line}")
                selected_file=$selected_row[-1]
                selectedfiles=(
                $selectedfiles
                $selected_file
                )
            done
        fi
    fi
    pdebug "selected files $#selectedfiles"
}
# }
# comment out next line if sourcing .. sorry could not find a cleaner way
myzfm
#if [ "$(basename $0)" = "m.sh" ]
#then
    #myzfm
    ## this is running a as a command, run myfunc
#else
    #echo "This is being sourced"
    #alias m=myzfm
    ## this is being sourced, make aliases
#fi
