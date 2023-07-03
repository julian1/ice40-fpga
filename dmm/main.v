
// change name top.v

// - can have heartbeat timer. over spi.
// - if have more than one dac. then just create another register. very clean.
// - we can actually handle a toggle. if both set and clear bit are hi then toggle
// - instead of !cs or !cs2.  would be good if can write asserted(cs)  asserted(cs2)



`include "register_set.v"
`include "mux_spi.v"
`include "blinker.v"
`include "modulation_az.v"





/*
  TODO
  module myreset a soft reset module...
  that decodes an spi command/address/value, and resets all lines.

  need to think how to handle peripheral reset.
*/








`default_nettype none


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
  output _4094_OE_CTL,

  output GLB_4094_CLK,
  output GLB_4094_DATA,
  output GLB_4094_STROBE_CTL,
  input GLB_4094_MISO_CTL,   // this is unused. but it's an input


  output SIG_PC_SW_CTL,

  output U413_A0_CTL,
  output U413_A1_CTL,
  output U413_A2_CTL,

  output U402_A0_CTL,
  output U402_A1_CTL,
  output U402_A2_CTL,

  output U414_A0_CTL,
  output U414_A1_CTL,
  output U414_A2_CTL,

);


  reg dummy;

  // Put the strobe as first.
  // monitor isolator/spi,                                                  D4          D3       D2       D1        D0
  // assign { MON7, MON6, MON5, MON4, MON3 , MON2, MON1 /* MON0 */ } = {  SPI_MISO, SPI_MOSI, SPI_CLK,  SPI_CS  /* RAW-CLK */} ;

//  assign { MON7, MON6, /*MON5,*/ MON4, MON3 , MON2, MON1 /* MON0 */ } = {  SPI_MISO, SPI_MOSI, SPI_CLK,  SPI_CS  /* RAW-CLK */} ;

  // assign { MON7, MON6, MON5, MON4, MON3 , MON2, MON1 /* MON0 */ } = {  _4094_OE_CTL  /* RAW-CLK */} ;

  // monitor the 4094 spi                                                 D6       D5             D4            D3              D2              D1                 D0
  // assign { MON7, MON6, MON5, MON4, MON3 , MON2, MON1 /* MON0 */ } = {  SPI_CLK, SPI_CS2, GLB_4094_MISO_CTL, GLB_4094_DATA, GLB_4094_CLK, GLB_4094_STROBE_CTL  /* RAW-CLK */} ;


  // monitor the 4094 spi                                               D4            D3              D2              D1                 D0
  // assign { MON7, MON6, MON5, MON4, MON3 , MON2, MON1 /* MON0 */ } = {  _4094_OE_CTL, GLB_4094_DATA, GLB_4094_CLK, GLB_4094_STROBE_CTL  /* RAW-CLK */} ;

  //                                                                       D5           D4        D3        D2       D1        D0
  // assign { MON7, MON6, MON5, MON4, MON3 , MON2, MON1 /* MON0 */ } = { _4094_OE_CTL,   SPI_MISO, SPI_MOSI, SPI_CLK,  SPI_CS  /* RAW-CLK */} ;
  // assign { MON7, MON6, MON5, MON4, MON3 , MON2, MON1 /* MON0 */ } = 0  ;

  // ok. this does work.
  // assign SPI_MISO = 1;

  ////////////////////////////////////////
  // spi muxing

  wire [24-1:0] reg_spi_mux ;// = 8'b00000001; // test


  // rather than doing individual assignments. - should just pass in anoter vector whether it's active low.
  // EXTR.  We should use an 8bit mux with 16bit toggle. rather than this complication.


  wire [8-1:0] vec_cs ;
  assign {  GLB_4094_STROBE_CTL  } = vec_cs;

  wire [8-1:0] vec_clk;
  assign { GLB_4094_CLK } = vec_clk ;   // have we changed the clock polarity.

  wire [8-1:0] vec_mosi;
  assign { GLB_4094_DATA } = vec_mosi;

  wire [8-1:0] vec_miso ;
  assign { GLB_4094_MISO_CTL } = vec_miso;    // this isn't right ... it is spi_miso?//


  // jeezus.

  // dout for fpga spi.
  // need to rename. it's an internal dout... that can be muxed out.
 //  wire my_dout ;
  reg my_dout ; // should be a register, since it's written to.



  mux_spi #( )      // output from POV of the mcu. ie. fpga as slave.
  mux_spi
  (
    . reg_spi_mux(reg_spi_mux),
    . cs2(SPI_CS2),
    . clk(SPI_CLK),
    . mosi(SPI_MOSI ),
    // . cs_polarity( 8'b01110000  ),

    //////
    . cs_polarity( 8'b00000001  ),  // 4094 strobe should go hi, for output
    . vec_cs(vec_cs),
    . vec_clk(vec_clk),
    . vec_mosi(vec_mosi),

    ////////////////

    . dout(my_dout),                              // use when cs active
    . vec_miso(vec_miso),                         // use when cs2 active
    . miso(SPI_MISO)                              // output pin
  );


  ////////////////////////////////////////
  // register

  // wire = no state preserved between clocks.

  // TODO change prefix to w_

  wire [24-1:0] reg_led;
  // assign {  LED0 } = reg_led;

  wire [24-1:0] reg_4094;
  // assign { _4094_OE_CTL } = reg_4094;



  register_set // #( 32 )   // register bank  . change name 'registers'
  register_set
    (
    . clk(SPI_CLK),
    . cs(SPI_CS),
    . din(SPI_MOSI),
    . dout( my_dout ),            // drive miso from via muxer
    // . dout( SPI_MISO ),        // drive miso output pin directly.

    // registers
    . reg_led(reg_led),
    . reg_spi_mux(reg_spi_mux),
    . reg_4094(reg_4094 )// ,

  );


  reg [3:0] vec_dummy;

  blinker #(  )
  blinker
    (
    .clk( CLK ),
    // .vec_leds( { MON7, MON6, MON5, MON4, MON3 , MON2, MON1, dummy  } )
    .vec_leds( { LED0, vec_dummy } )
  );



  /////////////////////
  assign { _4094_OE_CTL } = 1;    //  on for test.



  // mux_hi  does not need to gokkkkkkkkkkkk
  reg [6-1:0 ] mux_hi /*= `MUX_HI_DCV_IN */;
  assign  {   U402_A2_CTL, U402_A1_CTL, U402_A0_CTL, U413_A2_CTL, U413_A1_CTL, U413_A0_CTL } = mux_hi;

  // need some defines for


  // az
  wire [3-1: 0] mux_az ;
  assign { U414_A2_CTL, U414_A1_CTL, U414_A0_CTL } = mux_az;



  /////////

  reg [7-1:0] mode;


  // az mux does not need ot know about mux_hi
  modulation_az
  modulation_az
    (
    .clk( CLK),
    .reset( 0),
    // .mode( 1),
    .mode( mode ),
    .sw_pc_ctl( SIG_PC_SW_CTL),
    .mux_az (mux_az),
    .vec_monitor( { MON7, MON6, MON5, MON4, MON3 , MON2, MON1, dummy  } )
  );


  modulation_az_tester
  modulation_az_tester (
    .clk(CLK),
    .reset( 0),
    .mux_hi(mux_hi),
    .mode(mode)
    // want to pass in some stuff here. i think.
  );



endmodule




/*
  // mux hi
  reg [3-1: 0] u413 = 3'b110; // s7 == DCV-IN
  assign { U413_A2_CTL, U413_A1_CTL, U413_A0_CTL } = u413;    //  turn on DCV. 7 - 1?   on for test.  nice. measures 125R.

  // mux hi 2.
  reg [3-1: 0] u402 = 3 - 1 ; // s3 == unconnected/ hi-z input == off.
  assign { U402_A2_CTL, U402_A1_CTL, U402_A0_CTL } = u402;
*/


