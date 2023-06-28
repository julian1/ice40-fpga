
// - can have heartbeat timer. over spi.
// - if have more than one dac. then just create another register. very clean.
// - we can actually handle a toggle. if both set and clear bit are hi then toggle
// - instead of !cs or !cs2.  would be good if can write asserted(cs)  asserted(cs2)



`include "my_register_bank02.v"

`default_nettype none







function [4-1:0] update (input [4-1:0] x, input [4-1:0] set, input [4-1:0] clear,);
  begin
    if( clear & set  /*!= 0*/  ) // if both a bit of both set and clear are set, then treat as toggle
      update =  (clear & set )  ^ x ; // xor. to toggle.
    else
      update = ~(  ~(x | set ) | clear);    // clear in priority
  end
endfunction













//
function [8-1:0] setbit( input [8-1:0]  val);
  begin
    setbit = (1 << val ) >> 1;
  end
endfunction


/*

  my_mux_spi_output #( )      // output from POV of the mcu. ie. fpga as slave.
  my_mux_spi_output
  (
    . reg_spi_mux(reg_spi_mux),
    . cs2(SPI_CS2),
    . clk(SPI_CLK),
    . mosi(SPI_MOSI ),
    // . miso(SPI_MISO)                          // WE drive SPI_MISO here.
    . dout(my_dout),                             // default. dout when no spi selected. (eg. register bank.
    // . cs_polarity( 8'b01110000  ),

    . cs_polarity( 8'b00000001  ),  // 4094 strobe should go hi, for output
    . vec_cs(vec_cs),
    . vec_clk(vec_clk),
    . vec_mosi(vec_mosi)
    . vec_miso(vec_miso),
  );

    . dout(my_dout),                              // use when cs active
    . vec_miso(vec_miso),                         // use when cs2 active
    . miso(SPI_MISO)                              // output pin

*/

module my_mux_spi_output    (
  input wire [8-1:0] reg_spi_mux,
  input cs2,
  input clk,
  input mosi,


  input wire [8-1:0]  cs_polarity,
  output wire [8-1:0] vec_cs,
  output wire [8-1:0] vec_clk,
  output wire [8-1:0] vec_mosi,

  ///////
  input dout,                         // use when cs active.  or at least c2 not active
  input wire [8-1:0] vec_miso,        // use when cs2 active
  output wire miso                    // output pin

);

  // setbit() is slow. should remove it.


  // should be assign?
  wire [8-1:0] cs_active = setbit( reg_spi_mux )  & {8 {  ~cs2 } } ;   // cs is active lo.

  assign vec_cs  = ~(cs_active ^ cs_polarity );    // works for active hi strobe 4094.   Think that it works for spi.


  assign vec_clk  = setbit( reg_spi_mux )  & {8 {  clk } } ;   // cs is active lo.
  assign vec_mosi = setbit( reg_spi_mux )  & {8 {  mosi } } ;   // cs is active lo.

  ///////////////

  // cs2 is active lo
  assign miso = cs2 ? dout : (reg_spi_mux & vec_miso) != 0 ;


endmodule


