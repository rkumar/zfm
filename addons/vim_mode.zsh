#!/usr/bin/env zsh
# ----------------------------------------------------------------------------- #
#         File: vim_mode.zsh
#  Description: 
#       Author: rkumar http://github.com/rkumar/rbcurse/
#         Date:zfm_goto_dir 2013-02-02 - 00:48
#      License: Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)
#  Last update: 2013-02-04 20:39
# ----------------------------------------------------------------------------- #
function vimmode_init() {
    zfm_set_mode "VIM"
    M_MESSAGE="Welcome to VIM Mode. Quit using q z or C-q"
    MULTIPLIER=""
    PENDING=()
    [[ -n $M_VIMMODE_LOADED ]] && return 1
    export M_VIMMODE_LOADED=1
    typeset -Ag keymap_VIM

    ## can use x for selecting as gmail and o for open
    ## can use ' or whatever for hints as in vimperator, it uses 'f' but f has naother meaning here
    # jump to hints for one selection
    vim_bind_key "j" "vim_cursor_down"
    vim_bind_key "k" "vim_cursor_up"
    vim_bind_key "l" "cursor_right"
    vim_bind_key "h" "cursor_left"
    vim_bind_key "PgDn" "cursor_bottom"
    vim_bind_key "PgUp" "cursor_top"
    vim_bind_key "ENTER" "select_current_line"
    # i could have put the name of the fucntion to call here itself but the caller
    # does not do an eval, it executes the method and i don't want an eval happening
    vim_bind_key "g" "vim_set_pending vim_goto_line"
    ## actually G defaults to EOF otherwise it goes to line of MULTI
    #vim_bind_key "G" "vim_motion END"
    vim_bind_key "G" "vim_goto_end"
    vim_bind_key "H" "vim_motion PAGE_TOP"
    vim_bind_key "L" "vim_motion PAGE_END"
    #vim_bind_key "g g" "vim_goto_line"
    #vim_bind_key "G" "zfm_go_bottom"
    #vim_bind_key "g $" "zfm_go_bottom"
    #vim_bind_key "y" "vim_set_pending vim_yank"
    #vim_bind_key "d" "vim_set_pending vim_delete"
    vim_bind_key "y" "vim_set_pending zfm_add_to_selection"
    vim_bind_key "d" "vim_set_pending $ZFM_RM_COMMAND"
    vim_bind_key "o" "vim_set_pending $EDITOR"
    vim_bind_key "e" "zfm_open_file"
    vim_bind_key "x" "zfm_toggle_file"
    #vim_bind_key "y y" "zfm_add_to_selection"
    #vim_bind_key "y G" "zfm_add_to_selection $CURSOR $VPACOUNT"
    # actually we woul rather G and $ etc be defined as motion so they can call others
    # if operator pending
    # "G" "vim_motion $END"
    #
    # all motions commands should calculate position to go to and then call vim_motion with lineno.
    # vim_motion:
    #   checks if operator pending then calls "y" with range, or just sets range and returns
    #   else it moves to that position.
    #   "y" "vim_resolve zfm_add_to_selection"
    vim_bind_key "'" "vim_resolve"
    vim_bind_key "' '" "vim_goto_last_position"
    vim_bind_key "ESCAPE" "vim_escape"
    vim_bind_key "C-c" "vim_escape"
    vim_bind_key "C-g" "vim_escape"
    vim_bind_key "z" "exit_vim"
    vim_bind_key "q" "exit_vim"
    vim_bind_key "g h" "zfm_goto_parent_dir"
    vim_bind_key "t" "zfm_goto_dir"
    vim_bind_key "f" "full_indexing_toggle"
    vim_bind_key "INT" "vim_int_handler"
    vim_bind_key "CHAR" "vim_char_handler"
    vim_bind_key "OTHER" "vim_other_handler"
    vim_bind_key "ENTER" "select_current_line"
    vim_bind_key "g l" "select_current_line"
}
function VIM_key_handler() {
    local key=$1
        if [[ "$key" == <0-9> ]]; then
            vim_int_handler $key
        elif [[ $key =~ ^[a-zA-Z]$ ]]; then
            ## should only be one character otherwise C- and M- etc will all come
            vim_char_handler $key
        elif [[ $#key -eq 1 ]]; then
            # poach on global
            vim_other_handler $key
        else
            ## control and meta up down etc
            binding=$keymap_VIM[$key]
            if [[ -n $binding ]]; then
                zfm_exec_binding $binding
            else
                ## TODO poach on global functions
                zfm_get_key_binding $ZFM_KEY
                [[ -n $binding ]] && zfm_exec_binding $binding
            fi
        return
    fi
}
function exit_vim() {
    zfm_unset_mode
}
function vim_bind_key() {
    # should we check for existing and refuse ?
    keymap_VIM[$1]=$2
    if (( ${+keymap_VIM[$1]} )); then
    else
        perror "Unable to bind $1 to vim keymap "
        pause
    fi
}
## some operations like y and d cannot work without a second character which could be 
# a motion command or the same char. So we set the command as pending a motion command.
# If a yy or dd happends then call that same command. Else push that command onto pending stack.
function vim_set_pending() {
    local f=$1
    if [[ -n $PENDING ]]; then
        if [[ $PENDING[-1] == $f ]]; then
            PENDING[-1]=()
            #zfm_exec_binding $f
            vim_exec $f
            return
        fi
    fi
    PENDING+=( $f )
}
function vim_exec() {
    # first check mult
    # then check range
    # else current cursor
    local f=$1
    local n=$MULTIPLIER
    if [[ -n $MULTIPLIER ]]; then
        RANGE_START=$CURSOR
        (( RANGE_END = CURSOR + MULTIPLIER - 1 ))
        MULTIPLIER=
    fi
    # what if I want to send file names together
    # such as to vim, so they open in one process 
    if [[ -n $RANGE_START ]]; then
        for (( i = $RANGE_START; i <= $RANGE_END; i++ )); do
            ## this will not work in the case of vim_goto_line which expect number not filename
            # actually we need to send this to zfm_exec_binding and not just execit straight
            $f $PWD/$vpa[$i] 
        done
    else
        # take cursor pos
        # actually we need to send this to zfm_exec_binding and not just execit straight
        $f $PWD/$vpa[$CURSOR]
    fi
}

## All motion command should call this command with the target
# rather than try to make the move themselves.
# This checks for a pending operation on which to act, if none then it makes the move
#
# Should we use some symbols like END START HOME MIDDLE etc so user can use these in definitions
# and have them computed somewhere like here, rather than try to put actual variable values in
#  when mapping. 
function vim_motion() {
    local _pos=$1
    ## if pos is a constant then we expect it to be defined as a variable and having that value
    if [[ $_pos =~ [A-Z] ]]; then
        pos=${(P)_pos}
        [[ -z $pos ]] && { perror "$0:: Constant $_pos not defined"; pause; return 1 }
    else
        pos=$_pos
    fi

    ## check for pending method
    if [[ -n $PENDING ]]; then
        f=$PENDING[-1]
        PENDING[-1]=()
        ## the command called will check for CURSOR being current spot
        #  and CURSOR_TARGET as other spot
        #  or should we put START and END to make backward commands easy
        CURSOR_TARGET=$pos
        RANGE_START=$CURSOR
        RANGE_END=$CURSOR_TARGET
        (( CURSOR_TARGET < CURSOR )) && { 
            RANGE_START=$CURSOR_TARGET
            RANGE_END=$CURSOR
        }
        ## what if there's a multiplier thre, should we not unset it ? XXX 5yG
        # vim exec takes care of mult and range etc
        vim_exec $f
        return
    else
        ## make the move
        PREV_CURSOR=$CURSOR
        CURSOR=$pos
        if [[ $CURSOR -lt 1 ]]; then
            zfm_prev_page
        elif [[ $CURSOR -gt $#vpa ]]; then
            zfm_next_page 
        fi
        (( CURSOR < 1 )) && CURSOR=1
    fi
}
function vim_resolve () {
    local key=$ZFM_KEY
    local binding _key ret=0

    read -k _key
    ckey="${key} $_key"
    binding=$keymap_VIM[$ckey]
    if [[ -n $binding ]]; then
        zfm_exec_binding $binding
    else
        perror "[$ckey]: $_key not bound to anything with $key in $ZFM_MODE:: ${(k)ZFM_MODE_MAP}"
        #for f ( ${(k)ZFM_MODE_MAP}) print "[$f] $ZFM_MODE_MAP[$f] ..."
    fi
    MULTIPLIER=""
    return $ret
}
function vim_int_handler() {
    local key=$1
    if [[ -n "$M_FULL_INDEXING" ]]; then
        zfm_get_full_indexing_filename $key
        zfm_open_file $selection
        full_indexing_toggle
    else
        MULTIPLIER+=$1
        pinfo "multiplier is : $MULTIPLIER"
    fi
}
function vim_char_handler() {
    local key=$1
    if [[ -n "$M_FULL_INDEXING" ]]; then
        zfm_get_full_indexing_filename $key
        zfm_open_file $selection
        full_indexing_toggle
    else
        binding=$keymap_VIM[$key]
        if [[ -n $binding ]]; then
            zfm_exec_binding $binding
        fi
    fi
}
function vim_other_handler() {
    ## this gives us unhandled punctuation and other chars which can be routed back to the main map

    zfm_get_key_binding $ZFM_KEY
    if [[ -n $binding ]]; then
        zfm_exec_binding $binding
    else
        M_MESSAGE=" No binding for $ZFM_KEY in global map"
    fi
}
## escape pressed clear stuff or pending commands if possible
function vim_escape() {
    MULTIPLIER=
    M_FULL_INDEXING=
    PENDING=()
}
function vim_cursor_down() {
    PREV_CURSOR=$CURSOR
    local n=$1
    n=${n:-$MULTIPLIER}
    n=${n:-1}
    local newpos
    (( newpos = CURSOR + n ))
    MULTIPLIER=
    vim_motion $newpos
    #(( CURSOR += n ))
    #(( CURSOR > $#vpa )) && { zfm_next_page  }
}
function vim_cursor_up() {
    PREV_CURSOR=$CURSOR
    local n=$1
    n=${n:-$MULTIPLIER}
    n=${n:-1}
    local newpos
    (( newpos = CURSOR - n ))
    MULTIPLIER=
    vim_motion $newpos
    #(( CURSOR -= n ))
    #(( CURSOR < 1 )) && zfm_prev_page
    #(( CURSOR < 1 )) && CURSOR=1
    #MULTIPLIER=""
}

## Goes to specified line, else start.  
# see :help gg
function vim_goto_line() {
    PREV_CURSOR=$CURSOR
    # what if it is sent a file name by mistake and not a number
    local n=$1
    if [[ $n =~ [a-zA-Z] ]]; then
        perror "$0 sent wrong argument $1"
        n=
    fi
    n=${n:-$MULTIPLIER}
    n=${n:-1}
    #let CURSOR=$n
    vim_motion $n
    # if exceeding page, try a page down
    #(( CURSOR > $#vpa )) && { zfm_next_page  }
    #(( CURSOR < 1 )) && CURSOR=1
    MULTIPLIER=
    #[[ $PREV_CURSOR -ne $CURSOR ]] && on_enter_row
}
## goes to line of MULT otherwise defaults to END 
# see :help G
function vim_goto_end() {
    PREV_CURSOR=$CURSOR
    local n
    n=$MULTIPLIER
    n=${n:-$END}
    vim_motion $n
    MULTIPLIER=
}
function vim_goto_last_position(){
    CURSOR=$PREV_CURSOR
}
function vim_yank() {
    # first check mult
    # then check range
    # else current cursor
    local n=$MULTIPLIER
    if [[ -n $MULTIPLIER ]]; then
        RANGE_START=$CURSOR
        (( RANGE_END = CURSOR + MULTIPLIER ))
        MULTIPLIER=
    fi
    if [[ -n $RANGE_START ]]; then
        for (( i = $RANGE_START; i <= $RANGE_END; i++ )); do
            zfm_add_to_selection $PWD/$vpa[$i] 
        done
    else
        # take cursor pos
        zfm_add_to_selection $PWD/$vpa[$CURSOR]
    fi
}
## this is identical to vim_yank except for the command called
function vim_delete() {
    # first check mult
    # then check range
    # else current cursor
    local n=$MULTIPLIER
    if [[ -n $MULTIPLIER ]]; then
        RANGE_START=$CURSOR
        (( RANGE_END = CURSOR + MULTIPLIER ))
        MULTIPLIER=
    fi
    if [[ -n $RANGE_START ]]; then
        for (( i = $RANGE_START; i <= $RANGE_END; i++ )); do
            $ZFM_RM_COMMAND $vpa[$i] 
        done
    else
        # take cursor pos
        $ZFM_RM_COMMAND $vpa[$CURSOR]
    fi
}

#[[ -z $M_VIMMODE_LOADED ]] && vimmode_init
