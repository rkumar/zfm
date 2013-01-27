#!/usr/bin/env zsh
# Last update: 2013-01-27 15:59
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
function view_menu() {
    select_menu "   ==      M e n u     ==" main_menu_options main_menu_command_hash
    if [  $? -ne 0 ]; then
        perror "Incorrect option $reply"
    fi
    # pressing menu key again, repeats last seletion
    [[ $reply == $ZFM_MENU_KEY ]] && reply=$view_menu_last_choice
    view_menu_last_choice=$reply
}
# this implements a drill-down which employs grep.
# You could call this fuzzy
# in that the pattern is not contiguous, if you press abc it matches "a.*b.*c"
#
function fuzzyselectrow() {
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

    local sta fin sortrev
    sta=1

    ## used in scrolling list
    integer offset
    offset=0

    while (true)
    do

        ## filter the list on rows (used if more rows than can be viewed
        fin=$#ff
        (( offset > 0 )) && {
            (( fin = $#files - offset ))
        }
        (( sortrev == 1 )) && { 
            ## reverse sort the list on index order
            files=(${(Oa)files})
            sortrev=0
        }
        viewport=$(print -rl -- $files  | grep "$gpatt" | sed -n "$sta,$fin p")
        vpa=("${(@f)$(print -rl -- $viewport)}")
        local _hv=$#vpa # size of result after grep
        print  "   No.\t  Name"

        if [[ $ZFM_AUTO_COLUMNS == "1" && $_hv -gt $rows ]]; then
            # split into 2 columns
            print -rC2 -- "${(@f)$(print -rl -- $viewport | numbernine | sed "s#$HOME#~#g")}"
        else
            print -rl -- $viewport | numbernine | sed "s#$HOME#~#g"
        fi
        # PROMPT prompt
        print  -n "Select a row [1-$_hv] ? Help, ESC/ENTER ($#deleted/$#vpa)/$gpatt/: "
        _read_numbers $#vpa
        print

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


    [[ $reply = "" ]] && { selected_file=; selected_files=; break }
    pdebug "got $reply $ckey"
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
        print -rl  "         | Toggle 2 columns"
        print -rl  "         = Toggle auto-view"
        print -rl  "         C-n Scroll List"
        print -rl  "         C-p Scroll List"
        print -rl  "         C-w Reverse List"
        pause
    else
        # Use chars to drill down
        #  Handling backspace
        if [[ "$reply" == "" || "$reply" == "" ]]; then
            if [[ -n "$gpatt" ]]; then
                gpatt=${gpatt[1,-2]}
                [[ $gpatt[-2,-1] == ".*" ]] && gpatt=${gpatt[1,-3]}
            fi
        elif [[ "$reply" == '|' ]]; then
            if [[ $ZFM_AUTO_COLUMNS == "1" ]]; then
                ZFM_AUTO_COLUMNS=
            else
                ZFM_AUTO_COLUMNS="1"
            fi
        elif [[ "$reply" == '=' ]]; then
            pinfo "Toggling auto viewing of selected files/"
            toggle_auto_view
        elif [[ "$reply" == $ZFM_MENU_KEY ]]; then
            # files with spaces are getting split !!! 
            menu_loop "Options for filtering list" "reject truncate reject_extn accept filter" "rtxaf"
            case $menu_text in
                "reject")
                    print  "reject all files matching given pattern"
                    rejpattern=${rejpattern:-"tmp Trash Backups"}
                    vared -p "Enter pattern to reject: " rejpattern
                    rejpattern=${rejpattern:gs/ /|/}
                    local oldc=$#files
                    files=("${(@f)$(print -rl -- $ff | egrep -v "($rejpattern)")}")
                    ;;
                "truncate")
                    print  "truncates beginning of files to shorten name, toggles "
                    (( ZFM_TRUNCATE = ZFM_TRUNCATE * -1 ))
                    #pdebug "truncate value is: $ZFM_TRUNCATE "
                    ;;
                "reject_extn")
                    print  "removes files for given extensions (space delim)"
                    xrejpattern=${xrejpattern:-"~ bak swp o pyo class lib"}
                    vared -p "Enter extensions to reject: " xrejpattern
                    xrejpattern=${xrejpattern:gs/ /|/}
                    files=("${(@f)$(print -rl -- $ff | egrep -v "\.($xrejpattern)$")}")
                    ;;
                "accept")
                    print  "only show files for given extensions (space delim) remove others"
                    accpattern=${accpattern:-""}
                    vared -p "Enter pattern to accept: " accpattern
                    accpattern=${accpattern:gs/ /|/}
                    files=("${(@f)$(print -rl -- $ff | egrep "\.($accpattern)$")}")
                    ;;
                "filter")
                    print  "Add a command to filter file list, e.g. head / grep foo/ "
                    vared -c -p "Enter filter: " cfilter
                    files=("${(@f)$(print -rl -- $ff | eval "$cfilter"   )}")
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
        elif [[ $ckey == "C-n" ]]; then
            ## scroll list down -- neeeded if more rows than can be seen
            let offset++
        elif [[ $ckey == "C-p" ]]; then
            let offset--
            (( offset < 0 )) && offset=0
        elif [[ $ckey == "C-w" ]]; then
            # sort reverse order so first comes closest to prompt
            # i chose c-w since C-r not working on my terminal ?? even Alt-x just flashin in
            #  iterm but okay in Terminal.
            let sortrev=1
        elif [[ -n $ckey ]]; then
            pdebug "Not trapped $ckey !" 
            ckey=
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
    M_MESSAGE=
}

