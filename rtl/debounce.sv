// Ref.: https://projectf.io/posts/fpga-pong/

module debounce(
    input logic clk,        // clock
    input logic in,         // signal input
    output logic out,       // signal output (debounced)
    output logic ondn,      // on down (one tick)
    output logic onup       // on up (one tick)
    );

    // sync with clock and combat metastability
    logic sync_0, sync_1;
    always_ff @(posedge clk) sync_0 <= in;
    always_ff @(posedge clk) sync_1 <= sync_0;

    logic [19:0] cnt;       // 2^20 = 10 ms counter at 100 MHz
    logic idle, max;
    always_comb begin
        idle = (out == sync_1);
        max = &cnt;
        ondn = ~idle & max & ~out;
        onup = ~idle & max & out;
    end

    always_ff @(posedge clk) begin
        if (idle) begin
            cnt <= 0;
        end else begin
            cnt <= cnt + 1;
            if (max) out <= ~out;
        end
    end


endmodule