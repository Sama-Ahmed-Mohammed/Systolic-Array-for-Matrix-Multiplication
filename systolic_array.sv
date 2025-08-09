module systolic_array #(
    parameter DATAWIDTH = 16,
    parameter N_SIZE = 5
)(
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    input wire [DATAWIDTH-1:0] matrix_a_in [N_SIZE - 1 : 0],
    input wire [DATAWIDTH-1:0] matrix_b_in [N_SIZE - 1 : 0],
    output wire valid_out, // Changed from reg to wire
    output wire [2*DATAWIDTH-1:0] matrix_c_out [N_SIZE - 1 : 0] // Changed from reg to wire
);

//=============================================================================
//          internal wires for pipelining registers
//=============================================================================
    // Wires for pipelining 'a' inputs: a_pipelined_data[row_idx][stage_idx]
    // stage_idx 0 is directly from matrix_a_in.
    // stage_idx 'i' is the output after 'i' registers for row 'i'.
    wire [DATAWIDTH-1:0] a_pipelined_data [N_SIZE-1:0][N_SIZE:0];

    // Wires for pipelining 'b' inputs: b_pipelined_data[stage_idx][col_idx]
    // stage_idx 0 is directly from matrix_b_in.
    // stage_idx 'i' is the output after 'i' registers for column 'i'.
    wire [DATAWIDTH-1:0] b_pipelined_data [N_SIZE:0][N_SIZE-1:0];

// =========================================================================
//          Input Pipelining Registers Instantiation
// =========================================================================
    // These registers provide 'i' delays for row 'i' of matrix_a_in
    // and 'i' delays for column 'i' of matrix_b_in.
    genvar i, j;
    generate
        for (i = 0; i < N_SIZE; i++) begin : input_pipeline_gen
            // Pipelining registers for 'a' inputs (along rows)
            // Row 'i' needs 'i' registers. The loop runs 'i' times (j from 0 to i-1).
            // Example: For i=0 (first row), loop does not run, so no registers.
            // For i=1 (second row), loop runs once for j=0, instantiating 1 register.
            // For i=2 (third row), loop runs twice for j=0,1, instantiating 2 registers.
            for (j = 0; j < i; j++) begin : a_pipe_reg_inst
                pipe_reg #(DATAWIDTH) pipe_reg_a_inst (
                    .clk(clk),
                    .rst_n(rst_n),
                    .valid_in(valid_in), // Global valid_in enables these registers
                    .in(a_pipelined_data[i][j]),
                    .out(a_pipelined_data[i][j+1])
                );
            end

            // Pipelining registers for 'b' inputs (along columns)
            // Column 'i' needs 'i' registers. Similar logic as for 'a'.
            for (j = 0; j < i; j++) begin : b_pipe_reg_inst
                pipe_reg #(DATAWIDTH) pipe_reg_b_inst (
                    .clk(clk),
                    .rst_n(rst_n),
                    .valid_in(valid_in), // Global valid_in enables these registers
                    .in(b_pipelined_data[j][i]),
                    .out(b_pipelined_data[j+1][i])
                );
            end
        end
    endgenerate

// =========================================================================================
//      Connect matrix_a_in and matrix_b_in to the initial stage of pipelining
// =========================================================================================
    // This connects matrix_a_in[i] to a_pipelined_data[i][0]
    // and matrix_b_in[i] to b_pipelined_data[0][i].
    // These '0' indexed wires are the starting point for the input delays.
    genvar idx;
    generate
        for (idx = 0; idx < N_SIZE; idx++) begin : connect_inputs_to_pipeline_start
            assign a_pipelined_data[idx][0] = matrix_a_in[idx]; //a_pipelined_data[0][0] is just a wire that will connect to PE directly
            assign b_pipelined_data[0][idx] = matrix_b_in[idx];
        end
    endgenerate

//===========================================================================================
//       internal wires between PEs and PEs instances
//===========================================================================================

    // Wires for inputs to each PE at (row_idx, col_idx)
    wire [DATAWIDTH-1:0] a_in_pe [N_SIZE-1:0][N_SIZE-1:0];
    wire [DATAWIDTH-1:0] b_in_pe [N_SIZE-1:0][N_SIZE-1:0];
    wire valid_in_pe [N_SIZE-1:0][N_SIZE-1:0]; // Valid in signal for each PE

    // Wires for outputs from each PE at (row_idx, col_idx)
    wire [DATAWIDTH-1:0] a_out_pe [N_SIZE-1:0][N_SIZE-1:0];
    wire [DATAWIDTH-1:0] b_out_pe [N_SIZE-1:0][N_SIZE-1:0];
    wire [2*DATAWIDTH-1:0] c_out_pe [N_SIZE-1:0][N_SIZE-1:0];
    wire valid_out_pe [N_SIZE-1:0][N_SIZE-1:0]; // Valid output from PE

