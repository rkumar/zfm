#!/usr/bin/env zsh
# ----------------------------------------------------------------------------- #
#         File: cursor.zsh
#  Description: cursor movement (arrow key) for file lists
#       Author: rkumar http://github.com/rkumar/rbcurse/
#         Date: 2013-01-21 - 13:22
#      License: Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)
#  Last update: 2013-01-21 13:24
# ----------------------------------------------------------------------------- #
# ## maybe we should have an initi method to be called by zfm
# and we shd put a check that this file is not sourced more than once
# -- trying out on 2013-01-20 - 22:15 
## we simulate a cursor or current line with arrow keys
##  so that user can press ENTER and get the fileopt menu for that file
function cursor_init() {
    export CURSOR_MARK='>'
    CURSOR=1
    zfm_bind_key "DOWN" "cursor_down"
    zfm_bind_key "UP" "cursor_up"
    zfm_bind_key "RIGHT" "cursor_right"
    zfm_bind_key "LEFT" "cursor_left"
    zfm_bind_key "PgDn" "cursor_bottom"
    zfm_bind_key "PgUp" "cursor_top"
    zfm_bind_key "C-j" "select_current_line"
}

cursor_init

function cursor_down () {
    let CURSOR++
}
function cursor_up () {
    let CURSOR--
    (( CURSOR < 1 )) && CURSOR=1
}
function cursor_right () {
    #(( _rows = $#vpa / cols ))
    _rows=$(ceiling_divide $#vpa $cols)
    (( CURSOR += _rows ))
    (( CURSOR < 1 )) && CURSOR=1
    (( CURSOR > $#vpa )) && CURSOR=$#vpa
}
function cursor_left () {
    #(( _rows = $#vpa / cols ))
    _rows=$(ceiling_divide $#vpa $cols)
    (( CURSOR -= _rows ))
    (( CURSOR < 1 )) && CURSOR=1
    (( CURSOR > $#vpa )) && CURSOR=$#vpa
}
ceiling_divide() {
    integer ceiling_result
    ceiling_result=$(($1/$2))
    print $((ceiling_result+1))
}
function cursor_top () {
    CURSOR=1
}
function cursor_bottom () {
    CURSOR=-1
}
function select_current_line () {
    [[ -z "$CURSOR" ]] && { perror "Cursor not on a row." 1>&2; return 1; }
    local selected
    M_NO_AUTO=1
    selected=$vpa[$CURSOR]
    fileopt $selected
}
