module controlsimple(
    input bit clk,
    input bit reset,
    output bit[3:0] state
);

    bit[3:0] s_state;

    always_ff @(posedge clk) begin
        if (reset)
            s_state <= 4'b0001;
        else 
            case (s_state)
                4'b0001: s_state <= 4'b0010;
                4'b0010: s_state <= 4'b0100;
                4'b0100: s_state <= 4'b1000;
                default: s_state <= 4'b0001;
            endcase
    end

    assign state = s_state;

endmodule