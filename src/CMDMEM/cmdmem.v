// Little Endian
// Побайтная адресация
module cmdmem(
    input [31:0] addr,
    output [31:0] cmd
);

initial $readmemb("./memory/cmd.mem", memory);

reg [7:0] memory [0:32*4-1];

assign cmd = {memory[addr + 3], memory[addr + 2], memory[addr + 1], memory[addr]};


endmodule