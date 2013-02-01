#!/usr/bin/env zsh
# ----------------------------------------------------------------------------- #
#         File: vim_mode.zsh
#  Description: 
#       Author: rkumar http://github.com/rkumar/rbcurse/
#         Date: 2013-02-02 - 00:48
#      License: Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)
#  Last update: 2013-02-02 01:33
# ----------------------------------------------------------------------------- #
function exit_vim() {
    zfm_unset_mode
}
function vim_bind_key() {
    # should we check for existing and refuse ?
    keymap_VIM[$1]=$2
    if (( ${+keymap_VIM[$1]} )); then
    else
        perror "Unable to bind $1 to keymap "
        pause
    fi
}
function vimmode_init() {
    zfm_set_mode "VIM"
    [[ -n $M_VIMMODE_LOADED ]] && return 1
    export M_VIMMODE_LOADED=1
    typeset -Ag keymap_VIM
    vim_bind_key "j" "cursor_down"
    vim_bind_key "k" "cursor_up"
    vim_bind_key "l" "cursor_right"
    vim_bind_key "h" "cursor_left"
    vim_bind_key "PgDn" "cursor_bottom"
    vim_bind_key "PgUp" "cursor_top"
    vim_bind_key "ENTER" "select_current_line"
    vim_bind_key "g" "edit_cursor"
    vim_bind_key "ESCAPE" "exit_vim"
    vim_bind_key "z" "exit_vim"
}

#[[ -z $M_VIMMODE_LOADED ]] && vimmode_init
