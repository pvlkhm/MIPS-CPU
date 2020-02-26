all: init

init: out
	./a.out

out: program
	iverilog cpu.v src/data_path.v src/control_path.v src/ALU/alu.v src/CMDMEM/cmdmem.v src/DATAMEM/datamem.v src/PC/pc.v src/REGFILE/regfile.v test/test_cpu.v

program:
	assembler/mipsasm.sh program.asm assembler/program.txt
	assembler/bintomem.sh assembler/program.txt memory/cmd.mem
	rm -rf assembler/program.txt