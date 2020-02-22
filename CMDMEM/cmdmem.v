module cmdmem(
    input [31:0] addr,
    output [31:0] cmd
);

reg [31:0] memory [0:31];

assign cmd = memory[addr];

endmodule