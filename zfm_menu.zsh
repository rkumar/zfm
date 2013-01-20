#!/usr/bin/env zsh
# ----------------------------------------------------------------------------- #
#         File: menu.zsh
#  Description: common routine for prompting user with a menu
#       Author: rkumar http://github.com/rkumar/rbcurse/
#         Date: 2012-12-09 - 21:08 
#      License: Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)
#  Last update: 2013-01-20 15:41
# ----------------------------------------------------------------------------- #
# see tools.zsh for how to use:
# source this file
# set myhash and myopts
#      - myhash is a hash, myopts is an array with commands to be executed
#      - myhash contains mnemonics or shortcuts for some of commands in myopts
# call menu_loop

export COLOR_DEFAULT="\\033[0m"
export COLOR_RED="\\033[1;31m"
export COLOR_GREEN="\\033[1;32m"
export COLOR_BOLD="\\033[1m"
export COLOR_BOLDOFF="\\033[22m"
# edit these or override in ENV
ZFM_ZIP_COMMAND=${ZFM_ZIP_COMMAND:-tar zcvf}
ZFM_RM_COMMAND=${ZFM_RM_COMMAND:-rmtrash}
ZFM_UNZIP_COMMAND=${ZFM_UNZIP_COMMAND:-dtrx}
# stores autoaction per filetype
typeset -A ZFM_AUTO_ACTION

#  Print error to stderr so it doesn't mingle with output of method
perror(){
    print -- "ERROR: ${COLOR_RED}$@${COLOR_DEFAULT}" 1>&2
}
#  Print debug statement to stderr so it doesn't mingle with output of method
pdebug(){
    [[ -n "$ZFM_VERBOSE" ]] && print -- "DEBUG: ${COLOR_RED}$@${COLOR_DEFAULT}" 1>&2
}
psuccess(){
    print -- "${COLOR_GREEN}$@${COLOR_DEFAULT}" 1>&2
}

#  Print info statement to stderr so it doesn't mingle with output of method
pinfo(){
    print -- "INFO: $@" 1>&2
}
#  Print something bold to stderr
pbold() {
    print -- "${COLOR_BOLD}$*${COLOR_DEFAULT}" 1>&2
}
#  Pause and get a single key
pause() {
    #local prompt=${1:"Press a key ..."}
    local prompt="Press a key ..."
    local kk
    print -- "$prompt"
    read -k kk
    print
}
#  Print a title in bold
print_title() {
    local title="$@"
    print -- "${COLOR_BOLD}${title}${COLOR_DEFAULT}"
}

# check if being used else delete
array2lines() {
    ZFM_NEWLINE_ARRAY=("${(@f)$(print -rl -- $@)}")
}
#typeset -A myhash
#myhash=( v v r ranger m mc n ncdu l list s sl)
#myopts=(v vifm ranger vshnu mc ncdu list sl)
default="1"

#  Display a menu using numbering and hotkeys if provided
#  Returns selected char in "menu_char"
print_menu() {
    print_title "$1"
    local mnem="$3"
    # trying out, if you are generating some data i could give you more hotkeys
    [[ -z "$mnem" ]] && mnem="         abcdefghijklmnoprstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

    local myopts
    read -A myopts <<< "$2"
    local c=1
    for f in $myopts
    do
        sub=$c
        [[ $c -gt 9 ]] && { sub=" " }
        desc=
        if [[ -z "$M_SUPPRESS_PRINT_COMMAND" ]]; then
            desc="$COMMANDS[$f]"
            [[ -n "$desc" ]] && desc="==>  $desc"
        fi
        # TODO improve by using printf since we are putting the desc
        print -- "$sub ${mnem[$c]})  $f	    $desc"
        let c++
    done
    # show only a max of 9 in text
    (( c-- ))
    (( c > 9 )) && c=9
    print -n "Enter choice 1-${c} (q=quit): "
    read -k menu_char
}