#
# recursive listing
#
function recviewoptions() {
    M_REC_STRING="**/"
    M_ACK_REC_FLAG="-r"
    viewoptions
}
# non-recursive listing
function nonrecviewoptions(){
    M_REC_STRING=""
    M_ACK_REC_FLAG="-n"
    viewoptions

}
# various canned listings like today's modified files or recent ones
# ACK
function viewoptions() {
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
            $ZFM_FILE_SELECT_FUNCTION $files
            ;;
        "substring" )
            print "Filenames containing pattern:"
            read patt
            files=$(eval "listdir.pl ${M_REC_STRING}*${patt}*(.)")
            print ${M_REC_STRING}*${patt}*(.)
            listdir.pl ${M_REC_STRING}*${patt}*(.)
            print
            $ZFM_FILE_SELECT_FUNCTION $files
            #[[ -n $ZFM_VERBOSE ]] && echo "file: $selected_file"
            ;;
        "ack" )
            zfm_ack
            ;;
        "dirs")
            # list dirs under current dir
            m_child_dirs
            #break
            ;; 
    esac
    [[ -n "$str" ]] && {
            pdebug "listdir.pl --file-type ${M_REC_STRING}*${M_EXCLUDE_PATTERN}$str"
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
## XXX is this really in use now ?
function handle_selection() {
    local reply=$1
    shift
    selected_files=($@:q)
    #selected_files=${selected_files:q}
    pdebug "$0 with $reply $#selected_files"

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
##
## take a file list and allow user to select one or more files, and then popup a menu of options
#  for those files
#  Typically you would execute a command that returns a files list and then hand the list
#  to this function so the user can select files and then be sent to fileopt or multi depending
#  on how many he selected
#
function handle_files() {
    files=($@)
    if [[ $#files -gt 0 ]]; then
        #files=$( echo $files | xargs ls -t )
        fuzzyselectrow $files

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
}
## 
# enter a command and select files from output
# e.g. output of locate command
# select_files_from_cmd_output
function command_select() {
    vared -c -p "Enter command to pipe to selectrows: " command
    files=("${(@f)$( eval "$command" )}")
    M_NO_AUTO=1
    handle_files $files
}
function zfm_locate() {
    searchpattern=${searchpattern:-""}
    vared -p "Filename to 'locate' (enter >= 3 characters): " searchpattern
    [[ -z $searchpattern ]] && return 1
    #files=$( locate "$searchpattern" | grep -P $searchpattern'[^/]*$' )
    #if [[ searchpattern[(i)/] -le $#searchpattern ]]; then
        files=$( locate -l 100 -i -0 "$searchpattern" | xargs -0 ls -t )
    #else
        # grep can't deal with zero byte terminating line, and --null is useless here
        # sicne there's no filename, grep only sees input
        # not sure how this will deal with spaces in file names
        #files=$( locate "$searchpattern" | grep  -P $searchpattern'[^/]*$' | xargs ls -t)
    #fi
    handle_files $files
}
#
#  toggle between full-indexing and drill down mode.
#  I think full-indexing will be useful in selection mode
#
function full_indexing_toggle() {
    if [[ -z "$M_FULL_INDEXING" ]]; then
        M_FULL_INDEXING=1
    else
        M_FULL_INDEXING=
    fi
    export M_FULL_INDEXING
}
function show_hidden_toggle() {
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
function fuzzy_match_toggle() {
    if [[ -z "$ZFM_FUZZY_MATCH_DIR" ]]; then
        ZFM_FUZZY_MATCH_DIR=1
    else
        ZFM_FUZZY_MATCH_DIR=
    fi
    export ZFM_FUZZY_MATCH_DIR
}
function ignore_case_toggle() {
    if [[ -z "$ZFM_IGNORE_CASE" ]]; then
        ZFM_IGNORE_CASE=1
    else
        ZFM_IGNORE_CASE=
    fi
    export ZFM_IGNORE_CASE
}
function approx_match_toggle() {
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
function color_toggle() {
    if [[ -z "$ZFM_NO_COLOR" ]]; then
        ZFM_NO_COLOR=1
        pinfo "Selected files will be displayed in bold"
    else
        ZFM_NO_COLOR=
        pinfo "Selected files will be displayed with a '*'"
    fi
    export ZFM_NO_COLOR
}
function settingsmenu(){
    settings_menu_options=("i) Full Indexing toggle" "c) Case toggle" "h) Hidden files toggle" "p) Paging key" "4) Dupe check" \
        "a) Auto select action" "A) Toggle Auto Action" "x) Approximate match toggle" "C) Color toggle" "_) Redefine command")
    typeset -A settings_menu_command_hash
    settings_menu_command_hash=(
        i full_indexing_toggle
        c ignore_case_toggle
        x approx_match_toggle
        h show_hidden_toggle
        p change_paging_key
        4 toggle_duplicate_check
        a define_auto_action
        A toggle_auto_view
        C color_toggle
        _ zfm_change_command
        )
    select_menu "Options" settings_menu_options settings_menu_command_hash
    if [  $? -ne 0 ]; then
        perror "Incorrect option $reply"
    fi
}
function change_paging_key() {
    print  "Page key is (default <SPACE>: [$M_PAGE_KEY]"
    print  -n "Enter key to use for paging (should preferable not exist in filenames): "
    read -k cha
    M_PAGE_KEY=cha
    print  "Using page key: $cha"
}
## define actions for various file types, if you don't want to be prompted with a menu
function define_auto_action() {
    # specify action with various filetypes
    # Misses out on OTHER category, not sure what to do
    # but some text files land in there, `file` says "data".
    print
    print  "Type Ctrl-u to clear line"
    print  "Blank line disables auto action"
    print
    #
    local v=""
    print -rl "Choose automatic action when selecting :"
    for ff in ${(k)FT_EXTNS} ; do
        v=$ZFM_AUTO_ACTION[$ff]
        vared -p "   $ff file: " v
        ZFM_AUTO_ACTION[$ff]=$v
    done

}
function toggle_duplicate_check() {
    print  "When pressing hotkeys 1-9, we check if there are files with numbers in that position"
    print  "Without this check some numbered files can become inaccessible"
    print  "If you rarely use this, you can switch it off here, or permanently at top of source"
    if [[ -z "$M_SWITCH_OFF_DUPL_CHECK" ]]; then
        M_SWITCH_OFF_DUPL_CHECK=1
    else
        M_SWITCH_OFF_DUPL_CHECK=
    fi
    export M_SWITCH_OFF_DUPL_CHECK
}
#  toggle between automatuc viewing on selection, the other mode
#  being that the fileopt menu is opened
function toggle_auto_view(){
    if [[ "$ZFM_AUTOVIEW_TOGGLE_KEY" == "1" ]]; then
        unset_auto_view
    else
        set_auto_view
    fi
}
function set_auto_view(){
    ZFM_AUTOVIEW_TOGGLE_KEY="1"
    typeset -Ag ZFM_AUTO_ACTION ZFM_AUTO_ACTION_BAK; 
    ZFM_AUTO_ACTION=("${(@kv)ZFM_AUTO_ACTION_BAK}")
    ZFM_AUTO_ACTION[IMAGE]=${ZFM_AUTO_ACTION_BAK[IMAGE]:-"open"}
    #ZFM_AUTO_ACTION[OTHER]=${ZFM_AUTO_ACTION_BAK[OTHER]:-"open"}
    ZFM_AUTO_ACTION[TXT]=${ZFM_AUTO_ACTION_BAK[TXT]:-$EDITOR}
    ZFM_AUTO_ACTION[ZIP]=${ZFM_AUTO_ACTION_BAK[ZIP]:-"tar ztvf"}
}
function unset_auto_view(){
    ZFM_AUTOVIEW_TOGGLE_KEY=
    ## store values in bak hash and clear this one
    typeset -Ag ZFM_AUTO_ACTION_BAK; ZFM_AUTO_ACTION_BAK=("${(@kv)ZFM_AUTO_ACTION}")
    unset ZFM_AUTO_ACTION

    #for key in ${(k)ZFM_AUTO_ACTION} ; do
        #val=$ZFM_AUTO_ACTION[$key]
        #ZFM_AUTO_ACTION_BAK[$key]=$val
        #ZFM_AUTO_ACTION[$key]=
    #done
}
function filteroptions() {
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
    ZFM_STRING="${pattern}${M_EXCLUDE_PATTERN}(${MFM_LISTORDER}$filterstr)"
    export ZFM_STRING
    param=$(eval "print -rl -- ${pattern}(${MFM_LISTORDER}$filterstr)")
    export param
}
function sortoptions() {
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
    #ZFM_STRING="${pattern}(${MFM_LISTORDER}$filterstr)"
    ZFM_STRING="${pattern}${M_EXCLUDE_PATTERN}(${MFM_LISTORDER}$filterstr)"
    export ZFM_STRING
    param=$(eval "print -rl -- ${pattern}(${MFM_LISTORDER}$filterstr)")
    export param
}
# cycle through various views
# This should include long listings
function zfm_views() {
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
    #ZFM_STRING="${pattern}(${MFM_LISTORDER}$filterstr)"
    ZFM_STRING="${pattern}${M_EXCLUDE_PATTERN}(${MFM_LISTORDER}$filterstr)"
    export ZFM_STRING
    param=$(eval "print -rl -- ${pattern}(${MFM_LISTORDER}$filterstr)")
    export param

}
# give directories from dirs command
function m_dirstack() {
    if [[ -x "${ZFM_DIR}/zfmdirs" ]]; then
        #files=$(listdir.pl $(${ZFM_DIR}/zfmdirs) | nl)
        #files=$(print -rl -- $(${ZFM_DIR}/zfmdirs))
        files=("${(@f)$(${ZFM_DIR}/zfmdirs )}")  # reqd to prevent wrapping on spaces - ugh
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
function m_child_dirs() {
    local ff
    ff=$(print -rl -- *(/) | wc -l)
    [[ $ff -eq 0 ]] && { perror "No child dirs." ; return }
    if [[ $ff -gt 0 ]]; then
        # only send dir name, not details.
        # as of 2013-01-20 - 00:29 this works fine if dirs has spaces in them
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
function m_recentfiles() {
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
            #perror "XXX $#selected_files ,, $selected_file,, $selected_files"
            if [[ $#selected_files -eq 1 ]]; then
                fileopt "$selected_files[1]"
            elif [[ $#selected_files -gt 1 ]]; then
                multifileopt $selected_files
            elif [[ -e "$selected_file" ]]; then
                fileopt "$selected_file"
            fi
        fi
    }
}
## 
#  zfmcommands has similar program, same name
#
zfm_ack() {
    print "List / select Files containing string"
    cpattern=${cpattern:-""}
    vared -p "Enter pattern to search for: " cpattern
    #files=$(eval "listdir.pl $(ack -l $M_ACK_REC_FLAG $cpattern)" | nl)
    # somehow with eval only first row was coming through
    # maybe due to newlines
    pinfo "Using ack -l $M_ACK_REC_FLAG (-n non recursive, -r recursive)"
    ack $M_ACK_REC_FLAG "$cpattern"
    pause
    files=$(ack -l $M_ACK_REC_FLAG "$cpattern")
    if [[ $#files -gt 0 ]]; then
        ## next line fails on spaces in files
        #  MAYBE listdir needs to be fixed so it can take spaces in files. XXX
        #files=$(listdir.pl $(ack -l $M_ACK_REC_FLAG $cpattern))
        #files=$(listdir.pl $files)
        $ZFM_FILE_SELECT_FUNCTION $files
        [[ $#selected_files -gt 0 ]] && {
            vim -c /$cpattern $selected_files
            selected_files=
        }
    else
        pinfo "No files found containing $cpattern (using ack -l $M_ACK_REC_FLAG)"
        pause
    fi
}
# this is a retake on select_menu using datastructures, so one may add or modify 
# items and hotkeys at startup thru a config file
function select_menu() {
    local title="$1"
    shift
    local moptions
    moptions=(${(P)1})
    typeset -A myhas
    myhas=(${(Pkv)2})
    #print $#moptions
    #print $#myhas
    #print $#myhas  :: ${(kv)myhas}
    print
    print  "${COLOR_BOLD}${title}${COLOR_DEFAULT}"
    #for o in $moptions
    #do
        #print  "  $o"
    #done
    M_BOLD_FIRST=1
    columnate $moptions
    print  -n "Select :"
    read -k reply
    print
    local ret=0
    if (( ${+myhas[$reply]} )); then
        #pdebug found $reply in hash as $myhas[$reply]
        $myhas[$reply]
        ret=0
    else
        #print
        #print $#myhas :: $myhas
        ret=1
        [[ $reply == "q" || $reply == "" ]] && ret=0
    fi
    print
    return $ret
}

# take an array that has values with some divider for columns and paste into one array
# lets use newlines as end of one column, we don;t know how many columns are coming in
# so use 50 as default. what of titles ??
#
function columnate() {

    local FOO BUFF ctr f ff
    FOO=($@)

    BUFF=()
    local width=25

    (( ctr = 0 ))

    ## loop through array creating a buffer called BUFF which contains
    #  side by side columns
    #
    for f in $FOO ; do
        ## newline signifies next column
        if [[ $f == "\n" ]]; then
            (( ctr = 0 ))
            continue
        else
            (( ctr++ ))
        fi
        ## we assume the first one in each list is a title and should be bolded
        ff=${(r:$width:)f}
        if [[ -n $M_BOLD_FIRST ]]; then
            if [[ $ctr -eq 1 ]]; then
                ff="$fg_bold[white]$ff$reset_color"
            fi
        fi
        BUFF[$ctr]+=$ff
        ## if we are to boldface, we must first pad then boldface otherwise
        # ANSI chars get counted in size but actually don't take up size,
        # we know that from past experience of using other libraries
        #
        #BUFF[$ctr]+=${(r:30:)f}
    done

    #print "$fg_bold[white] title $fg_bold[blue] red fgbbb $reset_color"
    M_BOLD_FIRST=
    print -l $BUFF
}

function mycommands() {
    source $ZFM_DIR/zfmcommands.zsh
    IFS=$ZFM_MY_DELIM menu_loop "My Commands" "$ZFM_MY_COMMANDS${ZFM_MY_DELIM:-' '}cmd" "${ZFM_MY_MNEM}:"
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
    pause
}

# numbers the first nine rows only since these are hotkeys
# the rest must be filtered by some character.
function numbernine() {
    let c=1
    local tabd=$'\t'
    local selct=$#deleted
    local crow cfile
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
            # how was this working earlier ? line contains full text wherease deleted only 
            # has file name XXX added split of line 2013-01-20 - 01:01 
            crow=("${(s/	/)line}")
            cfile=$crow[-1]
            if [[ $deleted[(i)$cfile] -gt $selct ]]; then
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
function edit_last_file() {
    pinfo "Last viewed : $last_viewed_files"
    [[ -n $last_viewed_files ]] && $EDITOR $last_viewed_files
}
function get_exclude_pattern() {
    M_EXCLUDE_PATTERN=${M_EXCLUDE_PATTERN:-"~(*.tgz|*.gz|*.z|*.bz2|*.zip)"}
    vared -p "Enter pattern to exclude from listings: " M_EXCLUDE_PATTERN
    ZFM_STRING="${pattern}${M_EXCLUDE_PATTERN}(${MFM_LISTORDER}$filterstr)"
}

## This take a single char from user. If its a number and the options are more than
# 10 it takes another. If he enters 2 and >= 20 options it takes another.
# It can also take a char or anything else to filter lists down.
#
function _read_numbers() {
    local rows=$1
    local ret=0
    read -k reply
    local key=$reply
    # if user enters a numeric and there are double digit values too
    # then wait for a second number. e.g. if he types 1 and there are 10 items
    # wait for another keypress for a second. BUt if he types 2 and there are less than
    # 20 then continue without taking another key
    if [[ "$reply" == <1-9> ]]; then
        (( tens = reply * 10 ))
        (( $rows >= tens )) && {
            read -k -t 1 ret1
            if [[  $? -eq 0 ]]; then
                # check it is numeric not a CR, if no input then $? gives 1
                if [[ $ret1 == <0-9> ]]; then
                    (( reply = reply * 10 + ret1 ))
                fi
            fi

        }
    elif [[ '#key' -eq '#\\e' ]]; then
        while (true); do
            read -t $(( KEYTIMEOUT / 1000 )) -k -s key2
            ret=$?
            if [[ $ret -ne 0 ]]; then
                break
            else
                reply+="$key2"
            fi
        done
        resolve_key_codes
        # check ckey
    else
        ascii=$((#key))
        # ctrl keys
        (( ascii >= 0 && ascii < 27 )) && { (( x = ascii + 96 ));  y=${(#)x}; ckey="C-$y"; }
    fi
}
