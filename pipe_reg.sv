module pipe_reg #(parameter DATAWIDTH = 16) (
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    input wire [DATAWIDTH-1:0] in,
    output reg [DATAWIDTH-1:0] out
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            out <= 0;
        else if (valid_in)
            out <= in;
    end
endmodule 