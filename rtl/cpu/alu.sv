module alu(
    input bit clk,
    input bit en,
    input bit[15:0] data_a,
    input bit[15:0] data_b,
    input bit data_d_we,
    input bit[4:0] alu_op,
    input bit[15:0] pc,
    input bit[15:0] data_imm,
    output bit[15:0] data_result,
    output bit data_write_reg,
    output bit should_branch
);

    `include "constants.sv"

    bit[17:0] result = 0;
    bit s_should_branch = 0;

    typedef bit unsigned [15:0] unsigned_t;
    typedef bit signed [15:0] signed_t;
    typedef bit unsigned [16:0] unsigned_ext_t;
    typedef bit signed [16:0] signed_ext_t;

    always_ff @(posedge clk) begin
        if (en) begin
            data_write_reg <= data_d_we;
            case(alu_op[4:1])
                `OPCODE_ADD: begin
                    if (alu_op[0] == 0)
                        result <= unsigned_ext_t'({ 1'b0, data_a }) + unsigned_ext_t'({ 1'b0, data_b });
                    else
                        result <= signed_ext_t'({ data_a[15], data_a }) + signed_ext_t'({ data_b[15], data_b });
                    s_should_branch <= 0;
                end
                `OPCODE_OR: begin
                    result[15:0] <= data_a | data_b;
                    s_should_branch <= 0;
                end
                `OPCODE_LOAD: begin
                    if (alu_op[0] == 0)
                        result[15:0] <= { data_imm[7:0], 8'h00 };
                    else
                        result[15:0] <= { 8'h00, data_imm[7:0] };
                    s_should_branch <= 0;
                end
                `OPCODE_CMP: begin
                    result[`CMP_BIT_EQ] <= (data_a == data_b) ? 1 : 0;
                    result[`CMP_BIT_AZ] <= (data_a == 0) ? 1 : 0;
                    result[`CMP_BIT_BZ] <= (data_b == 0) ? 1 : 0;
                    if (alu_op[0] == 0) begin
                        result[`CMP_BIT_AGB] <= unsigned_t'(data_a) > unsigned_t'(data_b) ? 1 : 0;
                        result[`CMP_BIT_ALB] <= unsigned_t'(data_a) < unsigned_t'(data_b) ? 1 : 0;
                    end else begin
                        result[`CMP_BIT_AGB] <= signed_t'(data_a) > signed_t'(data_b) ? 1 : 0;
                        result[`CMP_BIT_ALB] <= signed_t'(data_a) < signed_t'(data_b) ? 1 : 0;
                    end
                    result[15] <= 0;
                    result[9:0] <= 0;
                    s_should_branch <= 0;
                end
                `OPCODE_SHL: begin
                    result[15:0] <= data_b <= 15 ? data_a << data_b[3:0] : data_a;
                    s_should_branch <= 0;
                end
                `OPCODE_JUMPEQ: begin
                    // Set branch target regardless
                    result[15:0] <= data_b;

                    // The condition to jump is based on alu_op[0] and data_imm[1:0]
                    case ({alu_op[0], data_imm[1:0]})
                        `CJF_EQ: s_should_branch <= data_a[`CMP_BIT_EQ];
                        `CJF_AZ: s_should_branch <= data_a[`CMP_BIT_AZ];
                        `CJF_BZ: s_should_branch <= data_a[`CMP_BIT_BZ];
                        `CJF_ANZ: s_should_branch <= ~data_a[`CMP_BIT_AZ];
                        `CJF_BNZ: s_should_branch <= ~data_a[`CMP_BIT_BZ];
                        `CJF_AGB: s_should_branch <= data_a[`CMP_BIT_AGB];
                        `CJF_ALB: s_should_branch <= data_a[`CMP_BIT_ALB];
                        default: s_should_branch <= 0;
                    endcase
                end
                default:
                    result <= 0;
            endcase
        end                
    end

    assign data_result = result[15:0];
    assign should_branch = s_should_branch;        

endmodule