// Little Endian
// Побайтная адресация
module datamem(
    input clk, writeMem,
    input [31:0] addr, writeData,
    output [31:0] data
);

initial $readmemb("./memory/empty.mem", memory);

reg [7:0] memory [0:32*4-1];

assign data = {memory[addr + 3], memory[addr + 2], memory[addr + 1], memory[addr]};

always @(posedge clk)
    if (writeMem) {memory[addr + 3], memory[addr + 2], memory[addr + 1], memory[addr]} <= writeData;

always @(posedge clk) $writememb("./memory/data.mem", memory);

endmodule