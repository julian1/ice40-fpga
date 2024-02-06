


`default_nettype none

module test_pattern #(parameter BITS=32 ) (
  input   clk,


  output reg  [ BITS -1:0 ] out   // wire.kk
);

  always@(posedge clk  )
      begin
        // works all monitor pins.
        // remove the himux2  reg_direct value is not working.
        // out[ 17 : 0 ]  <= out [ 17  : 0   ] + 1;
        // out  <= out  + 1;
        out  <= out  + 1;
      end

endmodule


