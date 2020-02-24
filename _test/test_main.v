module test_main();

reg clk, rst;
main testee(.clk(clk), .rst(rst));

initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, test_main);
end
initial #40 $finish;
initial #0 clk = 0;
initial #0 rst = 1;
initial #2 rst = 0;
always begin
    #1 clk = !clk;
end

endmodule
