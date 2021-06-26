`define OPCODE_ADD      4'b0000
`define OPCODE_SUB      4'b0001
`define OPCODE_OR       4'b0010
`define OPCODE_XOR      4'b0011
`define OPCODE_AND      4'b0100
`define OPCODE_NOT      4'b0101
`define OPCODE_READ     4'b0110
`define OPCODE_WRITE    4'b0111
`define OPCODE_LOAD     4'b1000
`define OPCODE_CMP      4'b1001
`define OPCODE_SHL      4'b1010
`define OPCODE_SHR      4'b1011
`define OPCODE_JUMP     4'b1100
`define OPCODE_JUMPEQ   4'b1101

`define CMP_BIT_EQ      14
`define CMP_BIT_AGB     13
`define CMP_BIT_ALB     12
`define CMP_BIT_AZ      11
`define CMP_BIT_BZ      10

`define CJF_EQ          3'b000
`define CJF_AZ          3'b001
`define CJF_BZ          3'b010
`define CJF_ANZ         3'b011
`define CJF_BNZ         3'b100
`define CJF_AGB         3'b101
`define CJF_ALB         3'b110
