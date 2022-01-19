
/*
  Toggle, key gpio.

  Do *NOT* run this when circuit populated, and analog power is applied.
*/

module top (
  input  clk,
  output LED_R,
  output LED_G,
  output LED_B,

  output INT_IN_SIG_CTL,
  output INT_IN_P_CTL,
  output INT_IN_N_CTL,

  output COM_MISO,
  output COM_INTERUPT


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

  assign { INT_IN_SIG_CTL,  INT_IN_P_CTL , INT_IN_N_CTL }  = outcnt ^ (outcnt >> 1);

  assign { COM_MISO,  COM_INTERUPT }  = outcnt ^ (outcnt >> 1);



endmodule


