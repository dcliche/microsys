module alu_tb;

    bit clk;
    bit[15:0] data_a;
    bit[15:0] data_b;
    bit data_d_we;
    bit[4:0] alu_op;
    bit[15:0] pc;
    bit[15:0] data_imm;
    bit[15:0] data_result;
    bit data_write_reg;
    bit should_branch;

    `include "constants.sv"

    initial begin
        $dumpfile("alu.vcd");
        $dumpvars(0, dut);
        $monitor("time=%2d, data_result=%d", $time, data_result);
        data_imm = 16'hF1FA;
        data_a = 16'h0005;
        data_b = 16'hFFFE;
        alu_op = {`OPCODE_ADD, 1'b1};

        #20 data_a = 16'h0001;
        data_b = 16'h0004;
        alu_op = {`OPCODE_SHL, 1'b0};

        #100 $stop;
    end

    always #5 clk = ~clk;

    alu dut(.clk, .en(1'b1), .data_a, .data_b, .data_d_we, .alu_op, .pc, .data_imm, .data_result, .data_write_reg, .should_branch);

endmodule