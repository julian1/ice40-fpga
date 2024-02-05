
// consider, change name top.v

// - can have heartbeat timer. over spi.
// - if have more than one dac. then just create another register. very clean.
// - we can actually handle a toggle. if both set and clear bit are hi then toggle
// - instead of !cs or !cs2.  would be good if can write asserted(cs)  asserted(cs2)



`include "register_set.v"
`include "mux_spi.v"

`include "mux_assign.v"


`include "sample_acquisition_pc.v"

`default_nettype none






module test_pattern #(parameter BITS=32 ) (
  input   clk,


  output reg  [ BITS -1:0 ] out   // wire.kk
);

  always@(posedge clk  )
      begin
        // works all monitor pins.
        // remove the himux2  reg_direct value is not working.
        // out[ 17 : 0 ]  <= out [ 17  : 0   ] + 1;
        // out  <= out  + 1;
        out  <= out  + 1;
      end

endmodule

// rename this file. top.v, and top.pcf.
// move old projects into dir.


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


  output [ 4-1: 0 ] o_leds,

  output [ 8-1: 0]  o_monitor,

  input [3-1: 0]    i_hw_flags,



  input  CLK,




  // 4094
  output GLB_4094_DATA,
  output GLB_4094_CLK,
  output GLB_4094_OE_CTL,
  output GLB_4094_STROBE_CTL,

  input U1004_4094_DATA,



  output o_spi_interrupt_ctl,

  output o_meas_complete,


  output o_sig_pc1_sw,
  output o_sig_pc2_sw ,


  // az mux
  output [ 4-1: 0 ] o_u410,


  // adc comparator
  output o_cmpr_latch,

  // adc ref current mux
  output [ 4-1: 0 ] o_u902,

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

    i_hw_flags,

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


  reg [32-25- 1:0] output_dummy ;


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
    .reset( 1'b0 ), // TODO remove.

    // TODO - rename   , and prefix p_ .  p_clk_sample_duration
    // inputs
    .clk_sample_duration(   reg_adc_p_aperture ),
    .p_clk_count_precharge( reg_sa_p_clk_count_precharge[ 24-1:0] ),

    // outputs
    .sw_pc_ctl( sample_acquisition_pc_sw_pc_ctl   ),          // should pass in both. and a register like a mask. to indicate which to use. similar to register for az mux.  might encode in same register.
    .led0(      sample_acquisition_pc_led0 ),                 // EXTR. just use the bits of reg_direct for azmux and which pc switch to use.  add back reg_direc2 for the ratiometric.
    .monitor(   sample_acquisition_pc_monitor  )
  );





  // mode, alternative function selection
  mux_8to1_assign #( 32  )
  mux_8to1_assign_1  (

    .a( reg_direct ),                           // mode/AF 0     default, follow reg_direct, for led.
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
              o_u902,                   // 21
              o_cmpr_latch,             // 20
              o_u410,                   // 16
              o_sig_pc2_sw,             // 15
              o_sig_pc1_sw,             // 14
              o_meas_complete,          // 13
              o_spi_interrupt_ctl,      // 12
              o_monitor,                // 4
              o_leds                    // 0
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

