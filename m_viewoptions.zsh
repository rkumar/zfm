#!/usr/bin/env zsh

# for menu_loop we need to source
source menu.zsh
# for vared stty
stty erase 
setopt EXTENDED_GLOB
# pass in a list of files using a command such as:
# Displays a list of files and prompts user for a row number
# Then selects the row and filename
# Rows have columns delimited by tabs
# files=$(listdir.pl --file-type *(.m0) | nl)
view_menu() {
    select_menu "Menu" "o) Options and Settings" "f) File Listings" "r) Recursive Listings" "d) Directories" "b) Bookmarks" "x) Exclude Pattern" "F) Filter options" "s) Sort Options"
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
            m_directories
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
        *)
            ;;
    esac
}

# select a single row, based on line number which has been supplied with data
# (I know the line number coming in is not a good idea)
selectrow() {
    files=$@
    echo "   No.\t  Size \t  Modified Date  \t  Name"
    print -rl -- $files 
    echo -n "Select a row: "
    read reply
    ff=("${(@f)$(print -rl -- $files)}")
    [[ -z "$reply" ]] && break
    line="$ff[$reply]"
    # only a physical tab was working, \t etc was not working
    # split row with tabs into an array
    selected_row=("${(s/	/)line}")
    selected_file=$selected_row[4]
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
            "e"|"z")
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
            #[[ -n $M_VERBOSE ]] && echo "file: $selected_file"
            ;;
        "substring" )
            print "Filenames containing pattern:"
            read patt
            files=$(eval "listdir.pl ${M_REC_STRING}*${patt}*(.)" | nl)
            selectmulti $files
            #[[ -n $M_VERBOSE ]] && echo "file: $selected_file"
            ;;
        "ack" )
            print "Files containing string:"
            cpattern=${cpattern:-""}
            vared -p "Enter pattern to search for: " cpattern
            files=$(eval "listdir.pl $(ack -l $M_ACK_REC_FLAG $cpattern)" | nl)
            selectmulti $files
            #[[ -n $M_VERBOSE ]] && echo "file: $selected_file"
            ;;
        "dirs")
            #listdir.pl --file-type *(/)
            files=$(eval "listdir.pl --file-type ${M_REC_STRING}*(/)" | nl)
            selectrow $files
            [[ -n $M_VERBOSE ]] && echo "file: $selected_file"
            [[ -d $selected_file ]] && {
                cd $selected_file
            }
            #break
            ;; 
    esac
    [[ -n "$str" ]] && {
            #echo "listdir.pl --file-type ${M_REC_STRING}*${M_EXCLUDE_PATTERN}$str"
            files=$(eval "listdir.pl --file-type ${M_REC_STRING}*${M_EXCLUDE_PATTERN}$str" | nl)
            selectmulti $files
            [[ -n $M_VERBOSE ]] && echo "file: $selected_file"
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
            break
            ;;
        "e")
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
            [[ -z "$commandpre" ]] && break
            vared -p "Enter command to append to filenames (e.g. target) :" commandpost
            echo "$commandpre $selected_files $commandpost"
            eval "$commandpre $selected_files $commandpost"
        }
        ;;
    esac

}
settingsmenu(){
    select_menu "Options" "i) Full Indexing toggle" "h) hidden files toggle" "p) Paging key" "4) Dupe check"
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
            echo "may not work and may need to be set from filters"
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
    esac

}
filteroptions() {
    menu_loop "Filter Options " "Today Files Dirs Recent Oldest Largest Pattern Hidden Clear" "tfdrolphc"
    case $menu_text in
        "Files")
            filterstr="."
            ;;
        "Dirs")
            filterstr="/"
            ;;
        "Recent")
            filterstr=".om[1,15]"
            ;;
        "Today")
            filterstr=".m0"
            ;;
        "Oldest")
            filterstr="Om[1,15]"
            ;;
        "Largest")
            filterstr="OL[1,15]"
            ;;
        "Pattern")
            pattern=${pattern:-'*'}
            vared -p "Enter pattern: " pattern
            pattern=${pattern:-"*"}
            ;;
        "Smallest")
            filterstr="oL[1,15]"
            ;;
        "Hidden")
            filterstr="D${filterstr}"
            ;;
        "Clear")
            filterstr="M"
            ;;
    esac
    filterstr=${filterstr:-M}
    param=$(eval "print -rl -- ${pattern}(${MFM_LISTORDER}$filterstr)")
    export param
}
# give directories from dirs command
m_directories() {
    files=$(eval "listdir.pl $(dirs)" | nl)
    selectrow $files
    [[ -d $selected_file ]] && {
        cd $selected_file
    }

}
m_recentfiles() {
    typeset -U files
    files=""
    if [[ -f ~/.viminfo ]]; then
        echo "Reading from .viminfo"
        #files=$(eval "listdir.pl  ${M_REC_STRING}*.${extn}(.)" | nl)
        files=$(listdir.pl $(grep '^>' ~/.viminfo | cut -d ' ' -f 2 | sed "s#~#$HOME#g") | nl)
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
