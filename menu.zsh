#!/usr/bin/env zsh
# ----------------------------------------------------------------------------- #
#         File: menu.zsh
#  Description: common routine for prompting user with a menu
#       Author: rkumar http://github.com/rkumar/rbcurse/
#         Date: 2012-12-09 - 21:08 
#      License: Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)
#  Last update: 2012-12-23 22:19
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
    echo "${COLOR_RED}$@${COLOR_DEFAULT}" 1>&2
}
pdebug(){
    [[ -n "$M_VERBOSE" ]] && echo "${COLOR_RED}$@${COLOR_DEFAULT}" 1>&2
}
psuccess(){
    echo "${COLOR_GREEN}$@${COLOR_DEFAULT}" 1>&2
}

pinfo(){
    echo "$@" 1>&2
}
#  Print something bold to stderr
pbold() {
    echo "${COLOR_BOLD}$*${COLOR_DEFAULT}" 1>&2
}
#  Pause and get a single key
pause() {
    #local prompt=${1:"Press a key ..."}
    local prompt="Press a key ..."
    local kk
    echo "$prompt"
    read -k -r kk
    echo
}
#  Print a title in bold
print_title() {
    local title="$@"
    echo "${COLOR_BOLD}${title}${COLOR_DEFAULT}"
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
        echo "$c ${mnem[$c]})  $f"
        let c++
    done
    echo -n "Enter choice 1-${#myopts} [${mnem}] (q=quit): "
    read -r -k menu_char
}

