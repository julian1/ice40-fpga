

// useful test pattern generator

`default_nettype none



module blinker    (
  input clk,

  // module outputs can be safely ignored,
  output reg [8-1: 0] vec_leds 
);

  localparam BITS = 5;
  // localparam LOG2DELAY = 21;
  localparam LOG2DELAY = 19;

  reg [BITS+LOG2DELAY-1:0] counter = 0;
  reg [BITS-1:0] outcnt;

  always@(posedge clk) begin
    counter   <= counter + 1;
    outcnt    <= counter >> LOG2DELAY;

    vec_leds  <= outcnt ^ (outcnt >> 1);
  end

endmodule



