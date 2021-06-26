/*

Ref.: http://labs.domipheus.com/blog/designing-a-cpu-in-vhdl-part-3-instruction-set-decoder-ram/

Form      15   14   13   12   11   10   09   08   07   06   05   04   03   02   01   00
RRR      | opcode           | rD           | F  | rA           | rB           | Unused  |
RRs      | opcode           | Unused       | F  | rA           | rB           | Unused  |
RRd      | opcode           | rD           | F  | rA           | Unused                 |
R        | opcode           | rD           | F  | Unused                                |
RImm     | opcode           | rD           | F  | 8-bit Immediate Value                 |
Imm      | opcode           | Unused       | F  | 8-bit Immediate Value                 |

Opcode   Operation   Form   Write Register?   Comments
0000     ADD         RRR    Yes
0001     SUB         RRR    Yes
0010     OR          RRR    Yes
0011     XOR         RRR    Yes
0100     AND         RRR    Yes
0101     NOT         RRd    Yes
0110     READ        RRd    Yes
0111     WRITE       RRs    No
1000     LOAD        RImm   Yes               Flag bit indicates high or low load
1001     CMP         RRR    Yes               Flag bit indicates comparison signedness
1010     SHL         RRR    Yes
1011     SHR         RRR    Yes
1100     JUMP        R,Imm  No                Flag bit indicates a jump to register or jump to immediate
1101     JUMPEQ      RRs    No
1110     RESERVED    -      -
1111     RESERVED    -      -

*/

module decode(
    input bit clk,
    input bit[15:0] data_inst,
    input bit en,
    output bit[2:0] sel_a,
    output bit[2:0] sel_b,
    output bit[2:0] sel_d,
    output bit[15:0] data_imm,
    output bit reg_d_we,
    output bit[4:0] alu_op
);

    always_ff @(posedge clk) begin
        if (en) begin
            sel_a <= data_inst[7:5];
            sel_b <= data_inst[4:2];
            sel_d <= data_inst[11:9];
            data_imm <= { data_inst[7:0], data_inst[7:0] };
            alu_op <= { data_inst[15:12], data_inst[8] };

            case (data_inst[15:12])
                4'b0111:    // WRITE
                    reg_d_we <= 0;
                4'b1100:    // JUMP
                    reg_d_we <= 0;
                4'b1101:    // JUMPEQ
                    reg_d_we <= 0;
                default:
                    reg_d_we <= 1;
            endcase
        end
    end

endmodule