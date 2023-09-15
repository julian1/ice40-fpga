
/*
  blink led, and blink some other test signals.

*/

module top (
  input  CLK,

  output LED0,
  // output LED2,

  output MON0,
  output MON1,
  output MON2,
  output MON3,
  output MON4,
  output MON5,
  output MON6,
  output MON7,


  output _4094_OE_CTL,

  output SIG_PC_SW_CTL,



  output U402_EN_CTL,
  output U402_A0_CTL,
  output U402_A1_CTL,
  output U402_A2_CTL,

  output U414_EN_CTL,
  output U414_A0_CTL,
  output U414_A1_CTL,
  output U414_A2_CTL,

  output U413_EN_CTL,
  output U413_A0_CTL,
  output U413_A1_CTL,
  output U413_A2_CTL,


  output U902_SW0_CTL,
  output U902_SW1_CTL,
  output U902_SW2_CTL,
  output U902_SW3_CTL,

  input SWITCH_SENSE_OUT,
);

  localparam BITS = 5;
  localparam LOG2DELAY = 21;

  reg [BITS+LOG2DELAY-1:0] counter = 0;
  reg [BITS-1:0] outcnt;

  always@(posedge CLK) begin
    counter <= counter + 1;
    outcnt <= counter >> LOG2DELAY;
  end

  // assign { LED2, LED0} = outcnt ^ (outcnt >> 1);
  // assign {  LED0 } = outcnt ^ (outcnt >> 1);

  assign {  LED0 } = outcnt ^ (outcnt >> 1);
  // assign LED0 = SWITCH_SENSE_OUT;


  assign {  SIG_PC_SW_CTL } = outcnt ^ (outcnt >> 1);

  assign {  _4094_OE_CTL } = outcnt ^ (outcnt >> 1);


  assign { U402_A2_CTL, U402_A1_CTL, U402_A0_CTL, U402_EN_CTL } = outcnt ^ (outcnt >> 1);
  assign { U414_A2_CTL, U414_A1_CTL, U414_A0_CTL, U414_EN_CTL } = outcnt ^ (outcnt >> 1);
  assign { U413_A2_CTL, U413_A1_CTL, U413_A0_CTL, U413_EN_CTL } = outcnt ^ (outcnt >> 1);


  assign { U902_SW3_CTL, U902_SW2_CTL, U902_SW1_CTL , U902_SW0_CTL } = outcnt ^ (outcnt >> 1);



  assign MON0 = CLK ;   // note the slight skew. from input clock due popagation delay.

  assign { MON4, MON3, MON2, MON1 } = counter;



endmodule


