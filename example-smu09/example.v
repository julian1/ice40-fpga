
module blinker    (
  input clk,
  output led1,
  output led2

);

  localparam BITS = 5;
  // localparam LOG2DELAY = 21;
  localparam LOG2DELAY = 20;

  reg [BITS+LOG2DELAY-1:0] counter = 0;
  reg [BITS-1:0] outcnt;

  always@(posedge clk) begin
    counter <= counter + 1;
    outcnt <= counter >> LOG2DELAY;
  end

  // assign { led1, led2, LED3, LED4, LED5 } = outcnt ^ (outcnt >> 1);
  assign {  led1, led2 } = outcnt ^ (outcnt >> 1);
endmodule





module my_register_bank   #(parameter MSB=16)   (
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

  // clock value into tmp var
  always @ (negedge clk)
  begin
    if (!cs && !special)         // chip select asserted, and cspecial asserted.
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

    if(!special)    // only if special also asserted

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

/*
    miso must be high-Z. if a peripheral does not have CS asserted.
    otherwise there will be contention if several peripherals try to manipulate.
    in which case we will need a mux vector.
    -------------

    we are going to have to do it anyway....  because its not a wire...

    hang on. are we getting the clk propagating? kind of need to test.
*/



module my_cs_mux    (
  input wire [8-1:0] reg_mux,
  input  cs,
  input special,
  output [8-1:0] cs_vec
);

  // GAHHH. NO. if special is asserted. then we don't want cs being muxed to a peripheral...
  // and that peripheral picking up spurious writes

  always @ (cs) // both edges...

    if(special)   // special = high = not asserted
      if(cs)
        cs_vec = ~( reg_mux & 8'b00000000 );
      else
        cs_vec = ~( reg_mux & 8'b11111111 );
    else
        cs_vec = 8'b11111111;

endmodule




module my_miso_mux    (
  input wire [8-1:0] reg_mux,
  input wire [8-1:0] miso_vec,
  output miso
);

 always @ (miso_vec)

    // miso = (reg_mux & miso_vec) > 0 ;   // any bit. seems to work, while != 0 doesn't.
    miso = (reg_mux & miso_vec) != 0 ;   // hmmm seems ok.

endmodule


/*
  Hmmm. with separate cs lines. 
  remember that mcu only has one nss/cs.
    so even if had separate cs line for each peripheral we would need to toggle.
    but could be simpler than writing a register.
*/

/*
  TODO
  module myreset a soft reset module...
  that decodes an spi command/address/value, and resets all lines.

  need to think how to handle peripheral reset.
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
  input SPECIAL,
  output MISO,
  // output b


  // adc 03
  output ADC03_CLK,
  input ADC03_MISO,    // input
  output ADC03_MOSI,
  output ADC03_CS,


  // dac
  output DAC_SPI_CS ,
  output DAC_SPI_CLK,
  output DAC_SPI_SDI,
  input DAC_SPI_SDO,   // input

  output DAC_LDAC,
  output DAC_RST,
  output DAC_UNI_BIP_A,
  output DAC_UNI_BIP_B,

  // flash
  output FLASH_CS,
  output FLASH_CLK,
  output FLASH_MOSI ,
  input FLASH_MISO   // input


);

/*

  ////////////////////////////////////


  //////////////////////////////////////////

  wire [8-1:0] reg_led;
  // assign {LED2, LED1} = reg_led;
  assign {LED1, LED2} = reg_led;    // schematic has these reversed...


  wire [4-1:0] reg_dac;
  assign {DAC_UNI_BIP_B , DAC_UNI_BIP_A, DAC_RST,  DAC_LDAC } = reg_dac;    // can put reset in separate reg, to make easy to toggle.
*/

  ////////////////////////////////////////
  // spi muxing

  wire [8-1:0] reg_mux ;// = 8'b00000001; // test


  wire [8-1:0] cs_vec ;
  assign { FLASH_CS,  DAC_SPI_CS, ADC03_CS } = cs_vec;


  wire [8-1:0] miso_vec ;
  assign { FLASH_MISO,  DAC_SPI_SDO,  ADC03_MISO } = miso_vec;


  // pass-through adc03.
  assign ADC03_CLK = CLK;
  assign ADC03_MOSI = MOSI;

  // pass-through flash
  assign FLASH_CLK = CLK;
  assign FLASH_MOSI = MOSI;


  my_miso_mux #( )
  my_miso_mux
  (
    . reg_mux(reg_mux),
    . miso_vec(miso_vec),
    . miso(MISO)
  );


  my_cs_mux #( )
  my_cs_mux
  (
    . reg_mux(reg_mux),
    . cs(CS),
    . special(SPECIAL),
    . cs_vec(cs_vec)
  );


  ////////////////////////////////////////
  // register


  wire [8-1:0] reg_led;
  assign {LED1, LED2} = reg_led;    // schematic has these reversed...

  wire [4-1:0] reg_dac;
  assign {DAC_UNI_BIP_B , DAC_UNI_BIP_A, DAC_RST,  DAC_LDAC } = reg_dac;    
  // can/should put reset in separate reg, to make easy to toggle.


  my_register_bank #( 16 )   // register bank
  my_register_bank
    (
    .clk(CLK),
    .cs(CS),
    .special(SPECIAL),
    .d(MOSI),
    .reg_mux(reg_mux),
    .reg_led(reg_led),
    .reg_dac(reg_dac)
  );



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


