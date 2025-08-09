`timescale 1ns / 1ps
module systolic_array_tb();

    // Parameters (must match the DUT's parameters)
    localparam DATAWIDTH = 16;
    localparam N_SIZE = 5; // Example: 5x5 matrix

    // Testbench signals for DUT interface
    reg clk;
    reg rst_n;
    reg valid_in;
    reg [DATAWIDTH-1:0] matrix_a_in [N_SIZE - 1 : 0];
    reg [DATAWIDTH-1:0] matrix_b_in [N_SIZE - 1 : 0];
    wire valid_out;
    wire [2*DATAWIDTH-1:0] matrix_c_out [N_SIZE - 1 : 0];

    // Instantiate the Device Under Test (DUT)
    systolic_array #(
        .DATAWIDTH(DATAWIDTH),
        .N_SIZE(N_SIZE)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .matrix_a_in(matrix_a_in),
        .matrix_b_in(matrix_b_in),
        .valid_out(valid_out),
        .matrix_c_out(matrix_c_out)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns clock period (100 MHz)
    end

    // Single initial block: Controls the entire test sequence
    initial begin
        // ALL AUTOMATIC VARIABLE DECLARATIONS MUST BE AT THE TOP OF THE INITIAL BLOCK
        automatic int i, j;
        automatic int errors = 0;
        automatic int expected_c_value;
        automatic int wait_cycles_before_check; // Moved declaration to the top

        $display("-----------------------------------------------------");
        $display("Starting Systolic Array Testbench (N_SIZE = %0d)", N_SIZE);
        $display("-----------------------------------------------------");

        // 1. Initial Reset and Self-Checking
        $display("Applying reset");
        rst_n = 0;    // Assert active-low reset
        valid_in = 0; // No valid input
        // Initialize inputs to 0 during reset
        for (i = 0; i < N_SIZE; i++) begin
            matrix_a_in[i] = 0;
            matrix_b_in[i] = 0;
        end

        repeat(5) @(negedge clk); // Wait sufficient cycles (e.g., 5) for all regs to reset to 0
        // Check if all outputs are 0 after reset
        if (valid_out !== 1'b0) begin
            $error("ERROR: valid_out is not 0 after reset. Expected 0, Got %b", valid_out);
            errors++;
        end
        for (i = 0; i < N_SIZE; i++) begin
            if (matrix_c_out[i] !== {2*DATAWIDTH{1'b0}}) begin
                $error("ERROR: matrix_c_out[%0d] is not 0 after reset. Expected 0, Got %h", i, matrix_c_out[i]);
                errors++;
            end
        end
        $display("Initial reset and output check complete. Errors: %0d", errors);

        rst_n = 1; // Release reset
        @(negedge clk); // Wait one cycle after releasing reset

        // 2. Prepare Input Data (all raws = 1)
        $display("Preparing input matrices A and B (all raws = 1)");
        for (i = 0; i < N_SIZE; i++) begin
            matrix_a_in[i] = 1;
            matrix_b_in[i] = 1;
        end
        $display("matrix_a = %0d | %0d | %0d | %0d | %0d | ", matrix_a_in[0], matrix_a_in[1], matrix_a_in[2], matrix_a_in[3], matrix_a_in[4]);
        $display("matrix_b = %0d | %0d | %0d | %0d | %0d | ", matrix_b_in[0], matrix_b_in[1], matrix_b_in[2], matrix_b_in[3], matrix_b_in[4]);

        // 4. Apply Stimulus to DUT
        // valid_in needs to be asserted for exactly N_SIZE cycles to push all data through for one matrix multiplication.
        $display("Applying valid_in and input data for %0d cycles...", N_SIZE);
        valid_in = 1; // Assert global valid input

        for (i = 0; i < N_SIZE; i++) begin
            @(negedge clk); // Apply inputs for N_SIZE cycles
            $display("   Cycle %0d: Input data applied.", i);
        end

        valid_in = 0; // Deassert valid_in after all inputs are provided
 
        wait(valid_out);

        @(negedge clk); //when valid_out is asserted the counter starts at the next edge, so wait for it to avoid sampling raw0 twice

        $display("Starting output self-check for %0d rows...", N_SIZE);
        for (i = 0; i < N_SIZE; i++) begin
            $display("   Sim Time: %0d ns: Checking output row %0d.", $time, dut.output_row_counter.count);

            // Self-check valid_out
            if (valid_out === 1'b1) begin
                $display("     valid_out is HIGH. Output row %0d is valid.", dut.output_row_counter.count);
                // Self-check the current row of matrix_c_out
                for (j = 0; j < N_SIZE; j++) begin
                    $display("matrix_c_out[%0d] for row %0d. Expected %0d, Got %0d", j, dut.output_row_counter.count, 5, matrix_c_out[j]);
                end
            end
            else begin
                $error("ERROR: valid_out is LOW for row %0d. Expected HIGH.", dut.output_row_counter.count);
            end
            @(negedge clk);
        end

        @(posedge clk); // Wait one more cycle
        $finish; // End simulation
    
    end
endmodule
