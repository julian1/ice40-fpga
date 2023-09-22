

// useful test pattern generator

`default_nettype none


// should paramaterize paramaterize
module blinker    (
  input clk,

  // module outputs can be safely ignored,
  output reg [8-1: 0] vec_leds      // change name out.
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




// should paramaterize paramaterize
module counter  #(parameter MSB=8) (
  input clk,
  // module outputs can be safely ignored,
  output reg [MSB -1: 0] out
);

  always@(posedge clk) begin
    out <= out + 1;
  end

endmodule