#  Display menu, hotkeys, convert selected char to actual selection
#  Updates  menu_text
#  Try to keep options to 9, and add a mnemonic for options that go beyond
menu_loop () {
    menu_text=""  # this contains the text of menu such as command
    menu_char="" # contains actual character pressed could be numeric or hotkey (earlier ans)
    menu_index=0 # this contain index numeric

    mnem="$3"
# we read only one char, so if the options go beyond 9 then we are royally screwed, take off -1
while (true) 
do
    local options="$2"
    local myopts
    read -A myopts <<< "$2"
    print_menu "$@"
    echo
    #perror "key is 1 $menu_char"
    # next line crashes program on ESC
    [[ $menu_char = "" ]] && { perror "Got a ESC XXX"; menu_char="q" }
    menu_char=$(echo "$menu_char" | tr -d '[\n\r\t ]')
    #perror "key is 2 $menu_char"
    #[[ -z $menu_char ]] && menu_char="$default"
    if [[ -z $menu_char ]] ;
    then
        echo "whazzup ?" 1>&2
        #print_menu 
    else
        [[ "$menu_char" =~ [q,\!] ]] && { break }
        echo ""
        #perror "key is 3 $menu_char"
        # A ! cause next line to silently exit, so if ! is a hotkey it must be evaluated in caller
        # Now even o is causing an exit 2012-12-22 - 00:14 
        local var
        if [[ "$menu_char" == [0-9] ]]; then
            var="${myopts[$menu_char]}" # 2>/dev/null
            menu_index=$menu_char
        else
            index=$mnem[(i)$menu_char]; 
            var=${myopts[$index]} 
            menu_index=$index
            # TODO what if caller wants numeric char, should it not go in menu_char
            # always
        fi
        #perror "key 4 is $menu_char"
        #[[ -z $var1 ]] && { index=$mnem[(i)$menu_char]; var2=${myopts[$index]} }
        #var2="${myhash[$menu_char]}"
        #var=${var1:-$var2}
        if [[ "$menu_char" = "?" ]]; then
            #echo "${COLOR_BOLD}Mnemonics are:${COLOR_DEFAULT}"
            print_title "   Mnemonics are:"
            #for f (${(k)myhash}) do
                #print -l "[$f]  => ${myhash[$f]}"
            #done
            local i=0
            # ${string// /}
            while (( i++ < $#mnem )) { [[ -n ${mnem[$i]// /} ]] && echo "    ${mnem[$i]}      =>  ${options[(w)$i]}  ";  }
            echo "    Enter  => menu"
            echo "    [q]    => quit"
            echo ""
            echo -n " Press a key ... "
            read -q hitenter
            echo
        elif [[ -z "$var" ]] ; then
            perror "Wrong option $menu_char, q - quit, <ENTER> - menu" 
        elif [[ -n "$var" ]] ; then
            perror "returning $var"
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
    local type="$(filetype $name)"
    echo "got $type for $name"
    case $type in
        "text")
            textfileopt $name
            ;;
        "image")
            otherfileopt $name
            ;;
        "zip")
            zipfileopt $name
            ;;
        *)
            otherfileopt $name
            ;;
    esac
}
#  check file type based on output of file command and return a few
filetype(){
    local name="$1"
    local type=""
    extn=$name:e
    perror "extn: $extn"
    case $extn in
        "txt"|"c"|"rb"|"pl"|"py"|"sh"|"zsh"|"md"|"css"|"html"|"java"|"conf")
            type="text"
            ;;
        "jpg"|"gif"|"png")
            type="image"
            ;;
        "tgz"|"zip"|"bz2"|"Z"|"z")
            type="zip"
            ;;
    esac
    [[ -n "$type" ]] && { echo "$type" && return }
    if [[ "$name" =~ "^..*rc$" ]]; then
        perror "inside check for rc file" 
        type="text"
        echo "$type"
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
    echo $type
}
# WARNING XXX some of these commands will fail is a file has a space in it
# Then you must put the command in a string and eval it.
# Also all files in the selection list have been quoted, but from other sources they could
# come unquoted, esp to other procedures. If so, have them quoted first.
#   This procedure has operations for multiple files
multifileopt() {
    local files
    files="$@"
    print_title "File summary for $#files files:"
    # eval otherwise files with spaces will cause an error
    eval "ls -lh $files"
    menu_loop "File operations:" "zip cmd grep mv rmtrash gitadd gitcom" "z!gmra"
    [[ -n $M_VERBOSE ]] && perror "returned $menu_char, $menutext "
    [[ "$menu_char" = "!" ]] && menu_text="cmd"
    case $menu_text in
        "cmd")
            [[ -n $M_VERBOSE ]] && perror "PATH is ${PATH}"
            command=${command:-""}
            postcommand=${postcommand:-""}
            vared -p "Enter command (first part) : " command
            vared -p "Enter command (second part): " postcommand
            echo "$command $files $postcommand"
            eval "$command $files $postcommand"
            ;;
        "")
            [[ "$menu_char" =~ [a-zA-Z0-9] ]] || {
            perror "got nothing in fileopt $menu_char. Coud be programmer error or key needs to be handled"
            }
            ;;
        "mv") 
            target=${target:-/Users/}
            #echo -n "Enter target: "
            #read target
            vared -p "Enter target: " target
            [[ -n $target ]] && { 
                echo $menu_text $files $target 
                eval "$menu_text $files $target"
            }
            ;;
        "zip") 
            ddate=$(date +%Y%m%d_%H%M)
            local arch="archive-${ddate}.tgz"
            #echo -n "Enter target: [$arch]"
            #read target
            vared -p "Enter zip file name: " arch
            #[[ -z $target ]] && target="$arch"
            eval "tar zcvf $arch $files"
            ;;
        "grep")
            greppatt=${greppatt:-""}
            vared -p "Enter pattern : " greppatt
            eval "grep $greppatt $files"
            ;;
        "gitadd")
            eval "git add $files"
            ;;
        "gitcom")
            eval "git commit $files"
            ;;
        *)

            #[[ -n $M_VERBOSE ]] && perror "213: $menu_text $files"
            eval "$menu_text $files"
            ;;
    esac
}
textfileopt() {
    local files="$@"
    #files=$(print -r $files | sed 's/\.\. //g;s/\~ //g;s/ all$//g')
    # NOTE XXX splitting on space means space in files will cause misbehavior
    [[ ! -f "$files" ]] && files=$(echo "$files" | cut -f 1 -d ' ')
    #print -rl -- $files
    #menu_dyn "Select file/s:" "$flist all"
    #[[ -z "$menu_text" ]] && break
    #[[ "$menu_text" = "all" ]] && $menu_text="$flist"
    #local files=$menu_text
    # NOTE what about multiple files
    print_title "File summary for $files:"
    file $files
    ls -lh $files
    menu_loop "File operations:" "vim cmd less cat mv rmtrash archive tail head wc open" "v!lcmrzthwo"
    [[ -n $M_VERBOSE ]] && perror "returned $menu_char, $menutext "
    [[ "$menu_char" = "!" ]] && menu_text="cmd"
    case $menu_text in
        "cmd")
            [[ -n $M_VERBOSE ]] && perror "PATH is ${PATH}"
            command=${command:-""}
            vared -p "Enter command: " command
            eval "$command $files"
            ;;
        "")
            [[ "$menu_char" =~ [a-zA-Z0-9] ]] || {
            perror "got nothing in fileopt $menu_char. Coud be programmer error or key needs to be handled"
            }
            ;;
        "mv") 
            echo -n "Enter target: "
            read target
            target=${target:-""}
            vared -p "Enter target: " target
            [[ -n $target ]] && { 
            echo $menu_text $files $target 
            eval "$menu_text $files $target"
            }
            ;;
        "archive") 
            ddate=$(date +%Y%m%d)
            local arch="archive-${ddate}.tgz"
            echo -n "Enter target: [$arch]"
            read target
            [[ -z $target ]] && target="$arch"
            tar zcvf $arch $files
            ;;
        *)

            [[ -n $M_VERBOSE ]] && perror "213: $menu_text $files"
            eval "$menu_text $files"
            ;;
    esac
}
zipfileopt() {
    local files="$@"
    [[ ! -f "$files" ]] && files=$(echo "$files" | cut -f 1 -d ' ')
    print -rl -- $files
    print_title "File summary for $files:"
    file $files
    ls -lh $files
    tar -ztvf $files | head -n 20
    menu_loop "Zip operations:" "cmd view zless mv rmtrash dtrx" "!vlmrd"
    [[ -n $M_VERBOSE ]] && perror "returned $menu_char, $menutext "
    [[ "$menu_char" = "!" ]] && menu_text="cmd"
    case $menu_text in
        "view") 
            tar ztvf $files
            ;;
        "cmd")
            [[ -n $M_VERBOSE ]] && perror "PATH is ${PATH}"
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
            echo -n "Enter target: "
            read target
            [[ -n $target ]] && { echo $menu_text $files $target }
            ;;
        *)
            eval "$menu_text $files"
            ;;
    esac
}
# takes one file (despite variable name) for non text files
otherfileopt() {
    local files="$@"
    #[[ ! -f "$files" ]] && files=$(echo "$files" | cut -f 1 -d ' ')
    print -rl -- $files
    print_title "File summary for $files:"
    file $files
    ls -lh $files
    menu_loop "Zip operations:" "cmd open rmtrash od stat" "!ords"
    [[ -n $M_VERBOSE ]] && perror "returned $menu_char, $menutext "
    [[ "$menu_char" = "!" ]] && menu_text="cmd"
    case $menu_text in
        "cmd")
            [[ -n $M_VERBOSE ]] && perror "PATH is ${PATH}"
            command=${command:-""}
            vared -p "Enter command: " command
            echo "executing: $command $files"
            eval "$command $files"
            ;;
        "")
            [[ "$menu_char" =~ [a-zA-Z0-9] ]] || {
            perror "got nothing in zipopt $menu_char. Coud be programmer error or key needs to be handled"
            }
            ;;
        "mv") 
            echo -n "Enter target: "
            read target
            [[ -n $target ]] && { echo $menu_text $files $target }
            ;;
        *)
            # fails on stat command if spaces in file, therefore quoting
            files=${files:q}
            eval "$menu_text $files"
            ;;
    esac
}
