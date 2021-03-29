


module mylatch   #(parameter MSB=16)   (
  input  clk,
  input  cs,
  input  special,
  input  d,   // sdi

  // latched val, rename
  output reg [8-1:0] reg_mux,
  output reg [8-1:0] reg_led,
  output reg [4-1:0] reg_dac
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

  need to put after the sequential block?
    see, http://referencedesigner.com/tutorials/verilog/verilog_32.php
  */

  // need to prevent a peripheral writing mosi. in a different frame .
  // actually don't think it will. will only write mosi. with cs asserted.

  always @ (posedge cs)   // cs done.
  begin

    if(!special)    // only if special asserted

      case (tmp[ MSB-1:8 ])  // high byte for reg, lo byte for val.

        // mux
        8 : reg_mux = tmp[ 8 - 1: 0 ];

        // leds
        // 7 : reg_led = tmp[ 8 - 1: 0 ];
        7 : reg_led = tmp;

        // dac
        9 : reg_dac = tmp;

      endcase


  end
endmodule


// EXTRME
// put adc/dac creset - in its own register. then we can assert/toggle it, without having to do bitshifting  - on mcu.
// eg. t
// actually if we can read a register, then we can do a toggle fairly simply... toggle over spi.


// Ok. put a scope on the CS. and see if we can write spi... and have it go through...

// EXTREME
// having this kind of transparent latching using only cs. means can actually employ different
// spi parameters. eg. clock polarity. etc.


module mymux    (
  input wire [8-1:0] reg_mux,     // inputs are wires. cannot be reg.
  input  cs,                      // wire?
  input  special,
  output [8-1:0] cs_mux
);

  /*
    1 = hi = off.  active lo.

    reg_mux 00001000    cs=0(active),~cs  ==   00000000,   then invert the output
    reg_mux 00001000    cs=1  ==   00001000

    // think it's this.
    ~(reg_mux & ~cs)

    eg.
    reg_mux 00001000    cs=0(active)
        == ~ (11111111 & 00001000)
        == 111101111
  */

  // https://stackoverflow.com/questions/50385144/how-to-expand-a-single-bit-to-multi-bits-depending-on-parameter-in-verilog
  // assign excs = {{(8-1){1'b0}}, cs};    // will this be ready in time????

  // cs_mux <= 1  ; // seems that cs is lo? ....... need to avoid special.

  always @ (cs) // both edges...
    begin

    // as soon as we add this it doesn't work...
    // timing issue?

    // OK. because special is not passed in.

    if(special)    // only if special hi,== deasserted 
      begin
        // cs_mux = ~( reg_mux & ~excs );
        //cs_mux = ~( reg_mux & ~ ({{(8-1){1'b0}}, cs})  );

        // forward to all
        // cs_mux = 1  ;    // dac. only hi.      seems that cs is lo? ....... need to avoid special.
        cs_mux = 1<<1  ; // adc03 only hi
      end
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
  input SPECIAL,
  // output b



  output ADC03_CLK,
  output ADC03_MISO,
  output ADC03_MOSI,
  output ADC03_CS,



  // dac
  output DAC_SPI_CS ,
  output DAC_SPI_CLK,
  output DAC_SPI_SDI,
  output DAC_SPI_SDO,
  output DAC_LDAC,
  output DAC_RST,
  output DAC_UNI_BIP_A,
  output DAC_UNI_BIP_B
);
  // should be able to assign extra stuff here.
  //



  ////////////////////////////////////
  // sayss its empty????
  wire [8-1:0] reg_mux;


  wire [8-1:0] cs_mux ;
  // assign { DAC_SPI_CS, ADC03_CS } = cs_mux;
  assign { ADC03_CS , DAC_SPI_CS } = cs_mux;

  // EXTREME - we haave the order of these things wrong....

  wire [8-1:0] reg_led;
  // assign {LED1, LED2} = reg_led;
  assign {LED1, LED2} = reg_led;    // schematic has these reversed...


  wire [4-1:0] reg_dac;
  // assign {DAC_LDAC, DAC_RST, DAC_UNI_BIP_A, DAC_UNI_BIP_B } = reg_dac;    // can put reset in separate reg, to make easy to toggle.
  assign {DAC_UNI_BIP_B , DAC_UNI_BIP_A, DAC_RST,  DAC_LDAC } = reg_dac;    // can put reset in separate reg, to make easy to toggle.

  mylatch #( 16 )   // register bank
  mylatch
    (
    .clk(CLK),
    .cs(CS),
    .special(SPECIAL),
    .d(MOSI),

    .reg_mux(reg_mux),
    .reg_led(reg_led),
    .reg_dac(reg_dac)
  );


  // assign cs_mux = 1;  // adc03 cs is high.
  // assign cs_mux = 0;  // adc03 cs is lo.

  mymux #( )
  mymux
  (
    . reg_mux(reg_mux),
    . cs(CS),
    . special(SPECIAL),
    . cs_mux(cs_mux)
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


