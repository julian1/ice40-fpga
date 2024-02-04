
// change name top.v

// - can have heartbeat timer. over spi.
// - if have more than one dac. then just create another register. very clean.
// - we can actually handle a toggle. if both set and clear bit are hi then toggle
// - instead of !cs or !cs2.  would be good if can write asserted(cs)  asserted(cs2)



`include "register_set.v"
`include "mux_spi.v"

`include "mux_assign.v"



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


  input  SPI_CS2,


  // leds
  output reg [ 4-1: 0 ] o_leds,    // 4 bits
/*
  output LED0,
  output LED1,
  output LED2,
  output LED3,
*/


/*
  // monitor - outputs
  output MON0,
  output MON1,
  output MON2,
  output MON3,
  output MON4,
  output MON5,
  output MON6,
  output MON7,


  // hardware flags - inputs
  input HW0,
  input HW1,
  input HW2,
*/


  // 4094
  output GLB_4094_DATA,
  output GLB_4094_CLK,
  output _4094_OE_CTL,
  output GLB_4094_STROBE_CTL,



  input U1004_4094_DATA



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

  wire [8-1:0] vec_cs ;
  assign {  GLB_4094_STROBE_CTL  } = vec_cs;

  wire [8-1:0] vec_clk;
  assign { GLB_4094_CLK } = vec_clk ;   // have we changed the clock polarity.

  wire [8-1:0] vec_mosi;
  assign { GLB_4094_DATA } = vec_mosi;

  wire [8-1:0] vec_miso ;
  assign  vec_miso[ 8-1 : 1] = 7'b0;

  assign { U1004_4094_DATA } = vec_miso;

  // a wire. since it is only used combinatorially .
  wire w_dout ;

  mux_spi #( )
  mux_spi
  (
    . reg_spi_mux(reg_spi_mux[ 8-1 : 0 ] ),
    . cs( SPI_CS2),
    . clk( SCK /* SPI_CLK */),
    . mosi(SDI /* SPI_MOSI */ ),

    //////
    . cs_polarity( 8'b00000001  ),  // 4094 strobe should go hi, for output
    // . cs_polarity( 8'b01110000  ),
    . vec_cs(vec_cs),
    . vec_clk(vec_clk),
    . vec_mosi(vec_mosi),

    ////////////////

    . dout(w_dout),                              // use when cs active
    . vec_miso(vec_miso),                         // use when cs2 active
    . miso( SDO /* SPI_MISO */)                              // output pin
  );
  ///////////////////////




  /////////////////////////////////////////////
  // 4094 OE
  wire [32-1:0] reg_4094;   // TODO rename
  assign { _4094_OE_CTL } = reg_4094;    //  lo. start up not enabled.
  // wire _4094_OE_CTL = 0;  // lo.



  ////////////////////////////////////////



  wire [32-1:0] reg_direct;




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


  // readable inputs
  wire [32 - 1 :0] reg_status ;

  assign reg_status = {

    32'b0
/*
    8'b0 ,
    monitor,                          // add a count, as a transactional read lock.

    HW2,  HW1,  HW0,
    reg_sa_arm_trigger[0],            // ease having to do a separate register read, to retrieve state.
    sample_acquisition_az_status_out, // 3 bits
    adc2_measure_valid,

    // HW2,  HW1,  HW0 ,   4'b0,  outputs_vec[ `IDX_SPI_INTERRUPT_CTL ] ,

    3'b0,
    SWITCH_SENSE_OUT, DCV_OVP_OUT, OHMS_OVP_OUT, SUPPLY_SENSE_OUT, UNUSED_2
*/
 };


  // verilog literals are hard!.
  // 4'b1                         == 0001
  // { 1,1,1,1}                   == 0001
  // { 1'b1, 1'b1, 1'b1, 1'b1 }   == 1111
  // 4 { 1'b1 }                   == 1111
  // 4'b1111                      == 1111

  wire [32-1 :0] reg_mode;     // _mode or AF reg_af alternate function  two bits


  reg [28-1:0] output_dummy ;


  mux_8to1_assign #( 32  )
  mux_8to1_assign_1  (


    .a( { 28'b0,  reg_direct[ 3: 0] }  ),        // mode/AF 0     default, follow reg_direct, for led.
    .b( { 28'b0,  reg_direct[ 0], reg_direct[ 1], reg_direct[ 2], reg_direct[ 3]    }  ),        // this works to reverse
    // .b( { 32'b0   }  ),                       // mode/AF  1
    .c(  {  { 28'b0   }, { 4 { 1'b1}}  }     ),      // mode/AF  2   only sigle led is on????
    .d( { 28'b0,  { 1, 1, 1, 1 }  }  ),        // mode/AF 3     { 1,1,1,1 } == 0b0001, not 4b1111
    .e( { 28'b0,  { 1'b1, 1'b1, 1'b1, 1'b1 }  }  ),        // mode/AF 4
    .f( 32'b0   ),                       // mode/AF  5
    .g( 32'b0   ),                       // mode/AF  6
    .h( { 32 { 1'b1 } }   ),                       // mode/AF  7

/*

    .a( { 1'b0, { 15 { 1'b0 } },  reg_led[ 0], { 13 { 1'b0 } } }    ),        // 0. default mode. 0 on all outputs, except follow reg_led, for led.
    .b( { 1'b0, { `NUM_BITS { 1'b1 } } } ),             // 1.
    .c( { 1'b0, test_pattern_out } ),                   // 2
    .d( { 1'b0, reg_direct[ `NUM_BITS - 1 :  0 ]  } ), // 3.    // direct mode. register control.
    .e( { 1'b0, sample_acquisition_pc_out} ),                   // 4
    .f( { sample_acquisition_az_adc2_measure_trig,    sample_acquisition_az_out } ),                   // 5
    .g( { sample_acquisition_no_az_adc2_measure_trig, sample_acquisition_no_az_out } ),                // 6
    // .h( { 1'b0, { `NUM_BITS { 1'b1 } } } ),             // 7
    .h( { 1'b0, sa_no_az_test_out } ),             // 7

*/

    .sel( reg_mode[ 3-1 : 0 ]),
    .out( { output_dummy,  o_leds  }  )

  );





  register_set // #( 32 )
  register_set
    (

    // should prefix fields with spi_
    . clk(   SCK ),
    . cs(  SS /*SPI_CS */ ),
    . din(   SDI /*SPI_MOSI */),
    . dout( w_dout ),            // drive miso from via muxer
    // . dout( SDO /* SPI_MISO */ ),        // drive miso output pin directly.


    // outputs
    . reg_spi_mux(reg_spi_mux),
    . reg_4094(reg_4094 ) ,

    . reg_mode(reg_mode),
    . reg_direct(reg_direct),



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


