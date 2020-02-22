// Счетчик команд
module pc(
    input clk, rst,
    input [31:0] nextaddr,
    output reg [31:0] addr
);
    always @(posedge clk) begin
        if (rst) addr <= 32'd0;
        else addr <= nextaddr;
    end
endmodule