module test_cpu();

reg clk, rst;
cpu testee(.clk(clk), .rst(rst));

initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, test_cpu);
end
initial #40 $finish;
initial #0 clk = 0;
initial #0 rst = 1;
initial #2 rst = 0;
always begin
    #1 clk = !clk;
end

endmodule