#  Display menu, hotkeys, convert selected char to actual selection
#  Updates  menu_text
#  Try to keep options to 9, and add a mnemonic for options that go beyond
#  TODO currently splits on string, thus cannot use parameters to command
#  TODO use a comma or something else to delimit so we can pass params
menu_loop () {
    menu_text=""  # this contains the text of menu such as command
    menu_char="" # contains actual character pressed could be numeric or hotkey (earlier ans)
    menu_index=0 # this contain index numeric

    mnem="$3"
    # we read only one char, so if the options go beyond 9 then we are royally screwed, take off -1
    local myopts var
while (true) 
do
    local options="$2"
    read -A myopts <<< "$2"
    print_menu "$@"
    print
    #perror "key is 1 $menu_char"
    # next line crashes program on ESC
    [[ $menu_char = "" ]] && { perror "Got a ESC XXX"; menu_char="q" }
    ## the -- is required else a hyphen entered is swallowed
    menu_char=$(print -- "$menu_char" | tr -d '[\n\r\t ]')
    pdebug "$0 : key is :: $menu_char"
    #[[ -z $menu_char ]] && menu_char="$default"
    if [[ -z $menu_char ]] ;
    then
        # enter pressed
        print "press q or ',' to exit without selection " 1>&2
        #print_menu 
    else
        # FIXME, ! is a shortcut for command, now that we are checking later
        # we can release it. The comma is used as it is the back key
        # hash '#' needs to be escaped to be detected
        [[ "$menu_char" =~ [q,] ]] && { return 1 }
        [[ "$menu_char" =~ [-+] ]] && { return 0 }
        print ""
        if [[ "$menu_char" == [1-9] ]]; then
            var="${myopts[$menu_char]}" # 2>/dev/null
            menu_index=$menu_char
        else
            [[ $menu_char == '#' ]] && menu_char='\#'
            index=$mnem[(i)$menu_char]; 
            #pdebug " index is $index of $#mnem, $mnem"
            if [[ $index -gt $#mnem ]]; then
                var=
                menu_index=
            else
                var=${myopts[$index]} 
                menu_index=$index
                # this is a clever loophole for an extra mnemonic that is beyond the 
                # menu options NOTE XXX
                [[ -z "$var" ]] && {  menu_text=$menu_char; break }
                
            fi
            #pdebug "menu_loop index in mnem is $index , $menu_char, $var : $mnem"
        fi
        #perror "key 4 is $menu_char"
        #[[ -z $var1 ]] && { index=$mnem[(i)$menu_char]; var2=${myopts[$index]} }
        #var2="${myhash[$menu_char]}"
        #var=${var1:-$var2}
        if [[ "$menu_char" = "?" ]]; then
            print_title "   Mnemonics are:"
            local i=1
            spl=( ${(s/ /)options})
            while (( i++ < $#mnem )) { 
                if [[ $i -gt $#spl ]]; then
                    # extra key added in call for passing back 
                    print "    $mnem[$i]      =>  (extra key)"
                else
                    [[ -n ${mnem[$i]// /} ]] && print "    ${mnem[$i]}      =>  ${options[(w)$i]}  ";  
                fi
            }
            print "    [q]    => quit"
            print ""
            print -n " Press a key ... "
            read -q hitenter
            print
        elif [[ -z "$var" ]] ; then
            perror "Wrong option $menu_char. q - quit, ? - options"
        elif [[ -n "$var" ]] ; then
            pdebug "$1 returning $var"
            menu_text=$var
            break
            #echo -n " Press a key ... "
            #read -q hitenter
            #echo
        else
            perror "something wrong"
        fi
    fi
done
}
# new
fileopt() {
    local name="$1"
    [[ -z $name ]] && return
    #local type="$(filetype $name)"
    ## if no extension then do filetype check
    local -U apps
    extn=$name:e
    if [[ -n $extn ]]; then
        uextn=${(U)extn}
        apps=$FT_ALL_APPS[$extn]  # check cache FT_ALL_APPS[pdf]
        ## if we have not already calculated apps for extension then do so
        if [[ -z "$apps" ]]; then
            ## check for specific apps for this file extn
            #local x="FT_$uextn"  # check FT_PDF
            #pdebug "checking $x : ${(P)x}"
            #apps=( ${(P)x} )
            apps=( $FT_OPTIONS[$uextn] )
            if [[ -z "$apps" ]]; then
                oextn=$FT_ALIAS[$extn]  # htm will translate to html or MARKDOWN to md
                pdebug "$0 checking FT_ALIAS with $extn : got $oextn"
                #[[ -n $oextn ]] && { apps=( ${(P)oextn} ) }
                [[ -n $oextn ]] && { apps=( $FT_OPTIONS[$oextn] ) }
                #pdebug "$0 got apps ... $apps "
            fi
            # repeated below in else
            ## determine filetype and general apps for it
            file_type="$(filetype $name)"
            file_type=${file_type:-other}
            #x="FT_${(U)file_type}"  # check FT_PDF
            #pdebug "checking after filetype $x"
            #apps+=( ${(P)x} ) 
            pdebug "$0 got filetype $file_type "
            uft="${(U)file_type}"  # check PDF or TXT in FT_OPTIONS
            apps+=( $FT_OPTIONS[$uft] )
            #pdebug "$0 got apps $apps "

            ## store for that extension so we can quickly reuse
            ##  It could have been for file type but then we would have to calc that all over
            FT_ALL_APPS[$extn]=$apps
            # calculate hotkeys
            hotkeys=$(get_hotkeys "$apps")
            FT_ALL_HK[$extn]=$hotkeys
        else
            hotkeys=$FT_ALL_HK[$extn]
        fi
    else
        # repeated from above
        file_type="$(filetype $name)"
        file_type=${file_type:-other}
        #x="FT_${(U)file_type}"  # check FT_TXT or FT_ZIP etc
        pdebug "checking after filetype $file_type"
        #apps+=( ${(P)x} ) 
            uft="${(U)file_type}"  # check FT_PDF
            apps+=( $FT_OPTIONS[$uft] )
        FT_ALL_APPS[$extn]=$apps
        # calculate hotkeys
        hotkeys=$(get_hotkeys "$apps")
        FT_ALL_HK[$extn]=$hotkeys
    fi
    [[ -z $file_type ]] && { 
        # this is only required for checking about auto-actions, can we avoid if none asked for.
        file_type="$(filetype $name)"
        file_type=${file_type:-other}
    }
    # if user has requested some action to be done automatically on selection of a file of some type
    uft=${(U)file_type}
    local act=$ZFM_AUTO_ACTION[$uft]
    if [[ -n "${act}" ]]; then
        pinfo "got $act for $_act ($uft)"
        name=${name:q}
        eval "${act} $name"
        [[ $act == $EDITOR ]] && { last_viewed_files=$name }
        [[ $act == $EDITOR ]] || pause
        return
    else
        pdebug "$0 got no auto action for $uft"
        print -rl -- ${(k)ZFM_AUTO_ACTION}
    fi
    print_title "File summary for $name:"
    file $name
    ls -lh $name
    [[ -f "$name" ]] || { perror "$name not found."; pause; return }
    pdebug "$0 before ML : $apps"
    menu_loop "File Operations:" "$apps" $hotkeys
    [[ -n $ZFM_VERBOSE ]] && pdebug "$0 returned 270 $menu_char, $menutext "
    [[ "$menu_char" =~ [!:] ]] && menu_text="cmd"   # XXX we've moved to ':'
    [[ "$menu_char" = '+' ]] && { zfm_add_option "$name" "$extn" }
    [[ "$menu_char" = '-' ]] && { zfm_rem_option "$name" "$extn" }
    [[ -z "$menu_text" ]] && { return 1; } # q pressed
    eval_menu_text "$menu_text" $name
    pause
    # we can store def app in a hash so not queried each time
    #default_app=$(alias -s | grep $extn | cut -f2 -d= )
    #[[ -n "$extn" ]] && default_app=$(alias -s | grep "$extn" | cut -f2 -d= )
}
function eval_menu_text () {
    local menu_text=$1
    [[ -z "$menu_text" ]] && { perror "$0 Empty command passed"; return 1; } # q pressed
    shift
    local files="$@"
    files=${files:q}
    local ret=0
    case $menu_text in
        "cmd")
            zfm_cmd $files
            ;;
        "auto")
            ## Now we meed to factor in file type
            file_type="$(filetype $files)"
            file_type=${file_type:-other}
            x="${(U)file_type}"
            # added this 2012-12-26 - 01:11 
            command=${command:-"$EDITOR"}
            vared -c -p "Enter command to automatically execute for $file_type files: " command
            ZFM_AUTO_ACTION[$x]="$command"
            eval "$command $files"
            [[ $command == $EDITOR ]] && { last_viewed_files=$files }
            ;;
        "")
            [[ "$menu_char" =~ [a-zA-Z0-9] ]] || {
            perror "got nothing in fileopt $menu_char. Coud be programmer error or key needs to be handled"
            }
            ;;
        "mv") 
            zfm_mv $files
            ;;
        "archive") 
            zfm_zip $files
            ;;
        *)
            # now again this needs to be done for all cases so we can't have such
            # a long loop repeated everywhere
            evaluate_command "$menu_text" $files
            [  $? -eq 0 ] && zfm_refresh
            ;;
    esac
}
## add an option to menu for existing extension
#
function zfm_add_option () {
    local file="$1"
    local extn="$2"
    vared -c -p "New option to add: " newoption
    [[ -z "$newoption" ]] && { return 1 }
    print "Current hotkeys are: $FT_ALL_HK[$extn]"
    print "Enter hotkey for this command: "
    read -k hk
    COMMAND_HOTKEYS[$newoption]=$hk
    print
    vared -c -p "Command to execute for above: " newcommand
    #FT_ALL_APPS[$extn]+=(newoption)
    local apps=$FT_ALL_APPS[$extn]
    apps+=($newoption)
    FT_ALL_APPS[$extn]=$apps
    # TODO XXX hotkeys needs to be regen
    # need to ask for a hotkey if user wants
    hotkeys=$(get_hotkeys "$apps")
    FT_ALL_HK[$extn]=$hotkeys

    [[ -n "$newcommand" ]] && { COMMANDS[$newoption]=$newcommand }
}
## remove an option from menu for existing extension
#
function zfm_rem_option () {
    local file="$1"
    local extn="$2"
    vared -c -p "Option to delete: " newoption
    [[ -z "$newoption" ]] && { return 1 }
    local apps
    apps=$FT_ALL_APPS[$extn]
    apps=("${(s/ /)apps}")  # convert to array
    index=$apps[(i)$newoption]
    if [[ $index -gt $#apps ]]; then
        perror "$newoption not found"
        pdebug "Options are $apps"
        pdebug "Index is $index, $#apps"
    else
        apps[$index]=()
        pdebug "Options are now $apps"
        FT_ALL_APPS[$extn]=$apps
        hotkeys=$(get_hotkeys "$apps")
        FT_ALL_HK[$extn]=$hotkeys
    fi
}
## add or change an existing command 
#
function zfm_change_command () {
    clear
    print
    pbold "File related commands are : "
    print
    for key in ${(k)COMMANDS}; do
        print "$key : ${COMMANDS[$key]}"
    done
    print
    print "Enter key to change (or add): "
    read key
    [[ -z $key ]] && return 1
    command=$COMMANDS[$key]
    vared -p "Edit command: " command
    COMMANDS[$key]=$command
    pbold "$key is ${COMMANDS[$key]}"
}
origfileopt() {
    local name="$1"
    [[ -z $name ]] && return
    local type="$(filetype $name)"
    extn=$name:e
    # we can store def app in a hash so not queried each time
    #default_app=$(alias -s | grep $extn | cut -f2 -d= )
    [[ -n "$extn" ]] && default_app=$(alias -s | grep "$extn" | cut -f2 -d= )
    pdebug "$0 got $type for $name"
    case $type in
        "text"|"txt")
            #[[ -n "$ZFM_AUTO_TEXT_ACTION" ]] && "$ZFM_AUTO_TEXT_ACTION" $name || textfileopt $name
            if [[ -n "$ZFM_AUTO_TEXT_ACTION" ]]; then
                "$ZFM_AUTO_TEXT_ACTION" $name
                [[ $ZFM_AUTO_TEXT_ACTION == $EDITOR ]] && { last_viewed_files=$name }
            else 
                textfileopt $name $default_app
            fi
            ;;
        "image")
            if [[ -n "$ZFM_AUTO_IMAGE_ACTION" ]]; then
               "$ZFM_AUTO_IMAGE_ACTION" $name 
               else
                   otherfileopt $name $default_app
               fi
            #otherfileopt $name
            ;;
        "zip")
            if [[ -n "$ZFM_AUTO_ZIP_ACTION" ]]; then
               eval "$ZFM_AUTO_ZIP_ACTION $name"
               else
                   zipfileopt $name $default_app
               fi
            #zipfileopt $name
            ;;
        *)
            if [[ -n "$ZFM_AUTO_OTHER_ACTION" ]]; then
               "$ZFM_AUTO_OTHER_ACTION" $name 
               else
                   otherfileopt $name $default_app
               fi
            #otherfileopt $name
            ;;
    esac
}
# bypass auto if user wants to exec action on file even though
# auto is on
fileopt_noauto() {
    local name="$1"
    local type="$(filetype $name)"
    extn=$name:e
    # we can store def app in a hash so not queried each time
    [[ -n "$extn" ]] && default_app=$(alias -s | grep "$extn" | cut -f2 -d= )
    pdebug "$0 got $type for $name"
    case $type in
        "text"|"txt")
            textfileopt $name $default_app
            ;;
        "zip")
            zipfileopt $name $default_app
            ;;
        *)
            otherfileopt $name $default_app
            ;;
    esac
}
#  check file type based on output of file command and return a filetype or blank
filetype(){
    local name="$1"
    [[ -z $name ]] && return
    local type=""
    extn=$name:e
    uextn=${(U)extn}
    pdebug "$0 extn: $extn"

    if [[ -n "$extn" ]]; then
        ## don't go in if no extension
        #
        ## loop through each definition list and search for our extn
        for ff in ${(k)FT_EXTNS} ; do
            v=$FT_EXTNS[$ff]
            pdebug "$0 $ff in ft_extns will search $v"
            ## we still need to put a spce around extn otherwise small extns like c and a will match wrongly
            local spextn=" $extn "
            if [[ $v[(i)$spextn] -le $#v ]]; then
                ## v is in uppercase
                type=${ff:l} # lower case
                pdebug "filetype got $type from array"
                break
            fi
        done
    fi
    [[ -n "$type" ]] && { print "$type" && return }
    if [[ "$name" =~ "^..*rc$" ]]; then
        pdebug "inside check for rc file" 
        type="text"
        type="txt"
        print "$type"
        return
    fi
    str="$(file $name)"
    # string search for zip
    ftpatts=(zip text video audio image SQLite)
    for _p in $ftpatts ; do
        ix=$str[(i)$_p]
        if [[ $ix -le $#str ]]; then
            type=$_p
            break
        fi
    done
    [[ $type == "text" ]] && type="txt"
    print $type
}
# WARNING XXX some of these commands will fail is a file has a space in it
# Then you must put the command in a string and eval it.
# Also all files in the selection list have been quoted, but from other sources they could
# come unquoted, esp to other procedures. If so, have them quoted first.
#   This procedure has operations for multiple files
multifileopt() {
    local files
    # careful I am quoting spaces so some commands can work like the tar
    # this may cause problems with some commands
    files=($@:q) # NOTE since array incoming we need to bracket else converts to string
    print_title "File summary for $#files files:"
    # eval otherwise files with spaces will cause an error
    eval "ls -lh $files"
    #IFS=, menu_loop "File operations:" "zip,cmd,grep,mv,${ZFM_RM_COMMAND},git add,git com,vim,vimdiff" "zcg!#a vd"
    hotkeys=$(get_hotkeys "$FT_OPTIONS[MULTI]")
    menu_loop "Multiple File operations:" $FT_OPTIONS[MULTI] $hotkeys
    [[ -n $ZFM_VERBOSE ]] && pdebug "$0 returned $menu_char, $menutext "
    [[ "$menu_char" = "!" ]] && menu_text="cmd"
    case $menu_text in
        "cmd")
            zfm_cmd $files
            ;;
        "")
            [[ "$menu_char" =~ [a-zA-Z0-9] ]] || {
                perror "got nothing in fileopt $menu_char. Could be programmer error or key needs to be handled"
            }
            ;;
        "mv") 
            zfm_mv $files
            ;;
        "zip") 
            zfm_zip $files
            ;;
        "grep")
            greppatt=${greppatt:-""}
            vared -p "Enter pattern : " greppatt
            # piping to pager not working in next line, maybe thinks we are not interactive
            eval "grep $greppatt $files " 
            pause
            ;;
        "gitadd")
            eval "git add $files"
            ;;
        "gitcom")
            eval "git commit $files"
            ;;
        *)

            evaluate_command "$menu_text" $files
            [  $? -eq 0 ] && zfm_refresh
            #[[ -n $ZFM_VERBOSE ]] && perror "213: $menu_text , $files"
            #eval "$menu_text $files"
            #[[ "$menu_text" == "${ZFM_RM_COMMAND}" ]] && zfm_refresh
            ;;
    esac
}
textfileopt() {
    local files="$@"
    # NOTE eval commands require quoting of spaces whereas other commands will fail
    # NOTE what about multiple files
    print_title "File summary for $files:"
    file $files
    ls -lh $files
    [[ -f "$files" ]] || { perror "$files not found."; pause; return }
    files=${files:q}
    # use ! for command even if not shown since user may replace menu with own commands
    #menu_loop "File operations:" "vim cmd less cat mv rmtrash archive tail head wc open auto" "v!lcmrzthwoa"
    #menu_loop "File operations:" "vim cmd less mv ${ZFM_RM_COMMAND} archive tail head open auto $default_app" "vcl!#zthoa"
    #M_MENU_TEXT=${M_MENU_TEXT:-"vim cmd less mv ${ZFM_RM_COMMAND} archive tail head open auto $default_app" 
    # based on text options we generate the hotkeys, however
    # this needs to be in all menu_loop calls so it has to be in one place
    # yet i don;t want to do this each time inside menu_loop. i want to do it once
    if [[ -z "$M_TEXT_HOTKEYS" ]]; then
        M_TEXT_HOTKEYS=$(get_hotkeys "$FT_TEXT")
    fi
    menu_loop "File operations:" "$FT_TEXT" $M_TEXT_HOTKEYS
    [[ -n $ZFM_VERBOSE ]] && pdebug "$0 returned $menu_char, $menutext "
    [[ "$menu_char" = "!" ]] && menu_text="cmd"
    case $menu_text in
        "cmd")
            zfm_cmd $files
            ;;
        "auto")
            # added this 2012-12-26 - 01:11 
            command=${command:-"$EDITOR"}
            vared -p "Enter command to automatically execute for selected text files: " command
            export ZFM_AUTO_TEXT_ACTION="$command"
            eval "$command $files"
            [[ $command == $EDITOR ]] && { last_viewed_files=$files }
            ;;
        "")
            [[ "$menu_char" =~ [a-zA-Z0-9] ]] || {
            perror "got nothing in fileopt $menu_char. Coud be programmer error or key needs to be handled"
            }
            ;;
        "mv") 
            zfm_mv $files
            ;;
        "archive") 
            zfm_zip $files
            ;;
        *)
            # now again this needs to be done for all cases so we can't have such
            # a long loop repeated everywhere
            evaluate_command "$menu_text" $files
            [  $? -eq 0 ] && zfm_refresh
            ;;
    esac
}
## 
## refresh should be done in caller if stat is 0
## need to check for any variables that need to be prompted
function evaluate_command () {
    local menu_text=$1
    shift
    #bombs if spaces in files
    #local files="$@"
    local files
    files="$@"
    local ret=0

    _cmd=$(get_command_for_title $menu_text)
    pdebug "$0 got command ($_cmd) for ($menu_text)"
    if [[ -n $_cmd ]]; then
        ## check for variables that need to be prompted
        ##  -- I tried doing this in zsh but did not get too far!
        vars=( $( print $_cmd | grep -o '${[^}]*}' ) )
        for var in $vars ; do
            vv=$(print $var | tr -d '${}' )
            vared -c -p "Enter $vv:" $vv
            _cmd=${(S)_cmd//$var/${(P)vv}}
            pdebug "subst: $_cmd"
        done

        ## check for file replacement marker
        if [[ $_cmd = *%%* ]]; then
            _cmd=${(S)_cmd//\%\%/${files}}
            pdebug "replaced files command $_cmd "
            eval "$_cmd" && ret=0 || ret=1
        else
            ## no marker just send file names as argument to command
            pdebug "passing files as args $_cmd "
            eval "$_cmd $files" && ret=0 || ret=1
        fi
    else
        # no translation just use the title as is
        [[ -n $ZFM_VERBOSE ]] && pdebug "213: $menu_text , $files"
        eval "$menu_text $files" && ret=0 || ret=1
    fi
    return $ret
}
zipfileopt() {
    # TODO allow user to add a string in ENV for other executables which we can add here
    # such as als or atools aunpack
    local files="$@"
    print_title "File summary for $files:"
    file $files
    ls -lh $files
    [[ -f "$files" ]] || { perror "$files not found."; pause; return 1 }
    tar -ztvf $files | head -n 20
    files=${files:q} # required for eval
    if [[ -z "$M_ZIP_HOTKEYS" ]]; then
        M_ZIP_HOTKEYS=$(get_hotkeys "$FT_ZIP")
    fi
    menu_loop "File operations:" "$FT_ZIP" $M_ZIP_HOTKEYS
    #menu_loop "Zip operations:" "cmd view zless mv ${ZFM_RM_COMMAND} $ZFM_UNZIP_COMMAND" "cvl!#d"
    [[ -n $ZFM_VERBOSE ]] && pdebug "$0 returned $menu_char, $menutext "
    #[[ "$menu_char" = "!" ]] && menu_text="cmd"
    case $menu_text in
        "view") 
            eval "tar ztvf $files"
            ;;
        "cmd")
            zfm_cmd $files
            ;;
        "")
            [[ "$menu_char" =~ [a-zA-Z0-9] ]] || {
            perror "got nothing in zipopt $menu_char. Coud be programmer error or key needs to be handled"
            }
            ;;
        "mv") 
            zfm_mv $files
            ;;
        *)
            evaluate_command "$menu_text" $files
            [  $? -eq 0 ] && zfm_refresh
            #eval "$menu_text $files"
            #[[ "$menu_text" == "${ZFM_RM_COMMAND}" ]] && zfm_refresh
            ;;
    esac
}
# takes one file (despite variable name) for non text files
# TODO check for pdf2html antiword and put in menu
# or allow to be added as ENV var by user
otherfileopt() {
    local files="$@"
    #[[ ! -f "$files" ]] && files=$(echo "$files" | cut -f 1 -d ' ')
    print -rl -- $files
    print_title "File summary for $files:"
    file $files
    ls -lh $files
    [[ -f "$files" ]] || { perror "$files not found."; pause; return }
    files=${files:q} # required for eval
    if [[ -z "$M_OTHER_HOTKEYS" ]]; then
        M_OTHER_HOTKEYS=$(get_hotkeys "$FT_OTHER")
    fi
    menu_loop "File operations:" "$FT_OTHER" $M_OTHER_HOTKEYS
    #menu_loop "Other operations:" "cmd open mv ${ZFM_RM_COMMAND} od stat vim $default_app" "co!#dsv"
    [[ -n $ZFM_VERBOSE ]] && pdebug "$0 returned $menu_char, $menu_text "
    [[ "$menu_char" = "!" ]] && menu_text="cmd"
    case $menu_text in
        "cmd")
            zfm_cmd $files
            ;;
        "")
            [[ "$menu_char" =~ [a-zA-Z0-9] ]] || {
            perror "got nothing in zipopt $menu_char. Coud be programmer error or key needs to be handled"
            }
            ;;
        "mv") 
            zfm_mv $files
            ;;
        "vim")
            zfm_edit $files
            ;;
        *)
            evaluate_command "$menu_text" $files
            [  $? -eq 0 ] && zfm_refresh
            #eval "$menu_text $files"
            #[[ "$menu_text" == "${ZFM_RM_COMMAND}" ]] && zfm_refresh
            ;;
    esac
}
#
# print a hash with key in bold
# We need to have some options of separator (space, line) and color

