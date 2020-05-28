#!/bin/bash

file=$1
memory=$2
`` > $memory

i=64

while read line || [[ -n $line ]]; do
    {
    echo -n "${line:24:8} "
    echo -n "${line:16:8} "
    echo -n "${line:8:8} "
    echo -n "${line:0:8}"
    echo
    } >> $memory
    i=$(( i - 1 ))
done < $file

while [[ $i -ne 0 ]]; do
    echo -n "00000000 00000000 00000000 00000000" >> $memory
    echo >> $memory
    i=$(( i - 1 ))
done
