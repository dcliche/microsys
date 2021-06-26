module cpu(input bit clk, input bit reset, input logic [15:0] data_in, output logic [15:0] data_out, output logic [5:0] addr, output logic rw);

    bit[15:0] data_result;
    bit data_write_reg;
    bit should_branch;

    alu alu0(
        .clk,
        .en(1'b1),
        .data_a(16'h0000),
        .data_b(16'h0000),
        .data_d_we(1'b0),
        .alu_op(5'b00000),
        .pc(16'h0000),
        .data_imm(16'h0000),
        .data_result,
        .data_write_reg,
        .should_branch
    );

endmodule