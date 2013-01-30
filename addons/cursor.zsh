#!/usr/bin/env zsh
# ----------------------------------------------------------------------------- #
#         File: cursor.zsh
#  Description: cursor movement (arrow key) for file lists
#       Author: rkumar http://github.com/rkumar/rbcurse/
#         Date: 2013-01-21 - 13:22
#      License: Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)
#  Last update: 2013-01-30 19:11
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
    zfm_bind_key "ENTER" "select_current_line"
    zfm_bind_key "ML g" "edit_cursor"
    cursor_up_action=_my_goto_parent
    cursor_left_action=_my_popd
    cursor_right_action=_my_cd
    cursor_down_action=
}

cursor_init

function cursor_down () {
    PREV_CURSOR=$CURSOR
    $cursor_down_action
    [[ $? -eq 1 ]] && return
    let CURSOR++
    [[ $PREV_CURSOR -ne $CURSOR ]] && on_enter_row
    #selected=$vpa[$CURSOR]
    #if [[ -d "$selected" ]]; then
        #M_MESSAGE="=> Press Enter to cd into directory"
    #else
        #M_MESSAGE="=> Press Enter to run command on file"
        #M_MESSAGE=
    #fi
}
function cursor_up () {
    PREV_CURSOR=$CURSOR
    ## -le required for empty dirs
    $cursor_up_action
    [[ $? -eq 1 ]] && return
    let CURSOR--
    M_MESSAGE=
    (( CURSOR == 1 )) && { M_MESSAGE="=>  <UP>:parent, <LEFT>:popd" }
    (( CURSOR < 1 )) && CURSOR=1
    [[ $PREV_CURSOR -ne $CURSOR ]] && on_enter_row
}
function _my_goto_parent() {
    [[ $CURSOR -le 1 ]] && { goto_parent_dir ; return 1 }
    return 0
}
## goes to files in next column
# if no files on right, and on a dir, then goes into dir
# XXX if we are not displayig entire list shouldnot right pan to other rows basically paging
function cursor_right () {
    PREV_CURSOR=$CURSOR
    $cursor_right_action
    [[ $? -eq 1 ]] && return

    local old=$CURSOR

    _rows=$(ceiling_divide $#vpa $LIST_COLS)
    (( CURSOR += _rows ))
    (( CURSOR < 1 )) && CURSOR=1
    (( CURSOR > $#vpa )) && { 
        CURSOR=$PREV_CURSOR
        (( rem = CURSOR / _rows ))
        (( CURSOR = ( CURSOR - ( _rows * rem )) + 1 ))

    }
    [[ $PREV_CURSOR -ne $CURSOR ]] && on_enter_row
}
function _my_cd() {
    ## slightly dicey or clever if right pressed on a dir
    # and you can't go anymore right then traverse into the dir.
    # Should we do this always on a dir, or only if there's one row ?
    #
    #(( CURSOR >= $#vpa )) && { 
        #CURSOR=$#vpa
        if [[ $LIST_COLS -eq 1 ]]; then
            selected=$vpa[$PREV_CURSOR]
            if [[ -d "$selected" ]]; then
                selection=$selected
                return 1
            fi
        fi
    #}
    return 0
}
## moves to files in left column
# if pressed on first file, pops dir stack
function cursor_left () {
    PREV_CURSOR=$CURSOR
    ## -le required for empty dirs
    $cursor_left_action
    [[ $? -eq 1 ]] && return
    _rows=$(ceiling_divide $#vpa $LIST_COLS)
    (( CURSOR -= _rows ))
    #(( CURSOR < 1 )) && CURSOR=1
    (( CURSOR < 1 )) && { 
        CURSOR=$PREV_CURSOR
        (( i = _rows * ( LIST_COLS - 1) ))
        (( CURSOR = ( i + CURSOR - 1 ) ))

    }
    (( CURSOR > $#vpa )) && CURSOR=$#vpa

    [[ $PREV_CURSOR -ne $CURSOR ]] && on_enter_row
}
function _my_popd() {
    [[ $CURSOR -le 1 ]] && { zfm_popd ; return 1 }
    return 0
}
# http://stackoverflow.com/questions/2394988/get-ceiling-integer-from-number-in-linux-bash
ceiling_divide() {
  ceiling_result=$((($1+$2-1)/$2))
  print $ceiling_result
}
#
# typically mapped to PgUp
function cursor_top () {
    PREV_CURSOR=$CURSOR
    CURSOR=1
    [[ $PREV_CURSOR -ne $CURSOR ]] && on_enter_row
}
#
# typically mapped to PgDn
function cursor_bottom () {
    PREV_CURSOR=$CURSOR
    CURSOR=$#vpa
    [[ $PREV_CURSOR -ne $CURSOR ]] && on_enter_row
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
        #selection=$selected
        fileopt $selected
    else
        fileopt $selected
    fi
}
## what to do when user enters a row, such as display some text or 
# help or pop or enter dir
function on_enter_row() {
    selected=$vpa[$CURSOR]
    if [[ -d "$selected" ]]; then
        M_MESSAGE="=> Press Enter to cd into directory"
    else
        M_MESSAGE="=> Press Enter to run command on file"
        #
        ## only display details in multicol listing when file details are not shown
        if [[ $LIST_COLS -gt 1 ]]; then
            get_file_details $selected
            M_MESSAGE="$M_HELP [$CURSOR] $_detail"
        fi
    fi

}
function edit_cursor() {
    vared -p "Goto line: " CURSOR
}
