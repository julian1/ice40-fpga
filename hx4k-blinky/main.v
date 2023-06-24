

module top (
  input  clk,
  output LED1,
  output LED2,

  output MON1,
  output MON2,
  output MON3,
  output MON4,
  output MON5,
  output MON6,   
  output MON7,   

  output U413_A0_CTL,
  output U413_A1_CTL,
  output U413_A2_CTL,

  output U902_SW1_CTL,
  output U902_SW2_CTL,
  output U902_SW3_CTL,
  output U902_SW4_CTL,

);

  localparam BITS = 5;
  localparam LOG2DELAY = 21;

  reg [BITS+LOG2DELAY-1:0] counter = 0;
  reg [BITS-1:0] outcnt;

  always@(posedge clk) begin
    counter <= counter + 1;
    outcnt <= counter >> LOG2DELAY;
  end

  // assign { LED1, LED2} = outcnt ^ (outcnt >> 1);
  assign { LED2, LED1} = outcnt ^ (outcnt >> 1);
  





  assign MON1 = clk ;   // note the slight skew. from input clock due popagation delay.

  assign { MON4, MON3, MON2 } = counter;

  assign { U413_A2_CTL, U413_A1_CTL, U413_A0_CTL } = counter;

  assign { U902_SW4_CTL, U902_SW3_CTL, U902_SW2_CTL, U902_SW1_CTL} = counter;

endmodule


