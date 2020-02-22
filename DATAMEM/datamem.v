module datamem(
    input clk, writeMem,
    input [31:0] addr, writeData,
    output [31:0] data
);

reg [31:0] memory [0:31];

assign data = memory[addr];

always  @(posedge clk) begin
    if (writeMem) memory[addr] <= writeData;
end

endmodule