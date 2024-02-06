

  // might be easier - to just use numerals as indicies for everything not assigned.
  // is it possible to do multiple subsripts?? eg with a comma?

/*


x +: N, The start position of the vector is given by x and you count up from x by N.

There is also

x -: N, in this case the start position is x and you count down from x by N.


logic [31: 0] a_vect;
a_vect[ 0 +: 8] // == a_vect[ 7 : 0]
a_vect[15 -: 8] // == a_vect[15 : 8]

don't have to do the -1. everywhere this is good.  eg. it's a span.

*/


// old.
// just switch between two direct registers.


// perhaps change name mode_4_pattern
// mode 4.

module test_pattern_2 (

  /*
    just mux output between two values. not sure if this is useful.
    versus real az.
  */

  input   clk,                               // master clk.

  input [ `NUM_BITS - 1 :0 ] reg_direct,     // synchronous on spi_clk.
  input [ `NUM_BITS - 1 :0 ] reg_direct2,    // synchronous on spi_clk.

  output reg [`NUM_BITS-1:0 ] out            //output reg -> driving wire.  not working.
);

  reg [31:0]   counter = 0;
  reg [1: 0] state = 0;  // sig/zero .   could have 4 mode representation.  // is a single reg a single state

  always@(posedge clk  )
      begin

        // default.
        counter <= counter + 1;

        if(counter == `CLK_FREQ / 10 )   // 10Hz.
          begin
            // reset counter - overide
            counter <= 0 ;
            // for the test-- spin the precharge switch - but keep mux constant - by repeating the patterns.
            // for mux leakage - don't want to spin pre-charge, but do need the floated mux.

            if(state)
              begin
                state           <= 0;
                out             <= reg_direct;
              end
            else
              begin
                state           <= 1;
                out             <= reg_direct2;
              end
          end // counter
      end   // posedge clk

endmodule


  // TODO - these outputs. I think should be wires... the regsisters are in the modules.

  wire [ `NUM_BITS-1:0 ]  test_pattern_2_out;
  test_pattern_2
  test_pattern_2 (
    .clk( CLK),
    .reg_direct(  reg_direct[ `NUM_BITS - 1 :  0 ]),      // truncate 32 bit reg, to output vec.
    .reg_direct2( reg_direct2[ `NUM_BITS - 1 :  0 ]),
    .out(  test_pattern_2_out )
  );