function print_hash () {
   local h
   h=( "$@" ) 
   for (( i = 1; i < $#h; i+=2 )); do
       print -n "${COLOR_BOLD}$h[i]${COLOR_DEFAULT} ${COLOR_GREEN}$h[i+1] ${COLOR_DEFAULT}  "
   done
   print
}
function zfm_cmd () {
    files=($@)
    #[[ -n $ZFM_VERBOSE ]] && pdebug "PATH is ${PATH}"
    command=${command:-""}
    postcommand=${postcommand:-""}
    vared -p "Enter command (first part) : " command
    [[ -z "$command" ]] && { perror "Command blank. No action taken" ; return }
    vared -p "Enter command (second part): " postcommand
    print "$command $files $postcommand"
    eval "$command $files $postcommand" && zfm_refresh
    [[ $command == $EDITOR ]] && { last_viewed_files=$files }
}
function zfm_zip () {
    files=($@)
    ddate=$(date +%Y%m%d_%H%M)
    local arch="archive-${ddate}.tgz"
    vared -p "Enter zip file name: " arch
    # if you don't check the first file will get overwritten with the tar file
    if [[ -e "$arch" ]]; then
        perror "$file exists, cannot overwrite"
        return
    fi
    [[ -n "$arch" ]] && eval "${ZFM_ZIP_COMMAND} $arch $files" && zfm_refresh
}
function zfm_mv() {
    files=($@)
    pinfo "Got $#files : $files"
    target=${target:-$HOME/}
    vared -p "Enter target: " target
    [[ -n $target ]] && { 
        [[ -d $target ]] || perror "$target not a directory, mv likely to fail"
        print "[$menu_text] [$files] $target"
        eval "$menu_text $files $target"
        zfm_refresh
    }
}
function zfm_edit () {
    files=($@)
    eval "$EDITOR $files"
    last_viewed_files=$files
}
## convert menu options or titles to a string of hotkeys formenu_loop
function get_hotkeys () {
    local options="$@"
    local title ii
    local opts
    local str=""
    opts=(${=options})
    for title in $opts; do
        ii=$COMMAND_HOTKEYS[$title]
        if [[ -n "$ii" ]]; then
            str+=$ii
        else
            str+=$title[1]
        fi
    done
    print $str
}
