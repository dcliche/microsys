module reg16_8(
    input bit clk,
    input bit en,
    input bit we,
    input bit[15:0] data_d,
    input bit[2:0] sel_a,
    input bit[2:0] sel_b,
    input bit[2:0] sel_d,
    output bit[15:0] data_out_a,
    output bit[15:0] data_out_b,

    output bit[15:0] dbg_reg0,
    output bit[15:0] dbg_reg1,
    output bit[15:0] dbg_reg2,
    output bit[15:0] dbg_reg3,
    output bit[15:0] dbg_reg4,
    output bit[15:0] dbg_reg5,
    output bit[15:0] dbg_reg6,
    output bit[15:0] dbg_reg7
);
    bit[15:0] regs[8];

    always_ff @(posedge clk) begin
        if (en) begin
            data_out_a <= regs[sel_a];
            data_out_b <= regs[sel_b];
            if (we) begin
                regs[sel_d] <= data_d;
            end
        end
    end

    assign dbg_reg0 = regs[0];
    assign dbg_reg1 = regs[1];
    assign dbg_reg2 = regs[2];
    assign dbg_reg3 = regs[3];
    assign dbg_reg4 = regs[4];
    assign dbg_reg5 = regs[5];
    assign dbg_reg6 = regs[6];
    assign dbg_reg7 = regs[7];


endmodule