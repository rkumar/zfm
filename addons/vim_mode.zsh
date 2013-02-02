#!/usr/bin/env zsh
# ----------------------------------------------------------------------------- #
#         File: vim_mode.zsh
#  Description: 
#       Author: rkumar http://github.com/rkumar/rbcurse/
#         Date: 2013-02-02 - 00:48
#      License: Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)
#  Last update: 2013-02-02 16:06
# ----------------------------------------------------------------------------- #
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
    MULTIPLIER=""
    [[ -n $M_VIMMODE_LOADED ]] && return 1
    export M_VIMMODE_LOADED=1
    typeset -Ag keymap_VIM
    vim_bind_key "j" "vim_cursor_down"
    vim_bind_key "k" "cursor_up"
    vim_bind_key "l" "cursor_right"
    vim_bind_key "h" "cursor_left"
    vim_bind_key "PgDn" "cursor_bottom"
    vim_bind_key "PgUp" "cursor_top"
    vim_bind_key "ENTER" "select_current_line"
    # i could have put the name of the fucntion to call here itself but the caller
    # does not do an eval, it executes the method and i don't want an eval happening
    vim_bind_key "g" "vim_resolve"
    vim_bind_key "g g" "zfm_go_top"
    vim_bind_key "G" "zfm_go_bottom"
    vim_bind_key "g $" "zfm_go_bottom"
    vim_bind_key "ESCAPE" "vim_escape"
    vim_bind_key "z" "exit_vim"
    vim_bind_key "q" "exit_vim"
    vim_bind_key "INT" "vim_int_handler"
    vim_bind_key "CHAR" "vim_char_handler"
    vim_bind_key "OTHER" "vim_other_handler"
    typeset -Ag funcmap_VIM
    funcmap_VIM=(
    g   vim_goto_line
    d   vim_delete_line
    y   vim_yank_line
    )
}
function vim_resolve () {
    local key=$ZFM_KEY
    local binding _key ret=0
    if [[ -n "$vim_multiplier" ]]; then
        ## call the method, it will take care of using the multiplier
        binding=$funcmap_VIM[$key]
        $binding
    else
        ## no multiplier means we must accept another char and then try a mapping
        # however, sadly we can't pass back to main procedure to validate
        # if we could have done a ungetc that would have worked.
        read -k _key
        ckey="${key} $_key"
        binding=$ZFM_MODE_MAP[$ckey]
        if [[ -n $binding ]]; then
            $binding
        else
            perror "[$ckey]: $_key not bound to anything with $key in $ZFM_MODE:: ${(k)ZFM_MODE_MAP}"
            for f ( ${(k)ZFM_MODE_MAP}) print "[$f] $ZFM_MODE_MAP[$f] ..."
            pause
        fi
    fi
    return $ret
}
function vim_int_handler() {
    MULTIPLIER+=$1
    pinfo "multiplier is : $MULTIPLIER"
}
## escape pressed clear stuff or pending commands if possible
function vim_escape() {
    MULTIPLIER=""
}
function vim_cursor_down() {
    local n=$1
    n=${n:-$MULTIPLIER}
    n=${n:-1}
    (( CURSOR += n ))
    (( CURSOR > $#vpa )) && { zfm_next_page  }
    MULTIPLIER=""
}
function vim_goto_line() {
    PREV_CURSOR=$CURSOR
    #$cursor_down_action
    #[[ $? -eq 1 ]] && return
    [[ -z $MULTIPLIER ]] && return
    let CURSOR=$MULTIPLIER
    # if exceeding page, try a page down
    (( CURSOR > $#vpa )) && { zfm_next_page  }
    #[[ $PREV_CURSOR -ne $CURSOR ]] && on_enter_row
}

#[[ -z $M_VIMMODE_LOADED ]] && vimmode_init
