

module top (
  input  clk,
  output LED_R,
  output LED_G,
  output LED_B,
);

  localparam BITS = 5;
  localparam LOG2DELAY = 21;

  reg [BITS+LOG2DELAY-1:0] counter = 0;
  reg [BITS-1:0] outcnt;

  always@(posedge clk) begin
    counter <= counter + 1;
    outcnt <= counter >> LOG2DELAY;
  end

  assign { LED_R, LED_G, LED_B } = outcnt ^ (outcnt >> 1);

endmodule


