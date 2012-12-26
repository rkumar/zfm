#!/usr/bin/env zsh
# Last update: 2012-12-26 17:09
# Part of zfm, contains menu portion
# FIXME Issue this uses its own selection mechanism whereas user would 
# have got used to key based drill down. This is purely number based
# Create a scripts that drills down a list use nl1 also. provide a list
#
# don't use system calls for ls, just the array itself
# ----------------------------------
# for menu_loop we need to source
source $ZFM_DIR/zfm_menu.zsh
# for vared stty -- but messes with vim !
#stty erase 
setopt EXTENDED_GLOB
ZFM_CD_COMMAND=${ZFM_CD_COMMAND:-"pushd"}
# pass in a list of files using a command such as:
# Displays a list of files and prompts user for a row number
# Then selects the row and filename
# Rows have columns delimited by tabs
# files=$(listdir.pl --file-type *(.m0) | nl)
view_menu() {
    select_menu "Menu" "o) Options and Settings" "f) File Listings" "r) Recursive Listings" "k) Dirstack" "d) Dirs (child)" "b) Bookmarks" "x) Exclude Pattern" "F) Filter options" "s) Sort Options" "c) Commands"
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
        "k")
            m_dirstack
            ;;
        "b")
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
        *)
            perror "Wrong / unhandle option $reply"
            ;;
    esac
}

# select a single row, based on line number which has been supplied with data
# (I know the line number coming in is not a good idea)
selectrow() {
    local files=$@
    [[ $#files -eq 0 ]] && return
    ff=("${(@f)$(print -rl -- $files)}")
    local hv=$#ff
    if [[ $hv -gt 24 ]]; then
        # split into 2 columns, hopefully only name was sent in and not details
        echo "   No.\t  Name"
        #print -rC2 -- $files 
        print -rC2 -- $(print -rl -- $files | tr "[ \t]" "" ) | tr "" " "
    else
        echo "   No.\t  Size \t  Modified Date  \t  Name"
        print -rl -- $files 
    fi
    local len=$#hv  # accept only those many characters from user
    echo -n "Select a row [1-$hv] (blank to cancel): "
    read -k $len reply
    echo

    # if using read -k then we need to make enter into a blank
    reply=$(echo "$reply" | tr -d '[\n\r\t ]')

    [[ -z "$reply" ]] && return
    #  check for numeric as some values like "o" can cause abort
    if [[ "$reply" == <-> ]]; then
        line="$ff[$reply]"
        # only a physical tab was working, \t etc was not working
        # split row with tabs into an array
        selected_row=("${(s/	/)line}")
        #selected_file=$selected_row[4]
        # just in case only file name passed as in dirnames
        selected_file=$selected_row[-1]
    else
        perror "Sorry. [$reply] not numeric"
    fi
}
# this implemnents select multiple with deletion of selected item
# into another buffer, looks nice as the list shrinks, but doesn't
# allow for unselection of item
selectrows() {
    local files
    files=$@
    # selected rows go into a buffer named deleted
    # as they are no longer displayed
    deleted=()
    while (true) 
    do
        echo "   No.\t  Size \t  Modified Date  \t  Name"
        print -rl -- $files | nl
        echo -n "select row (all-A, invert-I, e - edit, z - zip): "
        read -r reply
        [[ -z $reply ]] && { echo "breaking on blank" ; break }
        case $reply in
            "z"|"e"|"v")
                # zips selected files, pref don't select zips
                break
                ;;
            "A") 
                echo "selected all"
                ff=("${(@f)$(print -rl -- $files)}")
                deleted=(
                $deleted
                $ff
                )
                break
                ;;
            'I')
                # invert selection
                ttmp=("${(@f)$(print -rl -- $files)}")
                files=( $deleted )
                #ff=("${(@f)$(print -rl -- $files)}")
                deleted=($ttmp)
                #files=()
                ;; 
            [1-9][0-9]*)

        ff=("${(@f)$(print -rl -- $files)}")
        line=${ff[$reply]}
        # only a physical tab was working, \t etc was not working
        #split
        selected_row=("${(s/	/)line}")
        selected_file=$selected_row[4]
        echo $selected_file
        deleted=(
        $deleted
        $line
        )
        ff[$reply]=()
        files=$( print -rl -- $ff)
