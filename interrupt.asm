mfc $s0
xori $s1, $s0, 2
bne $s1, $0, 2
nop
rfe
xori $s1, $s0, 1
bne $s1, $0, 1
j 63
nop
nop
rfe
nop