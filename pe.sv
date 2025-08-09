module pe #(parameter DATAWIDTH = 16) (
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    input wire [DATAWIDTH-1:0] a_in,
    input wire [DATAWIDTH-1:0] b_in,

    output reg valid_out,
    output reg [DATAWIDTH-1:0] a_out,
    output reg [DATAWIDTH-1:0] b_out,
    output reg [2*DATAWIDTH-1:0] c_out
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_out <= 0;
            b_out <= 0;
            c_out <= 0;
            valid_out <=0;
        end 
        else if (valid_in) begin
            a_out <= a_in;
            b_out <= b_in;
            c_out <= c_out + a_in*b_in;
            valid_out <= 1;
        end
        else if(!valid_in) valid_out <=0; //this signal is used to stop PE from accumulating when there's no more input comming
    end

endmodule