/*

module my_mux_spi_input    (

  // bloody hell. this has to drive MISO using cs also.

  input wire [8-1:0] reg_spi_mux,
  input cs2,
  output wire miso
);

  // this code is combinatory but doesnt'

  // cs2 not asserted, the just use dout. else whatever is asserted....
  assign miso = cs2 ? dout : (reg_spi_mux & vec_miso) != 0 ;

endmodule
*/

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
  input  CLK,

  output MON1,
  output MON2,
  output MON3,
  output MON4,
  output MON5,
  output MON6,
  output MON7,



  // leds
  output LED0,

  // spi
  input  SPI_CLK,
  input  SPI_CS,
  input  SPI_MOSI,
  input  SPI_CS2,
  output SPI_MISO,
  // output b

  output SPI_INTERUPT_OUT,



  //////////////////////////
  // 4094
  output GLB_4094_OE,

  output GLB_4094_CLK,
  output GLB_4094_DATA,
  output GLB_4094_STROBE_CTL,
  output GLB_4094_MISO_CTL,



);



  // Put the strobe as first.
  // monitor isolator/spi,                                                  D4          D3       D2       D1        D0
  // assign { MON7, MON6, MON5, MON4, MON3 , MON2, MON1 /* MON0 */ } = {  SPI_MISO, SPI_MOSI, SPI_CLK,  SPI_CS  /* RAW-CLK */} ;

  // assign { MON7, MON6, MON5, MON4, MON3 , MON2, MON1 /* MON0 */ } = {  GLB_4094_OE  /* RAW-CLK */} ;

  // monitor the 4094 spi                                                 D6       D5             D4            D3              D2              D1                 D0
  // assign { MON7, MON6, MON5, MON4, MON3 , MON2, MON1 /* MON0 */ } = {  SPI_CLK, SPI_CS2, GLB_4094_MISO_CTL, GLB_4094_DATA, GLB_4094_CLK, GLB_4094_STROBE_CTL  /* RAW-CLK */} ;


  // monitor the 4094 spi                                               D4            D3              D2              D1                 D0
  // assign { MON7, MON6, MON5, MON4, MON3 , MON2, MON1 /* MON0 */ } = {  GLB_4094_OE, GLB_4094_DATA, GLB_4094_CLK, GLB_4094_STROBE_CTL  /* RAW-CLK */} ;

  //                                                                       D5           D4        D3        D2       D1        D0
  assign { MON7, MON6, MON5, MON4, MON3 , MON2, MON1 /* MON0 */ } = { GLB_4094_OE,   SPI_MISO, SPI_MOSI, SPI_CLK,  SPI_CS  /* RAW-CLK */} ;

  // ok. this does work.
  // assign SPI_MISO = 1;

  ////////////////////////////////////////
  // spi muxing

  wire [8-1:0] reg_spi_mux ;// = 8'b00000001; // test


  // rather than doing individual assignments. - should just pass in anoter vector whether it's active low.
  // EXTR.  We should use an 8bit mux with 16bit toggle. rather than this complication.


  wire [8-1:0] vec_cs ;
  assign {  GLB_4094_STROBE_CTL  } = vec_cs;

  wire [8-1:0] vec_clk;
  assign { GLB_4094_CLK } = vec_clk ;   // have we changed the clock polarity.

  wire [8-1:0] vec_mosi;
  assign { GLB_4094_DATA } = vec_mosi;

  wire [8-1:0] vec_miso ;
  assign { GLB_4094_MISO_CTL } = vec_miso;



  // dout for fpga spi.
  // need to rename. it's an internal dout... that can be muxed out.
  wire my_dout ;

  /*
    we must pass cs as well.j
  */

/*
  // miso muxer.
  my_mux_spi_input #( )
  my_mux_spi_input
  (
    . reg_spi_mux(reg_spi_mux),
    . cs2(SPI_CS2),
  );
*/

  // when device is 0.

  my_mux_spi_output #( )      // output from POV of the mcu. ie. fpga as slave.
  my_mux_spi_output
  (
    . reg_spi_mux(reg_spi_mux),
    . cs2(SPI_CS2),
    . clk(SPI_CLK),
    . mosi(SPI_MOSI ),
    // . cs_polarity( 8'b01110000  ),

    . cs_polarity( 8'b00000001  ),  // 4094 strobe should go hi, for output
    . vec_cs(vec_cs),
    . vec_clk(vec_clk),
    . vec_mosi(vec_mosi),

    ////////////////

    . dout(my_dout),                              // use when cs active
    . vec_miso(vec_miso),                         // use when cs2 active
    . miso(SPI_MISO)                              // output pin
  );

/*
  input wire [8-1:0] reg_spi_mux,
  input cs2,
  input clk,
  input mosi,


  input wire [8-1:0]  cs_polarity,
  output wire [8-1:0] vec_cs,
  output wire [8-1:0] vec_clk,
  output wire [8-1:0] vec_mosi,

  // input wire [8-1:0] vec_miso
  // output wire [8-1:0] vec_miso

  ///////
  input dout,
  input wire [8-1:0] vec_miso,
  output wire miso
*/


  ////////////////////////////////////////
  // register

  // wire = no state preserved between clocks.

  // TODO change prefix to w_

  wire [4-1:0] reg_led;
  assign {  LED0 } = reg_led;

  wire [4-1:0] reg_4094;
  assign { GLB_4094_OE } = reg_4094;



  reg [ 12 - 1: 0 ] reg_array[ 32 - 1 : 0 ] ;    // 12x   32 bit registers

  my_register_bank02 // #( 32 )   // register bank  . change name 'registers'
  my_register_bank02
    (
    . clk(SPI_CLK),
    . cs(SPI_CS),
    . din(SPI_MOSI),
    . dout( my_dout ),      // writes to my_dout

    . reg_led(reg_led),
    . reg_spi_mux(reg_spi_mux),
    . reg_4094(reg_4094 )// ,

    // . reg_array( reg_array )
  );



/*

  blinker #(  )
  blinker
    (
    .clk(XTALCLK),
    .reg_vec( reg_led )

  );

*/



endmodule




