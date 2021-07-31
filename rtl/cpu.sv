`timescale 1ns / 1ps

module cpu(input logic clk, input logic reset, input logic [7:0] data_in, output logic [7:0] data_out, output logic [5:0] addr, output logic rw);

    enum logic [3:0] { reset_state, decode1_state, decode2_state, nor1_state, nor2_state, add1_state, add2_state, sta1_state, sta2_state} state;
    logic [8:0] accu;
    logic [5:0] pc;

    always_ff @(posedge clk)
    begin
        if (reset) begin
            state <= reset_state;
            accu <= 0;
            pc <= 0;
            rw <= 1;
            addr <= 0;
        end else begin
            case (state)
                reset_state: begin
                    addr <= pc;
                    state <= decode1_state;
                end
                
                decode1_state:
                    state <= decode2_state;

                decode2_state:
                    case (data_in[7:6])
                        2'b00: begin
                            // nor
                            addr <= data_in[5:0];
                            state <= nor1_state;
                        end
                        2'b01: begin
                            // add
                            addr <= data_in[5:0];
                            state <= add1_state;
                        end
                        2'b10: begin
                            // sta
                            addr <= data_in[5:0];
                            rw <= 0;
                            data_out <= accu[7:0];
                            state <= sta1_state;
                        end
                        2'b11: begin
                            // jcc
                            if (accu[8] == 0) begin
                                addr <= data_in[5:0];
                                pc <= data_in[5:0];
                            end else begin
                                accu[8] <= 0;
                                pc <= pc + 1;
                                addr <= pc + 1;
                            end
                            state <= decode1_state;                                
                        end
                        default:
                            state <= reset_state;
                    endcase
                
                nor1_state:
                    state <= nor2_state;

                nor2_state: begin
                    accu[7:0] <= ~(accu[7:0] | data_in);
                    pc <= pc + 1;
                    addr <= pc + 1;
                    state <= decode1_state;
                end

                add1_state:
                    state <= add2_state;

                add2_state: begin
                    accu <= {1'b0, accu[7:0]} + {1'b0, data_in};
                    pc <= pc + 1;
                    addr <= pc + 1;
                    state <= decode1_state;
                end

                sta1_state:
                    state <= sta2_state;

                sta2_state: begin
                    rw <= 1;
                    pc <= pc + 1;
                    addr <= pc + 1;
                    state <= decode1_state;
                end

                default:
                    state <= reset_state;

            endcase
        end
    end


endmodule