#!/usr/bin/env zsh
# ----------------------------------------------------------------------------- #
#         File: vim_mode.zsh
#  Description: 
#       Author: rkumar http://github.com/rkumar/rbcurse/
#         Date:zfm_goto_dir 2013-02-02 - 00:48
#      License: Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)
#  Last update: 2013-02-03 02:21
# ----------------------------------------------------------------------------- #
function VIM_key_handler() {
    local key=$1
    #if [[ -z $ZFM_MODE_MAP ]]; then
    #local km=keymap_$ZFM_MODE
    #ZFM_MODE_MAP=(${(Pkv)km})
    #pinfo "initialized zfm_mode_map to $ZFM_MODE: $#ZFM_MODE_MAP"
    #else
    #fi
    #binding=$keymap_VIM[$key]
    #if [[ -n $binding ]]; then
        #$binding
        #key=
        ## NOTE, i think we should only break if the dir has changed
        #return 0
    #else
        # TODO
        # a mode may want charactuers and numbers to do its thing
        # so we should call some general method to handle these
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
                $binding
            else
                ## TODO poach on global functions
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
function vimmode_init() {
    zfm_set_mode "VIM"
    M_MESSAGE="Welcome to VIM Mode. Quit using q z or C-q"
    MULTIPLIER=""
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
    vim_bind_key "g" "vim_resolve"
    vim_bind_key "g g" "vim_goto_line"
    vim_bind_key "G" "zfm_go_bottom"
    vim_bind_key "g $" "zfm_go_bottom"
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
    vim_bind_key "o" "zfm_open_file"
}
function vim_resolve () {
    local key=$ZFM_KEY
    local binding _key ret=0

    read -k _key
    ckey="${key} $_key"
    binding=$keymap_VIM[$ckey]
    if [[ -n $binding ]]; then
        $binding
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
            $binding
        fi
    fi
}
function vim_other_handler() {
    ## this gives us unhandled punctuation and other chars which can be routed back to the main map

    zfm_get_key_binding $ZFM_KEY
    if [[ -n $binding ]]; then
        $binding
    else
        M_MESSAGE=" No binding for $ZFM_KEY in global map"
    fi
}
## escape pressed clear stuff or pending commands if possible
function vim_escape() {
    MULTIPLIER=""
    M_FULL_INDEXING=
}
function vim_cursor_down() {
    PREV_CURSOR=$CURSOR
    local n=$1
    n=${n:-$MULTIPLIER}
    n=${n:-1}
    (( CURSOR += n ))
    (( CURSOR > $#vpa )) && { zfm_next_page  }
    MULTIPLIER=""
}
function vim_cursor_up() {
    PREV_CURSOR=$CURSOR
    local n=$1
    n=${n:-$MULTIPLIER}
    n=${n:-1}
    (( CURSOR -= n ))
    (( CURSOR < 1 )) && zfm_prev_page
    (( CURSOR < 1 )) && CURSOR=1
    MULTIPLIER=""
}
function vim_goto_line() {
    PREV_CURSOR=$CURSOR
    #$cursor_down_action
    #[[ $? -eq 1 ]] && return
    local n=$1
    n=${n:-$MULTIPLIER}
    n=${n:-1}
    let CURSOR=$n
    # if exceeding page, try a page down
    (( CURSOR > $#vpa )) && { zfm_next_page  }
    (( CURSOR < 1 )) && CURSOR=1
    #[[ $PREV_CURSOR -ne $CURSOR ]] && on_enter_row
}
function vim_goto_last_position(){
    CURSOR=$PREV_CURSOR
}

#[[ -z $M_VIMMODE_LOADED ]] && vimmode_init
