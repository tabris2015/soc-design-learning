// First light on the DE25-Nano: LED0 blinks at about 0.75 Hz.
//
// A 26-bit counter on the 50 MHz clock; bit 25 flips every 2^25 cycles, so
// the LED is on for 0.67 s and off for 0.67 s.
module blink (input logic clk, output logic led);
    logic [25:0] count = '0;
    always_ff @(posedge clk) count <= count + 1'b1;
    assign led = count[25];
endmodule
