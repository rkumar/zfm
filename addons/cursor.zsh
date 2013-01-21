#!/usr/bin/env zsh
# ----------------------------------------------------------------------------- #
#         File: cursor.zsh
#  Description: cursor movement (arrow key) for file lists
#       Author: rkumar http://github.com/rkumar/rbcurse/
#         Date: 2013-01-21 - 13:22
#      License: Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)
#  Last update: 2013-01-22 00:56
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
    ## -le required for empty dirs
    [[ $CURSOR -le 1 ]] && { goto_parent_dir ; return }
    let CURSOR--
    (( CURSOR < 1 )) && CURSOR=1
}
## goes to files in next column
# if no files on right, and on a dir, then goes into dir
function cursor_right () {
    #(( _rows = $#vpa / cols ))
    _rows=$(ceiling_divide $#vpa $cols)
    local old=$CURSOR
    (( CURSOR += _rows ))
    (( CURSOR < 1 )) && CURSOR=1
    ## slightly dicey or clever if right pressed on a dir
    # and you can't go anymore right then traverse into the dir.
    # Should we do this always on a dir, or only if there's one row ?
    #
    (( CURSOR > $#vpa )) && { 
        CURSOR=$#vpa
        selected=$vpa[$old]
        if [[ -d "$selected" ]]; then
            selection=$selected
        fi
    }
}
## moves to files in left column
# if pressed on first file, pops dir stack
function cursor_left () {
    ## -le required for empty dirs
    [[ $CURSOR -le 1 ]] && { zfm_popd ; return }
    _rows=$(ceiling_divide $#vpa $cols)
    (( CURSOR -= _rows ))
    (( CURSOR < 1 )) && CURSOR=1
    (( CURSOR > $#vpa )) && CURSOR=$#vpa
}
# http://stackoverflow.com/questions/2394988/get-ceiling-integer-from-number-in-linux-bash
ceiling_divide() {
  ceiling_result=$((($1+$2-1)/$2))
  print $ceiling_result
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
    if [[ -d "$selected" ]]; then
        ## or should we have some options for directories ? we should
        #FT_DIRS
        # this falls through into caller of list_printer which changes
        # dirctory.
        selection=$selected
    else
        fileopt $selected
    fi
}
