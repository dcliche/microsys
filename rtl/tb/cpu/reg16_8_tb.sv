module reg16_8_tb;

    bit clk;
    bit en;
    bit we;
    bit[15:0] data_d;
    bit[2:0] sel_a;
    bit[2:0] sel_b;
    bit[2:0] sel_d;
    bit[15:0] data_out_a;
    bit[15:0] data_out_b;

    initial begin
        $dumpfile("reg16_8.vcd");
        $dumpvars(0, dut);
        en = 1;
        sel_a = 0;
        sel_b = 1;
        sel_d = 0;
        data_d = 16'hFAB5;
        we = 1;
        #50 we = 0;
        sel_b = 0;
        #100 $stop;
    end

    always #5 clk = !clk;

    reg16_8 dut(.clk, .en, .we, .data_d, .sel_a, .sel_b, .sel_d, .data_out_a, .data_out_b);

endmodule