

// should be able to be used to toggle the monitor pins also if want.

`default_nettype none



module blinker    (
  input clk,

  // module outputs can be safely ignored,
  output led0,
  output led1,
  output led2,
  output led3,
  output led4
);

  localparam BITS = 5;
  // localparam LOG2DELAY = 21;
  localparam LOG2DELAY = 19;

  reg [BITS+LOG2DELAY-1:0] counter = 0;
  reg [BITS-1:0] outcnt;

  always@(posedge clk) begin
    counter <= counter + 1;
    outcnt <= counter >> LOG2DELAY;
  end

  assign { led4,led3, led2, led1, led0  } = outcnt ^ (outcnt >> 1);
endmodule