// =========================================================================
//          PE Array Instantiation
// =========================================================================

    // Instantiates N_SIZE x N_SIZE Processing Elements.
    genvar raw, col; 
    generate
        for (raw = 0; raw < N_SIZE; raw++) begin : pe_row_gen
            for (col = 0; col < N_SIZE; col++) begin : pe_col_gen
                pe #(DATAWIDTH) pe_inst (
                    .clk(clk),
                    .rst_n(rst_n),
                    .valid_in(valid_in_pe[raw][col]), // Input valid signal to PE
                    .a_in(a_in_pe[raw][col]),
                    .b_in(b_in_pe[raw][col]),
                    .valid_out(valid_out_pe[raw][col]), // Registered valid output from PE
                    .a_out(a_out_pe[raw][col]),
                    .b_out(b_out_pe[raw][col]),
                    .c_out(c_out_pe[raw][col])
                );
            end
        end
    endgenerate

// ========================================================================================
//      Connect Pipelined Data and PE Outputs to PE Inputs & Valid Propagation
// ========================================================================================
    // This section defines how each PE receives its 'a', 'b', and 'c' inputs,
    // and how the valid signal propagates through the array.
    genvar row_idx, col_idx;
    generate
        for (row_idx = 0; row_idx < N_SIZE; row_idx++) begin : pe_input_connections_row
            for (col_idx = 0; col_idx < N_SIZE; col_idx++) begin : pe_input_connections_col

                // 'a' input to PE(row_idx, col_idx):
                // If it's the first column (col_idx == 0), 'a_in' comes from the input pipelining chain.
                // Otherwise, it comes from the 'a_out' of the PE to its left.
                assign a_in_pe[row_idx][col_idx] = (col_idx == 0) ?
                                                 a_pipelined_data[row_idx][row_idx] : // Output of 'row_idx' delays for row 'row_idx'
                                                 a_out_pe[row_idx][col_idx-1];

                // 'b' input to PE(row_idx, col_idx):
                // If it's the first row (row_idx == 0), 'b_in' comes from the input pipelining chain.
                // Otherwise, it comes from the 'b_out' of the PE above it.
                assign b_in_pe[row_idx][col_idx] = (row_idx == 0) ?
                                                 b_pipelined_data[col_idx][col_idx] : // Output of 'col_idx' delays for col 'col_idx'
                                                 b_out_pe[row_idx-1][col_idx];

                // Valid input to PE(row_idx, col_idx):
                // Valid signal propagates from the top-left PE (0,0) through the array.
                if (row_idx == 0 && col_idx == 0) begin
                    assign valid_in_pe[row_idx][col_idx] = valid_in;
                end else if (row_idx == 0) begin // First row, valid comes from PE to the left
                    assign valid_in_pe[row_idx][col_idx] = valid_out_pe[row_idx][col_idx-1];

                end else if (col_idx == 0) begin // First column valid comes from PE above
                    assign valid_in_pe[row_idx][col_idx] = valid_out_pe[row_idx-1][col_idx];

                end else begin // Internal PEs, valid comes from left and above PEs together
                    assign valid_in_pe[row_idx][col_idx] =
                        valid_out_pe[row_idx-1][col_idx] && valid_out_pe[row_idx][col_idx-1];
                end
            end
        end
    endgenerate

// =========================================================================
//          Final Output (C Matrix) Muxing
// =========================================================================
    // Re-arrange c_out_pe to be column-major for MUX inputs

    wire [2*DATAWIDTH -1:0] c_pe_column_data [N_SIZE-1:0][N_SIZE-1:0];
    genvar r_reorder, c_reorder;
    generate
        for (r_reorder = 0; r_reorder < N_SIZE; r_reorder++) begin
            for (c_reorder = 0; c_reorder < N_SIZE; c_reorder++) begin
                assign c_pe_column_data[c_reorder][r_reorder] = c_out_pe[r_reorder][c_reorder];
            end
        end
    endgenerate

    wire [$clog2(N_SIZE) - 1 : 0] output_row_select; //MUX selector, which raw to pass tp output

    // Counter to select the output row from the PEs
    counter #(
        .N_SIZE(N_SIZE)
    ) output_row_counter (
        .clk(clk),
        .rst_n(rst_n),
        .valid_out_enable(valid_out), // Enable counter when the last PE finishes
        .count(output_row_select)
    );

    // Instantiate N_SIZE MUXes, one for each column of the final C matrix.
    // Each MUX selects a row from its respective column of PE outputs.
    genvar mux_col_idx;
    generate
        for (mux_col_idx = 0; mux_col_idx < N_SIZE; mux_col_idx++) begin : c_output_mux_gen
            mux #(
                .N_INPUTS(N_SIZE),
                .DATAWIDTH(2*DATAWIDTH), // C matrix elements are 2*DATAWIDTH wide
                .SELWIDTH($clog2(N_SIZE)) // Select width for N_SIZE inputs
            ) c_output_mux_col(
                .in_array(c_pe_column_data[mux_col_idx]), // Inputs from this column of PEs (all rows)
                .sel(output_row_select), // Select signal from the counter
                .out(matrix_c_out[mux_col_idx]) // Output to the corresponding column of matrix_c_out
            );
        end
    endgenerate

//===================================================================================
//  Valid out logic
//=================================================================================
    assign valid_out = valid_out_pe[N_SIZE - 1][N_SIZE - 1];
endmodule
