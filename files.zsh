#!/usr/bin/env zsh

    setopt EXTENDED_GLOB
today() {
    setopt EXTENDED_GLOB
    checkargs $*;
    #ls *${exclude}(.${not}m0)
    #echo "ls *${exclude}(.${not}m0)"
    eval "ls *${exclude}(.${not}m0)"
}
newerthan() {
    setopt EXTENDED_GLOB
    checkargs $*;
    #echo "ls *${exclude}(.${not}m-$argsrem)" 1>&2
    eval "ls *${exclude}(.${not}m-$argsrem)"
}

olderthan() {
    checkargs $*;
    ls *(.${not}m+$1)
}
zero(){ checkargs $*; ls *(.${not}L0) }
small(){ 
    checkargs $*;
    ls *(.${not}L-20) }
large() { checkargs $*; ls $OPT *(.N${not}Lm+2) }
largerthan() { 
    local sz=""
    local not=""
    local unit="m"
    while [[ -n $1 ]]; do
        case "$1" in
            -n|--not)
                not='^'
                ;;
            -u|--unit)
                shift
                unit=$1
                ;;

            *) sz=$1
                ;;
        esac
        shift
    done
    ls $OPT *(.N${not}L${unit}+$sz) 
}
checkargs() {
    # NOTE This loops through options starting with - leaving the rest
    # however the original array $* in the caller is untouched
    # so to get remmaining params, check argsrem.
    argsrem=""
    #sz=""
    not=""
    except=""
    exclude=""
    unit="m"
    unused=""
    while [[ $1 = -* ]]; do
        case "$1" in
            -n|--not)
                not='^'
                ;;
            -X|--except)
                except='~'
                ;;
            -x|--exclude)
                shift
                exclude="~$1"
                ;;
            --nozip)
                exclude='~(*.bz2|*.gz|*.tgz|*.zip|*.z)'
                ;;
            -u|--unit)
                shift
                unit=$1
                ;;
            *) unused="$unused $1"
                ;;
        esac
        shift
    done
    argsrem="$*"
}
zipfiles() {
    local files=""
    checkargs $*
    [[ -n $not ]] && { not='~' ; files='(.)' }
    eval "ls *${not}(*.bz2|*.gz|*.tgz|*.zip|*.z)${files}"
    #ls *${not}(*.bz2|*.gz|*.tgz|*.zip|*.z)${files}
}

