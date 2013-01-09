#!/usr/bin/env zsh
# ----------------------------------------------------------------------------- #
#         File: menu.zsh
#  Description: common routine for prompting user with a menu
#       Author: rkumar http://github.com/rkumar/rbcurse/
#         Date: 2012-12-09 - 21:08 
#      License: Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)
#  Last update: 2013-01-09 18:49
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
#  Print error to stderr so it doesn't mingle with output of method
perror(){
    print "ERROR: ${COLOR_RED}$@${COLOR_DEFAULT}" 1>&2
}
#  Print debug statement to stderr so it doesn't mingle with output of method
pdebug(){
    [[ -n "$ZFM_VERBOSE" ]] && print "DEBUG: ${COLOR_RED}$@${COLOR_DEFAULT}" 1>&2
}
psuccess(){
    print "${COLOR_GREEN}$@${COLOR_DEFAULT}" 1>&2
}

#  Print info statement to stderr so it doesn't mingle with output of method
pinfo(){
    print "INFO: $@" 1>&2
}
#  Print something bold to stderr
pbold() {
    print "${COLOR_BOLD}$*${COLOR_DEFAULT}" 1>&2
}
#  Pause and get a single key
pause() {
    #local prompt=${1:"Press a key ..."}
    local prompt="Press a key ..."
    local kk
    print "$prompt"
    read -k -r kk
    print
}
#  Print a title in bold
print_title() {
    local title="$@"
    print "${COLOR_BOLD}${title}${COLOR_DEFAULT}"
}

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
        print "$sub ${mnem[$c]})  $f"
        let c++
    done
    # show only a max of 9 in text
    (( c-- ))
    (( c > 9 )) && c=9
    print -n "Enter choice 1-${c} (q=quit): "
    read -r -k menu_char
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
    menu_char=$(print "$menu_char" | tr -d '[\n\r\t ]')
    pdebug "key is 2 $menu_char"
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
        [[ "$menu_char" =~ [q,] ]] && { return }
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
            perror "Wrong option $menu_char, q - quit, ? - options"
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
fileopt() {
    local name="$1"
    [[ -z $name ]] && return
    local type="$(filetype $name)"
    extn=$name:e
    # we can store def app in a hash so not queried each time
    #default_app=$(alias -s | grep $extn | cut -f2 -d= )
    [[ -n "$extn" ]] && default_app=$(alias -s | grep "$extn" | cut -f2 -d= )
    pdebug "$0 got $type for $name"
    case $type in
        "text")
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
        "text")
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
#  check file type based on output of file command and return a few
filetype(){
    local name="$1"
    [[ -z $name ]] && return
    local type=""
    extn=$name:e
    pdebug "extn: $extn"
    case $extn in
        "txt"|"c"|"rb"|"pl"|"py"|"sh"|"zsh"|"md"|"css"|"html"|"java"|"conf")
            type="text"
            ;;
        "jpg"|"gif"|"png")
            type="image"
            ;;
        "pdf"|"ps"|"doc")
            # XXX what if user has pdf2html or antiword etc installed
            type="other"
            ;;
        "tgz"|"zip"|"bz2"|"Z"|"z")
            type="zip"
            ;;
    esac
    [[ -n "$type" ]] && { print "$type" && return }
    if [[ "$name" =~ "^..*rc$" ]]; then
        pdebug "inside check for rc file" 
        type="text"
        print "$type"
        return
    fi
    str="$(file $name)"
    local ix=$str[(i)zip]
    if [[ $ix -le $#str ]]; then
        type="zip"
    else
        local ix=$str[(i)text]
        if [[ $ix -le $#str ]]; then
            type="text"
        else
            local ix=$str[(i)image]
            if [[ $ix -le $#str ]]; then
                type="image"
            else

            fi
        fi
    fi
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
    IFS=, menu_loop "File operations:" "zip,cmd,grep,mv,rmtrash,git add,git com,vim,vimdiff" "zcg!#a vd"
    [[ -n $ZFM_VERBOSE ]] && pdebug "returned $menu_char, $menutext "
    [[ "$menu_char" = "!" ]] && menu_text="cmd"
    case $menu_text in
        "cmd")
            #[[ -n $ZFM_VERBOSE ]] && pdebug "PATH is ${PATH}"
            command=${command:-""}
            postcommand=${postcommand:-""}
            vared -p "Enter command (first part) : " command
            vared -p "Enter command (second part): " postcommand
            print "$command $files $postcommand"
            eval "$command $files $postcommand"
            ;;
        "")
            [[ "$menu_char" =~ [a-zA-Z0-9] ]] || {
            perror "got nothing in fileopt $menu_char. Could be programmer error or key needs to be handled"
            }
            ;;
        "mv") 
            target=${target:-$HOME/}
            vared -p "Enter target: " target
            [[ -n $target ]] && { 
                print $menu_text $files $target 
                eval "$menu_text $files $target"
                zfm_refresh
            }
            ;;
        "zip") 
            ddate=$(date +%Y%m%d_%H%M)
            local arch="archive-${ddate}.tgz"
            #echo -n "Enter target: [$arch]"
            #read target
            vared -p "Enter zip file name: " arch
            #[[ -z $target ]] && target="$arch"
            # if you don't check the first file will get overwritten with the tar file
            [[ -n "$arch" ]] && eval "tar zcvf $arch $files" && zfm_refresh
            ;;
        "grep")
            greppatt=${greppatt:-""}
            vared -p "Enter pattern : " greppatt
            # piping to pager not working in next line, maybe thinks we are not interactive
            eval "grep $greppatt $files " 
            pause
            ;;
        "git add")
            eval "git add $files"
            ;;
        "git com")
            eval "git commit $files"
            ;;
        *)

            #[[ -n $ZFM_VERBOSE ]] && perror "213: $menu_text $files"
            eval "$menu_text $files"
            [[ "$menu_text" == "rmtrash" ]] && zfm_refresh
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
    #menu_loop "File operations:" "vim cmd less cat mv rmtrash archive tail head wc open auto" "v!lcmrzthwoa"
    menu_loop "File operations:" "vim cmd less mv rmtrash archive tail head open auto $default_app" "vcl!#zthoa"
    [[ -n $ZFM_VERBOSE ]] && pdebug "returned $menu_char, $menutext "
    [[ "$menu_char" = "!" ]] && menu_text="cmd"
    case $menu_text in
        "cmd")
            #[[ -n $ZFM_VERBOSE ]] && perror "PATH is ${PATH}"
            command=${command:-""}
            vared -p "Enter command: " command
            eval "$command $files" && zfm_refresh
            [[ $command == $EDITOR ]] && { last_viewed_files=$files }
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
            target=${target:-$HOME/}
            vared -p "Enter target: " target
            [[ -n $target ]] && { 
            print $menu_text $files $target 
            eval "$menu_text $files $target" && zfm_refresh
            }
            ;;
        "archive") 
            ddate=$(date +%Y%m%d)
            local arch="archive-${ddate}.tgz"
            print -n "Enter target: [$arch]"
            read target
            [[ -z $target ]] && target="$arch"
            # eval required since strings quoted above
            eval "tar zcvf $arch $files" && zfm_refresh
            ;;
        *)

            [[ -n $ZFM_VERBOSE ]] && perror "213: $menu_text $files"
            eval "$menu_text $files" && zfm_refresh
            ;;
    esac
}
zipfileopt() {
    # TODO allow user to add a string in ENV for other executables which we can add here
    # such as als or atools aunpack
    local files="$@"
    print_title "File summary for $files:"
    file $files
    ls -lh $files
    [[ -f "$files" ]] || { perror "$files not found."; pause; return }
    tar -ztvf $files | head -n 20
    files=${files:q} # required for eval
    menu_loop "Zip operations:" "cmd view zless mv rmtrash dtrx" "cvl!#d"
    [[ -n $ZFM_VERBOSE ]] && pdebug "returned $menu_char, $menutext "
    #[[ "$menu_char" = "!" ]] && menu_text="cmd"
    case $menu_text in
        "view") 
            eval "tar ztvf $files"
            ;;
        "cmd")
            [[ -n $ZFM_VERBOSE ]] && pdebug "PATH is ${PATH}"
            command=${command:-""}
            vared -p "Enter command: " command
            eval "$command $files"
            ;;
        "")
            [[ "$menu_char" =~ [a-zA-Z0-9] ]] || {
            perror "got nothing in zipopt $menu_char. Coud be programmer error or key needs to be handled"
            }
            ;;
        "mv") 
            target=${target:-$HOME/}
            vared -p "Enter target: " target
            [[ -n $target ]] && { 
                print $menu_text $files $target 
                eval "$menu_text $files $target" && zfm_refresh
                psuccess "Please use refresh key to rescan files"
            }
            ;;
        *)
            eval "$menu_text $files"
            [[ "$menu_text" == "rmtrash" ]] && zfm_refresh
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
    menu_loop "Other operations:" "cmd open mv rmtrash od stat vim $default_app" "co!#dsv"
    [[ -n $ZFM_VERBOSE ]] && pdebug "returned $menu_char, $menu_text "
    [[ "$menu_char" = "!" ]] && menu_text="cmd"
    case $menu_text in
        "cmd")
            [[ -n $ZFM_VERBOSE ]] && pdebug "PATH is ${PATH}"
            command=${command:-""}
            vared -p "Enter command: " command
            print "executing: $command $files"
            eval "$command $files"
            [[ $command == $EDITOR ]] && { last_viewed_files=$files }
            ;;
        "")
            [[ "$menu_char" =~ [a-zA-Z0-9] ]] || {
            perror "got nothing in zipopt $menu_char. Coud be programmer error or key needs to be handled"
            }
            ;;
        "mv") 
            target=${target:-$HOME/}
            vared -p "Enter target: " target
            [[ -n $target ]] && { 
                print $menu_text $files $target 
                eval "$menu_text $files $target" && zfm_refresh
            }
            ;;
        "vim")
            eval "$EDITOR $files"
            last_viewed_files=$files
            ;;
        *)
            eval "$menu_text $files"
            [[ "$menu_text" == "rmtrash" ]] && zfm_refresh
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
