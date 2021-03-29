
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


// ok. lets try to use the special flag.

module mylatch   #(parameter MSB=8)   (
  input  clk,
  input  cs,
  input  special,
  input  d,   // sdi

  // latched val, rename
  output reg [MSB-1:0] out
);

  reg [MSB-1:0] tmp;


  always @ (negedge clk)
  begin
    if (!cs && !special)         // chip select asserted.
    // if (!cs )         // chip select asserted.
      tmp <= {tmp[MSB-2:0], d};
    // else
    //  tmp <= tmp;
  end
  /*
    RIGHT. it doesn't like having both a negedge and posedge...
  */


  always @ (posedge cs)
  begin
    if(!special)    // special asserted
      out <= tmp;
  end


endmodule




module mymux    (
  input  clk,
  input  cs,
  input  d,   
  input wire [8-1:0] myreg,     // inputs are wires. cannot be reg.
  output adc03_clk
);

  // mux example, https://www.chipverify.com/verilog/verilog-case-statement

  always @ (myreg )     // eg. whenever myreg changes we update ... i think.
    begin
   
      case (myreg )
        1 :      adc03_clk = clk;  
        default: adc03_clk = 0;
      endcase

    end

endmodule



// OK. we only want to latch the value in, on correct clock transition count.


/*
  EXTREME
    - we ought should be able to do miso / sdo - easily - its the same as the other peripheral wires going to dac,adc etc.
    - there may be an internal creset?
*/

module top (
  input  XTALCLK,

  // leds
  output LED1,
  output LED2,

  // spi
  input CLK,
  input CS,
  input MOSI,
  input SPECIAL
  // output b
);
  // should be able to assign extra stuff here.
  //



  ////////////////////////////////////
  // sayss its empty????
  wire [8-1:0] out;
  // reg [8-1:0] out = 0;
  // register [8-1:0] out = 0;


  assign {LED1, LED2} = out;

  mylatch #( 8 )
  mylatch
    (
    .clk(CLK),
    .cs(CS),
    .special(SPECIAL),
    .d(MOSI),

    .out(out)
  );


  mymux #( )
  mymux 
  (
    .clk(CLK),
    .cs(CS),
    .d(MOSI),
    . myreg( out ),
    . adc03_clk(ADC03_CLK)
  );
  

  // want to swapt the led order.
  // assign LED1 = MOSI;
  // assign LED1 = MOSI;
  // assign LED1 = SPECIAL;

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


