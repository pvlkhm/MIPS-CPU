addi $t0, $0, 12
addi $t1, $0, 24
nop
add $s0, $t1, $t0
sub $s1, $t1, $t0
and $s2, $t1, $t0
or $s3, $t1, $t0
xor $s4, $t1, $t0
sll $s5, $t1, 2
srl $s6, $t1, 2
nop
addi $t3, $t0, 1
andi $t4, $t0, 6
ori $t5, $t0, 6
xori $t6, $t0, 6
nop
sw $t1, 4($0)
nop
lw $t7, 4($0)
nop
jal 24
addi $t8, $t8, 1
j 26
nop
addi $t8, $0, 255
jr $ra
nop
beq $t0, $t1, 1
bne $t0, $t1, 1
sw $t1, 8($0)
sw $t1, 12($0)
addi $t8, $t8, 1