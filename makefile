all: init

init: out
	./a.out

out: program
	iverilog cpu.v src/data_path.v src/control_path.v src/ALU/alu.v src/CMDMEM/cmdmem.v src/CACHE/DATAMEM/datamem.v src/PC/pc.v src/REGFILE/regfile.v test/test_cpu.v src/hazard_mngr.v src/CACHE/cache.v src/CACHE/cacheBuffer.v src/CACHE/memoryBuffer.v src/CACHE/tableControl.v src/CACHE/tableData.v

program:
	assembler/mipsasm.sh program.asm assembler/program.txt
	assembler/bintomem.sh assembler/program.txt memory/cmd.mem
	rm -rf assembler/program.txt