
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


/*
    we just want a register bank....
*/


module mylatch   #(parameter MSB=8)   (
  input  clk,
  input  cs,
  input  special,
  input  d,   // sdi

  // latched val, rename
  output reg [MSB-1:0] out    // rename muxreg
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
      //out <= tmp;

      case (tmp)  // high byte for reg
        1 :
        begin
          out = 1;
        end

        default:
          out = 0;

      endcase



  end
endmodule




module mymux    (

  input wire [8-1:0] myreg,     // inputs are wires. cannot be reg.

  input  cs,

  output adc03_cs,
  output myregister_cs,

);

/*
  we only really have to mux cs.
  lets try that...
*/
  // mux example, https://www.chipverify.com/verilog/verilog-case-statement

  always @ (myreg )     // eg. whenever myreg changes we update ... i think.
    begin

    // I think this doesn't work. 
    // It is assigning the value when myreg changes.
    // not connecting a line.

    // think we're going to have to do a clk.

      case (myreg )
        1 :
        begin
          adc03_cs = cs;
          myregister_cs = 1;  // deassert
        end

        2 :
        begin
          adc03_cs = 1;   // deassert
          myregister_cs = cs;
        end


        default: 
        begin
          adc03_clk = 1;
          myregister_cs = 1;
        end
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
  wire [8-1:0] muxreg;

  wire [8-1:0] anotherreg;

  assign {LED1, LED2} = muxreg;

  mylatch #( 8 )
  mylatch
    (
    .clk(CLK),
    .cs(CS),
    .special(SPECIAL),
    .d(MOSI),
    .out(muxreg)
  );





  mymux #( )
  mymux
  (
    . myreg(muxreg),
    . cs(CS),
    . adc03_cs(ADC03_CS),
    . myregister_cs(myregister_cs),
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


