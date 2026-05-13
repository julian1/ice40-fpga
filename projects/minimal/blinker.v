
/*
  perhaps rename generator
  some test pattern generator
*/

`default_nettype none


// should paramaterize paramaterize
module blinker  #(parameter BITS=4)   (
  input clk,

  // module reg outputs can be safely ignored,
  output reg [ BITS -1: 0] out
);

  // localparam BITS = 5;
  localparam LOG2DELAY = 21;
  // localparam LOG2DELAY = 19;

  reg [BITS+LOG2DELAY-1:0] counter = 0;
  reg [BITS-1:0] outcnt;

  always@(posedge clk) begin
    counter   <= counter + 1;
    outcnt    <= counter >> LOG2DELAY;

    out  <= outcnt ^ (outcnt >> 1);
  end

endmodule



