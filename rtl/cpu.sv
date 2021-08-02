// Based on femto16 architecture
// Ref.: https://8bitworkshop.com

`default_nettype none
`timescale 1ns / 1ps

// ALU operations
`define OP_ZERO     4'h0
`define OP_LOAD_A   4'h1
`define OP_INC      4'h2
`define OP_DEC      4'h3
`define OP_ASL      4'h4
`define OP_LSR      4'h5
`define OP_ROL      4'h6
`define OP_ROR      4'h7
`define OP_OR       4'h8
`define OP_AND      4'h9
`define OP_XOR      4'ha
`define OP_LOAD_B   4'hb
`define OP_ADD      4'hc
`define OP_SUB      4'hd
`define OP_ADC      4'he
`define OP_SBB      4'hf

module alu #(
    parameter N = 8 	        // default width = 8 bits
    ) (
    input wire logic [N-1:0] A,	    // A input      
    input wire logic [N-1:0] B,	    // B input
    input wire logic carry,		    // carry input
    input wire logic [3:0] aluop,	// alu operation
    output logic [N:0] Y	    // Y output + carry
    );
  
    always_comb
        case (aluop)
            // unary operations
            `OP_ZERO:         Y = 0;
            `OP_LOAD_A:       Y = {1'b0, A};
            `OP_INC:          Y = A + 1;
            `OP_DEC:          Y = A - 1;
            // unary operations that generate and/or use carry
            `OP_ASL:          Y = {A, 1'b0};
            `OP_LSR:          Y = {A[0], 1'b0, A[N-1:1]};
            `OP_ROL:          Y = {A, carry};
            `OP_ROR:          Y = {A[0], carry, A[N-1:1]};
            // binary operations
            `OP_OR:           Y = {1'b0, A | B};
            `OP_AND:          Y = {1'b0, A & B};
            `OP_XOR:          Y = {1'b0, A ^ B};
            `OP_LOAD_B:       Y = {1'b0, B};
            // binary operations that generate and/or use carry
            `OP_ADD:          Y = A + B;
            `OP_SUB:          Y = A - B;
            `OP_ADC:          Y = A + B + (carry?1:0);
            `OP_SBB:          Y = A - B - (carry?1:0);
        endcase
  
endmodule

/*
00000aaa 0++++bbb	operation A+B->A
00001aaa 0++++bbb	operation A+[B]->A
00011aaa 0++++000	operation A+imm16 -> A
00101aaa ########	load zero page
00110aaa ########	store zero page
01001aaa #####bbb	load [B+#] -> A
01010aaa #####bbb	store A -> [B+#]
01101aaa 0++++000	store A -> A+[imm16]
01110aaa 00cccbbb	store A -> [B], C -> IP
1000tttt ########	conditional branch
*/

module cpu #(
    parameter RAM_WAIT = 1  // wait state for RAM?
    ) (
    input wire logic clk,
    input wire logic reset,
    input wire logic hold,
    output logic busy,
    output logic [15:0] address,
    input wire logic [15:0] data_in,
    output logic [15:0] data_out,
    output logic write
    );
  
    logic [15:0] regs[0:7]; // 8 16-bit registers
    logic [2:0] state; // CPU state

    logic carry;	// carry flag
    logic zero;	// zero flag
    logic neg;	// negative flag

    logic [16:0] Y;	// ALU 16-bit + carry output
    logic [3:0] aluop;	// ALU operation

    logic [15:0] opcode; // used to decode ALU inputs
    wire logic [2:0] rdest = opcode[10:8];  // ALU A input reg.
    wire logic [2:0] rsrc = opcode[2:0];    // ALU B input reg.
    wire logic Bconst = opcode[15];         // ALU B = 8-bit constant
    wire logic Bload = opcode[11];          // ALU B = data bus

    // CPU states
    localparam S_RESET   = 0;
    localparam S_SELECT  = 1;
    localparam S_DECODE  = 2;
    localparam S_COMPUTE = 3;
    localparam S_DECODE_WAIT = 4;
    localparam S_COMPUTE_WAIT = 5;

    localparam SP = 6; // stack ptr = register 6
    localparam IP = 7; // IP = register 7
  
    alu #(16) alu0(
        .A(regs[rdest]),
        .B(Bconst ? {8'b0, opcode[7:0]} 
            : Bload ? data_in 
                    : regs[rsrc]),
        .Y(Y),
        .aluop(aluop),
        .carry(carry));

    always_ff @(posedge clk)
        if (reset) begin
            state <= S_RESET;
            busy <= 1;
        end else begin
            case (state)
                // state 0: reset
                S_RESET: begin
                    regs[IP] <= 16'h0000;
                    write <= 0;
                    state <= S_SELECT;
                end
                // state 1: select opcode address
                S_SELECT: begin
                    write <= 0;
                    if (hold) begin
                    busy <= 1;
                    state <= S_SELECT;
                    end else begin
                    busy <= 0;
                    address <= regs[IP];
                    regs[IP] <= regs[IP] + 1;
                    state <= RAM_WAIT ? S_DECODE_WAIT : S_DECODE;
                    end
                end
                // state 2: read/decode opcode
                S_DECODE: begin
                    // default next state
                    state <= RAM_WAIT && data_in[11] ? S_COMPUTE_WAIT : S_COMPUTE;
                    casez (data_in)
                    //  00000aaa0++++bbb	operation A+B->A
                    16'b00000???0???????: begin
                        aluop <= data_in[6:3];
                    end
                    //  00001aaa01+++bbb	operation A+[B]->A
                    16'b00001???01??????: begin
                        address <= regs[data_in[2:0]];
                        aluop <= data_in[6:3];
                        if (data_in[2:0] == SP)
                        regs[SP] <= regs[SP] + 1;
                    end
                    //  00011aaa0++++000	operation A+imm16 -> A
                    16'b00011???0????000: begin
                        address <= regs[IP];
                        regs[IP] <= regs[IP] + 1;
                        aluop <= data_in[6:3];
                    end
                    //  11+++aaa########	immediate binary operation
                    16'b11??????????????: begin
                        aluop <= data_in[14:11];
                    end
                    //  00101aaa########	load ZP memory
                    16'b00101???????????: begin
                        address <= {8'b0, data_in[7:0]};
                        aluop <= `OP_LOAD_B;
                    end
                    //  00110aaa########	store ZP memory
                    16'b00110???????????: begin
                        address <= {8'b0, data_in[7:0]};
                        data_out <= regs[data_in[10:8]];
                        write <= 1;
                        state <= S_SELECT;
                    end
                    //  01001aaa#####bbb	[B+#] -> A
                    16'b01001???????????: begin
                        address <= regs[data_in[2:0]] + { {11{data_in[7]}}, data_in[7:3] };
                        aluop <= `OP_LOAD_B;
                        if (data_in[2:0] == SP)
                        regs[SP] <= regs[SP] + 1;
                    end
                    //  01010aaa#####bbb	store A -> [B+#]
                    16'b01010???????????: begin
                        address <= regs[data_in[2:0]] + { {11{data_in[7]}}, data_in[7:3] };
                        data_out <= regs[data_in[10:8]];
                        write <= 1;
                        state <= S_SELECT;
                        if (data_in[2:0] == SP)
                        regs[SP] <= regs[SP] - 1;
                    end
                    //  01011aaa0++++000	operation A+[imm16] -> A
                    16'b01011????????000: begin
                        address <= regs[IP];
                        regs[IP] <= regs[IP] + 1;
                        aluop <= data_in[6:3];
                    end
                    //  01110aaa00cccbbb	store A -> [B], C -> IP
                    16'b01110???00??????: begin
                        address <= regs[data_in[2:0]];
                        data_out <= regs[data_in[10:8]];
                        write <= 1;
                        state <= S_SELECT;
                        if (data_in[2:0] == SP)
                        regs[SP] <= regs[SP] - 1;
                        regs[IP] <= regs[data_in[5:3]];
                    end
                    //  1000????########	conditional branch
                    16'b1000????????????: begin
                        if (
                        (data_in[8] && (data_in[11] == carry)) ||
                        (data_in[9] && (data_in[11] == zero)) ||
                        (data_in[10] && (data_in[11] == neg))) 
                        begin
                        // relative branch, sign extended
                        regs[IP] <= regs[IP] + { {8{data_in[7]}}, data_in[7:0] };
                        end
                        state <= S_SELECT;
                    end
                    // fall-through RESET
                    default: begin
                        state <= S_RESET; // reset
                    end
                    endcase
                    opcode <= data_in; // (only use opcode next cycle)
                end
                // state 3: compute ALU op and flags
                S_COMPUTE: begin
                    // transfer ALU output to destination
                    regs[rdest] <= Y[15:0];
                    // set carry for certain operations (4-7,12-15)
                    if (aluop[2]) carry <= Y[16];
                    // set zero flag
                    zero <= ~|Y[15:0];
                    neg <= Y[15];
                    // repeat CPU loop
                    state <= S_SELECT;
                end
                // wait 1 cycle for RAM read
                S_DECODE_WAIT: begin
                    state <= S_DECODE;
                end
                S_COMPUTE_WAIT : begin
                    state <= S_COMPUTE;
                end
            endcase
    end

endmodule