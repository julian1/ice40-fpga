
/*
  - can have heartbeat timer. over spi.
      but don't want to spew spi tranmsission emi during acquisition.

  - if have more than one dac. then just create another register. very clean.
   - perhaps instead of !cs or !cs2.  could write macro  or asserted_n(cs ) etc
*/



/*
`include "../../common/mux_assign.v"
`include "../../common/test_pattern.v"
`include "../../common/timed_latch.v"

*/
`include "register_set.v"

/*
`include "adc-mock.v"
`include "refmux-test.v"

`include "adc_modulation_05.v"
`include "sequence_acquisition.v"

*/
`default_nettype none



module top (


  ////////////////////////
  // spi

  /*#A dual-function, serial output pin in both configuration modes.
  #iCE40 LM devices have this pin shared with hardened SPI IP
  #SPI_MISO pin. */
  output SDO,

  /*# A dual-function, serial input pin in both configuration modes.
  # iCE40 LM devices have this pin shared with hardened SPI IP
  # SPI_MOSI pin. */
  input SDI,

  /*#A dual-function clock signal. An output in Master mode and
  #input in Slave mode. iCE40 LM devices have this pin shared with
  # hardened SPI IP SPI_SCK pin.*/
  input SCK,

  /*#An important dual-function, active-low slave select pin. After
  #the device exits POR or CRESET_B is toggled (High-Low-High), it
  #samples the SPI_SS to select the configuration mode (an output
  #in Master mode and an input in Slave mode). iCE40 LM devices
  #have this pin shared with hardened SPI IP SPI1_CSN pin.*/
  input SS,


  // input  SPI_CS2,


  ///////////
  output [ 4-1: 0 ] leds_o


);



  // wire SDO = 1;

  register_set // #( 32 )
  register_set
    (

    // should prefix fields with spi_
    . clk(   SCK ),
    . cs_n(  SS /*SPI_CS */ ),        // rename cs_n
    . din(   SDI /*SPI_MOSI */),

    . dout( SDO /*miso*/ ),


    // outputs
    // . reg_spi_mux(reg_spi_mux),

    . reg_direct( leds_o ),

  );



endmodule


