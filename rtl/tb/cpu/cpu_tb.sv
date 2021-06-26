module cpu_tb;

    bit clk;
    bit en;
    bit[15:0] data_a;
    bit[15:0] data_b;
    bit data_d_we;
    bit[4:0] alu_op;
    bit[15:0] pc;
    bit[15:0] data_imm;
    bit[15:0] data_result;
    bit data_write_reg;
    bit should_branch;
    bit[15:0] instruction;
    bit reg_d_we;
    bit[2:0] sel_a, sel_b, sel_d;

    bit[15:0] dbg_reg0;
    bit[15:0] dbg_reg1;
    bit[15:0] dbg_reg2;
    bit[15:0] dbg_reg3;
    bit[15:0] dbg_reg4;
    bit[15:0] dbg_reg5;
    bit[15:0] dbg_reg6;
    bit[15:0] dbg_reg7;

    `include "constants.sv"

    initial begin
        $dumpfile("cpu.vcd");
        $dumpvars(0, alu0);
        $dumpvars(0, reg0);
        $monitor("time=%2d, data_result=%d, r0=%x, r1=%x, r2=%x, r3=%x,", $time, data_result, dbg_reg0, dbg_reg1, dbg_reg2, dbg_reg3);

        repeat(10) @(posedge clk);
        en = 1;

        @(posedge clk);
        @(posedge clk);

        // load.h r0,0xfe
        instruction = {`OPCODE_LOAD, 3'b000, 1'b0, 8'hFE};
        @(posedge clk);
        @(posedge clk);

        // load.l r1, 0xed
        instruction = {`OPCODE_LOAD, 3'b001, 1'b1, 8'hED};
        @(posedge clk);
        @(posedge clk);
 
        // or r2, r0, r1
        instruction = {`OPCODE_OR, 3'b010, 1'b0, 3'b000, 3'b001, 2'b00};
        @(posedge clk);
        @(posedge clk);

        /*

        // load.l r3, 1
        instruction = {`OPCODE_LOAD, 3'b011, 1'b1, 8'h01};
        @(posedge clk);
        @(posedge clk);
 
        // load.l r4, 2
        instruction = {`OPCODE_LOAD, 3'b100, 1'b1, 8'h02};
        @(posedge clk);
        @(posedge clk);


        // add.u r3, r3, r4
        instruction = {`OPCODE_ADD, 3'b011, 1'b0, 3'b011, 3'b100, 2'b00};
        @(posedge clk);
        @(posedge clk);

        // or r5, r0, r3
        instruction = {`OPCODE_OR, 3'b101, 1'b0, 3'b000, 3'b011, 2'b00};
        @(posedge clk);
        @(posedge clk);
        */

        #1000 $stop;
    end

    always #5 clk = ~clk;

    decode decode0(
        .clk,
        .en,
        .data_inst(instruction),
        .sel_a,
        .sel_b,
        .sel_d,
        .data_imm,
        .reg_d_we(data_d_we),
        .alu_op
    );

    alu alu0(
        .clk,
        .en,
        .data_a,
        .data_b,
        .data_d_we,
        .alu_op,
        .pc,
        .data_imm,
        .data_result,
        .data_write_reg,
        .should_branch
    );

    reg16_8 reg0(
        .clk,
        .en,
        .data_d(data_result),
        .data_out_a(data_a),
        .data_out_b(data_b),
        .sel_a,
        .sel_b,
        .sel_d,
        .we(data_write_reg),

        .dbg_reg0,
        .dbg_reg1,
        .dbg_reg2,
        .dbg_reg3,
        .dbg_reg4,
        .dbg_reg5,
        .dbg_reg6,
        .dbg_reg7
    );



    

endmodule