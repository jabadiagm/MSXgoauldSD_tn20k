module pulse_min #(
    parameter int N_BITS = 8
)(
    input wire clk,          // System clock
    input wire reset,        // Reset signal
    input wire pulse_in,     // Input pulse signal
    output wire [N_BITS-1:0] minimum, // Minimum pulse length in clock cycles
    output wire valid    // Indicates if a valid pulse length is found
);

    reg [N_BITS-1:0] count;           // Counter for pulse duration
    reg [N_BITS-1:0] min_len;
    reg counting;              // State to check if we are in pulse mode
    reg pulse_valid;
    reg wait0;
    reg latch;
    assign minimum = min_len;
    assign valid = pulse_valid;

    // Initialize values
    initial begin
        count = 0;
        count = 0;
        min_len = {N_BITS {1'b1} };    // Set to max value initially
        pulse_valid = 0;
        counting = 0;
        wait0 <= 1;
        latch <= 0;
    end

    // Pulse detection and counting
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counting <= 0;
            wait0 <= 1;
            latch <= 0;
        end else begin
            latch <= 0;
            if (pulse_in == 0) wait0 <= 0;
            if (counting == 0) begin
                if (pulse_in == 1 && wait0 == 0) begin
                    counting <= 1;
                end
            end
            else begin
                if (pulse_in == 0) begin
                    latch <= 1;
                    counting <= 0;
                end  
            end
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            count <= 0;       // Reset count
            min_len = {N_BITS {1'b1} };
            pulse_valid <= 0;     // Reset valid pulse indicator
        end else begin
            if (counting == 1) begin
                count <= count + 1;
            end
            else if (latch == 1) begin
                if (count < min_len) begin
                    min_len <= count; // Update minimum length
                    pulse_valid <= 1;
                end
            end
            else begin
                count <= 0;
            end
        end
    end

endmodule