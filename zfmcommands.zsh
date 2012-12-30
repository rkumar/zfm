#!/usr/bin/env zsh
# ----------------------------------------------------------------------------- #
#         File: zfmcommands.zsh
#  Description: command picks up by zfm, for user to override or change
#       Author: rkumar http://github.com/rkumar/rbcurse/
#         Date: 2012-12-26 - 15:13
#      License: Freeware
#  Last update: 2012-12-30 22:33
# ----------------------------------------------------------------------------- #

# The delim you are using between commands. If commands use a space inside
# then use comma or some such delim. Otherwise commands will be delimited on space.
#
ZFM_MY_DELIM=,
#
# these are the commands that will be available when you press
# MENU_KEY + c (i.e. backtick + c) and will operate without any file names provided
# usually directory level. They are currently parsed using "read -A" and use IFS.
#
#
ZFM_MY_COMMANDS="ack,ag,tig stats,git stats,ffind,mdfind,locate"
# hotkeys for commands, put space if no hotkey
ZFM_MY_MNEM="agtsf"

#  Now place functions for above commands, otherwise it is expected they
#  are in path, if ZFM_xxx is first looked for, otherwise xxx in $PATH
#

ZFM_ack() {
    # check for whether you have ack installed
    searchpattern=${searchpattern:-""}
    vared -p "Pattern to ack for:" searchpattern
    ack "$searchpattern"
    pause
}


ZFM_ag() {
    # check for whether you have ag installed (the_silver_searcher)
    searchpattern=${searchpattern:-""}
    vared -p "Pattern to ag for:" searchpattern
    ag "$searchpattern"
    pause
}
#
# remove the space when defining the function and add ZFM_ before it.
#
ZFM_tigstats() {
    # check for whether you have tig installed
    # If you have problems committing try setting GIT_EDITOR
    # e.g. export GIT_EDITOR=/usr/local/bin/vim
    echo "C for commit mode, S for status mode"
    tig status
}
ZFM_gitstats() {
    # check for whether you have git installed
    git status -sb | $PAGER
}
ZFM_ffind() {
    # find files with string in filename, uses perl expressions and requires GNU grep (coreutils)
    searchpattern=${searchpattern:-""}
    vared -p "Filename to search for (enter 3 characters): " searchpattern
    # recurse and match filename only
    files=$( print -rl -- **/*(.) | grep -P $searchpattern'[^/]*$' )
    if [[ $#files -gt 0 ]]; then
        files=$( echo $files | xargs ls -t )
        fuzzyselectrow $files

        [[ -n "$selected_file" ]] && {
            fileopt "$selected_file"
        }
    else
        perror "No files matching $searchpattern"
    fi
}
ZFM_locate() {
    perror "Not yet implemented, the results are usually too massive to be of use here"
    searchpattern=${searchpattern:-""}
    vared -p "Filename to 'locate' for (enter >= 3 characters): " searchpattern
    [[ -z $searchpattern ]] && break
    files=$( locate "$searchpattern" | grep -P $searchpattern'[^/]*$' )
    if [[ $#files -gt 0 ]]; then
        # actually if we user -tr then numbering should be reverse too XXX FIXME
        # next will explode dirs
        #files=$( echo $files | xargs ls -tr )
        ZFM_AUTO_COLUMNS="0" fuzzyselectrow $files

        [[ -n "$selected_file" ]] && {
            fileopt "$selected_file"
        }
    else
        perror "No files matching $searchpattern"
    fi
}
ZFM_mdfind() {
    perror "Not yet implemented, the results are usually too massive to be of use here"
}
