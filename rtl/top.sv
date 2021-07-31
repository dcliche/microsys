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
    // sprite
    //

    localparam SPR_WIDTH    = 32;   // width in pixels
    localparam SPR_HEIGHT   = 20;   // number of lines
    localparam SPR_SCALE_X  = 4;    // width scale-factor
    localparam SPR_SCALE_Y  = 4;    // height scale-factor
    localparam COLR_BITS    = 4;    // bits per pixel (2^4=16 colours)
    localparam SPR_TRANS    = 9;    // transparent palette entry
    localparam SPR_FRAMES   = 3;    // number of frames in graphic
    localparam SPR_FILE     = "hedgehog.mem";
    localparam SPR_PALETTE  = "hedgehog_palette.mem";

    localparam SPR_PIXELS = SPR_WIDTH * SPR_HEIGHT;
    localparam SPR_DEPTH  = SPR_PIXELS * SPR_FRAMES;
    localparam SPR_ADDRW  = $clog2(SPR_DEPTH);

    logic spr_start, spr_drawing;
    logic [COLR_BITS-1:0] spr_pix;

    // sprite graphic ROM
    logic [COLR_BITS-1:0] spr_rom_data;
    logic [SPR_ADDRW-1:0] spr_rom_addr, spr_base_addr;
    rom_sync #(
        .WIDTH(COLR_BITS),
        .DEPTH(SPR_DEPTH),
        .INIT_F(SPR_FILE)
    ) spr_rom (
        .clk(clk_pix),
        .addr(spr_base_addr + spr_rom_addr),
        .data(spr_rom_data)
    );

    // draw sprite at position
    localparam H_RES = 640;
    localparam SPR_SPEED_X = 2;
    logic signed [CORDW-1:0] sprx, spry;

    // sprite frame selector
    logic [5:0] cnt_anim;       // count from 0-63

    always_ff @(posedge clk_pix) begin
        if (frame) begin
            // select sprite frame
            cnt_anim <= cnt_anim + 1;
            case (cnt_anim)
                0: spr_base_addr <= 0;
                15: spr_base_addr <= SPR_PIXELS;
                31: spr_base_addr <= 0;
                47: spr_base_addr <= 2 * SPR_PIXELS;
                default: spr_base_addr <= spr_base_addr;
            endcase
            // walk right-to-left: -132 covers sprite width and within blanking
            sprx <= (sprx > -132) ? sprx - SPR_SPEED_X : H_RES;
        end
        if (!clk_locked) begin
            sprx <= H_RES;
            spry <= 200;
        end
    end

    // signal to start sprite drawing
    always_comb spr_start = (line && sy == spry);

    sprite #(
        .WIDTH(SPR_WIDTH),
        .HEIGHT(SPR_HEIGHT),
        .COLR_BITS(COLR_BITS),
        .SCALE_X(SPR_SCALE_X),
        .SCALE_Y(SPR_SCALE_Y),
        .ADDRW(SPR_ADDRW)
        ) spr_instance (
        .clk(clk_pix),
        .rst(!clk_locked),
        .start(spr_start),
        .sx,
        .sprx,
        .data_in(spr_rom_data),
        .pos(spr_rom_addr),
        .pix(spr_pix),
        .drawing(spr_drawing),
        /* verilator lint_off PINCONNECTEMPTY */
        .done()
        /* verilator lint_on PINCONNECTEMPTY */
    );

    // colour lookup table (ROM) 11x12-bit entries
    logic [11:0] clut_colr;
    rom_async #(
        .WIDTH(12),
        .DEPTH(11),
        .INIT_F(SPR_PALETTE)
    ) clut (
        .addr(spr_pix),
        .data(clut_colr)
    );

    // map sprite colour index to palette using CLUT and incorporate background
    logic spr_trans;  // sprite pixel transparent?
    logic [3:0] red_spr, green_spr, blue_spr;  // sprite colour components
    logic [3:0] red_bg,  green_bg,  blue_bg;   // background colour components
    logic [3:0] red, green, blue;              // final colour
    always_comb begin
        spr_trans = (spr_pix == SPR_TRANS);
        {red_spr, green_spr, blue_spr} = clut_colr;
        {red_bg,  green_bg,  blue_bg}  = 12'h260;
        red   = (spr_drawing && !spr_trans) ? red_spr   : red_bg;
        green = (spr_drawing && !spr_trans) ? green_spr : green_bg;
        blue  = (spr_drawing && !spr_trans) ? blue_spr  : blue_bg;
    end

    // Sprite output
    always_ff @(posedge clk_pix) begin
        sprite_vga_r <= de ? red   : 4'h0;
        sprite_vga_g <= de ? green : 4'h0;
        sprite_vga_b <= de ? blue  : 4'h0;
    end

    //
    // VGA output
    //

    always_ff @(posedge clk_pix) begin
        vga_hsync <= hsync;
        vga_vsync <= vsync;
        vga_r <= sprite_vga_r;
        vga_g <= sprite_vga_g;
        vga_b <= sprite_vga_b;
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
