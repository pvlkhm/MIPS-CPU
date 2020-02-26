#!/bin/bash

file=$1
program=$2
`` > $program

#Поиск opcode
opcode=""
findOpcode() {
    case $1 in
    addi) opcode="001000";;
    andi) opcode="001100";;
    ori)  opcode="001101";;
    xori) opcode="001110";;
    beq)  opcode="000100";;
    bnq)  opcode="000101";;
    lw)   opcode="100011";;
    sw)   opcode="101011";;
    j)    opcode="000010";;
    jal)  opcode="000011";;
    jr)   opcode="000000";;
    *)    opcode="xxxxxx";;
    esac
}

#Поиск funct
funct=""
findFunct() {
    case $1 in
    add) funct="100000";;
    sub) funct="100010";;
    and) funct="100100";;
    or)  funct="100101";;
    xor) funct="100110";;
    sll) funct="000000";;
    srl) funct="000010";;
    jr)  funct="001000";;
    *)   funct="xxxxxx";;
    esac
}

#Поиск регистров reg
reg=""
findReg() {
    case $1 in
    0) reg="00000";; at) reg="00001";; v0) reg="00010";; v1) reg="00011";;
    a0) reg="00100";; a1) reg="00101";; a2) reg="00110";; a3) reg="00111";;
    t0) reg="01000";; t1) reg="01001";; t2) reg="01010";; t3) reg="01011";;
    t4) reg="01100";; t5) reg="01101";; t6) reg="01110";; t7) reg="01111";;
    s0) reg="10000";; s1) reg="10001";; s2) reg="10010";; s3) reg="10011";;
    s4) reg="10100";; s5) reg="10101";; s6) reg="10110";; s7) reg="10111";;
    t8) reg="11000";; t9) reg="11001";; k0) reg="11010";; k1) reg="11011";;
    gp) reg="11100";; sp) reg="11101";; fp) reg="11110";; ra) reg="11111";;
    *) reg="xxxxx";;
    esac
}

while read line || [[ -n $line ]]; do
    cmd=${line%% *}
    case $cmd in
    add|sub|and|or|xor)
        {
        echo -n "000000"
        rs=${line#*, }
        rs=${rs%%,*}
        findReg ${rs#$}
        echo -n $reg
        rt=${line##*, }
        findReg ${rt#$}
        echo -n $reg
        rd=${line#* }
        rd=${rd%%,*}
        findReg ${rd#$}
        echo -n $reg
        echo -n "00000"
        f=${line%% *}
        findFunct $f
        echo -n $funct
        echo
        } >> $program
        ;;
    sll|srl)
        {
        echo -n "000000"
        echo -n "00000" 
        rt=${line#*, }
        rt=${rt%%,*}
        findReg ${rt#$}
        echo -n $reg
        rd=${line#* }
        rd=${rd%%,*}
        findReg ${rd#$}
        echo -n $reg
        shamt=${line##*, }
        printf "%05.5s" $(echo "obase=2;$shamt" | bc)
        f=${line%% *}
        findFunct $f
        echo -n $funct
        echo
        } >> $program
        ;;
    addi|andi|ori|xori|beq|bne|lw|sw)
        {
        op=${line%% *}
        findOpcode $op
        echo -n $opcode
        rs=${line#*, }
        rs=${rs%%,*}
        findReg ${rs#$}
        echo -n $reg
        rd=${line#* }
        rd=${rd%%,*}
        findReg ${rd#$}
        echo -n $reg
        immd=${line##*, }
        printf "%016.16s" $(echo "obase=2;$immd" | bc)
        echo
        } >> $program
        ;;
    j|jal)
        {
        op=${line%% *}
        findOpcode $op
        echo -n $opcode
        addr=${line##* }
        printf "%026.26s" $(echo "obase=2;$addr" | bc) 
        echo
        } >> $program
        ;;
    jr)
        {
        echo -n "000000"
        rs=${line##* }
        findReg ${rs#$}
        echo -n $reg
        echo -n "00000"
        echo -n "00000"
        echo -n "00000"
        f=${line%% *}
        findFunct $f
        echo -n $funct
        echo
        } >> $program
        ;;
    nop)
        for i in {1..32}; do echo -n "0" >> $program; done
        echo >> $program
        ;;
    *)
        echo "unknown command in ${line}"
        exit
        ;;
    esac
done < $file


