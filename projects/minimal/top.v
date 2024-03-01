
/*
  - can have heartbeat timer. over spi.
      but don't want to spew spi tranmsission during acquisition.

  - if have more than one dac. then just create another register. very clean.
   - perhaps instead of !cs or !cs2.  could write macro  or asserted_n(cs ) etc
*/



`include "../../common/mux_spi.v"
`include "../../common/mux_assign.v"
`include "../../common/test_pattern.v"
`include "../../common/timed_latch.v"

`include "register_set.v"
`include "sample_acquisition_pc.v"


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


  output sig_pc1_sw_o,
  output sig_pc2_sw_o ,


  // az mux
  // u410
  output [ 4-1: 0 ] azmux_o,


  // adc comparator latch ctl.
  // should be cmpr_latch_ctl
  output cmpr_latch_o,

  // U902. adc ref current mux
  output [ 4-1: 0 ] refmux_o,

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

  wire [8-1:0] vec_cs ;
  // assign { monitor_o[2], GLB_4094_STROBE_CTL  } = vec_cs;
  assign { SPI_DAC_SS, GLB_4094_STROBE_CTL  } = vec_cs;


  // reg [6-1:0] vec_cs_dummy ;

  /*
    OK. there's a problem,   that each spi output is driven eg. high, even if unused.
    so if use same wire, then there are two drivers for the same output.

    - OK. way to fix is to remove the clk, and mosi.  entirely from muxer. and not mux them.
    - we only mux the strobe.
    - so the muxer only muxes the strobe.
    - and we could use a different control line anyway. - eg. UNUSED1_OUT.
    hmmmm.
  */

  /*
      NO. we need to fix this - we don't want signal propagation, for normal operation when just readin adc registers.
      easy way.  is to add a vector. controlling whether to drive. if not selected.
      But it cannot be left undefined - else - it will probably propagate, because that's

      Just express the logic, specificially.

      assign GLB_SPI_CLK  =  reg_mux == 0 ? 0 : ...
  */

  wire [8-1:0] vec_clk;
  // assign { GLB_SPI_CLK } = vec_clk ;   // have we changed the clock polarity.
  // assign GLB_SPI_CLK =  SCK;

  assign GLB_SPI_CLK  =  reg_spi_mux == 8'b0 ? 1 : SCK;

  wire [8-1:0] vec_mosi;
  // assign { GLB_SPI_MOSI } = vec_mosi;
  // assign GLB_SPI_MOSI = SDI;

  assign GLB_SPI_MOSI =  reg_spi_mux == 8'b0 ? 1 : SDI;


  wire [8-1:0] vec_miso ;
  assign  vec_miso[ 8-1 : 1] = 7'b0;

  assign { U1004_4094_DATA } = vec_miso;

  // unused.
  // assign monitor_o[8-1: 3] = 0;

  // a wire. since it is only used combinatorially .
  wire w_dout ;

  mux_spi #( )
  mux_spi
  (
    . reg_spi_mux(reg_spi_mux[ 8-1 : 0 ] ),
    . cs( SPI_CS2),
    . clk( SCK /* SPI_CLK */),      // UNUSED
    . mosi(SDI /* SPI_MOSI */ ),    // UNUSED

    //////
    . cs_polarity( 8'b00000001  ),  // 4094 strobe should go hi, for output
    // . vec_cs(   { vec_cs_dummy,  monitor_o[2], GLB_4094_STROBE_CTL  }  ),    // why doesn't this work?
    . vec_cs(   vec_cs   ),
    . vec_clk(vec_clk),
    . vec_mosi(vec_mosi),

    ////////////////

    . dout(w_dout),                              // use when cs active
    . vec_miso(vec_miso),                         // use when cs2 active
    . miso( SDO /* SPI_MISO */)                              // output pin
  );
  ///////////////////////


  assign monitor_o[0]  = GLB_SPI_CLK;
  assign monitor_o[1]  = GLB_SPI_MOSI;
  assign monitor_o[2]  = SPI_DAC_SS     ;







    // . cs_polarity( 8'b01110000  ),

  /////////////////////////////////////////////
  // 4094 OE
  wire [32-1:0] reg_4094;   // TODO rename
  assign { GLB_4094_OE_CTL } = reg_4094;    //  lo. start up not enabled.
  // wire GLB_4094_OE_CTL = 0;  // lo.



  ////////////////////////////////////////



  wire [32-1:0] reg_direct;




/*
  wire [32-1:0] reg_4094;   // TODO remove

  assign { GLB_4094_OE_CTL } = reg_4094;    //  lo. start up not enabled.
  // assign { GLB_4094_OE_CTL } = 1;    //  on for test.  should defer to mcu control. after check supplies.

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

  wire sample_acquisition_pc_sw_pc_ctl;
  wire sample_acquisition_pc_led0;
  wire [8-1 : 0] sample_acquisition_pc_monitor;

  sample_acquisition_pc
  sample_acquisition_pc (
    // inputs
    .clk(CLK),
    .reset_n( 1'b0 ), // TODO remove.

    // TODO - rename   , and prefix p_ .  p_p_clk_sample_duration
    // inputs
    .p_clk_sample_duration(   reg_adc_p_aperture ),
    .p_clk_count_precharge( reg_sa_p_clk_count_precharge[ 24-1:0] ),

    // outputs
    .sw_pc_ctl( sample_acquisition_pc_sw_pc_ctl   ),          // should pass in both. and a register like a mask. to indicate which to use. similar to register for az mux.  might encode in same register.
    .led0(      sample_acquisition_pc_led0 ),                 // EXTR. just use the bits of reg_direct for azmux and which pc switch to use.  add back reg_direc2 for the ratiometric.
    .monitor(   sample_acquisition_pc_monitor  )
  );




  /////////////////////////
  // We could do one led, for SS, and one for CS2 (4094,etc).
  // rename timed_latch_hold
  wire led0;
  timed_latch timed_latch (
    . clk(CLK),
    . trig_i( !SS || !SPI_CS2 ),      // rename set?
    . out( led0 )
  );





  ////////////////////////////
  reg [32-25- 1:0] output_dummy ;
  reg  output_led_dummy ;


  reg [8-1: 0 ] monitor_dummy;


  // mode, alternative function selection
  mux_8to1_assign #( 32  )
  mux_8to1_assign_1  (

    .a( { reg_direct[ 32 - 1 : 1 ] ,  led0 } ),                           // mode/AF 0     default, follow reg_direct, for led.
    .b(  32'b0  ),                              // mode/AF  1   only sigle led is on????
    .c( { 32 { 1'b1 } }    ),                   // mode/AF 2     { 1,1,1,1 } == 0b0001, not 4b1111
    .d( test_pattern_out ),                     // mode/AF 3

    .e( {  { 32 - 15 { 'b0 }},                  // mode/AF 4
                                            // 15
          sample_acquisition_pc_sw_pc_ctl,  // 14
          2'b0,                             // 12   - should be reg_direct
          sample_acquisition_pc_monitor,    // 4
          3'b0,                             // 1    - should be reg_direct.
          sample_acquisition_pc_led0        // 0
        } ),



    .f( 32'b0 ),                                // mode/AF  5
    .g( 32'b0 ),                                // mode/AF  6
    .h( 32'b0 ),                                // mode/AF  7

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

    // add leds and monitor first, as the most generic

    .out( { output_dummy,               // 32
                                        // 25
              refmux_o,                   // 21
              cmpr_latch_o,             // 20
              azmux_o,                   // 16
              sig_pc2_sw_o,             // 15
              sig_pc1_sw_o,             // 14
              meas_complete_o,          // 13
              spi_interrupt_ctl_o,      // 12
              // monitor_o,                // 4
              monitor_dummy,
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
    // outputs signal acquisiation
    .reg_sa_arm_trigger ( reg_sa_arm_trigger ),


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


