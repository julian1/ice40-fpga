
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


/*
  rather than having register bank.
  have one 'special' mux register.

  and then have the register bank be it's own spi peripheral.
  that should make reading simpler.
  eg. the special only controls mux.
*/

/*
  CS - must be in clk domain. because it can be de/asserted without spi clk. and
  we want to do stuff in response.
*/
module my_register_bank   #(parameter MSB=16)   (
  input  clk,
  input  cs,
  input  special,
  input  din,       // sdi
  output dout,   // sdo

  // latched val, rename
  output reg [8-1:0] reg_mux,
  output reg [8-1:0] reg_led,
  output reg [3-1:0] reg_dac,
  output reg  reg_dac_rst
);


  reg [MSB-1:0] tmp;
  reg [MSB-1:0] ret  ;    // padding bit
  reg [8-1:0]   count;


  // 

  // clock value into tmp var
  always @ (negedge clk or posedge cs)
  begin
    if(cs)          // cs not asserted
      begin
        count = 0;

        // dropping of the highest bit maybe cannot avoid...
        // because it is the first bit.

        // no. 255 is wrong. it overclocks it

        // ret = 16'b1111110111011010 ;
        // ret = 255 ;
        ret = 255 << 8;
        //ret = 0;
        //ret = 0;

        // highest bit looks problematic...
        // ret = 65535 ;
      end
    else
    if ( !special)  // cs asserted, and cspecial asserted.
      begin

        // d into lsb, shift left toward msb
        tmp = {tmp[MSB-2:0], din};

        /*
        // appears to work. actually we could return the address...
        if(count == 0)
          ret = 255 << 7;
        // have the address, so can start sending current value back...
        if(count == 7)
          ret = 255 << 7;
        */
          // return value
        dout = ret[MSB-2];    // OK. doing this gets our high bit. but loses the last bit... because its delayed??
        ret = ret << 1; // this *is* zero fill operator.

        count = count + 1;

      end
  end


  always @ (posedge cs)   // cs done.
  begin
    // we can assert a done flag here... and factor this code...
    if(/*cs &&*/ !special && count == 16 )
      begin
        case (tmp[ MSB-1:8 ])  // high byte for reg/address, lo byte for val.

          // mux
          8 : reg_mux = tmp;

          // leds
          7 : 
            begin
              reg_led = tmp;
              // reg_dac_rst = tmp;  // useful way to check a value . this works??? to toggle reset.
            end

          // dac
          9  : reg_dac = tmp;
          10 : reg_dac_rst = tmp;

        endcase
      end
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
  input special,
  input dout,
  input wire [8-1:0] miso_vec,
  output miso
);

 always @ (miso_vec)

// #FIXME change to blocking.
    // if special is asserted just mux dout.
    if(!special)
      miso = dout;
    // else use the vector
    else
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


  // need to rename. it's an internal dout... that can be muxed out.
  reg dout ;


  my_miso_mux #( )
  my_miso_mux
  (
    . reg_mux(reg_mux),
    . special(SPECIAL),
    . dout(dout),
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

  // wire = no state preserved between clocks.

  wire [8-1:0] reg_led;
  assign {LED1, LED2} = reg_led;    // schematic has these reversed...

  wire [3-1:0] reg_dac;
  assign {DAC_UNI_BIP_B , DAC_UNI_BIP_A,  DAC_LDAC } = reg_dac;

  wire reg_dac_rst;
  // assign DAC_RST = 1;//assigning manually pulls it high.
  assign DAC_RST = reg_dac_rst;


  // can/should put reset in separate reg, to make easy to toggle.


  my_register_bank #( 16 )   // register bank
  my_register_bank
    (
    .clk(CLK),
    .cs(CS),
    .special(SPECIAL),
    .din(MOSI),
    .dout( dout  ),
    .reg_mux(reg_mux),
    .reg_led(reg_led),
    .reg_dac(reg_dac),
    .reg_dac_rst(reg_dac_rst)
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


