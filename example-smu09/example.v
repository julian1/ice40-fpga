
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




module mylatch   #(parameter MSB=8)   (
  input  clk,
  input  cs,
  input  special,
  input  d,   // sdi

  // latched val, rename
  output reg [MSB-1:0] out
);

  reg [31:0] counter = 0; // need to let it count past 8, so doesn't trigger on 16 or 24 etc.
  reg [MSB-1:0] tmp;

  always @ (negedge clk)
  begin
      if (!cs)         // chip select asserted.
        begin
          counter <= counter + 1;
          tmp <= {tmp[MSB-2:0], d};
        end
      else
        begin
          counter <= 0;
          tmp <= tmp;
        end
  end
  /*
    RIGHT. it doesn't like having both a negedge and posedge...
  */


  always @ (posedge cs)
  begin

    if(counter == 8 )  // == MSB
        out <= tmp;
//      else
//       out <= out;

  end


endmodule




module mymux    (
  input  clk,
  input  cs,
  input  d,   
  input wire [8-1:0] myreg,     // inputs are wires. cannot be reg.
  output adc03_sclk
);

  // mux example, https://www.chipverify.com/verilog/verilog-case-statement

  always @ (myreg )     // eg. whenever myreg changes we update ... i think.
    begin
   
      case (myreg )
        1 :      adc03_sclk = clk;  
        default: adc03_sclk = 0;
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

  mylatch #( 8 )
  mylatch
    (
    .clk(SCLK),
    .cs(CS),
    .special(1),
    .d(MOSI),

    .out(out)
  );

  assign { LED1, LED2 } = out;    // lowest bits or highest?

/*
  input  clk,
  input  cs,
  input  d,   
  input wire [8-1:0] myreg,     // inputs are wires. cannot be reg.
  output adc03_sclk

*/

  mymux #( )
  mymux 
  (
    .clk(SCLK),
    .cs(CS),
    .d(MOSI),
    . myreg( out ),
    . adc03_sclk(ADC03_SCLK)
  );
  

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


