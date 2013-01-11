#!/usr/bin/env zsh
# Last update: 2013-01-11 17:40
# Part of zfm, contains menu portion
#
# ----------------------------------
# for menu_loop we need to source
source $ZFM_DIR/zfm_menu.zsh
# for vared stty -- but messes with vim !
#stty erase 
setopt EXTENDED_GLOB
ZFM_CD_COMMAND=${ZFM_CD_COMMAND:-"pushd"}
# pass in a list of files using a command such as:
# files=$(listdir.pl --file-type *(.m0) | nl)
# Displays a list of files and prompts user for a row number
# Then selects the row and filename
# Rows have columns delimited by tabs

# MENU that comes up on ZFM_MENU_KEY 
view_menu() {
    select_menu "Menu"  "f) File Listings" "r) Recursive Listings" "z|k) dirjump" "d) Dirs (child)" "v|l) filejump" "x) Exclude Pattern" "F) Filter options" "s) Sort Options" "c) Commands" "o) Options and Settings" "_) Last viewed file"
    # pressing menu key again, repeats last seletion
    [[ $reply == $ZFM_MENU_KEY ]] && reply=$view_menu_last_choice
    view_menu_last_choice=$reply
    case $reply in
        "o")
            settingsmenu
            ;;
        "f")
            nonrecviewoptions
            ;;
        "r")
            recviewoptions
            ;;
        "d")
            m_child_dirs
            ;;
        "z"|"k")
            m_dirstack
            ;;
        "v")
            ZFM_RECENT_MULTI=1
            m_recentfiles
            ;;
        "l")
            ZFM_RECENT_MULTI=
            m_recentfiles
            ;;
        "F")
            filteroptions
            ;;
        "x")
            M_EXCLUDE_PATTERN=${M_EXCLUDE_PATTERN:-"~(*.tgz|*.gz|*.z|*.bz2|*.zip)"}
            vared -p "Enter pattern to exclude from listings: " M_EXCLUDE_PATTERN
            ;;
        "s")
            sortoptions
            ;;
        "c")
            mycommands
            ;;
        "_")
            edit_last_file
            ;;
        *)
            perror "Wrong / unhandle option $reply"
            ;;
    esac
}
# this implements a drill-down which employs grep.
# You could call this fuzzy
# in that the pattern is not contiguous, if you press abc it matches "a.*b.*c"
#
fuzzyselectrow() {
    local files
    files=($@)
    [[ $#files -eq 0 ]] && return

    typeset -U deleted
    deleted=()
    selected_file=
    selected_files=
    #local rows= # try to columnate if more than 24 items, based on tput lines
    integer rows=$(tput lines)
    # should we try printing in 2 columns if items more than $rows
    ZFM_AUTO_COLUMNS=${ZFM_AUTO_COLUMNS:-"1"}
    ZFM_TRUNCATE=${ZFM_TRUNCATE:-"-1"}

    ff=("${(@f)$(print -rl -- $files)}")
    local gpatt="" # grep pattern which user types

    while (true)
    do
        viewport=$(print -rl -- $files  | grep "$gpatt")
        vpa=("${(@f)$(print -rl -- $viewport)}")
        local _hv=$#vpa # size of result after grep
        print  "   No.\t  Name"

        if [[ $ZFM_AUTO_COLUMNS == "1" && $_hv -gt $rows ]]; then
            # split into 2 columns
            print -rC2 -- "${(@f)$(print -rl -- $viewport | numbernine | sed "s#$HOME#~#g")}"
        else
            print -rl -- $viewport | numbernine
        fi
        # PROMPT prompt
        print  -n "Select a row [1-$_hv] ? Help, ESC/ENTER ($#deleted/$#vpa)/$gpatt/: "
        len=1
        read -k $len reply
        # if user enters a numeric and there are double digit values too
        # then wait for a second number. e.g. if he types 1 and there are 10 items
        # wait for another keypress for a second. BUt if he types 2 and there are less than
        # 20 then continue without taking another key
        if [[ "$reply" == <1-9> ]]; then
            (( tens = reply * 10 ))
            (( $#vpa >= tens )) && {
                read -k -t 1 ret1
                if [[  $? -eq 0 ]]; then
                    # check it is numeric not a CR, if no input then $? gives 1
                    if [[ $ret1 == <0-9> ]]; then
                        (( reply = reply * 10 + ret1 ))
                    fi
                fi

            }
        fi
        echo

    #
    #  pressing ENTER selects first item by default
    [[ $reply = $'\n'  ]] && {
        # typically in cases of directories pressing enter selects #1
        if [[ -n "$ZFM_SINGLE_SELECT" ]]; then
            reply=1 # in case of auto selection we need to exit with all select XXX
        #elif [[ $#deleted -eq 0 && $#vpa -eq 1 ]]; then
            # user has not selected anything, and there's only one row on screen
            # assume he is selecting
        elif [[ $#deleted -eq 0 ]]; then
            # user has not selected anything and presses enter, assume he selects first
            line="$vpa[1]"
            # only a physical tab was working, \t etc was not working
            # split row with tabs into an array
            selected_row=("${(s/	/)line}")
            selected_file=$selected_row[-1]
            break
        else
            # put all selection in selected_files and break
            # why are we keeping two arrays here, just keep selected CLEANUP 
            selected_files=()
            for line in $deleted
            do
                selected_files+=( $line )
            done
            pdebug "$#selected_files selected"
            break
        fi
    }


    [[ $reply = "" ]] && { pdebug "Got esc" ; selected_file=; selected_files=; break }
    pdebug "got $reply"
    [[ -z "$reply" ]] && break
    #  check for numeric as some values like "o" can cause abort
    if [[ "$reply" == <1-> ]]; then
        line="$vpa[$reply]"
        # only a physical tab was working, \t etc was not working
        # split row with tabs into an array
        selected_row=("${(s/	/)line}")
        selected_file=$selected_row[-1]
        if [[ -n "$ZFM_SINGLE_SELECT" ]]; then
            # select as a user presses a number and get out
            break # 2012-12-26 - 19:05 
        else
            # accumulate selection
            if [[ $deleted[(i)$selected_file] -le $#deleted ]]; then
                deleted[$deleted[(i)$selected_file]]=()
                pinfo "Removing $selected_file from list - $#deleted remaining"
            else
                deleted+=($selected_file)
                #deleted=(
                #$deleted
                #$selected_file
                #)
                pinfo "Adding $selected_file to list - $#deleted selected. Press ENTER when done"
            fi
        fi
    elif [[ "$reply" == "?" ]]; then
        print -rl  "Keys are <CR> Accept selection"
        print -rl  "         <ESC> Cancel"
        print -rl  "         [a-zA-Z] to narrow down search"
        print -rl  "         [1-9] to add to selection"
        print -rl  "         $ZFM_MENU_KEY menu"
        print -rl  "         ^ Toggle fuzzy mode"
        print -rl  "         = Toggle 2 columns"
        pause
    else
        #perror "Sorry. [$reply] not numeric"
        # Use chars to drill down
        #  Handling backspace
        if [[ "$reply" == "" || "$reply" == "" ]]; then
            if [[ -n "$gpatt" ]]; then
                gpatt=${gpatt[1,-2]}
                [[ $gpatt[-2,-1] == ".*" ]] && gpatt=${gpatt[1,-3]}
            fi
        elif [[ "$reply" == "=" ]]; then
            if [[ $ZFM_AUTO_COLUMNS == "1" ]]; then
                ZFM_AUTO_COLUMNS=
            else
                ZFM_AUTO_COLUMNS="1"
            fi
        elif [[ "$reply" == $ZFM_MENU_KEY ]]; then
            # files with spaces are getting split !!! 
            menu_loop "Options" "remove truncate rem_extn extn" ""
            case $menu_text in
                "remove")
                    print  "removes all files matching given pattern"
                    rejpattern=${rejpattern:-"tmp Trash Backups"}
                    vared -p "Enter pattern to reject: " rejpattern
                    #files=( $(print -rl -- $ff ) )
                    rejpattern=${rejpattern:gs/ /|/}
                    files=("${(@f)$(print -rl -- $ff | egrep -v "\.($rejpattern)$")}")
                    ;;
                "truncate")
                    print  "truncates beginning of files to shorten name, toggles "
                    (( ZFM_TRUNCATE = ZFM_TRUNCATE * -1 ))
                    #pdebug "truncate value is: $ZFM_TRUNCATE "
                    ;;
                "rem_extn")
                    print  "removes files for given extensions (space delim)"
                    xrejpattern=${xrejpattern:-"~ bak swp o pyo class lib"}
                    vared -p "Enter extensions to reject: " xrejpattern
                    xrejpattern=${xrejpattern:gs/ /|/}
                    files=("${(@f)$(print -rl -- $ff | egrep -v "\.($xrejpattern)$")}")
                    ;;
                "extn")
                    print  "only keep files for given extensions (space delim) remove others"
                    accpattern=${accpattern:-""}
                    vared -p "Enter pattern to accept: " accpattern
                    accpattern=${accpattern:gs/ /|/}
                    files=("${(@f)$(print -rl -- $ff | egrep "\.($accpattern)$")}")
                    ;;
            esac
            ff=( $files ) # XXX what if nothign changed above ?
        elif [[ "$reply" == "^" ]]; then
            fuzzy_match_toggle
            # remove .*s
            if [[ -n "$ZFM_FUZZY_MATCH_DIR" ]]; then
                gpatt=${gpatt:gs/*//}
                gpatt=${gpatt:gs/\.//}
            else
                local xx=""
                # insert .* between each char
                for ((i = 1; i <= $#gpatt; i++)); do xx="${xx}$gpatt[i].*"; done
                gpatt=$xx
            fi
        elif [[ -z "$gpatt" ]]; then
            gpatt="$reply"
        else
            if [[ "$ZFM_FUZZY_MATCH_DIR" == "1" ]]; then
                # contiguous search
                gpatt="${gpatt}${reply}"
            else
                gpatt="${gpatt}.*${reply}"
            fi
        fi
        pdebug "gpattern is $gpatt"
        if [[ $#files -eq 0 ]] ; then
            perror "No files for $gpatt. Use backspace or try another pattern"
       elif [[ $#files -eq 1 ]] ; then
           # if there's only one file than accept it, no confirmation and break
           if [[ -n $ZFM_NO_CONFIRM ]]; then
               selected_row=("${(s/	/)files}")
               selected_file=$selected_row[-1]
               break
           fi
       else
       fi
    fi
    done
}

# 
# Allow multiple selection of row, highlight selected row
# This allows deselection also
# Pressing <enter> completes selection
# 
selectmulti() {
    local files
    local tabd=$'\t'
    #files=$@
    files=($@)
    # selected rows go into a buffer named deleted
    # as they are no longer displayed
    typeset -U deleted
    deleted=()
    selected_files=
    local delix=1
    print  "Enter row numbers to select, press ENTER when finished selection"
    print  "  Press I to invert selection, A to select all"
    print  "  e opens EDITOR on selected files, z zips selected files"
    print  " Press 'S' for short 2-col list, 's' to revert to 1-col"
    echo
    local M_SHORT="1"
    local indices
    indices=( {1..$#files} )
    while (true) 
    do
        local c=1
        print  "No.\t  Size \t  Modified Date  \t  Name"
        #print -rl -- $files
        ff=("${(@f)$(print -rl -- $files)}")

        # print in 1 or 2 columns, if list is long, then print only filename
        # and break into 2 columns.
        #
        print -rC$M_SHORT -- $( \
        #for fil in $ff
        for ix in $indices
        do
            fil=$ff[$ix]
            # stores the entire row and matches entire row, so take care when shortening that only
            # filename is matched

            [[ $#deleted -gt 0 ]] && { delix=$deleted[(i)$fil]
            }
                # M_SHORT signifies how many columns, we try 2
                if [[ $M_SHORT == "2" ]]; then
                    row=("${(s/	/)fil}")
                    rfile=$row[-1]
                    fil=$rfile
                fi
            if [[ $delix -gt $#deleted ]]; then
                print  "$ix${tabd}$fil"
            else
                print  "$ix${tabd}${COLOR_BOLD}${fil}${COLOR_DEFAULT}"
            fi
            let c++

        done \
        | tr " \t" "" )  | tr "" " \t"

        print  -n "Select rows by number (ENTER when done, all-A, invert-I, reverse-R, e - edit, z - zip): "
        read -r reply
        [[ -z $reply ]] && { pdebug "breaking on blank" ; break }
        case $reply in
            "S")
                M_SHORT="2"
                ;;
            "s")
                M_SHORT="1"
                ;;
            "R")
                # reverse the output in case important files are no longer on screen
                #files=(${(Oa)files} )
                indices=(${(Oa)indices} )
                ;;
            "q")
                break
                ;;
            "e"|"z"|"v")
                break
                ;;
            "A") 
                pdebug "selected all"
                ff=("${(@f)$(print -rl -- $files)}")
                deleted+=($ff)
                #deleted=(
                #$deleted
                #$ff
                #)
                #break
                ;;
            'I')
                # invert selection
                ff=("${(@f)$(print -rl -- $files)}")
                deleted=( ${ff:|deleted} )
                #delix=0
                #ttmp=($deleted)
                #deleted=()
                #ff=("${(@f)$(print -rl -- $files)}")
                #for fil in $ff
                #do
                    #[[ $#ttmp -gt 0 ]] && 
                    #{ delix=$ttmp[(i)$fil]
                    ##print  "      [ $fi ] : delix, deleted: $delix => $#deleted "
                #}
                #if [[ $delix -gt $#ttmp ]]; then
                    #deleted+=($fil)
                    ##deleted=(
                    ##$deleted
                    ##$fil
                    ##)
                #fi
                #done
            ;; 
            *)

                if [[ "$reply" == <-> ]]; then
                    ff=("${(@f)$(print -rl -- $files)}")
                    line=${ff[$reply]}
                    # only a physical tab was working, \t etc was not working
                    #split
                    selected_row=("${(s/	/)line}")
                    selected_file=$selected_row[-1]
                    pdebug "selected: $selected_file"
                    if [[ $deleted[(i)$line] -le $#deleted ]]; then
                        deleted[$deleted[(i)$line]]=()
                    else
                        deleted+=($line)
                        #deleted=(
                        #$deleted
                        #$line
                        #)
                    fi
                    files=$( print -rl -- $ff)
                else
                    perror "Don't know what to do with $reply"
                fi
                ;;
    #*)
        #print  "default got $reply"
        #;;
esac
    done
    pdebug "selected were:"
    selected_files=()
    for line in $deleted
    do
        #print  "line $line"
        selected_row=("${(s/	/)line}")
        selected_file=$selected_row[-1]
        selected_files+=($selected_file)
        #selected_files=(
        #$selected_files
        #$selected_file
        #)
        pdebug " file: $selected_file "
    done
    pdebug " sm files: $#selected_files "
}
#
# recursive listing
#
recviewoptions() {
    M_REC_STRING="**/"
    M_ACK_REC_FLAG="-r"
    viewoptions
}
# non-recursive listing
nonrecviewoptions(){
    M_REC_STRING=""
    M_ACK_REC_FLAG="-n"
    viewoptions

}
# various canned listings like today's modified files or recent ones
viewoptions() {
    local str=""
    menu_loop "Directory views" "today ago recent largest dirs extn oldest substring ack" "tarldxosk"
    case $menu_text in
        "today")
            str="(.m0)"
            ;; 
        "ago")
            print  "Examples : 1 -1 2 -2  -5[1,10]  -10[10,20] "
            ago=${ago:-1}
            vared -p "Modified how many days ago: " ago
            str="(.m${ago})"
            ;; 
        "recent")
            str="(.om[1,15])"
            ;; 
        "oldest")
            str="(.Om[1,15])"
            ;; 
        "largest")
            #listdir.pl --file-type *(.OL[1,15])
            str="(.OL[1,15])"
            ;; 
        "extn" )
            print -n "Enter one extension e.g log tmp :"
            read extn
            files=$(eval "listdir.pl  ${M_REC_STRING}*.${extn}(.)" )
            #selectmulti $files
            $ZFM_FILE_SELECT_FUNCTION $files
            #[[ -n $ZFM_VERBOSE ]] && echo "file: $selected_file"
            ;;
        "substring" )
            print "Filenames containing pattern:"
            read patt
            files=$(eval "listdir.pl ${M_REC_STRING}*${patt}*(.)")
            print ${M_REC_STRING}*${patt}*(.)
            listdir.pl ${M_REC_STRING}*${patt}*(.)
            echo
            #selectmulti $files
            $ZFM_FILE_SELECT_FUNCTION $files
            #[[ -n $ZFM_VERBOSE ]] && echo "file: $selected_file"
            ;;
        "ack" )
            print "List / select Files containing string"
            cpattern=${cpattern:-""}
            vared -p "Enter pattern to search for: " cpattern
            #files=$(eval "listdir.pl $(ack -l $M_ACK_REC_FLAG $cpattern)" | nl)
            # somehow with eval only first row was coming through
            # maybe due to newlines
            pinfo "Using ack -l $M_ACK_REC_FLAG (-n non recursive, -r recursive)"
            files=$(ack -l $M_ACK_REC_FLAG $cpattern)
            if [[ $#files -gt 0 ]]; then
                files=$(listdir.pl $(ack -l $M_ACK_REC_FLAG $cpattern))
                #selectmulti $files
                $ZFM_FILE_SELECT_FUNCTION $files
            else
                pinfo "No files found containing $cpattern (using ack -l $M_ACK_REC_FLAG)"
            fi
            #[[ -n $ZFM_VERBOSE ]] && echo "file: $selected_file"
            ;;
        "dirs")
            # list dirs under current dir
            m_child_dirs
            #break
            ;; 
    esac
    [[ -n "$str" ]] && {
            #echo "listdir.pl --file-type ${M_REC_STRING}*${M_EXCLUDE_PATTERN}$str"
            files=$(eval "listdir.pl --file-type ${M_REC_STRING}*${M_EXCLUDE_PATTERN}$str")
            #selectmulti $files
            $ZFM_FILE_SELECT_FUNCTION $files
            [[ -n $ZFM_VERBOSE ]] && print  "files: $#selected_files"
        }
        # i am getting selects from a previous selection, i quit this time
    [[ $#selected_files -gt 0 ]] && {
        handle_selection "$reply" $selected_files
    }
}
# handle multiple selection
# e - use editor to edit
# q   don't do anything
# *  allow user to enter command
handle_selection() {
    local reply=$1
    shift
    selected_files=($@:q)
    #selected_files=${selected_files:q}
    #pdebug "handle_selection with $reply $#selected_files"

    case $reply in
        "q")
            selected_files=
            return
            #break
            ;;
        "e"|"v")
            eval "$EDITOR $selected_files"
            last_viewed_files=$selected_files
            ;;
        "z")
            local arch="$(date +%Y%m%d_%H%M).tgz"
            eval "tar zcvf $arch $selected_files"
            ls -l $arch
            ;;
        *)
            [[ $#selected_files -gt 0 ]] && {
            commandpost=${commandpost:-""}
            commandpre=${commandpre:-""}
            vared -p "Enter command (e.g. mv) :" commandpre
            [[ -z "$commandpre" ]] && { print "No action." ; return }
            vared -p "Enter command to place after filenames (e.g. target) :" commandpost
            pdebug "$commandpre $selected_files $commandpost"
            eval "$commandpre $selected_files $commandpost"
        }
        ;;
    esac
    selected_files=

}
#
#  toggle between full-indexing and drill down mode.
#  I think full-indexing will be useful in selection mode
#
full_indexing_toggle() {
    if [[ -z "$M_FULL_INDEXING" ]]; then
        M_FULL_INDEXING=1
    else
        M_FULL_INDEXING=
    fi
    export M_FULL_INDEXING
}
show_hidden_toggle() {
    if [[ -z "$M_SHOW_HIDDEN" ]]; then
        M_SHOW_HIDDEN=1
        setopt GLOB_DOTS
        pinfo "set glob_dots"
    else
        M_SHOW_HIDDEN=
        unsetopt GLOB_DOTS
        setopt NO_GLOB_DOTS
        pinfo "unset glob_dots"
    fi
    export M_SHOW_HIDDEN
}
fuzzy_match_toggle() {
    if [[ -z "$ZFM_FUZZY_MATCH_DIR" ]]; then
        ZFM_FUZZY_MATCH_DIR=1
    else
        ZFM_FUZZY_MATCH_DIR=
    fi
    export ZFM_FUZZY_MATCH_DIR
}
ignore_case_toggle() {
    if [[ -z "$ZFM_IGNORE_CASE" ]]; then
        ZFM_IGNORE_CASE=1
    else
        ZFM_IGNORE_CASE=
    fi
    export ZFM_IGNORE_CASE
}
approx_match_toggle() {
    if [[ -z "ZFM_APPROX_MATCH" ]]; then
        ZFM_APPROX_MATCH=1
    else
        ZFM_APPROX_MATCH=
    fi
    export ZFM_APPROX_MATCH
}
#
# Display selected files with an asterisk or using ANSI colors
# THis is because sometimes colors may not show, or long files can have the ANSI escape
# sequence truncated at end
#
color_toggle() {
    if [[ -z "$ZFM_NO_COLOR" ]]; then
        ZFM_NO_COLOR=1
        pinfo "Selected files will be displayed in bold"
    else
        ZFM_NO_COLOR=
        pinfo "Selected files will be displayed with a '*'"
    fi
    export ZFM_NO_COLOR
}
settingsmenu(){
    select_menu "Options" "i) Full Indexing toggle" "c) Case toggle" "h) Hidden files toggle" "p) Paging key" "4) Dupe check" \
        "a) Auto select action" "A) Toggle Auto Action" "x) Approximate match toggle" "C) Color toggle"
    case $reply in
        "i")
            full_indexing_toggle
            ;;
        "c")
            ignore_case_toggle
            ;;
        "x")
            approx_match_toggle
            ;;
        "h")
            pinfo "may work after changing directory, and should be set from Filters"
            show_hidden_toggle
            ;;
        "p")
            print  "Page key is (default <ENTER>: [$M_PAGE_KEY]"
            print  -n "Enter key to use for paging (should preferable not exist in filenames): "
            read -k cha
            M_PAGE_KEY=cha
            print  "Using page key: $cha"
            ;;
        "4")
            print  "When pressing hotkeys 1-9, we check if there are files with numbers in that position"
            print  "Without this check some numbered files can become inaccessible"
            print  "If you rarely use this, you can switch it off here, or permanently at top of source"
            if [[ -z "$M_SWITCH_OFF_DUPL_CHECK" ]]; then
                M_SWITCH_OFF_DUPL_CHECK=1
            else
                M_SWITCH_OFF_DUPL_CHECK=
            fi
            export M_SWITCH_OFF_DUPL_CHECK
            ;;
        "k")
            print  "Change the character used for various functions (Enter leaves them as they are"

            print  "TODO someday not immed"
            # what is this anyway ? changing hotkeys ?
            # menu
            # back (up dir)
            # sort options
            # filter options
            # freq dirs
            # freq files

            ;;
        "a")
            # specify action with various filetypes
            # Misses out on OTHER category, not sure what to do
            # but some text files land in there, `file` says "data".
            echo
            print  "Type Ctrl-u to clear line"
            print  "Blank line disables auto action"
            echo
            ZFM_AUTO_TEXT_ACTION=${ZFM_AUTO_TEXT_ACTION:-$EDITOR}
            ZFM_AUTO_IMAGE_ACTION=open
            ZFM_AUTO_ZIP_ACTION="tar ztvf"
            print  "Choose automatic action when selecting a text-file"
            vared ZFM_AUTO_TEXT_ACTION
            print  "Choose automatic action when selecting an image file"
            vared ZFM_AUTO_IMAGE_ACTION
            print  "Choose automatic action when selecting a zip file"
            vared ZFM_AUTO_ZIP_ACTION
            export ZFM_AUTO_ZIP_ACTION ZFM_AUTO_IMAGE_ACTION ZFM_AUTO_TEXT_ACTION
            ;;
        "A")
            toggle_auto_view
            ;;
        "C")
            color_toggle
            ;;
    esac

}
#  toggle between automatuc viewing on selection, the other mode
#  being that the fileopt menu is opened
toggle_auto_view(){
    if [[ "$ZFM_AUTOVIEW_TOGGLE_KEY" == "1" ]]; then
        unset_auto_view
    else
        set_auto_view
    fi
}
set_auto_view(){
    ZFM_AUTOVIEW_TOGGLE_KEY="1"
    ZFM_AUTO_IMAGE_ACTION=${ZFM_AUTO_IMAGE_ACTION_BAK:-"open"}
    ZFM_AUTO_TEXT_ACTION=${ZFM_AUTO_TEXT_ACTION_BAK:-$EDITOR}
    ZFM_AUTO_ZIP_ACTION=${ZFM_AUTO_ZIP_ACTION_BAK:-"tar ztvf"}
    export ZFM_AUTO_ZIP_ACTION ZFM_AUTO_IMAGE_ACTION ZFM_AUTO_TEXT_ACTION
}
unset_auto_view(){
    ZFM_AUTOVIEW_TOGGLE_KEY=
    ZFM_AUTO_TEXT_ACTION_BAK=$ZFM_AUTO_TEXT_ACTION
    ZFM_AUTO_ZIP_ACTION_BAK=$ZFM_AUTO_ZIP_ACTION
    ZFM_AUTO_IMAGE_ACTION_BAK=$ZFM_AUTO_IMAGE_ACTION
    ZFM_AUTO_IMAGE_ACTION=
    ZFM_AUTO_TEXT_ACTION=
    ZFM_AUTO_ZIP_ACTION=
}
filteroptions() {
    menu_loop "Filter Options " "Today Files Dirs Recent Old Large Pattern Small Hidden Links Clear" "tfdrolpshLc"
    # XXX usage of o or O clashes with sort order and gives error, FIXME
    case $menu_text in
        "Files")
            filterstr="."
            ;;
        "Dirs")
            filterstr="/"
            ;;
        "Recent")
            filterstr=".om[1,15]"
            filterstr=".m-7"
            ;;
        "Today")
            filterstr=".m0"
            ;;
        "Old")
            filterstr="Om[1,15]"
            filterstr="m+365"
            ;;
        "Large")
            filterstr="OL[1,15]"
            filterstr="Lm+2"
            ;;
        "Pattern")
            pattern=${pattern:-'*'}
            vared -p "Enter pattern: " pattern
            pattern=${pattern:-"*"}
            ;;
        "Small")
            filterstr="oL[1,15]"
            filterstr="L-1024"
            ;;
        "Hidden")
            filterstr="D${filterstr}"
            ;;
        "Links")
            filterstr="@"
            ;;
        "Clear")
            filterstr="M"
            ;;
    esac
    filterstr=${filterstr:-M}
    ZFM_STRING="${pattern}(${MFM_LISTORDER}$filterstr)"
    export ZFM_STRING
    param=$(eval "print -rl -- ${pattern}(${MFM_LISTORDER}$filterstr)")
    export param
}
sortoptions() {
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
    ZFM_SORT_ORDER=$menu_text
    export ZFM_SORT_ORDER
    #param=$(eval "print -rl -- *${MFM_LISTORDER}")
    filterstr=${filterstr:-M}
    ZFM_STRING="${pattern}(${MFM_LISTORDER}$filterstr)"
    export ZFM_STRING
    param=$(eval "print -rl -- ${pattern}(${MFM_LISTORDER}$filterstr)")
    export param
}
# cycle through various views
# This should include long listings
zfm_views() {
    #typeset -A views
    #views=(om Newest Om Oldest OL Largest oL smallest)
    views=(om Om OL oL On on /)
    viewlabels=(Newest Oldest Largest Smallest Reverse Name Dirs)
    viewcount=${viewcount:-0}
    let viewcount++
    (( viewcount > $#views )) && viewcount=0 # zero so that normal view (default) can be shown

    MFM_LISTORDER=$views[$viewcount]
    ZFM_SORT_ORDER=$viewlabels[$viewcount]
    export ZFM_SORT_ORDER
    #param=$(eval "print -rl -- *${MFM_LISTORDER}")
    filterstr=${filterstr:-M}
    ZFM_STRING="${pattern}(${MFM_LISTORDER}$filterstr)"
    export ZFM_STRING
    param=$(eval "print -rl -- ${pattern}(${MFM_LISTORDER}$filterstr)")
    export param

}
# give directories from dirs command
m_dirstack() {
    if [[ -x "${ZFM_DIR}/zfmdirs" ]]; then
        #files=$(listdir.pl $(${ZFM_DIR}/zfmdirs) | nl)
        files=$(print -rl -- $(${ZFM_DIR}/zfmdirs))
    else
        # this only works when this file is sourced, otherwise relies on current session
        # not what is in your zshrc
        pbold "These are directories on internal stack (dirs command)"
        files=$(eval "listdir.pl $(dirs)" )
    fi
    pbold "Recent Directories"
    ZFM_SINGLE_SELECT=1 fuzzyselectrow $files
    [[ -d $selected_file ]] && {
        $ZFM_CD_COMMAND $selected_file
    }

}
m_child_dirs() {
    local ff
    ff=$(print -rl -- *(/) | wc -l)
    [[ $ff -eq 0 ]] && { perror "No child dirs." ; return }
    if [[ $ff -gt 0 ]]; then
        # only send dir name, not details.
        #files=$(eval "print -rl -- ${M_REC_STRING}*(/)" | nl)
        files=$(eval "print -rl -- ${M_REC_STRING}*(/)" )
    #else
        #files=$(eval "listdir.pl --file-type ${M_REC_STRING}*(/)" | nl)
    fi
    pbold "Directories"
    ZFM_SINGLE_SELECT=1 fuzzyselectrow $files
    [[ -d $selected_file ]] && {
        [[ -n $ZFM_VERBOSE ]] && print  "file: $selected_file"
        $ZFM_CD_COMMAND $selected_file
    }
}
m_recentfiles() {
    # recently edited files
    typeset -U files
    files=""
    if [[ -x "${ZFM_DIR}/zfmfiles" ]]; then
        # next line resulted in spaces getting broken into multiple files
        #files=( $(${ZFM_DIR}/zfmfiles) )
        files=("${(@f)$(${ZFM_DIR}/zfmfiles )}")  # reqd to prevent wrapping on spaces - ugh
        #pdebug "1 got $#files"
        (( $#files < 15 )) && {
            # if i don't put N then crashes out if no files for match
            files+=( *(.Nom[1,10]) )  # add 10 recent files from current dir if not enough
        }
    else
        perror "No ~/.viminfo file found"
        # fuzzy doesn't expect dettails i think - it can but won't be able to color bold any longer
        #files=$(listdir.pl *(.m0) ~/.vimrc ~/.zshrc ~/.bashrc ~/.screenrc ~/.tmux.conf)
        files=( *(.om[1,10]) ~/.vimrc ~/.zshrc ~/.bashrc ~/.screenrc ~/.tmux.conf)
        # if no files for today add recent files here TODO
    fi
    [[ -n "$files" ]] && {
        pbold "Recent files"
        if [[ -n "$ZFM_RECENT_MULTI" ]]; then
            $ZFM_FILE_SELECT_FUNCTION $files
            [[ $#selected_files -gt 0 ]] && {
                handle_selection "$reply" $selected_files
            }
        else
            tmpfuzz=$ZFM_FUZZY_MATCH_DIR
            # we want a contiguous match, not fuzzy
            ZFM_FUZZY_MATCH_DIR="1"
            $ZFM_FILE_SELECT_FUNCTION $files
            ZFM_FUZZY_MATCH_DIR=$tmpfuzz
            #perror "XXX $#selected_files ,, $selected_file"
            if [[ $#selected_files -eq 1 ]]; then
                fileopt "$selected_file"
            elif [[ $#selected_files -gt 1 ]]; then
                multifileopt $selected_files
            elif [[ -e "$selected_file" ]]; then
                fileopt "$selected_file"
            fi
        fi
    }
}
# select_menu "A menu" "r) recursive menu" "l) listing files" "o) Options and setttings"
select_menu() {
    local title="$1"
    shift
    local moptions
    moptions=( "$@" )
    print  "${COLOR_BOLD}${title}${COLOR_DEFAULT}"
    for o in $moptions
    do
        print  "  $o"
    done
    print  -n "Select :"
    read -k reply
    echo
}
mycommands() {
    source $ZFM_DIR/zfmcommands.zsh
    IFS=$ZFM_MY_DELIM menu_loop "My Commands" "$ZFM_MY_COMMANDS${ZFM_MY_DELIM:-' '}cmd" "${ZFM_MY_MNEM}!"
    local zcmd z

    # check for internall defined function, removing spaces
    pdebug "menu_text is $menu_text"
    z=${menu_text:gs/ //}
    zcmd=ZFM_$z
    #print  "testing $zcmd"
    type $zcmd >/dev/null
    stat=$?
    if [[ $stat -eq 0 ]]; then
        # call internal function
        $zcmd
    elif [[ "$menu_text" = "cmd" ]]; then
        command=${command:-""}
        vared -p "Enter command: " command
        [[ -n "$command" ]] && eval "$command"

    elif [[ -x "$menu_text" ]]; then
        # not sure it will come here
        eval "$menu_text"
    else
        # check for executable by that name in path
        type $menu_text >/dev/null
        stat=$?
        if [[ $stat -eq 0 ]]; then
            eval "$menu_text"
        else
            # doesn't come here
            perror "could not find [$menu_text]"
            command=${command:-""}
            vared -p "Enter command: " command
            [[ -n $command ]] && eval "$command"
        fi
    fi
}

# numbers the first nine rows only since these are hotkeys
# the rest must be filtered by some character.
numbernine() {
    let c=1
    local tabd=$'\t'
    local selct=$#deleted
    local csel cres
    integer maxct=99

    while IFS= read -r line; do
        sub="$c)"
        if [[ $c -gt $maxct ]]; then
            sub="  "
            #print -r -- "  ${tabd}$line"
        else
            #print -r -- "$sub)${tabd}$line"
        fi
        if [[ $selct -gt 0 ]]; then
            if [[ $deleted[(i)$line] -gt $selct ]]; then
                #print -r -- "$sub) $line"
                csel=
                cres=
            else
                csel=${COLOR_BOLD}
                cres=${COLOR_DEFAULT}
                #print -- "$sub) ${COLOR_BOLD}$line${COLOR_DEFAULT}"
            fi
        else
            #print -r -- "$sub) $line"
        fi
        if [[ "$ZFM_TRUNCATE" -eq 1 ]]; then
            line=${line[-40,-1]}
        fi
        print -- "$sub ${csel}$line${cres}"
        let c++
    done
}
edit_last_file() {
    print "Last viewed : $last_viewed_files"
    [[ -n $last_viewed_files ]] && $EDITOR $last_viewed_files
}
