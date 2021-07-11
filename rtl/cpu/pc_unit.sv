module pc_unit(
    input bit clk,
    input bit[15:0] pc_in,
    input bit[1:0] pc_op,
    output bit[15:0] pc_out
);

    `include "constants.sv"

    bit[15:0] current_pc = 0;

    always_ff @(posedge clk) begin
        case (pc_op)
            PCU_OP_NOP:
            PCU_OP_INC:
                current_pc <= current_pc + 1;
            PCU_OP_ASSIGN:
                current_pc <= pc_in;
            PCU_OP_RESET:
                current_pc <= 0;
            default:
        endcase
    end

    assign pc_out = current_pc;

endmodule