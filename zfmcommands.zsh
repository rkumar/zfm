#!/usr/bin/env zsh
# ----------------------------------------------------------------------------- #
#         File: zfmcommands.zsh
#  Description: command picks up by zfm, for user to override or change
#       Author: rkumar http://github.com/rkumar/rbcurse/
#         Date: 2012-12-26 - 15:13
#      License: Freeware
#  Last update: 2012-12-28 21:06
# ----------------------------------------------------------------------------- #

ZFM_MY_DELIM=,
export ZFM_MY_COMMANDS="ack,ag,tig stats,git stats"
# hotkeys for commands, put space if no hotkey
export ZFM_MY_MNEM="agts"

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
    # check for whether you have ag installed
    searchpattern=${searchpattern:-""}
    vared -p "Pattern to ag for:" searchpattern
    ag "$searchpattern"
    pause
}
ZFM_tigstats() {
    # check for whether you have tig installed
    # If you have problems committing try setting GIT_EDITOR
    # e.g. export GIT_EDITOR=/usr/local/bin/vim
    echo "C for commit mode, S for status mode"
    tig status
}
ZFM_gitstats() {
    # check for whether you have tig installed
    git status -sb | $PAGER
}
