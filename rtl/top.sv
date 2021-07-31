/*

Ref.: https://projectf.io

640x480 Timings     HOR    VER
-------------------------------
Active Pixels       640     480
Front Porch         16      10
Sync Width          96      2
Back Porch          48      33
Blanking Total      160     45
Total Pixels        800     525
Sync Polarity       neg     neg

Pixel Clock @60Hz: 25.2 MHz

*/

`timescale 1ns / 1ps

module top(
   input clk,
   input reset,

   input logic [3:0] sw,
   input logic btn_up,
   input logic btn_ctrl,
   input logic btn_dn,
   output logic [3:0] led,
   output logic vga_hsync,
   output logic vga_vsync,
   output logic [3:0] vga_r,
   output logic [3:0] vga_g,
   output logic [3:0] vga_b
   );

   logic clk_pix;
   logic clk_locked;

   logic [3:0] pong_vga_r, pong_vga_g, pong_vga_b;
   logic [3:0] sprite_vga_r, sprite_vga_g, sprite_vga_b;

`ifdef verilator
   assign clk_pix = clk;
   assign clk_locked = 1;
`else
   pll pll_inst(.clkref(clk), .clkout(clk_pix));
   assign clk_locked = 1;
`endif

   // debounce buttons
   logic sig_ctrl, move_up, move_dn;
   debounce deb_ctrl(.clk(clk_pix), .in(btn_ctrl), .out(), .ondn(), .onup(sig_ctrl));
   debounce deb_up(.clk(clk_pix), .in(btn_up), .out(move_up), .ondn(), .onup());
   debounce deb_dn(.clk(clk_pix), .in(btn_dn), .out(move_dn), .ondn(), .onup());

   // display timings
   localparam CORDW = 16;
   logic signed [CORDW-1:0] sx, sy;
   logic hsync, vsync;
   logic de, line;
   logic frame;
   display_timings_480p #(.CORDW(CORDW)) display_timings_inst (
        .clk_pix,
        .rst(!clk_locked),  // wait for pixel clock lock
        .sx,
        .sy,
        .hsync,
        .vsync,
        .de,
        /* verilator lint_off PINCONNECTEMPTY */
        .frame,
        /* verilator lint_on PINCONNECTEMPTY */
        .line
    );

   //
   // Pong
   // Ref.: https://projectf.io/posts/fpga-pong/
   //

   logic lft_col, rgt_col;

   // game state
   enum {INIT, IDLE, START, PLAY, POINT_END} state, state_next;
   always_comb begin
      case (state)
         INIT: state_next = IDLE;
         IDLE: state_next = (sig_ctrl) ? START : IDLE;
         START: state_next = (sig_ctrl) ? PLAY : START;
         PLAY: state_next = (lft_col || rgt_col) ? POINT_END : PLAY;
         POINT_END: state_next = (sig_ctrl) ? START : POINT_END;
         default: state_next = IDLE;
      endcase
   end

   // size of the screen with and without blanking
   localparam H_RES_FULL = 800;
   localparam V_RES_FULL = 525;
   localparam H_RES = 640;
   localparam V_RES = 480;

   logic animate; // high for one clock tick at the start of vertical blanking
   always_comb animate = frame;

   // ball
   localparam B_SIZE = 8;     // size in pixels
   logic [CORDW-1:0] bx, by;  // position
   logic dx, dy;              // direction: 0 is right/down
   logic [CORDW-1:0] spx = 6; // horizontal speed
   logic [CORDW-1:0] spy = 4; // vertical speed
   logic b_draw;              // draw ball?
   logic p1_col, p2_col;      // paddle collision

   // ball animation
   always_ff @(posedge clk_pix) begin
      if (state == INIT || state == START) begin            // reset ball position
         bx <= (H_RES - B_SIZE) >> 1;
         by <= (V_RES - B_SIZE) >> 1;
         dx <= 0; // serve towards player 2 (AI)
         dy <= ~dy;
         lft_col <= 0;
         rgt_col <= 0;
      end else if (animate && state != POINT_END) begin
         // Horizontal
         if (p1_col) begin                                  // left paddle collision
            dx <= 0;
            bx <= bx + spx;
            dy <= (by + B_SIZE/2 < p1y + P_H/2) ? 1 : 0;
         end else if (p2_col) begin                         // right paddle collision
            dx <= 1;
            bx <= bx - spx;
            dy <= (by + B_SIZE/2 < p2y + P_H/2) ? 1 : 0;
         end else if (bx >= H_RES - (spx + B_SIZE)) begin   // right edge
            rgt_col <= 1;
         end else if (bx < spx) begin                       // left edge
            lft_col <= 1;
         end else bx <= (dx) ? bx - spx : bx + spx;

         // Vertical
         if (by >= V_RES - (spy + B_SIZE)) begin            // bottom edge
            dy <= 1;
            by <= by - spy;
      end else if (by < spy) begin                          // top edge
            dy <= 0;
            by <= by + spy;
         end else by <= (dy) ? by - spy : by + spy;
      end
   end

   // ball speed control
   localparam SPEED_STEP = 5;    // speed up after this many collisions
   logic [$clog2(SPEED_STEP)-1:0] cnt_sp; // speed counter
   always_ff @(posedge clk_pix) begin
      if (state == INIT) begin   // demo speed
         spx <= 6;
         spy <= 4;
      end else if (state == START) begin // initial game speed
         spx <= 4;
         spy <= 2;
         cnt_sp <= 0;
      end else if (state == PLAY && animate && (p1_col || p2_col)) begin
         if (cnt_sp == SPEED_STEP - 1) begin
            spx <= spx + 1;
            spy <= spy + 1;
            cnt_sp <= 0;
         end else begin
            cnt_sp <= cnt_sp + 1;
         end
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
   localparam P_SP = 4;          // speed
   localparam P_OFFS = 32;       // offset from screen edge
   logic [CORDW-1:0] p1y, p2y;   // vertical position of paddles 1 and 2
   logic p1_draw, p2_draw;       // draw paddles?

   // paddle animation
   always_ff @(posedge clk_pix) begin
      if (state == INIT || state == START) begin  // reset paddle position
         p1y <= (V_RES - P_H) >> 1;
         p2y <= (V_RES - P_H) >> 1;
      end else if (animate && state != POINT_END) begin
         if (state == PLAY) begin   // human paddle 1
            if (move_up)
               if (p1y > P_SP) p1y <= p1y - P_SP;
            if (move_dn)
               if (p1y < V_RES - (P_H + P_SP)) p1y <= p1y + P_SP; 
         end else begin
            // "AI" paddle 1
            if ((p1y + P_H/2) + P_SP/2 < (by + B_SIZE/2)) begin
               if (p1y < V_RES - (P_H + P_SP/2))   // screen bottom?
                  p1y <= p1y + P_SP;               // move down
            end else if ((p1y + P_H/2) > (by + B_SIZE/2) + P_SP/2) begin
               if (p1y > P_SP)                     // screen top?
                  p1y <= p1y - P_SP;               // move up
            end
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

   // paddle collision detection
   always_ff @(posedge clk_pix) begin
      if (animate) begin
         p1_col <= 0;
         p2_col <= 0;
      end else if (b_draw) begin
         if (p1_draw) p1_col <= 1;
         if (p2_draw) p2_col <= 1;
      end
   end

   // Output
   always_ff @(posedge clk_pix) begin
      pong_vga_r <= (de && (b_draw || p1_draw || p2_draw)) ? 4'hF : 4'h0;
      pong_vga_g <= (de && (b_draw || p1_draw || p2_draw)) ? 4'hF : 4'h0;
      pong_vga_b <= (de && (b_draw || p1_draw || p2_draw)) ? 4'hF : 4'h0;
   end

   always_ff @(posedge clk_pix) begin
      state <= state_next;
   end

   //
   // sprite
   //

    localparam SPR_WIDTH  = 8;  // width in pixels
    localparam SPR_HEIGHT = 8;  // number of lines
    localparam SPR_FILE = "saucer.mem";
    logic spr_start;
    logic spr_pix;

    // draw sprite at position
    localparam DRAW_X = 16;
    localparam DRAW_Y = 16;

    // signal to start sprite drawing
    always_comb spr_start = (line && sy == DRAW_Y);

    sprite_v2 #(
        .WIDTH(SPR_WIDTH),
        .HEIGHT(SPR_HEIGHT),
        .SCALE_X(4),
        .SCALE_Y(4),
        .SPR_FILE(SPR_FILE)
    ) spr_instance (
        .clk(clk_pix),
        .rst(!clk_locked),
        .start(spr_start),
        .sx,
        .sprx(DRAW_X),
        .pix(spr_pix)
    );

    // Output
    always_ff @(posedge clk_pix) begin
        sprite_vga_r <= (de && spr_pix) ? 4'hF: 4'h0;
        sprite_vga_g <= (de && spr_pix) ? 4'hC: 4'h0;
        sprite_vga_b <= (de && spr_pix) ? 4'h0: 4'h0;
    end

    //
    // VGA output
    //

    always_ff @(posedge clk_pix) begin
        vga_hsync <= hsync;
        vga_vsync <= vsync;
        vga_r <= pong_vga_r | sprite_vga_r;
        vga_g <= pong_vga_g | sprite_vga_g;
        vga_b <= pong_vga_b | sprite_vga_b;
    end

   //
   // CPU
   //

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
      .clk, .reset, .rw, .addr, .data_in(cpu_data_in), .data_out(cpu_data_out)
   );


   assign led = display[3:0];

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
