module horizontal_counter(
    input logic clk,
    output reg enable_v_counter = 0,
    output reg [15:0] h_count_value = 0
    );

    parameter WIDTH;
    
    always @(posedge clk) begin
        if (h_count_value < WIDTH - 1) begin
            h_count_value <= h_count_value + 1;
            enable_v_counter <= 0;
        end else begin
            h_count_value <= 0;
            enable_v_counter <= 1;  // trigger v counter             
        end
    end        
    
endmodule

module vertical_counter(
    input logic clk,
    input logic enable_v_counter,
    output reg [15:0] v_count_value = 0
    );

    parameter HEIGHT;
    
    always @(posedge clk) begin
        if (enable_v_counter == 1'b1) begin
            if (v_count_value < HEIGHT - 1)
                v_count_value <= v_count_value + 1;
            else
                v_count_value <= 0;
        end
    end
endmodule

module vga(
    input logic clk,
    output logic hsync,
    output logic vsync,
    output logic [3:0] red,
    output logic [3:0] green,
    output logic [3:0] blue
);

    parameter WIDTH = 256, HEIGHT = 192;
	
    function logic [11:0] pixel_value(
        input logic [15:0] x,
        input logic [15:0] y);
        begin
            pixel_value = (x % 10 == 0) || (y % 10 == 0) ? 12'hF00 : 12'h00F;
        end
    endfunction	
            
    logic enable_v_counter;
    logic [15:0] h_count_value;
    logic [15:0] v_count_value;
    logic is_visible;
    logic [11:0] current_pixel_value;

	horizontal_counter #(.WIDTH) vga_horiz(
        .clk,
        .enable_v_counter,
        .h_count_value
    );

    vertical_counter #(.HEIGHT) vga_verti(
        .clk,
        .enable_v_counter,
        .v_count_value
    );
    
    // sync
    assign hsync = (h_count_value == WIDTH - 1) ? 1'b1 : 1'b0;
    assign vsync = (v_count_value == HEIGHT - 1) ? 1'b1 : 1'b0;
    
    // colors
    assign current_pixel_value = pixel_value(h_count_value, v_count_value);
    assign red = current_pixel_value[11:8];
    assign green = current_pixel_value[7:4];
    assign blue = current_pixel_value[3:0];

endmodule