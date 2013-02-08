#!/usr/bin/env zsh
# ----------------------------------------------------------------------------- #
#         File: insmode.zsh
#  Description: insert mode key handling basically filters list as you type
#       Author: rkumar http://github.com/rkumar/rbcurse/
#         Date: 2013-02-06 - 19:51
#      License: GPL
#  Last update: 2013-02-08 15:12
# ----------------------------------------------------------------------------- #
#  Copyright (C) 2012-2013 rahul kumar

function insmode_init() {
    mess "INS Mode: C-g: clear pattern, C-c: Exit mode"
}
function ins_key_handler() {
    local ans=$1
    # is ix even used ?? XX
    local ix
    case $ans in
        "")
            # BLANK blank
            (( sta = 1 ))
            PATT=""
            ;;
        [1-9])
            # KEY PRESS key

                # actix needs to be consistent in 2 cases:
                #   - when paging - correct is from myopts
                #   - when filtering. (in this case the correct is from viewport/vpa
                #   - there is a third case of paging after filtering GAAH
                (( ix = sta + $ans - 1))
                #
                # NEW now check if 2 files satisfy this key (edge case but
                # could happen alot if you keep numbered files)

                selection=
                if [[ $VPACOUNT -gt 9 ]]; then
                    if [[ $PATT = "" ]]; then
                        npatt="${ans}*"
                    else
                        npatt="$PATT$ans"
                    fi
                    lines=
                    if [[ -n "$M_SWITCH_OFF_DUPL_CHECK" ]]; then
                        lines=$(check_patt $npatt)
                        ## XXX why not ct=$#lines 2013-01-24 - 20:05 
                        ct=$(print -rl -- $lines | wc -l)
                    else
                        ct=0
                    fi
                    [[ -n $lines ]] || ct=0
                    [[ -n $ZFM_VERBOSE ]] && pdebug "comes here $ct , ($lines)"
                    if [[ $ct -eq 1 ]]; then
                        [[ -n "$lines" ]] && { selection=$lines; break }
                    elif [[ $ct -eq 0 ]]; then
                        selection=$vpa[$ans]
                        #selection=$myopts[$ix] # fails on filtering
                        [[ -n $ZFM_VERBOSE ]] && print " selected $selection"
                    else
                        PATT=$npatt
                    fi
                else
                    # there are only 9 or less so just use mnemonics, don't check
                    # earlier
                    selection=$vpa[$ans]
                fi
            [[ -n "$selection" ]] && break
            ;;
        [a-zA-Z_0\.\ \*])
            ## UPPER CASE upper section alpha characters
            (( sta = 1 ))

                if [[ $PATT = "" ]]; then
                    [[ $ans = '.' ]] && { 
                        # i will be doing this each time dot is pressed
                        # ad changing setting for calling shell too ! XXX
                        pdebug "I should only set and do this if nothing is showing or glob dots is off"
                        #pbold "Setting glob_dots ..."
                        #setopt GLOB_DOTS
                        show_hidden_toggle
                        #setopt globdots
                        param=$(eval "print -rl -- ${pattern}(${MFM_LISTORDER}$filterstr)")
                        myopts=("${(@f)$(print -rl -- $param)}")
                        pbold "count is $#myopts"
                    }
                    PATT="${ans}"
                else
                    [[ -n $ZFM_VERBOSE ]] && pdebug "comes here 1"

                    ## Fpatt is either unset or contains .*
                    PATT+="${FPATT}$ans"
                fi
                ## if there's only one file for that char then just jump to it
                lines=$(check_patt $PATT)
                ct=$(print -rl -- $lines | wc -l)
                if [[ $ct -eq 1 ]]; then
                    [[ -n "$lines" ]] && { selection=$lines; break }
                fi
            ;;
        BACKSPACE)
            # BACKSPACE backspace if we are filtering, if blank and still backspace then put start of line char
            if [[ $PATT = "" ]]; then
                M_NO_REPRINT=1
            else
                # backspace if we are filtering, remove last char from pattern
                #patt=${patt[1,${#patt}-1]}
                PATT[-1]=
                PATT=${PATT%.*}
            fi
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
            zfm_set_mode $ZFM_DEFAULT_MODE
            ;;

        *)
            zfm_exec_key_binding $ans
            ans=
            ;; 

    esac

    ## above this line is insert mode
}
