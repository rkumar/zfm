#!/usr/bin/env zsh
# ----------------------------------------------------------------------------- #
#         File: bookmark.zsh
#  Description: 
#       Author: rkumar http://github.com/rkumar/zfm/
#         Date: 2013-02-10 - 15:51
#      License: GPL
#  Last update: 2013-02-11 00:41
# ----------------------------------------------------------------------------- #
#  bookmark.zsh  Copyright (C) 2012-2013 rahul kumar
#
# Vim_mode will not execute a char binding in the main binding, it will get
# swallowed. This has to go in vim's binding, but vim has not go loaded until mode is set.
#
# MARK stores the cursor position not the filename, this means that if the directory
#  listing is sorted or filtered, then the marks will not land on the correct file.
#  THus we do not keep file names although we can. This hold true also if files are added or deleted
#   but do NOTE that sorting will affect this. However, you can still jump to the directroy easily.
#
#vim_bind_key "m" zfm_mark
zfm_bind_key "'" zfm_jump_to_mark
zfm_bind_subcommand "marks" zfm_print_marks

# also :marks to list marks
# NOTE: TODO These are also selectors so one should be able to do d'a or y'b etc

typeset -Ag M_MARKS
M_MARKS=()


function zfm_mark () {
    #local ret=0
    #return $ret
    # get a char a-ZA-Z 
    # set current location (path , cursor and sta as that)
    #
    # Each path can have its own a-z
    #  hh[PATH:a]="sta:cursor" or rather have abs_cursor, so we can goto
    #  line
    #
    # A-Z are across paths
    # h[A]="/some/path : abs_cursor
    #  see :help marks or help ' for 0-9 these are not set directly but
    #  are related to viminfo, we can use these for last edited files.
    #  however the desc says something else
    #
    #
    print -n "Enter character for mark [a-z A-Z]: "
    read -k reply
    local pos
    curpos pos
    if [[ $reply =~ [a-z] ]]; then
        M_MARKS[$PWD:$reply]=$pos
        pinfo "$0 set mark ($PWD:$reply) for $pos"
    elif [[ $reply =~ [A-Z] ]]; then 
        M_MARKS[$reply]="$PWD:$pos"
        pinfo "$0 set mark ($reply) for $PWD $pos"
    else
        perror "$0: $reply is not handled as a mark"
        pause
    fi

}
function zfm_jump_to_mark () {
    print -n "Enter character for mark [a-z A-Z]: "
    read -k reply
    local pos rep dir columns
    pos=1
    if [[ $reply =~ [a-z] ]]; then
        pos=$M_MARKS[$PWD:$reply]
        [[ -n $pos ]] && zfm_goto_line $pos
    elif [[ $reply =~ [A-Z] ]]; then 
        rep=$M_MARKS[$reply]
        if [[ -z $rep ]]; then
            perror "$0: No such mark ($reply)"
            pause
            return
        fi
        columns=("${(s/:/)rep}")
        dir=$columns[1]
        pos=$columns[2]
        pos=${pos:-1}
        #pinfo "$0: Got $dir, $pos for $reply"
        zfm_open_dir $dir $pos
    fi
}
## Print marks set 
#  Ideally I need to print only local marks for current folder, not all local marks
#
function zfm_print_marks() {
    clear
    pbold "Marks set"
    print
    # first print global ones
    pbold "Global marks"
    print
    for key in ${(k)M_MARKS} ; do
        if [[ $key =~ ^[A-Z]$ ]]; then
            val=$M_MARKS[$key]
            columns=("${(s/:/)val}")
            dir=$columns[1]
            pos=$columns[2]
            print -rl -- " $fg_bold[white]$key$reset_color = $dir $pos"
        fi
    done
    print
    pbold "Local marks"
    print
    for key in ${(k)M_MARKS} ; do
        if [[ $key =~ ^[A-Z]$ ]]; then
            #print "ignoring $key"
        else
            columns=("${(s/:/)key}")
            dir=$columns[1]
            ch=$columns[2]
            if [[ $dir == $PWD ]]; then
                pos=$M_MARKS[$key]
                print -rl -- " $fg_bold[white]$ch$reset_color = $pos $fg[green]($dir)$reset_color"
            else
                #print "rejected $dir ($PWD)"
            fi
        fi
    done
}
