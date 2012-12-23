#!/usr/bin/env zsh
# header {
# vim: set foldmarker={,} foldlevel=0 foldmethod=marker spell:
# ----------------------------------------------------------------------------- #
#         File: m.sh
#  Description: file/dir navigator based on hotkeys
#       Author: rkumar http://github.com/rkumar/rbcurse/
#         Date: 2012-12-17 - 19:21
#      License: GPL
#  Last update: 2012-12-23 22:15
#   This is the new kind of file browser that allows section based on keys
#   either chose 1-9 or drill down based on starting letters
#
#   In memory of my dear child Gabbar missing since Nov 13th, 2012.
# ----------------------------------------------------------------------------- #
#   Copyright (C) 2012 rahul kumar

#  TODO show dirs in another color _HOWTO since i hand over to print
#  TODO multiple selection
#    TODO select all
#    TODO invert selection
#    TODO maybe some spec *.txt etc
#    TODO select deselect ranges
#  Specify automatic action for files when selected, so menu not popped up.
#  TODO jump withing deeply nested structures like we do "cd extras experimental" bookmark ?
# header }
ZFM_DIR=${ZFM_DIR:-~/bin}
export ZFM_DIR
source ${ZFM_DIR}/menu.zsh
setopt MARK_DIRS
M_VERBOSE=1
export M_FULL_INDEXING=
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
    local viewport vpa fin
    myopts=("${(@f)$(print -rl -- $@)}")
    local cols=3
    local tot=$#myopts
    local sta=1
    #local patt="."
    local patt=""
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
        if [[ -z $M_MATCH_ANYWHERE ]]; then
            viewport=(${(M)myopts:#$patt*})
        else
            viewport=(${(M)myopts:#*$patt*})
        fi
        # this line replaces the sed filter
        viewport=(${viewport[$sta, $fin]})
        vpa=("${(@f)$(print -rl -- $viewport)}")
        #vpa=("${(f)=viewport}")
        local ttcount=$#vpa
        if [[ $ttcount -lt 15 ]]; then
            cols=1
            width=80
        elif [[ $ttcount -lt 40 ]]; then
            cols=2
            width=40
        else
            cols=3
            width=30
        fi
        # NO, vpa is not entire thing, its grepped and filtered
        #let tot=$#vpa
        [[ $fin -gt $tot ]] && fin=$tot
        print_title "$title $sta to $fin of $tot"
        print -rC$cols $(print -rl -- $viewport | nl1.sh -p "$patt" | cut -c-$width | tr "[ \t]" "?"  ) | tr -s "" |  tr "" " " 
        #print -rC3 $(print -rl -- $myopts  | grep "$patt" | sed "$sta,${fin}"'!d' | nl.sh | cut -c-30 | tr "[ \t]" ""  ) | tr -s "" |  tr "" " " 

        #echo -n "> $patt"
        echo -n "$patt > "
        bindkey -s "OD" ","
        bindkey -s "OA" "~"
        read -k -r ans
        echo
        clear # trying this out
        [[ $ans = $'\t' ]] && perror "Got a TAB XXX"
        [[ $ans = "" ]] && perror "Got a ESC XXX"
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
                #[[ -n $M_VERBOSE ]] && echo "actual ix $ix"
                #[[ -n $M_VERBOSE ]] && echo "OLD selected $myopts[$ix] "
                #perror " vpa $ans : $vpa[$ans]  "
                #perror " vpa $ix : $vpa[$ix]  "
                #
                # NEW now check if 2 files satisfy this key (edge case but
                # could happen alot of you keep numbered files)
                selection=""
                #vpa=( $(print -rl -- $viewport) )
                [[ -n $M_VERBOSE ]] && perror "files shown $#vpa "
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
                    [[ -n $M_VERBOSE ]] && perror "comes here $ct , $lines"
                    if [[ $ct -eq 1 ]]; then
                        [[ -n "$lines" ]] && { selection=$lines; break }
                    elif [[ $ct -eq 0 ]]; then
                        selection=$vpa[$ans]
                        #selection=$myopts[$ix] # fails on filtering
                        [[ -n $M_VERBOSE ]] && echo " selected $selection"
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
            ","|"+"|"~"|":"|"\`"|"@"|"%"|"#")
                # we break these keys so caller can handle them, other wise they
                # get unhandled PLACE SWALLOWED keys here to handle
                # go down to MARK1 section to put in handling code
                [[ -n $M_VERBOSE ]] && perror "breaking here with $ans"
                break
                ;;
            "^")
                # if you press this anywhere while typing it will toggle ^
                toggle_match_from_start
                ;;
            "q")
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
                        echo "I should only set and do this if nothing is showing of its off"
                        pbold "Setting glob_dots ..."
                        setopt GLOB_DOTS
                        #setopt globdots
                        param=$(eval "print -rl -- ${pattern}(${MFM_LISTORDER}$filterstr)")
                        myopts=("${(@f)$(print -rl -- $param)}")
                        pbold "count is $#myopts"
                    }
                        patt="${ans}"
                    else
                        [[ -n $M_VERBOSE ]] && perror "comes here 1"

                        patt="$patt$ans"
                    fi
                    #[[ $ans = '.' && $patt = '' ]] && patt="^\."
                    pinfo "Pattern is $patt "
                    [[ -n $M_VERBOSE ]] && echo "Pattern IS :$patt:"
                    [[ -n $M_VERBOSE ]] && perror "sending $patt to chcek"
                    # if there's only one file for that char then just jump to it
                    lines=$(check_patt $patt)
                    ct=$(print -rl -- $lines | wc -l)
                    #perror "comes here $ct , $lines"
                    if [[ $ct -eq 1 ]]; then
                        [[ -n "$lines" ]] && { selection=$lines; break }
                    fi
                fi # M_FULL
                ;;
            "[")
                # siblings (find a better place to put this, and what if there
                # are too many options)
                echo "Siblings of this dir:"
                menu_loop "Siblings" "$(print ${PWD:h}/*(/) )"
                echo "selected $menu_text"
                cd $menu_text
                filterstr=${filterstr:-M}
                param=$(eval "print -rl -- ${pattern}(${MFM_LISTORDER}$filterstr)")
                break
                ;;
            "]")
                # siblings (find a better place to put this, and what if there
                # are too many options)
                pbold "This implements the: cd OLD NEW "
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
                    cd $menu_text
                    filterstr=${filterstr:-M}
                    param=$(eval "print -rl -- ${pattern}(${MFM_LISTORDER}$filterstr)")
                }
                break
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
                        perror "Key $ans unhandled and swallowed"
                        #  put key in SWALLOW section to pass to caller
                        patt=""
                        ;;
                esac
                [[ -n $M_VERBOSE ]] && echo "Pattern is :$patt:"
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
    #if [[ -n "$M_SWITCH_OFF_DUPL_CHECK" ]]; then
        #echo ""
    #else
        local p=${1:s/^//}
        #perror "check got pattern:$p:"
        lines=$(print -rl -- ${p}*)
        #echo $lines | wc -l
        echo $lines
    #fi
}

