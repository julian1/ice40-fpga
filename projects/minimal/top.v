
/*
  - can have heartbeat timer. over spi.
      but don't want to spew spi tranmsission during acquisition.

  - if have more than one dac. then just create another register. very clean.
   - perhaps instead of !cs or !cs2.  could write macro  or asserted_n(cs ) etc
*/



// `include "../../common/mux_spi.v"
`include "../../common/mux_assign.v"
`include "../../common/test_pattern.v"
`include "../../common/timed_latch.v"

`include "register_set.v"
`include "sample_acquisition_pc.v"

`include "sample_acquisition_az.v"

`include "adc-test.v"


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


  output [ 4-1: 0 ] leds_o,

  output [ 8-1: 0]  monitor_o,

  input [4-1: 0]    hw_flags_i,



  input  CLK,




  // 4094
  output GLB_SPI_MOSI,
  output GLB_SPI_CLK,
  output GLB_4094_OE_CTL,
  output GLB_4094_STROBE_CTL,

  output SPI_DAC_SS,

  input U1004_4094_DATA,



  output spi_interrupt_ctl_o,

  output meas_complete_o,


  // output sig_pc1_sw_o,
  // output sig_pc2_sw_o ,

  output [ 2-1: 0 ] sig_pc_sw_o,

  // az mux
  // u410
  output [ 4-1: 0 ] azmux_o,


  // adc comparator latch ctl.
  // should be cmpr_latch_ctl
  output adc_cmpr_latch_o,

  // U902. adc ref current mux
  output [ 4-1: 0 ] adc_refmux_o,

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

  /*
    TODO. rather than pulling all these out in vectors.
          we should combine in line/place. the same way we do mux align.
          eg.

      . vec_cs(  {  dummy,  GLB_4094_STROBE_CTL  }   ),
      ote. we are already doing this for polarity
  */

  wire [32-1:0] reg_spi_mux ;// = 8'b00000001; // test

  assign GLB_SPI_CLK          = reg_spi_mux == 8'b0 ? 1 : SCK;      // park hi

  assign GLB_SPI_MOSI         = reg_spi_mux == 8'b0 ? 1 : SDI;      // park hi

  assign GLB_4094_STROBE_CTL  = reg_spi_mux == 8'b01 ?  (~ SPI_CS2)  : 0;     // active hi

  assign SPI_DAC_SS           = reg_spi_mux == 8'b10 ?  SPI_CS2 : 1;     // active lo


  wire w_dout ;

  assign w_dout = SDO;




/*
  // would be nice perhaps to have these controlled in mode0.

  assign monitor_o[0]  = GLB_SPI_CLK;
  assign monitor_o[1]  = GLB_SPI_MOSI;
  assign monitor_o[2]  = SPI_DAC_SS     ;
*/




  /////////////////////////////////////////////
  // 4094 OE
  wire [32-1:0] reg_4094;   // TODO rename
  assign { GLB_4094_OE_CTL } = reg_4094;    //  lo. start up not enabled.

  ////////////////////////////////////////



  wire [32-1:0] reg_direct;

  wire [32-1 :0] reg_sa_arm_trigger;              // only a single bit is needed here. should be able to write to handle more efficiently.



/*
  wire [32-1:0] reg_4094;   // TODO remove

  assign { GLB_4094_OE_CTL } = reg_4094;    //  lo. start up not enabled.
  // assign { GLB_4094_OE_CTL } = 1;    //  on for test.  should defer to mcu control. after check supplies.

  wire [32-1 :0] reg_mode;     // two bits
  wire [32-1 :0] reg_direct;
  wire [32-1 :0] reg_direct2;
  wire [32-1 :0] reg_reset;

  wire [32-1 :0] reg_sa_p_clk_count_precharge_i;


  wire [32-1 :0] reg_adc_p_aperture;  // 32/31 bit nice. for long sample.
  wire [32-1 :0] reg_adc_p_clk_count_reset;

*/


  // readable inputs
  wire [32 - 1 :0] reg_status ;

  assign reg_status = {



    21'b0,

    hw_flags_i,

    { 8'b10101010 }  // magic
/*
    8'b0 ,
    monitor,                          // don't see having the monitor readable through a different register is useful.   a git commit or crc would be useful.
                                      // add a count, as a transactional read lock.
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




  // TODO drop the _out suffix. because any wire is a driver in the context of the top module.
  // should prefix o_test_pattern ?  or just on module names?
  wire [32-1 :0] test_pattern_out;

  test_pattern  test_pattern_1 (
    . clk( CLK),
    . out( test_pattern_out)
  );




  wire [32-1 :0] reg_adc_p_aperture;  // 32/31 bit nice. for long sample.
  wire [32-1:0]  reg_sa_p_clk_count_precharge;


  ////////
  // rename sa_simple_ ?
  // sa_pc_test
  // or test_sa_pc

  /*
    - note that we can still hook this up to the adc. for measurement.
    - slightly different from a direct mode. where there is no pc switching.
  */

  wire sample_acquisition_pc_sw_pc_ctl;
  wire sample_acquisition_pc_led0;
  wire [8-1 : 0] sample_acquisition_pc_monitor;

  sample_acquisition_pc
  sample_acquisition_pc (
    // inputs
    .clk(CLK),
    .reset_n( 1'b0 ), // TODO remove.

    // TODO - rename   , and prefix p_ .  p_p_clk_sample_duration_i
    // inputs
    .p_clk_sample_duration_i( reg_adc_p_aperture ),
    .p_clk_count_precharge_i( reg_sa_p_clk_count_precharge[ 24-1:0] ),

    // outputs
    .sw_pc_ctl_o( sample_acquisition_pc_sw_pc_ctl   ),          // should pass in both. and a register like a mask. to indicate which to use. similar to register for az mux.  might encode in same register.
    .led0_o(      sample_acquisition_pc_led0 ),                 // EXTR. just use the bits of reg_direct for azmux and which pc switch to use.  add back reg_direc2 for the ratiometric.
    .monitor_o(   sample_acquisition_pc_monitor  )
  );






  ////////////////////////

  // wire [ `NUM_BITS-1:0 ]  sa_no_az_test_out ;  // beter name ... _outputs_vec ?
  wire          adc_test_measure_trig;
  wire          adc_test_measure_valid;
  wire [6-1:0 ] adc_test_monitor;

  adc_test
  adc_test (
    .clk(CLK),

    // inputs
    .p_clk_count_aperture_i( reg_adc_p_aperture ),
    .adc_measure_trig_i( adc_test_measure_trig ),

    // outputs
    .adc_measure_valid_o( adc_test_measure_valid ),
    .monitor_o(  adc_test_monitor )
  );



