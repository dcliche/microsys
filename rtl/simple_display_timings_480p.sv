// Ref.: https://projectf.io/posts/fpga-graphics/

/*

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

module simple_display_timings_480p(
    input   wire logic clk_pix,     // pixel clock
    input   wire logic rst,         // reset
    output  logic[9:0] sx,          // horizontal screen position
    output  logic[9:0] sy,          // vertical screen position
    output  logic hsync,            // horizontal sync
    output  logic vsync,            // vertical sync
    output  logic de                // data enable (low in blanking interval)    
);

    // horizontal timings
    parameter HA_END = 639;         // end of active pixels
    parameter HS_STA = HA_END + 16; // sync starts after front porch
    parameter HS_END = HS_STA + 96; // sync ends
    parameter LINE = 799;           // last pixel on line (after back porch)

    // vertical timings
    parameter VA_END = 479;         // end of active pixels
    parameter VS_STA = VA_END + 10; // sync starts after front porch
    parameter VS_END = VS_STA + 2;  // sync ends
    parameter SCREEN = 524;         // last line on screen (after back porch)

    always_comb begin
        hsync = ~(sx >= HS_STA && sx < HS_END);     // invert: negative polarity
        vsync = ~(sy >= VS_STA && sy < VS_END);     // invert: negative polarity
        de = (sx <= HA_END && sy <= VA_END);
    end

    // Calculate horizontal and vertical screen position
    always_ff @(posedge clk_pix) begin
        if (sx == LINE) begin   // last pixel on line?
            sx <= 0;
            sy <= (sy == SCREEN) ? 0 : sy + 1;
        end else begin
            sx <= sx + 1;
        end
        if (rst) begin
            sx <= 0;
            sy <= 0;
        end
    end
endmodule