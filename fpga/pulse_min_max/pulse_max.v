module pulse_max #(
    parameter int N_BITS = 8
)(
    input wire clk,          // System clock
    input wire reset,        // Reset signal
    input wire pulse_in,     // Input pulse signal
    output wire [N_BITS-1:0] maximum, // Maximum pulse length in clock cycles
    output wire valid    // Indicates if a valid pulse length is found
);

    reg [N_BITS-1:0] count;           // Counter for pulse duration
    reg [N_BITS-1:0] max_len;
    reg counting;              // State to check if we are in pulse mode
    reg pulse_valid;
    reg wait0;
    reg latch;
    assign maximum = max_len;
    assign valid = pulse_valid;

    // Initialize values
    initial begin
        count = 0;
        count = 0;
        max_len = 0;    // Set to max value initially
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
            max_len = 0;
            pulse_valid <= 0;     // Reset valid pulse indicator
        end else begin
            if (counting == 1) begin
                count <= count + 1;
            end
            else if (latch == 1) begin
                if (count > max_len) begin
                    max_len <= count; // Update maximum length
                    pulse_valid <= 1;
                end
            end
            else begin
                count <= 0;
            end
        end
    end

endmodule