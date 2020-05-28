module test_cpu();

reg clk, rst, irq;
cpu testee(.clk(clk), .rst(rst), .irq(irq));

initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, test_cpu);
end
initial #1000 $finish;
initial #0 clk = 0;
initial #0 rst = 1;
initial #0 irq = 0;
initial #2 rst = 0;
initial #54 irq = 1;
initial #56 irq = 0;

always begin
    #1 clk = !clk;
end

endmodule
