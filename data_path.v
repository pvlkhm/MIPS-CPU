/*
JBEQ — Jump относительный (После beq/bne)
JJRJAL — Jump по прямому/псевдопрямому адресу
JAL — Выбор регистра $ra для записи при jal
JR – Выбор адреса для jump'а из регистра
RI – R или I инструкция
LW – Инструкция lw
SHIFT – Инструкиця сдвига
SRL – Выбор сдвига вправо (srl)
writeReg/writeMem – разрешение записи по clk в память
*/
module data_path(
    input clk, rst,
    input JBEQ, JJRJAL, JAL, JR, RI, LW, SHIFT, SRL,
    input writeReg, writeMem,
    input [2:0] op,
    output [5:0] opcode, funct,
    output zero
);

// PC + CMDMEM wires
wire [31:0] nextaddr, addr, cmd;
wire [31:0] addrDirect, addrRelate, addrAdd4;
// REGFILE wires
wire [4:0] wa;
wire [31:0] wd, rd1, rd2;
// ALU + near wires
wire [31:0] b, c;
wire [31:0] shiftRt;
// DATAMEM wires
wire [31:0] addrData, data;


// Выбор частей из шины команды
wire [4:0] rs, rt, rdR, shamt, rdI;
wire [15:0] immd;
wire [25:0] jaddr;
assign  opcode = cmd[31:26],
        rs = cmd[25:21],
        rt = cmd[20:16],
        rdR = cmd[15:11],
        shamt = cmd[10:6],
        funct = cmd[5:0],
        rdI = cmd[20:16],
        immd = cmd[15:0],
        jaddr = cmd[25:0];


// Расширение со знаком immd 16->32
wire [31:0] immd32;
assign immd32 = {{16{immd[15]}}, immd};
// Выбор нужного адреса записи для REGFILE
assign wa = JAL ? 5'd31 : (RI ? rd2 : rd1);
// Выбор второго (b) значения ALU + сдвинутый rt 
assign b = RI ? immd32 : rd2;
assign shiftRt = SRL ? rd2 >> shamt : rd2 << shamt;
// Выбор адреса для Data Memory
assign addrData = SHIFT ? shiftRt : c;
// Выбор значения записи для REGFILE
assign wd = LW ? data : addrData;
// Выбор следующей команды для PC
assign addrAdd4 = addr + 4;
assign addrDirect = JR ? rd1 : {addr[31:28], jaddr, 4'b0000};
assign addrRelate = JBEQ ? ((immd32 << 2) + addrAdd4) : addrAdd4;
assign nextaddr = JJRJAL ? addrDirect : addrRelate;


pc pc(.clk(clk), .rst(rst), .nextaddr(nextaddr), .addr(addr));
cmdmem cmdmem(.addr(addr), .cmd(cmd));
regfile regfile(.clk(clk), .rst(rst), .writeReg(writeReg),
                .ra1(rs), .ra2(rt), .wa(wa), .wd(wd),
                .rd1(rd1), .rd2(rd2));
alu alu(.op(op), .a(rd1), .b(b), .c(c), .zero(zero));
datamem datamem(.clk(clk), .writeMem(writeMem), .addr(addrData), .writeData(rd2), .data(data));


endmodule