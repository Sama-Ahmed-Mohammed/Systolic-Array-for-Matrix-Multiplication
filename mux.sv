module mux #(
    parameter DATAWIDTH = 16, // Specifies the bit width of each data element in the input array and output.
    parameter N_INPUTS = 8,      // Specifies the total number of input lines (elements) in the 'in_array'.
    parameter SELWIDTH = 3       // Specifies the bit width of the 'sel' (select) signal.
) (
    input wire [DATAWIDTH - 1 : 0 ] in_array [N_INPUTS-1:0], // Input array of data elements.
                                                                 // The size is N_INPUTS, indexed from 0 to N_INPUTS-1.
    input wire [SELWIDTH-1:0] sel,                               // Select signal to choose which input element to route to the output.
    output wire [DATAWIDTH - 1 : 0 ] out 
);
    // Combinational assignment: the output 'out' is directly assigned the element
    // from 'in_array' at the index specified by 'sel'.
    assign out = in_array[sel];
endmodule
