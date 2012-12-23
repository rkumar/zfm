#!/usr/bin/env zsh
#  Date: 2012-12-17 
#  Last update: 2012-12-21 20:14
#  A very quaint numering tool that numbers first 9 lines 
#  and then uses first letter of file name or item as key
# XXX we do use q for exiting, will have to think of something else
let c=1
local patt='.'
##local defpatt='.'
local defpatt=""
[[ $1 = "-p" ]] && { shift; patt="$1"; shift }
# since string searching in zsh isn;t on regular expressions and ^ is not respected
# i am taking width of match after removing ^ and using next char as next shortcut
patt=${patt:s/^//}
local w=$#patt
#let w++
nlidx="123456789abcdefghijklmnoprstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
while IFS= read -r line; do
    if [[ -n "$M_FULL_INDEXING" ]]; then
        sub=$nlidx[$c]
    else
        sub=$c
        [[ $c -gt 9 ]] && {
            #sub=$line[$w,$w] ;  
            # in the beggining since the patter is . we show first char
            # otherwise this will match the dot
            if [[ $patt = "$defpatt" ]]; then
                sub=$line[1,1]
            else
                # after removing the ^ we find match and get the character after the pattern
                # NOTE: that if the match is at end of filename there is no next character i can show.
                ix=$line[(i)$patt]
                (( ix += w ))
                sub=$line[$ix,$ix] ;  
            fi
        }
    fi
    print -r -- "$sub) $line"
    let c++
done
