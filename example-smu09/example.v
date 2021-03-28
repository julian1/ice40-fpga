
// from https://github.com/cliffordwolf/icestorm/tree/master/examples/icestick

// example.v


// HANG on how does register shadowing work???

// have separate modules for an 8 bit mux.
// versus a 16 bit reg value
// versus propagating.


module blinker    (
  input  clk,
  input  cs,
  input  d

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

  // assign {LED1} = counter2 >> 22;
  // assign { LED1, LED2, LED3, LED4, LED5 } = outcnt ^ (outcnt >> 1);
  // assign {  LED1, LED2 } = outcnt ^ (outcnt >> 1);




endmodule




module mymux   #(parameter MSB=8)   (
  input  clk,
  input  cs,
  input  d,

  // output led
  output reg [MSB-1:0] out
);

  // this should *not* take a led. it should just do the muxing
  // should just signal a high - if get a valid 8 bit spi word.
  // then in a separate module.
  // assign LED = CLK;

   always @ (posedge clk)
      if (!cs)
         out <= 0;        // this clears after de-assert... which is not what we want... 
                          // instead we want nop.
      else begin
         if (en)
            out <= {out[MSB-2:0], d};
         else
            out <= out;
      end
endmodule


// The above should be good enough to test ... just wire the led to the lsb. 


module top (
  input  clk,

  // leds
  output LED1,
  output LED2,

  // spi 
  input SCLK,
  input CS,
  input MOSI
  // output b
);

  // should be able to assign extra stuff here.
  // 

  wire [8-1:0] out;   

  mymux #( 8 )
  mymux
    (
    .clk(SCLK),
    .cs(CS),
    .d(MOSI),

    .out(out)
  );



  assign LED1 = SCLK;

endmodule


