


`default_nettype none




module blinker    (
  input clk,

  output reg [4-1:0] led_vec

);

  localparam BITS = 4;
  // localparam LOG2DELAY = 21;
  localparam LOG2DELAY = 20;

  reg [BITS+LOG2DELAY-1:0] counter = 0;
  reg [BITS-1:0] outcnt;

  // sequential
  always@(posedge clk) begin
    counter <= counter + 1;
    outcnt <= counter >> LOG2DELAY;
  end

  // assign { led1, led2, LED3, LED4, LED5 } = outcnt ^ (outcnt >> 1);
  // assign {  led1, led2 } = outcnt ^ (outcnt >> 1);

  // continuous. why?
  assign led_vec = outcnt ^ (outcnt >> 1);

endmodule


