


`define SOFF      4'b0000
`define S1        4'b1000

            // himux2 <= 4'b1011;  // select ground to clear charge on cap.    s4 - A400-5 gnd. / 8|(4-1).

module test_accumulation_cap (

  input   clk,
  input   reset,     // async

  output [`NUM_BITS-1:0 ] out

);

  // clk_count for the current phase. 31 bits is faster than 24 bits. weird. ??? 36MHz v 32MHz
  reg [31:0]    clk_count = 0;

  // destructure
  reg [4-1:0] azmux;
  reg [4-1:0] himux;
  reg [4-1:0] himux2;
  reg sig_pc_sw_ctl;
  reg led0;

  reg [8-1: 0] monitor;//  = { MON7, MON6, MON5,MON4, MON3, MON2, MON1, MON0 } ;

  // nice.
  assign { monitor, led0, sig_pc_sw_ctl, himux2, himux,  azmux } = out;

  /* perhaps create some macros for MUX_1OF8_S1.
    // not sure.  can represent 8|(4-1)   for s4. etc.
    // most code is not going to care. there will just be a register for the zero, and a register for the signal.
  */

  // Can move to reset. but might as well set in the block.
  // assign sig_pc_sw_ctl = clk_count;

  // it would actually be  nice to have control over the led here.  we need a mode state variable.
  // and the interupt. actually.
  // sampling the charge - is a bit difficult.  because this is a kind of input modulation...
  /*
      - actually this functionality - *can* be incorporated into regular AZ switching and measurement.
        the gnd and the off signal.  are just the normal 2 mode AZ.

      - But not charge-injection testing.  actually maybe even charge injection.
  */

  // always @(posedge clk  or posedge reset )
  always @(posedge clk  or posedge reset )
   if(reset)
    begin
      clk_count <= 0;
    end
    else
    begin

      clk_count <= clk_count + 1;   // positive clk

      // we can trigger on these if we want
      case (clk_count)
        0:
          begin
            // off
            monitor <= 0;
            azmux  <= 0;
            sig_pc_sw_ctl <= 0;

            // muxes
            himux   <=  4'b1001;  // s2 select himux2.  for leakage test this should be off.
            himux2  <= 4'b1011;  // select ground to clear charge on cap.    s4 - A400-5 gnd. / 8|(4-1).
            led0    <= 0;
          end

        `CLK_FREQ * 1:
          begin
            himux2 <= 4'b1000;  // s1 select dcv-source-hi.  actually for real.  actually we would turn off to test leakage.
                                // need to be high-z mode to measure.  or measure from op-amp.

            led0    <= 1;
          end

        `CLK_FREQ * 2:
          clk_count <= 0;


      endcase

    end

endmodule