# utility }
# main {
#   alias this to some signle letter after sourceing this file in .zshrc
myzfm() {
##  global section
ZFM_VERSION="0.0.0"
echo "zfm $ZFM_VERSION 2012/12/23"
#  Array to place selected files
typeset -U selectedfiles
selectedfiles=()

#  defaults
#ZFM_PAGE_KEY=$'\n'  # trying out enter if files have spaces and i need to type a space
ZFM_PAGE_KEY=${ZFM_PAGE_KEY:-' '}  # trying out enter if files have spaces and i need to type a space
ZFM_MENU_KEY=${ZFM_MENU_KEY:-$'\`'}  # trying out enter if files have spaces and i need to type a space
ZFM_GOTO_PARENT_KEY=${ZFM_GOTO_PARENT_KEY:-','}  # goto parent of this dir 
ZFM_GOTO_DIR_KEY=${ZFM_GOTO_DIR_KEY:-'+'}  # goto parent of this dir 
M_SWITCH_OFF_DUPL_CHECK=
MFM_LISTORDER=${MFM_LISTORDER:-""}
pattern='*'
filterstr="M"
MFM_NLIDX="123456789abcdefghijklmnoprstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
param=$(print -rl -- *(M))
    while (true)
    do
        list_printer "Directory Listing ${PWD} " $param
        # MARK1 section comes back when list_p breaks from SWALLOW
        [[ -n $selection ]] && echo "returned with $selection"
        # value selected is in selection, key pressed in ans
        [[ -z "$selection" ]] && {
            [[ "$ans" = "q" ]] && break
            case $ans in 
                "$ZFM_GOTO_PARENT_KEY")
                    cd ..
                    #param=$(print -rl -- *${MFM_LISTORDER})
                    #param=$(eval "print -rl -- *${MFM_LISTORDER}")
                    filterstr=${filterstr:-M}
                    param=$(eval "print -rl -- ${pattern}(${MFM_LISTORDER}$filterstr)")
                    ;;
                "$ZFM_GOTO_DIR_KEY")
                    ppath="/"
                    #stty erase 
                    # FIXME backspace etc issues in vared here, hist not working
                    vared -h -p "Enter path: " ppath
                    selection=$ppath
                    ;;
                "~")
                    selection=$HOME
                    ;;
                ":")
                    selection=
                    # COMMAND SECTION on directory level
                    #
                    dcommand=${dcommand:-""}
                    vared -p "Enter command: " dcommand
                    [[ "$dcommand" = "q" || $dcommand = "quit" ]] && break
                    eval "$dcommand"
                    pause
                    ;;
                "$ZFM_MENU_KEY")
                    local olddir=$PWD
                    source $ZFM_DIR/m_viewoptions.zsh
                    view_menu
                    [[ $olddir == $PWD ]] || {
                        filterstr=${filterstr:-M}
                        param=$(eval "print -rl -- ${pattern}(${MFM_LISTORDER}$filterstr)")
                    }
                    #pause
                    ;; 
                "@")
                    # maybe we could toggle
                    #  This switches on selection so files will be added to a list
                    if [[ -n "$M_SELECTION_MODE" ]]; then
                        M_SELECTION_MODE=
                        pinfo "array has $selectedfiles"
                        [[ $#selectedfiles -ge 1 ]] && multifileopt $selectedfiles
                        selectedfiles=()
                        pbold "selection mode is off"
                    else
                        M_SELECTION_MODE=1
                        pbold "selection mode is on"
                    fi
                    ;; 
                "%")
                    # LIST list section (think of a better key)
                    menu_loop "Sort Order" "newest oldest largest smallest name rname dirs clear" "nolsmrdc"
                    case $menu_text in
                        "newest")
                            MFM_LISTORDER="om"
                            ;;
                        "oldest")
                            MFM_LISTORDER="Om"
                            ;;
                        "largest")
                            MFM_LISTORDER="OL"
                            ;;
                        "smallest")
                            MFM_LISTORDER="oL"
                            ;;
                        "name")
                            MFM_LISTORDER="on"
                            ;;
                        "rname")
                            MFM_LISTORDER="On"
                            ;;
                        "dirs")
                            MFM_LISTORDER="/"
                            ;;
                        "clear")
                            MFM_LISTORDER=""
                            ;;
                    esac
                    #param=$(eval "print -rl -- *${MFM_LISTORDER}")
                    filterstr=${filterstr:-M}
                    param=$(eval "print -rl -- ${pattern}(${MFM_LISTORDER}$filterstr)")
                    ;;
                "#")
                    filteroptions
                    # FILTER filter section (think of a better key)
                    ;;

                *)
                    perror "unhandled key $ans"
                    ;;
            }

            #echo "Blank selection"
            #read -k

        }
        if [[ -d "$selection" ]]; then
            [[ -n $M_VERBOSE ]] && echo "got a directory $selection"
            cd $selection
            #param=$(print -rl -- *)
            #param=$(eval "print -rl -- *${MFM_LISTORDER}")
            filterstr=${filterstr:-M}
            param=$(eval "print -rl -- ${pattern}(${MFM_LISTORDER}$filterstr)")
        elif [[ -f "$selection" ]]; then
            # although nice to immediately open, but what if its not a text file
            # and what if i want to do something else
            #vim $selection
            if [[ -n "$M_SELECTION_MODE" ]]; then
                if [[ -n  ${selectedfiles[(r)$selection]} ]]; then
                    perror "File $selection already selected, removing ..."
                    i=$selectedfiles[(i)$selection]
                    selectedfiles[i]=()
                    pinfo "File $selection unselected"
                    pause
                else
                    selectedfiles=(
                    $selectedfiles
                    $selection:q
                    )
                    pinfo "Adding $selection to array, $#selectedfiles "
                fi
            else
                fileopt $selection
                pause
            fi
        else
            [[ -n "$selection" ]] && {
                pbold "Don't know how to handle $selection"
                file $selection
                pause
            }
        fi
        #case $selection in 
    done
    echo "bye"
}
# }
# comment out next line if sourcing .. sorry could not find a cleaner way
myzfm
