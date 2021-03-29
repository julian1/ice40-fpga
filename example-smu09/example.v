


module mylatch   #(parameter MSB=16)   (
  input  clk,
  input  cs,
  input  special,
  input  d,   // sdi

  // latched val, rename
  output reg [8-1:0] reg_led,
  output reg [8-1:0] reg_mux
);

  /*
    if the clk count is wrong. it will make a big mess of values.
    really need to validate count = 16,.
  */

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
    ok. maybe count is necessary to include in sensitivity list?
  */
  /*
  // these don't work...
  assign address = tmp[ MSB-1:8 ];
  assign value   = tmp[ 8 - 1: 0 ];
  */

  always @ (posedge cs)
  begin

    if(!special)    // special asserted

      case (tmp[ MSB-1:8 ])  // high byte for reg, lo byte for val.

        // leds
        7 : reg_led = tmp[ 8 - 1: 0 ];

        // mux
        8 : reg_mux = tmp[ 8 - 1: 0 ];

      endcase


  end
endmodule


// EXTRME
// put adc/dac creset - in its own register. then we can assert/toggle it, without having to do bitshifting  - on mcu.
// eg. t 


// Ok. put a scope on the CS. and see if we can write spi... and have it go through...

// EXTREME
// having this kind of transparent latching using only cs. means can actually employ different
// spi parameters. eg. clock polarity. etc.


module mymux    (

  input wire [8-1:0] reg_mux,     // inputs are wires. cannot be reg.

  input  cs,
  output adc03_cs,

);

                        // EXTREME this should be when cs changes. eg. we copy value. 
  always @ (cs)     // eg. whenever reg_mux changes we update ... i think.
    begin

      case (reg_mux )
        1 :
        begin
          adc03_cs = cs;
        end

        default  :
        begin
          adc03_cs = 1;   // deassert
        end
      endcase
    end
endmodule


// OK. we only want to latch the value in, on correct clock transition count.




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
  wire [8-1:0] reg_mux;
  wire [8-1:0] reg_led;

  assign {LED1, LED2} = reg_led;

  mylatch #( 16 )   // register bank
  mylatch
    (
    .clk(CLK),
    .cs(CS),
    .special(SPECIAL),
    .d(MOSI),
    .reg_led(reg_led),
    .reg_mux(reg_mux)
  );





  mymux #( )
  mymux
  (
    . reg_mux(reg_mux),
    . cs(CS),
    . adc03_cs(ADC03_CS)
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


