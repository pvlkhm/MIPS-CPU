module main(
    input clk, rst
);

wire JBEQ, JJRJAL, JAL, JR, RI, LW, SHIFT, SRL;
wire writeReg, writeMem;
wire [2:0] op;
wire [5:0] opcode, funct;
wire zero;

data_path data_path(.clk(clk), .rst(rst),
                    .JBEQ(JBEQ), .JJRJAL(JJRJAL), .JAL(JAL), .JR(JR), .RI(RI), .LW(LW), .SHIFT(SHIFT), .SRL(SRL),
                    .writeReg(writeReg), .writeMem(writeMem), .op(op),
                    .opcode(opcode), .funct(funct), .zero(zero));

control_path control_path(  .opcode(opcode), .funct(funct),
                            .zero(zero),
                            .JBEQ(JBEQ), .JJRJAL(JJRJAL), .JAL(JAL), .JR(JR), .RI(RI), .LW(LW), .SHIFT(SHIFT), .SRL(SRL),
                            .writeReg(writeReg), .writeMem(writeMem),
                            .op(op));

endmodule
