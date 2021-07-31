`timescale 1ns / 1ps

module ram(input bit clk, input bit cs, input bit write, input logic [A-1:0] addr, input logic [D-1:0] data_in, output logic [D-1:0] data_out);
    parameter A = 10, D = 8;

    logic [D-1:0] mem [0:(1<<A)-1];
    initial $readmemh("ram.hex", mem);

    always_ff @(posedge clk)
    begin
        if (cs) begin
            if (write)
                mem[addr] <= data_in;   // Write
                //$display("ram: write %x to addr %x", data_in, addr);
            else begin
                data_out <= mem[addr];  // Read
            end
        end
    end

endmodule