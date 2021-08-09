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
`default_nettype none

module top(
    input wire clk,
    input wire reset,
    input wire logic [3:0] sw,
    input wire logic btn_up,
    input wire logic btn_ctrl,
    input wire logic btn_dn,
    output logic [3:0] led,
    output logic vga_hsync,
    output logic vga_vsync,
    output logic [3:0] vga_r,
    output logic [3:0] vga_g,
    output logic [3:0] vga_b
    );

   logic clk_pix;
   logic clk_locked;

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

    //
    // VGA output
    //

    logic xosera_cs_n = 1'b1;
    logic xosera_rd_nwr = 1'b1;
    logic [3:0] xosera_reg_num;
    logic [7:0] xosera_data_in;
    logic xosera_bytesel;

    xosera_main xosera(
        .clk(clk_pix),
        .bus_cs_n_i(xosera_cs_n),
        .bus_rd_nwr_i(xosera_rd_nwr),
        .bus_reg_num_i(xosera_reg_num),
        .bus_bytesel_i(~xosera_bytesel),
        .bus_data_i(xosera_data_in),
        .bus_data_o(),
        .red_o(vga_r),
        .green_o(vga_g),
        .blue_o(vga_b),
        .hsync_o(vga_hsync),
        .vsync_o(vga_vsync),
        .dv_de_o(),
        .audio_l_o(),
        .audio_r_o(),
        .reconfig_o(),
        .boot_select_o(),
        .reset_i(reset)
    );

    //
    // CPU
    //

    logic [15:0] data_in, data_out;
    logic [15:0] cpu_data_in, cpu_data_out;
    logic [15:0] address;
    logic write;
    logic [7:0] display;
    logic ram_cs;

    ram #(.A(16), .D(16)) ram0(
        .clk(clk), .cs(ram_cs), .write, .addr(address), .data_in, .data_out
    );

    cpu cpu0(
        .clk(clk), .reset, .hold(0), .busy(), .address, .data_in(cpu_data_in), .data_out(cpu_data_out), .write
    );

    always_comb begin
        led = display[3:0];
        ram_cs = !address[15];
        data_in = cpu_data_out;
    end

    // Read
    always_comb begin
        if (address[15:12] == 4'h9)
            cpu_data_in = {4'b0000, sw};
        else if (address[15:12] == 4'hF)
            // Video
            cpu_data_in = {15'h0, vga_vsync};
        else cpu_data_in = data_out;
    end

    // Write
    always_ff @(posedge clk)
    begin
        if (write)
            if (address[15:12] == 4'h8)
                display <= cpu_data_out;
            else if (address[15:12] == 4'hA) begin
                //$display("[%0t] Xosera: Select register [%1d]...\n", $time, cpu_data_out);
                xosera_reg_num <= cpu_data_out[3:0];
                xosera_bytesel <= cpu_data_out[4];
            end else if (address[15:12] == 4'hB) begin
                //$display("[%0t] Xosera: Set data [%1d]...\n", $time, cpu_data_out);
                xosera_data_in <= cpu_data_out;
            end else if (address[15:12] == 4'hC) begin
                //$display("[%0t] Xosera: Strobe [%1d]...\n", $time, cpu_data_out);
                xosera_cs_n <= cpu_data_out[0];
                xosera_rd_nwr <= cpu_data_out[0];
            end                
    end

    // Print some stuff as an example
`ifdef verilator
    initial begin
        if ($test$plusargs("trace") != 0) begin
            $display("[%0t] Tracing to logs/vlt_dump.vcd...\n", $time);
            $dumpfile("logs/vlt_dump.vcd");
            $dumpvars();
        end
        $display("[%0t] Model running...\n", $time);
    end
`endif

endmodule
