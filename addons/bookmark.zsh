#!/usr/bin/env zsh
# ----------------------------------------------------------------------------- #
#         File: bookmark.zsh
#  Description: 
#       Author: rkumar http://github.com/rkumar/zfm/
#         Date: 2013-02-10 - 15:51
#      License: GPL
#  Last update: 2013-02-10 20:19
# ----------------------------------------------------------------------------- #
#  bookmark.zsh  Copyright (C) 2012-2013 rahul kumar
#
# Vim will not execute a char binding in the main binding, it will get
# swallowed. This has to go in vim's binding, but vim has not go loaded
# yet since it's in addons and comes later in order.
# Even when vim is sourced, the structures have only loaded when the mode is started first time.
#
#vim_bind_key "m" zfm_mark
zfm_bind_key "'" zfm_jump_to_mark

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
