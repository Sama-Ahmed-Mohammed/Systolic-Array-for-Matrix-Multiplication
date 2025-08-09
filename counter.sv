module counter #(
    parameter N_SIZE = 5 // Upper bound (counter counts from 0 to N_SIZE-1)
)(
    input  wire clk,
    input  wire rst_n,
    input wire valid_out_enable, //valid_out_enable signal is given as input to make counter start
    output reg [$clog2(N_SIZE)-1:0] count
);

    // Internal register for counter
    reg [$clog2(N_SIZE)-1:0] count_reg;

    always @(posedge clk or negedge rst_n ) begin
        if (!rst_n || !(valid_out_enable))
            count_reg <= '0;
        
        else if (valid_out_enable) begin
            if (count_reg == N_SIZE - 1)
                count_reg <= '0;  // wrap around
            else
                count_reg <= count_reg + 1;
        end
    end
    assign count = count_reg;
endmodule
