// from https://github.com/cliffordwolf/icestorm/tree/master/examples/icestick

// example.v


// HANG on how does register shadowing work???

// have separate modules for an 8 bit mux.
// versus a 16 bit reg value
// versus propagating.



/*
    we just want a register bank....
  TODO rename mylatch myregister_bank ?

  // use the special flag, to write to the register bank.
*/

module blinker    (
  input clk,
  output led1,
  output led2

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

  // assign {led1} = counter2 >> 22;
  // assign { led1, led2, LED3, LED4, LED5 } = outcnt ^ (outcnt >> 1);
  assign {  led1, led2 } = outcnt ^ (outcnt >> 1);
endmodule



