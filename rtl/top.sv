module top(
   input clk,
   input reset,

   input logic [7:0] sw,
   output logic [7:0] led,
   output logic vga_hsync,
   output logic vga_vsync,
   output logic [3:0] vga_r,
   output logic [3:0] vga_g,
   output logic [3:0] vga_b
   );

   logic clk_pix;
   logic clk_locked;

   // TODO: use a display clock at 25.2 MHz
   assign clk_pix = clk;
   assign clk_locked = 1;

   // display timings
   localparam CORDW = 10;  // screen coordinate width in bits
   logic hsync, vsync, de;
   logic [CORDW-1:0] sx, sy;

   simple_display_timings_480p display_timings_inst(
      .clk_pix,
      .rst(!clk_locked),
      .sx,
      .sy,
      .hsync,
      .vsync,
      .de
   );

   // 32 x 32 pixel square
   logic q_draw;
   always_comb q_draw = (sx < 32 && sy < 32) ? 1 : 0;

   // VGA output
   always_ff @(posedge clk_pix) begin
      vga_hsync <= hsync;
      vga_vsync <= vsync;
      vga_r <= !de ? 4'h0 : (q_draw ? 4'hF : 4'h0);
      vga_g <= !de ? 4'h0 : (q_draw ? 4'h8 : 4'h8);
      vga_b <= !de ? 4'h0 : (q_draw ? 4'h0 : 4'hF);
   end

   //
   // CPU
   //

   logic [7:0] cpu_data_in, cpu_data_out;
   logic [5:0] addr = 0;
   logic [11:0] mem_addr;
   logic rw = 1;
   logic [7:0] display = 0;
   logic ram_cs;

   ram #(.A(12), .D(8)) ram0(
      .clk, .cs(ram_cs), .rw, .addr(mem_addr), .data_in(cpu_data_out), .data_out(cpu_data_in)
   );

   cpu cpu0(
      .clk, .reset, .rw, .addr, .data_in(cpu_data_in), .data_out(cpu_data_out)
   );


   assign led = display;

   // Address decoding
   assign mem_addr = {6'b000000, addr};
   assign ram_cs = addr[5] != 1;

   always_ff @(posedge clk)
   begin
      if (addr[5] == 1 && rw == 0) begin
         display <= cpu_data_out;
      end
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
