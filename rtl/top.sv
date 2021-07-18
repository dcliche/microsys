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

   //
   // Pong
   // Ref.: https://projectf.io/posts/fpga-pong/
   //

   // size of the screen with and without blanking
   localparam H_RES_FULL = 800;
   localparam V_RES_FULL = 525;
   localparam H_RES = 640;
   localparam V_RES = 480;

   logic animate; // high for one clock ticj at the start of vertical blanking
   always_comb animate = (sy == V_RES && sx == 0);

   // ball
   localparam B_SIZE = 8;     // size in pixels
   logic [CORDW-1:0] bx, by;  // position
   logic dx, dy;              // direction: 0 is right/down
   logic [CORDW-1:0] spx = 1; // horizontal speed
   logic [CORDW-1:0] spy = 1; // vertical speed
   logic b_draw;              // draw ball?

   // ball animation
   always_ff @(posedge clk_pix) begin
      if (animate) begin
         // Horizontal
         if (bx >= H_RES - (spx + B_SIZE)) begin   // right edge
            dx <= 1;
            bx <= bx - spx;
         end else if (bx < spx) begin  // left edge
            dx <= 0;
            bx <= bx + spx;
         end else bx <= (dx) ? bx - spx : bx + spx;

         // Vertical
         if (by >= V_RES - (spy + B_SIZE)) begin   // bottom edge
            dy <= 1;
            by <= by - spy;
         end else if (by < spy) begin  // top edge
            dy <= 0;
            by <= by + spy;
         end else by <= (dy) ? by - spy : by + spy;
      end
   end

   // draw ball - is ball at current screen position?
   always_comb begin
      b_draw = (sx >= bx) && (sx < bx + B_SIZE) &&
               (sy >= by) && (sy < by + B_SIZE);
   end

   // paddles
   localparam P_H = 40;          // height in pixels
   localparam P_W = 10;          // width in pixels
   localparam P_SP = 1;          // speed
   localparam P_OFFS = 32;       // offset from screen edge
   logic [CORDW-1:0] p1y, p2y;   // vertical position of paddles 1 and 2
   logic p1_draw, p2_draw;       // draw paddles?

   // paddle animation
   always_ff @(posedge clk_pix) begin
      if (animate) begin
         // "AI" paddle 1
         if ((p1y + P_H/2) + P_SP/2 < (by + B_SIZE/2)) begin
            if (p1y < V_RES - (P_H + P_SP/2))   // screen bottom?
               p1y <= p1y + P_SP;               // move down
         end else if ((p1y + P_H/2) > (by + B_SIZE/2) + P_SP/2) begin
            if (p1y > P_SP)                     // screen top?
               p1y <= p1y - P_SP;               // move up
         end

         // "AI" paddle 2
         if ((p2y + P_H/2) + P_SP/2 < (by + B_SIZE/2)) begin
            if (p2y < V_RES - (P_H + P_SP/2))   // screen bottom?
               p2y <= p2y + P_SP;               // move down
         end else if ((p2y + P_H/2) > (by + B_SIZE/2) + P_SP/2) begin
            if (p2y > P_SP)                     // screen top?
               p2y <= p2y - P_SP;               // move up
         end
      end
   end

   // draw paddles - are paddles at current screen position?
   always_comb begin
      p1_draw = (sx >= P_OFFS) && (sx < P_OFFS + P_W) &&
                (sy >= p1y) && (sy < p1y + P_H);
      p2_draw = (sx >= H_RES - P_OFFS - P_W) && (sx < H_RES - P_OFFS) &&
                (sy >= p2y) && (sy < p2y + P_H);
   end

   // VGA output
   always_ff @(posedge clk_pix) begin
      vga_hsync <= hsync;
      vga_vsync <= vsync;
      vga_r <= (de && (b_draw || p1_draw || p2_draw)) ? 4'hF : 4'h0;
      vga_g <= (de && (b_draw || p1_draw || p2_draw)) ? 4'hF : 4'h0;
      vga_b <= (de && (b_draw || p1_draw || p2_draw)) ? 4'hF : 4'h0;
   end

   //
   // CPU
   //

   logic [7:0] cpu_data_in, cpu_data_out;
   logic [5:0] addr;
   logic [11:0] mem_addr;
   logic rw = 1;
   logic [7:0] display;
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
