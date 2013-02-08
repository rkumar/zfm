#!/usr/bin/env zsh
# ----------------------------------------------------------------------------- #
#         File: hintmode.zsh
#  Description: hint mode
#       Author: rkumar http://github.com/rkumar/rbcurse/
#         Date: 2013-02-06 - 22:31
#      License: GPL
#  Last update: 2013-02-08 15:14
# ----------------------------------------------------------------------------- #
#  Copyright (C) 2012-2013 rahul kumar

function hintmode_init() {
    mess "HINT Mode: C-c: Exit mode"
    M_FULL_INDEXING=1
    [[ $ZFM_PREV_MODE == "HINT" ]] || ZFM_PREV_MODE=$ZFM_MODE
}
function hint_key_handler() {
    local ans=$1
    # is ix even used ?? XX
    local ix
    case $ans in
        [1-9a-zA-Z])
            zfm_get_full_indexing_filename $ans
            ;;
        $ZFM_REFRESH_KEY)
            zfm_refresh
            ;;
        "$ZFM_RESET_PATTERN_KEY")
            PATT=""
            ;;
        "$ZFM_OPEN_FILES_KEY")
            # I think this overrides what cursor.zsh defines
            ## Open either selected files or what's under cursor
            if [[ -n $selectedfiles ]];then 
                call_fileoptions $selectedfiles
            else
                selection=$vpa[$CURSOR]
            fi
            [[ -n "$selection" ]] && break
            ;; 
        "C-g" )
            PATT=
            ;;
        "C-c")
            M_FULL_INDEXING=
            local mo=$ZFM_PREV_MODE
            if [[ $ZFM_PREV_MODE == "HINT" ]]; then
                mo=$ZFM_DEFAULT_MODE
            fi
            zfm_set_mode $mo
            ;;

        *)
            zfm_exec_key_binding $ans
            ans=
            ;; 
    esac

    ## above this line is insert mode
}
