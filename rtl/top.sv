module top(
   input clk,
   input reset_l,

   output logic [7:0] led
   );

   logic [7:0] cpu_data_in, cpu_data_out;
   logic [5:0] addr;
   logic [11:0] mem_addr;
   logic rw;
   logic [7:0] display;
   logic ram_cs;

   ram #(.A(12), .D(8)) ram0(
      .clk, .cs(ram_cs), .rw, .addr(mem_addr), .data_in(cpu_data_out), .data_out(cpu_data_in)
   );

   cpu cpu0(
      .clk, .reset(~reset_l), .rw, .addr, .data_in(cpu_data_in), .data_out(cpu_data_out)
   );

   assign led = display;

   // Address decoding
   assign mem_addr = {6'b000000, addr};
   assign ram_cs = addr[5] != 1;

   always_ff @(posedge clk)
   begin
      if (addr[5] == 1 && rw == 0)
         display <= cpu_data_out;
   end

   // Print some stuff as an example
   initial begin
      if ($test$plusargs("trace") != 0) begin
         $display("[%0t] Tracing to logs/vlt_dump.vcd...\n", $time);
         $dumpfile("logs/vlt_dump.vcd");
         $dumpvars();
      end
      $display("[%0t] Model running...\n", $time);
   end

endmodule