esac
    done
    echo "selected were:"
    selected=()
    for line in $deleted
    do
        #echo "line $line"
        selected_row=("${(s/	/)line}")
        selected_file=$selected_row[4]
        selected=(
        $selected
        $selected_file:q
        )
        echo "   >>>> file: $selected_file "
    done
    #echo "::: selected array"
    #echo $selected
}
# Allow multiple selection of row, highlight selected row
# This allows deselection also
# Pressing <enter> completes selection
selectmulti() {
    local files
    files=$@
    # selected rows go into a buffer named deleted
    # as they are no longer displayed
    typeset -U deleted
    deleted=()
    local delix=1
    echo "Enter row numbers to select, press ENTER when finished selection"
    echo "  Press I to invert selection, A to select all"
    echo "  e opens EDITOR on selected files, z zips selected files"
    echo
    while (true) 
    do
        echo "   No.\t  Size \t  Modified Date  \t  Name"
        #print -rl -- $files
        ff=("${(@f)$(print -rl -- $files)}")
        for fi in $ff
        do
            [[ $#deleted -gt 0 ]] && { delix=$deleted[(i)$fi]
            #echo "      [ $fi ] : delix, deleted: $delix => $#deleted "
            }
            if [[ $delix -gt $#deleted ]]; then
                echo "$fi"
            else
                echo "${COLOR_BOLD}${fi}${COLOR_DEFAULT}"
            fi

        done
        echo -n "select rows (ENTER when done, all-A, invert-I, e - edit, z - zip): "
        read -r reply
        [[ -z $reply ]] && { echo "breaking on blank" ; break }
        case $reply in
            "q")
                break
                ;;
            "e"|"z"|"v")
                break
                ;;
            "A") 
                echo "selected all"
                ff=("${(@f)$(print -rl -- $files)}")
                deleted=(
                $deleted
                $ff
                )
                #break
                ;;
            'I')
                # invert selection
                delix=0
                ttmp=($deleted)
                deleted=()
                ff=("${(@f)$(print -rl -- $files)}")
                for fi in $ff
                do
                    [[ $#ttmp -gt 0 ]] && 
                    { delix=$ttmp[(i)$fi]
                    #echo "      [ $fi ] : delix, deleted: $delix => $#deleted "
                }
                if [[ $delix -gt $#ttmp ]]; then
                    deleted=(
                    $deleted
                    $fi
                    )
                fi
            done
            ;; 
            *)

        ff=("${(@f)$(print -rl -- $files)}")
        line=${ff[$reply]}
        # only a physical tab was working, \t etc was not working
        #split
        selected_row=("${(s/	/)line}")
        selected_file=$selected_row[4]
        echo $selected_file
        if [[ $deleted[(i)$line] -le $#deleted ]]; then
            deleted[$deleted[(i)$line]]=()
        else
            deleted=(
            $deleted
            $line
            )
        fi
        files=$( print -rl -- $ff)
        ;;
    #*)
        #echo "default got $reply"
        #;;
esac
    done
    echo "selected were:"
    selected_files=()
    for line in $deleted
    do
        #echo "line $line"
        selected_row=("${(s/	/)line}")
        selected_file=$selected_row[4]
        selected_files=(
        $selected_files
        $selected_file:q
        )
        echo " file: $selected_file "
    done
}
# recursive listing
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
    menu_loop "Directory views" "today ago recent largest dirs extn oldest substring ack" "tarldxos"
    case $menu_text in
        "today")
            str="(.m0)"
            ;; 
        "ago")
            echo "Examples : 1 -1 2 -2  -5[1,10]  -10[10,20] "
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
            print -n "Enter extension e.g log tmp :"
            read extn
            files=$(eval "listdir.pl  ${M_REC_STRING}*.${extn}(.)" | nl)
            selectmulti $files
            #[[ -n $ZFM_VERBOSE ]] && echo "file: $selected_file"
            ;;
        "substring" )
            print "Filenames containing pattern:"
            read patt
            files=$(eval "listdir.pl ${M_REC_STRING}*${patt}*(.)" | nl)
            print ${M_REC_STRING}*${patt}*(.)
            listdir.pl ${M_REC_STRING}*${patt}*(.)
            echo
            selectmulti $files
            #[[ -n $ZFM_VERBOSE ]] && echo "file: $selected_file"
            ;;
        "ack" )
            print "List / select Files containing string"
            cpattern=${cpattern:-""}
            vared -p "Enter pattern to search for: " cpattern
            #files=$(eval "listdir.pl $(ack -l $M_ACK_REC_FLAG $cpattern)" | nl)
            # somehow with eval only first row was coming through
            # maybe due to newlines
            files=$(listdir.pl $(ack -l $M_ACK_REC_FLAG $cpattern) | nl)
            selectmulti $files
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
            files=$(eval "listdir.pl --file-type ${M_REC_STRING}*${M_EXCLUDE_PATTERN}$str" | nl)
            selectmulti $files
            [[ -n $ZFM_VERBOSE ]] && echo "file: $selected_file"
        }
    [[ -n "$selected_files" ]] && {
        handle_selection "$reply" "$selected_files"
    }
}
# handle multiple selection
# e - use editor to edit
# q   don't do anything
# *  allow user to enter command
handle_selection() {
    local reply=$1
    shift
    selected_files=$@
    perror "handle_selection with $reply"

    case $reply in
        "q")
            return
            #break
            ;;
        "e"|"v")
            eval "$EDITOR $selected_files"
            ;;
        "z")
            local arch="$(date +%Y%m%d_%H%M).tgz"
            eval "tar zcvf $arch $selected_files"
            ls -l $arch
            ;;
        *)
            [[ -n "$selected_files" ]] && {
            commandpost=${commandpost:-""}
            commandpre=${commandpre:-""}
            vared -p "Enter command (e.g. mv) :" commandpre
            [[ -z "$commandpre" ]] && return
            vared -p "Enter command to append to filenames (e.g. target) :" commandpost
            echo "$commandpre $selected_files $commandpost"
            eval "$commandpre $selected_files $commandpost"
        }
        ;;
    esac

}
settingsmenu(){
    select_menu "Options" "i) Full Indexing toggle" "h) hidden files toggle" "p) Paging key" "4) Dupe check" \
        "a) Auto select action"
    case $reply in
        "i")
            if [[ -z "$M_FULL_INDEXING" ]]; then
                M_FULL_INDEXING=1
            else
                M_FULL_INDEXING=
            fi
            export M_FULL_INDEXING
            ;;
        "h")
            echo "may work after changing directory, and should be set from Filters"
            if [[ -z "$M_SHOW_HIDDEN" ]]; then
                M_SHOW_HIDDEN=1
                setopt GLOB_DOTS
            else
                M_SHOW_HIDDEN=
                unsetopt GLOB_DOTS
            fi
            export M_SHOW_HIDDEN
            ;;
        "p")
            echo "Page key is (default <ENTER>: [$M_PAGE_KEY]"
            echo -n "Enter key to use for paging (should preferable not exist in filenames): "
            read -k cha
            M_PAGE_KEY=cha
            echo "Using page key: $cha"
            ;;
        "4")
            echo "When pressing hotkeys 1-9, we check if there are files with numbers in that position"
            echo "Without this check some numbered files can become inaccessible"
            echo "If you rarely use this, you can switch it off here, or permanently at top of source"
            if [[ -z "$M_SWITCH_OFF_DUPL_CHECK" ]]; then
                M_SWITCH_OFF_DUPL_CHECK=1
            else
                M_SWITCH_OFF_DUPL_CHECK=
            fi
            export M_SWITCH_OFF_DUPL_CHECK
            ;;
        "k")
            echo "Change the character used for various functions (Enter leaves them as they are"

            # menu
            # back (up dir)
            # sort options
            # filter options
            # freq dirs
            # freq files

            ;;
        "a")
            AUTO_TEXT_ACTION=$EDITOR
            AUTO_IMAGE_ACTION=open
            AUTO_ZIP_ACTION="tar ztvf"
            echo "Choose automatic action when selecting a text-file"
            vared AUTO_TEXT_ACTION
            echo "Choose automatic action when selecting an image file"
            vared AUTO_IMAGE_ACTION
            echo "Choose automatic action when selecting an zip file"
            vared AUTO_ZIP_ACTION
            export AUTO_ZIP_ACTION AUTO_IMAGE_ACTION AUTO_TEXT_ACTION
    esac

}
filteroptions() {
    menu_loop "Filter Options " "Today Files Dirs Recent Old Large Pattern Small Hidden Clear" "tfdrolphc"
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
# give directories from dirs command
m_dirstack() {
    if [[ -x "${ZFM_DIR}/zfmdirs" ]]; then
        files=$(listdir.pl $(${ZFM_DIR}/zfmdirs) | nl)
    else
        # this only works when this file is sourced
        pbold "These are directories on internal stack (dirs command)"
        files=$(eval "listdir.pl $(dirs)" | nl)
    fi
    selectrow $files
    [[ -d $selected_file ]] && {
        $ZFM_CD_COMMAND $selected_file
    }

}
m_child_dirs() {
    local ff
    ff=$(print -rl -- *(/) | wc -l)
    [[ $ff -eq 0 ]] && { perror "No child dirs." ; return }
    if [[ $ff -gt 24 ]]; then
        # only send dir name, not details.
        files=$(eval "print -rl -- ${M_REC_STRING}*(/)" | nl)
    else
        files=$(eval "listdir.pl --file-type ${M_REC_STRING}*(/)" | nl)
    fi
    selectrow $files
    [[ -d $selected_file ]] && {
        [[ -n $ZFM_VERBOSE ]] && echo "file: $selected_file"
        $ZFM_CD_COMMAND $selected_file
    }
}
m_recentfiles() {
    # recently edited files
    typeset -U files
    files=""
    if [[ -x "${ZFM_DIR}/zfmfiles" ]]; then
        files=$(listdir.pl $(${ZFM_DIR}/zfmfiles) | nl)
    else
        perror "No ~/.viminfo file found"
        files=$(listdir.pl *(.m0) ~/.vimrc ~/.zshrc ~/.bashrc ~/.screenrc ~/.tmux.conf)
    fi
    [[ -n "$files" ]] && {
        selectmulti $files
        [[ -n "$selected_files" ]] && {
            handle_selection "$reply" "$selected_files"
        }
    }
}
# select_menu "A menu" "r) recursive menu" "l) listing files" "o) Options and setttings"
select_menu() {
    local title="$1"
    shift
    local moptions
    moptions=( "$@" )
    echo "${COLOR_BOLD}${title}${COLOR_DEFAULT}"
    for o in $moptions
    do
        echo "  $o"
    done
    echo -n "Select :"
    read -k reply
    echo
}
mycommands() {
    source $ZFM_DIR/zfmcommands.zsh
    menu_loop "My Commands" "$ZFM_MY_COMMANDS" "$ZFM_MY_MNEM"
    type ZFM_$menu_text
    stat=$?
    if [[ $stat -eq 0 ]]; then
        ZFM_$menu_text
    elif [[ -x "$menu_text" ]]; then
        $menu_text
    else
        perror "could not find $menu_text"
    fi
}