/*
  // outputs.
  output reg adc_measure_trig_o,
  output reg  sw_pc_ctl_o,
  output reg [ 4-1:0 ] azmux_o,
  output reg led0_o,
  // must be a register if driven synchronously.
  output reg [3-1: 0 ] status_o,        // bit 0 - hi/lo,  bit 1 - prim/w4,   bit 2. reserved.

  // now a wire.  output wire [ 2-1:0]  monitor_o       // driven as wire/assign.
  output reg [ 2-1:0]  monitor_o
*/


  wire          sample_acquisition_az_sw_pc_ctl;
  wire [4-1:0]  sample_acquisition_az_azmux;
  wire          sample_acquisition_az_led0;
  wire [2-1:0]  sample_acquisition_az_monitor;
  wire [3-1:0]  sample_acquisition_az_status;
  // wire          sample_acquisition_az_adc_measure_trig;

  sample_acquisition_az
  sample_acquisition_az (

    .clk(CLK),

    // inputs
    .arm_trigger_i( reg_sa_arm_trigger[0 ]  ) ,
    .azmux_lo_val_i(  `S7  ),                       // TODO change to register
    .adc_measure_valid_i(   adc_test_measure_valid ),                     // fan-in from adc
    .p_clk_count_precharge_i( reg_sa_p_clk_count_precharge[ 24-1:0]  ),     // done

    // outputs
    .sw_pc_ctl_o( sample_acquisition_az_sw_pc_ctl  ),
    .azmux_o (    sample_acquisition_az_azmux  ),
    .led0_o(      sample_acquisition_az_led0  ),
    .monitor_o(   sample_acquisition_az_monitor  ),    // only pass 2 bit to the az monitor
    .status_o(  sample_acquisition_az_status ),
    .adc_measure_trig_o(  adc_test_measure_trig  )
  );







  /////////////////////////
  // We could do one led, for SS, and one for CS2 (4094,etc).
  // rename timed_latch_hold
  /*
    change name. this is more stretching the signal.
  */
  wire led0;
  timed_latch timed_latch (
    . clk(CLK),
    . trig_i( !SS || !SPI_CS2 ),      // rename set?
    . out( led0 )
  );





  ////////////////////////////
  reg [32-25- 1:0] dummy_bits_o ;
  // reg  output_led_dummy ;


  // mode, alternative function selection
  mux_8to1_assign #( 32  )
  mux_8to1_assign_1  (

    // .a( { reg_direct[ 32 - 1 : 1 ] ,  led0 } ), // mode/AF 0                 could also project the the spi signals on the monitor.
    .a(  reg_direct  ),                         // mode/AF 0  MODE_DIRECT       note, could change to project the the spi signals on the monitor, for easier ddebuggin. no. because want direct to control all outputs for test.
    .b(  32'b0  ),                              // mode/AF  1 MODE_LO           all outputs low.
    .c( { 32 { 1'b1 } }    ),                   // mode/AF 2  MODE_HI           all outputs hi.
    .d( test_pattern_out ),                     // mode/AF 3  MODE_PATTERN      pattern. needs xtal.

    // mode/AF 4 MODE_PC
    .e( {  { 32 - 15 { 'b0 }},
                                            // 15
          sample_acquisition_pc_sw_pc_ctl,  // 14
          2'b0,                             // 12   - should be reg_direct
          sample_acquisition_pc_monitor,    // 4
          3'b0,                             // 1    - should be reg_direct.
          sample_acquisition_pc_led0        // 0
        } ),

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


    // mode/AF  5
    .f( {  { 32 - 25 { 'b0 }},                  // 25
          4'b0,                               // 21  adc ref mux
          1'b0,                               // 20
          sample_acquisition_az_azmux,        // 16
          1'b0,                             // 15   - should be reg_direct
          sample_acquisition_az_sw_pc_ctl,   // 14
          2'b0,                             // 12    - should be reg_direct.
          adc_test_monitor, sample_acquisition_az_monitor,    // 4
          3'b0,                             // 1    - should be reg_direct.
          sample_acquisition_az_led0        // 0
        } ),
/*
  wire          sample_acquisition_az_sw_pc_ctl;  done
  wire [4-1:0]  sample_acquisition_az_azmux;      done
  wire          sample_acquisition_az_led0;       done.
  wire [2-1:0]  sample_acquisition_az_monitor;    done
  wire [3-1:0]  sample_acquisition_az_status;
*/



    .g( 32'b0 ),                                // mode/AF  6
    .h( 32'b0 ),                                // mode/AF  7




    .sel( reg_mode[ 3-1 : 0 ]),

    // add leds and monitor first, as this is the most generic functionality

    .out( {   dummy_bits_o,               // 25
              adc_refmux_o,                   // 21     // better name adc_refmux   adc_cmpr_latch
              adc_cmpr_latch_o,             // 20
              azmux_o,                   // 16
              sig_pc_sw_o,                // 14
              meas_complete_o,          // 13     // interupt_ctl *IS* generic so should be at start, and connects straight to adum. so place at beginning. same argument for meas_complete
              spi_interrupt_ctl_o,      // 12     todo rename. drop the 'ctl'.
              monitor_o,                // 4
              leds_o                    // 0
            }  )

  );







  register_set // #( 32 )
  register_set
    (

    // should prefix fields with spi_
    . clk(   SCK ),
    . cs_n(  SS /*SPI_CS */ ),        // rename cs_n
    . din(   SDI /*SPI_MOSI */),


    . dout( w_dout ),            // drive miso from via muxer
    // . dout( SDO /* SPI_MISO */ ),        // drive miso output pin directly.


    // outputs
    . reg_spi_mux(reg_spi_mux),
    . reg_4094(reg_4094 ) ,
    . reg_mode(reg_mode),
    . reg_direct(reg_direct),

    . reg_sa_arm_trigger ( reg_sa_arm_trigger ),


    // inputs
    . reg_status( reg_status ),

    // outputs - sample acquisition
    . reg_adc_p_aperture( reg_adc_p_aperture),
    . reg_sa_p_clk_count_precharge( reg_sa_p_clk_count_precharge),



/*
    . reg_spi_mux(reg_spi_mux),
    . reg_4094(reg_4094 ) ,
    . reg_mode( reg_mode ),      // ok.
    . reg_direct( reg_direct ),
    . reg_direct2( reg_direct2 ),
    . reg_reset( reg_reset),
*/

/*


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


