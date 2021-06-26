module cpu_tb;

    bit clk;
    bit reset;
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
    bit[3:0] state;

    bit en_decode, en_regread, en_alu, en_regwrite;

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
        $dumpvars(0, controlsimple0);
        $dumpvars(0, alu0);
        $dumpvars(0, reg0);
        $dumpvars(0, instruction);
        $dumpvars(0, en_decode, en_regread, en_alu, en_regwrite);
        $monitor("time=%2d, state=%d, r0=%x, r1=%x, r2=%x, r3=%x, r4=%x, r5=%x, r6=%x, r7=%x", $time, state, dbg_reg0, dbg_reg1, dbg_reg2, dbg_reg3, dbg_reg4, dbg_reg5, dbg_reg6, dbg_reg7);

        reset = 1;
        $display("// load.h r0,0xfe");
        instruction = {`OPCODE_LOAD, 3'b000, 1'b0, 8'hFE};
        #5 reset = 0;
        wait(en_regwrite);

        $display("// load.l r1, 0xed");
        instruction = {`OPCODE_LOAD, 3'b001, 1'b1, 8'hED};
        wait(~en_regwrite);
        wait(en_regwrite);
 
        $display("// or r2, r0, r1");
        instruction = {`OPCODE_OR, 3'b010, 1'b0, 3'b000, 3'b001, 2'b00};
        wait(~en_regwrite);
        wait(en_regwrite);

        $display("// load.l r3, 1");
        instruction = {`OPCODE_LOAD, 3'b011, 1'b1, 8'h01};
        wait(~en_regwrite);
        wait(en_regwrite);
 
        $display("// load.l r4, 2");
        instruction = {`OPCODE_LOAD, 3'b100, 1'b1, 8'h02};
        wait(~en_regwrite);
        wait(en_regwrite);

        $display("// add.u r3, r3, r4");
        instruction = {`OPCODE_ADD, 3'b011, 1'b0, 3'b011, 3'b100, 2'b00};
        wait(~en_regwrite);
        wait(en_regwrite);

        $display("// or r5, r0, r3");
        instruction = {`OPCODE_OR, 3'b101, 1'b0, 3'b000, 3'b011, 2'b00};
        wait(~en_regwrite);
        wait(en_regwrite);
        wait(~en_regwrite);
        wait(en_regwrite);

        $stop;

        /*

        // or r5, r0, r3
        instruction = {`OPCODE_OR, 3'b101, 1'b0, 3'b000, 3'b011, 2'b00};
        @(posedge clk);
        @(posedge clk);
        */

        #1000 $stop;
    end

    always #5 clk = ~clk;

    controlsimple controlsimple0(
        .clk,
        .reset,
        .state
    );

    decode decode0(
        .clk,
        .en(en_decode),
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
        .en(en_alu),
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
        .en(en_regread | en_regwrite),
        .data_d(data_result),
        .data_out_a(data_a),
        .data_out_b(data_b),
        .sel_a,
        .sel_b,
        .sel_d,
        .we(data_write_reg & en_regwrite),

        .dbg_reg0,
        .dbg_reg1,
        .dbg_reg2,
        .dbg_reg3,
        .dbg_reg4,
        .dbg_reg5,
        .dbg_reg6,
        .dbg_reg7
    );

    assign en_decode = state[0];
    assign en_regread = state[1];
    assign en_alu = state[2];
    assign en_regwrite = state[3];

endmodule