
// change name top.v

// - can have heartbeat timer. over spi.
// - if have more than one dac. then just create another register. very clean.
// - we can actually handle a toggle. if both set and clear bit are hi then toggle
// - instead of !cs or !cs2.  would be good if can write asserted(cs)  asserted(cs2)



`include "register_set.v"




`default_nettype none








module top (

  // these are all treated as wires.

  // input  CLK,


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



  // leds
  output LED0,
  output LED1,
  output LED2,

  // monitor
  output MON0,
  output MON1,
  output MON2,
  output MON3,
  output MON4,
  output MON5,
  output MON6,
  output MON7,


  // hardware flags
  input HW0,
  input HW1,
  input HW2,





/*


  //
  // inputs

  // spi
  input  SPI_CLK,
  input  SPI_CS,
  input  SPI_MOSI,
  input  SPI_CS2,
  output SPI_MISO,
  // output b

  input U1004_4094_DATA,
  input LINE_SENSE_OUT,
  input SWITCH_SENSE_OUT,
  input DCV_OVP_OUT,
  input OHMS_OVP_OUT,
  input SUPPLY_SENSE_OUT,
  input UNUSED_2,                    // change name UNUSED_2_OUT

  // input  U1004_4094_DATA,   // this is unused. but it's an input



  // or OUT_P and OUT_N ?
  input CMPR_P_OUT,
  input CMPR_N_OUT,



  //////////////////////////
  // outputs

  // 4094
  output _4094_OE_CTL,

  output GLB_4094_CLK,
  output GLB_4094_DATA,
  output GLB_4094_STROBE_CTL,


  // azmux
  output U414_A0_CTL,
  output U414_A1_CTL,
  output U414_A2_CTL,
  output U414_EN_CTL,

  // himux
  output U413_A0_CTL,
  output U413_A1_CTL,
  output U413_A2_CTL,
  output U413_EN_CTL,

  // himux 2.
  output U402_A0_CTL,
  output U402_A1_CTL,
  output U402_A2_CTL,
  output U402_EN_CTL,

  // pre-charge
  output SIG_PC_SW_CTL,


  //
  output SPI_INTERRUPT_CTL,    // should be modeal. eg. same as meas complete

  output MEAS_COMPLETE_CTL,

  //  adc current switches
  output U902_SW0_CTL,
  output U902_SW1_CTL,
  output U902_SW2_CTL,
  output U902_SW3_CTL,
  output CMPR_LATCH_CTL,

  ////////////
*/

);



  ////////////////////////////////////////
  // spi muxing

  wire [32-1:0] reg_spi_mux ;// = 8'b00000001; // test




  wire [32-1:0] reg_led;

  assign { LED2, LED1, LED0 } = reg_led[ 3-1: 0 ] ;


  // readable inputs
  wire [32 - 1 :0] reg_status ;


/*
  wire [32-1:0] reg_4094;   // TODO remove

  assign { _4094_OE_CTL } = reg_4094;    //  lo. start up not enabled.
  // assign { _4094_OE_CTL } = 1;    //  on for test.  should defer to mcu control. after check supplies.

  wire [32-1 :0] reg_mode;     // two bits
  wire [32-1 :0] reg_direct;
  wire [32-1 :0] reg_direct2;
  wire [32-1 :0] reg_reset;

  wire [32-1 :0] reg_sa_arm_trigger;              // only a bit is needed here. should be able to handle more efficiently.
  wire [32-1 :0] reg_sa_p_clk_count_precharge;


  wire [32-1 :0] reg_adc_p_aperture;  // 32/31 bit nice. for long sample.
  wire [32-1 :0] reg_adc_p_clk_count_reset;

*/



  register_set // #( 32 )
  register_set
    (

    // should prefix fields with spi_
    . clk(   SCK ),
    . cs(  SS /*SPI_CS */ ),
    . din(   SDI /*SPI_MOSI */),
    // . dout( w_dout ),            // drive miso from via muxer
    . dout( SDO /* SPI_MISO */ ),        // drive miso output pin directly.



    // outputs
    . reg_led(reg_led),        // required as test register

      // inputs
    . reg_status( reg_status ),


/*
    . reg_spi_mux(reg_spi_mux),
    . reg_4094(reg_4094 ) ,
    . reg_mode( reg_mode ),      // ok.
    . reg_direct( reg_direct ),
    . reg_direct2( reg_direct2 ),
    . reg_reset( reg_reset),
*/

/*
    // outputs signal acquisiation
    .reg_sa_arm_trigger ( reg_sa_arm_trigger ),
    .reg_sa_p_clk_count_precharge( reg_sa_p_clk_count_precharge),


    .reg_adc_p_aperture( reg_adc_p_aperture),
    .reg_adc_p_clk_count_reset(reg_adc_p_clk_count_reset ),

    // outputs adc
    .reg_adc_clk_count_refmux_reset({{ 8 { 1'b0 } }, adc2_clk_count_refmux_reset_last }  ) ,
    .reg_adc_clk_count_refmux_neg(  adc2_clk_count_refmux_neg_last   ) ,
    .reg_adc_clk_count_refmux_pos(  adc2_clk_count_refmux_pos_last  ) ,
    .reg_adc_clk_count_refmux_rd(  { {8{ 1'b0 }}, adc2_clk_count_refmux_rd_last }  ),
    .reg_adc_clk_count_mux_sig(                   adc2_clk_count_mux_sig_last   ),

    // adc stats
    .reg_adc_stat_count_refmux_pos_up( { {8{ 1'b0 }},adc2_stat_count_refmux_pos_up_last } ),
    .reg_adc_stat_count_refmux_neg_up( { {8{ 1'b0 }},adc2_stat_count_refmux_neg_up_last }),
    .reg_adc_stat_count_cmpr_cross_up(  { {8{ 1'b0 }},adc2_stat_count_cmpr_cross_up_last} )
*/
  );



endmodule


