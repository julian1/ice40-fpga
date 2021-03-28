
// from https://github.com/cliffordwolf/icestorm/tree/master/examples/icestick

// example.v


// HANG on how does register shadowing work???

// have separate modules for an 8 bit mux.
// versus a 16 bit reg value
// versus propagating.


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




module mymux   #(parameter MSB=8)   (
  input  clk,
  input  cs,
  input  d,   // sdi

  // output led
  output reg [MSB-1:0] out
);

   // always @ (posedge clk)
   always @ (negedge clk)
      /*
      if (!cs)
         out <= 0;        // this clears after de-assert... which is not what we want...
                          // instead we want nop.
      else begin
      */
         if (!cs)         // chip select.
            out <= {out[MSB-2:0], d};
         else
            out <= out;
      // end
endmodule

// DAMMM need to add a pullup resistor... for CS/NSS.

// The above should be good enough to test ... just wire the led to the lsb.

/*
  EXTREME
    we ought should be able to do miso / sdo - easily - its the same as the other peripheral wires going to dac,adc etc.
*/

module top (
  input  XTALCLK,

  // leds
  output LED1,
  output LED2,

  // spi
  input SCLK,
  input CS,
  input MOSI
  // output b
);

  // top most module - should just deleegate to other modules.
  // should be able to assign extra stuff here.
  //



  ////////////////////////////////////
  // sayss its empty????
  wire [8-1:0] out;
  // reg [8-1:0] out = 0;
  // register [8-1:0] out = 0;
  // assign {LED1, LED2} = out;

  mymux #( 8 )
  mymux
    (
    .clk(SCLK),
    .cs(CS),
    .d(MOSI),

    .out(out)
  );

  assign { LED1, LED2 } = out;    // lowest bits or highest?


  // want to swapt the led order.
  // assign LED1 = MOSI;

/*
  blinker #(  )
  blinker
    (
    .clk(XTALCLK),
    .led1(LED1),
    .led2(LED2)
  );
*/




endmodule


