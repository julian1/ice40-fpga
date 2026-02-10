
/*
  - can have heartbeat timer. over spi.
      but should avoid spewing spi tranmsission emi during ordinary acquisition.


  // verilog literals are hard!.
  // 4'b1                         == 0001
  // { 1,1,1,1}                   == 0001
  // { 1'b1, 1'b1, 1'b1, 1'b1 }   == 1111
  // 4 { 1'b1 }                   == 1111
  // 4'b1111                      == 1111


*/



`include "../../common/mux_assign.v"

`include "register_set.v"


`include "adc-mock.v"
`include "refmux-test.v"

`include "adc_modulation_06.v"
`include "sequence_acquisition.v"

`default_nettype none




// cs assert encoding for different spi devices.  decimal
`define SPI_CS_VEC_DEASSERT             3'd0
`define SPI_CS_VEC_FPGA0                3'd1
`define SPI_CS_VEC_4094                 3'd2
`define SPI_CS_VEC_INVERT_DAC           3'd3
`define SPI_CS_VEC_MDAC1                3'd4



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

  // input SS,

  // SS used as first bit of spi_cs_vec_i muxing - july 2025
  input [ 3-1 : 0 ] spi_cs_vec_i,


  ///////////
  output [ 4-1: 0 ] leds_o,

  output [ 8-1: 0]  monitor_o,

  input [4-1: 0]    hw_flags_i,





  // spi lines.
  output spi_glb_mosi,
  output spi_glb_clk,
  input spi_glb_miso,


  // 4094
  output spi_4094_strobe,
  output spi_4094_oe,


  // other cs lines
  // output SPI_CS_DAC,
  output spi_iso_cs,
  output spi_iso_cs2,



  output spi_invert_dac_data,
  output spi_invert_dac_clk,
  output spi_invert_dac_ss,



  // xtal
  input  CLK,


  output [ 2-1: 0 ] pc_sw_o,

  // az mux, u410
  output [ 4-1: 0 ] azmux_o,


  // U902. adc ref current mux
  output [ 2-1: 0 ] adc_refmux_o,
  output adc_sigmux_o,
  output adc_rstmux_o,



  input adc_cmpr_i,
  output adc_cmpr_latch_ctl_o,


  output spi_interrupt_ctl_o,


  input sa_trig_i

);


  // dec 2024. after changing pcb comparator output polarity
  wire cmpr_val;
  assign cmpr_val = ! adc_cmpr_i;




  ////////////////////////////////////////
  // spi muxing



  // spi lines - silence if active device is the fpga/register set
  assign spi_glb_clk              = spi_cs_vec_i ==  `SPI_CS_VEC_FPGA0 ? 1 : SCK;      // park hi
  assign spi_glb_mosi             = spi_cs_vec_i ==  `SPI_CS_VEC_FPGA0 ? 1 : SDI;      // park hi



  assign spi_invert_dac_data = spi_glb_mosi;
  assign spi_invert_dac_clk = spi_glb_clk;



  wire spi_register_set_cs        = spi_cs_vec_i ==  `SPI_CS_VEC_FPGA0 ? 0 : 1;         // active lo, park hi

  // 4094 strobe
  assign spi_4094_strobe          = spi_cs_vec_i == `SPI_CS_VEC_4094;                 // active hi, park lo

  assign spi_invert_dac_ss        = spi_cs_vec_i == `SPI_CS_VEC_INVERT_DAC ? 0 : 1;   // active lo, park hi

  assign spi_iso_cs               = spi_cs_vec_i == `SPI_CS_VEC_MDAC1 ? 0 : 1;        // active lo, park hi

  assign spi_iso_cs2              = 1;    // unused



  /////////////////////////



  // operating mode
  wire [3-1:0 ] mode = reg_cr[ 3-1 : 0 ];


  /*
    // can use this to test spi liines

    assign monitor_o[0]  = spi_glb_clk;
    assign monitor_o[1]  = spi_glb_mosi;
    assign monitor_o[2]  = SPI_DAC_SS     ;
  */




  /////////////////////////////////////////////
  // 4094 OE
  // JA. changed feb 2026. not tested.
  wire [32-1:0] reg_4094_oe;
  assign spi_4094_oe = reg_4094_oe[ 0 ] ;




  ////////////////////////////////////////

  wire [32-1 :0] reg_cr;     // _mode or AF reg_af alternate function  two bits

  wire [32-1:0] reg_direct;

  // wire [32-1:0] reg_seq_mode;    // just pass-through communcation. from reg to the status register out.



  // sample aquisition
  wire [32-1:0] reg_sa_p_clk_count_precharge;

  wire [32-1:0] reg_sa_p_seq_n;
  wire [32-1:0] reg_sa_p_seq0;
  wire [32-1:0] reg_sa_p_seq1;
  wire [32-1:0] reg_sa_p_seq2;
  wire [32-1:0] reg_sa_p_seq3;



  // adc
  wire [32-1 :0] reg_adc_p_clk_count_aperture;  // 32/31 bit nice. for long sample.
  wire [32-1 :0] reg_adc_p_clk_count_reset;



  // TODO consider rename adc_refmux_test.
  // no. because it is not the adc.
  wire [8-1:0] refmux_test_monitor;


  wire [2-1: 0 ] refmux_test_refmux;
  wire refmux_test_sigmux;
  wire refmux_test_rstmux;



  refmux_test refmux_test (

    .clk(CLK),
    // JA.   add a reset_n.  and only activate in the corresponding mode.
    // we don't care about reset here

    . p_clk_count_reset_i( $rtoi(  `CLK_FREQ * 500e-6 )  ), // 500us.
    . p_clk_count_fix_i(   $rtoi( `CLK_FREQ * 150e-6 )) ,  // 100us. initial but too long

    . cmpr_val_i( cmpr_val ),

    .monitor_o( refmux_test_monitor),
    /* ie. refmux order pos,neg,source,reset.
      do we want to change this in main.pcf.. no keep ic sw pinout order.  */
    // .refmux_o ( { refmux_test_refmux[  3  ],  refmux_test_refmux[ 0 +: 2 ]   }  ),
    // .sigmux_o( refmux_test_refmux[ 2] )

    .refmux( refmux_test_refmux ),
    .sigmux( refmux_test_sigmux ),
    .rstmux( refmux_test_rstmux )
  );







  ////////////////////////

  wire          adc_mock_reset_n;
  wire          adc_mock_measure_valid;
  wire [8-1:0 ] adc_mock_monitor;

  adc_mock
  adc_mock (

    .clk(CLK),
    .reset_n( adc_mock_reset_n ),

    // inputs
    .p_clk_count_aperture_i( reg_adc_p_clk_count_aperture ),

    // outputs
    .adc_measure_valid_o( adc_mock_measure_valid ),
    .monitor_o(  adc_mock_monitor )
  );

  wire [2-1:0]  sequence_acquisition_pc_sw;
  wire [4-1:0]  sequence_acquisition_azmux;

  wire [4-1:0]  sequence_acquisition_leds;
  wire [8-1:0]  sequence_acquisition_monitor;
  // wire [4-1:0]  sequence_acquisition_status;


  // perhaps rename sequence_acquisition_with_adc_mock

  sequence_acquisition
  sequence_acquisition (

    .clk(CLK),
    .reset_n( sa_trig_i ),

    // inputs
    .adc_measure_valid_i( adc_mock_measure_valid ),                     // fan-in from adc

    .p_seq_n_i( reg_sa_p_seq_n[ 3-1: 0]  ),   // 3 bits
    .p_seq0_i( reg_sa_p_seq0[ 6-1: 0]  ),
    .p_seq1_i( reg_sa_p_seq1[ 6-1: 0]  ),
    .p_seq2_i( reg_sa_p_seq2[ 6-1: 0] ),
    .p_seq3_i( reg_sa_p_seq3[ 6-1: 0] ),


    .p_clk_count_precharge_i( reg_sa_p_clk_count_precharge[ 24-1:0]  ),     // done

    // outputs
    .pc_sw_o( sequence_acquisition_pc_sw  ),
    .azmux_o (    sequence_acquisition_azmux ),


    .leds_o(      sequence_acquisition_leds  ),
    .monitor_o(   sequence_acquisition_monitor  ),    // only pass 2 bit to the az monitor
    // .status_last_o(  sequence_acquisition_status ),

    .adc_reset_no(  adc_mock_reset_n  )
  );


  ////////////////////








  ////////////////////////////


  // adc
  wire          adc_reset_n;
  wire          adc_measure_valid;

  wire [8-1: 0 ] adc_monitor;
  // wire [4-1:0]  adc_status;      // TODO


  wire [2-1: 0 ] adc_refmux;
  wire adc_sigmux;
  wire adc_rstmux;


  wire           adc_cmpr_latch_ctl;


  wire [24-1:0] adc_clk_count_rstmux_last;
  wire [32-1:0] adc_clk_count_refmux_neg_last;    // maybe add reg_ prefix. No. they are not registers, until they are in the register_bank context.
  wire [32-1:0] adc_clk_count_refmux_pos_last;
  wire [24-1:0] adc_clk_count_refmux_both_last;
  wire [32-1:0] adc_clk_count_sigmux_last;
  wire [32-1:0] adc_clk_count_aperture_last;

  wire [24-1 :0] adc_stat_count_refmux_pos_up_last;
  wire [24-1 :0] adc_stat_count_refmux_neg_up_last;
  wire [24-1 :0] adc_stat_count_cmpr_cross_up_last;





  adc_modulation
  adc(

    .clk(CLK),
    .reset_n( adc_reset_n),


    .cmpr_val( cmpr_val ),                  // OK.  fan in-  rename top_cmpr_val ?

    . p_clk_count_aperture( reg_adc_p_clk_count_aperture /*reg_adc_p_aperture */),
    . p_clk_count_reset( reg_adc_p_clk_count_reset[ 24-1: 0  ]  ) ,
    // . p_clk_count_fix( 24'd15 ) ,         // +-15V. reduced integrator swing.
    // . p_clk_count_var( 24'd100 ) ,

    . p_clk_count_fix( 24'd67 ) ,           // 1.5nF. 4x counts of 330p. oct. 2023. test.
    . p_clk_count_var( 24'd450 ) ,

    . p_use_slow_rundown( 1'b1 ),
    . p_use_fast_rundown( 1'b1 ),
    . p_use_input_signal( 1'b1 ),

    // outputs - ctrl
    .adc_measure_valid( adc_measure_valid),    // OK, fan out back to the sa controllers
    .cmpr_latch_ctl( adc_cmpr_latch_ctl   ),
    .monitor(  adc_monitor  ),


    .rstmux( adc_rstmux ),
    .refmux( adc_refmux ),
    .sigmux( adc_sigmux ),

    // adc clk counts for last sample measurement
    .clk_count_rstmux_last(adc_clk_count_rstmux_last),
    .clk_count_refmux_neg_last(  adc_clk_count_refmux_neg_last),
    .clk_count_refmux_pos_last(  adc_clk_count_refmux_pos_last),
    .clk_count_refmux_both_last(   adc_clk_count_refmux_both_last),
    .clk_count_sigmux_last(  adc_clk_count_sigmux_last ),
    .clk_count_aperture_last( adc_clk_count_aperture_last),

    // stats
    .stat_count_refmux_pos_up_last( adc_stat_count_refmux_pos_up_last),
    .stat_count_refmux_neg_up_last( adc_stat_count_refmux_neg_up_last),
    .stat_count_cmpr_cross_up_last( adc_stat_count_cmpr_cross_up_last)
  );




  /*
    status_o should be treated/managed generically - just like monitor_o and leds_o.  for each controller (sequence,adc etc).
      like a generic service to a module
    eg. try to conform to same/standard bit width.
    - call it status_last ... because it is for the completed measurement, not current.
  */

  //////////////////

  wire [2-1:0]  sequence_acquisition2_pc_sw;
  wire [4-1:0]  sequence_acquisition2_azmux;

  wire [4-1:0]  sequence_acquisition2_leds;
  wire [8-1:0]  sequence_acquisition2_monitor;

  // with two sequence modules,
  // we would need to encode this in output vector if we wanted both values available.
  wire [3-1:0]  sequence_acquisition2_sample_idx_last;
  wire          sequence_acquisitionr2_first_last;



  wire  sequence_acquisition2_adc_reset_n;


  sequence_acquisition
  sequence_acquisition2 (

    .clk(CLK),
    .reset_n( sa_trig_i ),    // we want this to remove. the old edge triggered stuff.

    // inputs
    .adc_measure_valid_i( adc_measure_valid ),                     // JA the real adc. from adc


    // TODO move to registers

    .p_seq_n_i( reg_sa_p_seq_n[ 3-1: 0]  ),
    .p_seq0_i( reg_sa_p_seq0[ 6-1: 0]  ),
    .p_seq1_i( reg_sa_p_seq1[ 6-1: 0]  ),
    .p_seq2_i( reg_sa_p_seq2[ 6-1: 0] ),
    .p_seq3_i( reg_sa_p_seq3[ 6-1: 0] ),


    .p_clk_count_precharge_i( reg_sa_p_clk_count_precharge[ 24-1:0]  ),     // done

    // outputs
    .pc_sw_o( sequence_acquisition2_pc_sw  ),
    .azmux_o (    sequence_acquisition2_azmux  ),

    .leds_o(      sequence_acquisition2_leds  ),
    .monitor_o(   sequence_acquisition2_monitor  ),    // only pass 2 bit to the az monitor

    .sample_idx_last_o( sequence_acquisition2_sample_idx_last),
    .first_last_o(sequence_acquisitionr2_first_last),

    .adc_reset_no(  sequence_acquisition2_adc_reset_n )

  );






  ////////////////////////////
  // unused. should be able to be wire?
  reg [32-26- 1:0] dummy_bits_o ;

  reg meas_complete_o;   // now unused.


  /*
     note - if a controller is unused in a mode - it would be nice to hold it in reset.
      can do by exposing the reset_n, and only turning it on, if active within the specific mode.
  */

  // mode, alternative function selection
  mux_8to1_assign #( 32  )
  mux_8to1_assign_1  (

    .a(  reg_direct  ),                       // mode/AF 0  MODE_DIRECT       note, could also project, spi signals on the monitor, for easier debuggin. no. because want direct to control all outputs for test.

    // unused.
    .b(  32'b0  ),
    .c(  32'b0  ),
    .d(  32'b0  ),
    .e(  32'b0  ),

    // mode  5. adc refmux test
    // limited modulation of ref currents, useful when populating pcb, don't need slope-amp/comparator etc.
    .f( {  { 32 - 22 { 'b0 }},
                                              // 22

          refmux_test_sigmux,
          refmux_test_rstmux,
          refmux_test_refmux,                 // 18+4

          4'b0,    // azmux                   // 14+4
          2'b0 ,  // precharge                // 12+2
          refmux_test_monitor,                // 4+8
          4'b0   // leds                      // 0+4
        } ),


    // mode  6  sequence acquisition with mocked adc.  and better monitor
    // useful to test precharge/az switching, without needing adc to be populated
    // and verifying timing sequences, with better monitor
    // needs trig asserted.  and seq-n. etc.
    // needs fpga cmos oscillator/xtal populated
    // eg. set ch2 lts ; set mode 6;  trig ;   works. jan 2026.
    .g( {  { 32 - 26 { 'b0 }},
                                              // 26
          1'b0, // adc_reset_n                // 25 + 1
          1'b0, // meas_complete              // 24+1
          1'b0,   // spi_interupt             // 23 + 1
          1'b0,  // adc_cmpr_latch            // 22+1
          4'b0,  // adc_refmux                // 18+4
          sequence_acquisition_azmux,         // 14+4
          sequence_acquisition_pc_sw,     // 12+2
          sequence_acquisition_monitor[ 0 +: 8],    // 4+8
          sequence_acquisition_leds           // 0+1
        } ),



    // mode 7. sequence acquisition controller and full adc.
    // needs trig asserted.
   .h( {  { 32 - 26 { 'b0 }},
                                              // 26
          sequence_acquisition2_adc_reset_n,  // adc_reset_n     // 25 + 1
          adc_measure_valid,                  // meas_complete              // 24+1
          adc_measure_valid,                  // spi_interupt   // 23 + 1
          adc_cmpr_latch_ctl,                 // adc_cmpr_latch   // 22+1

          adc_sigmux,
          adc_rstmux,
          adc_refmux,                            // adc muxes // 18+4

          sequence_acquisition2_azmux,        // azmux      // 14+4
          sequence_acquisition2_pc_sw,    // precharge    // 12+2
          // adc_monitor[ 0 +: 6], sequence_acquisition2_monitor[ 0 +: 2],    // 4+8
          adc_monitor[ 0 +: 6],  sequence_acquisition2_monitor[ 4],  sequence_acquisition2_monitor[ 0],    // 4+8.   eg. hi/lo, if ch1 pc is active
          sequence_acquisition_leds           // 0+4
        } ),


    .sel( mode ),

    // leds and monitor go first, since they are the most generic functionality

    .out( {   dummy_bits_o,               // 26

          adc_reset_n,        // 25 + 1

          meas_complete_o,          // 24+1     // interupt_ctl *IS* generic so should be at start, and connects straight to adum. so place at beginning. same argument for meas_complete
          spi_interrupt_ctl_o,      // 23+1     todo rename. drop the 'ctl'.
          adc_cmpr_latch_ctl_o,         // 22+1

          adc_sigmux_o,
          adc_rstmux_o,
          adc_refmux_o,             // adc muxes 18+4

          azmux_o,                  // 14+4
          pc_sw_o,                  // 12+2
          monitor_o,                // 4+8
          leds_o                    // 0+4
        }  )

  );



  /*
    note mcu we could also write some status flags from mode,
    as a way to communicate back to the data decoding.
    this - maintainis single source-of-authority. and is simple
    - eg. how to interpret the sequence - hi,lo, 4 cycle. etc.
    -----
    the advantage is the synchronization   - between mcu state, and adc/sa state.
      and being able to read consistently.
  */

  // readable inputs
  wire [32 - 1 :0] reg_status ;

  assign reg_status = {


    // todo consider - add adc_status,  and sa_status

    4'b0,   // ??

    // 24
    {  1'b0,  reg_sa_p_seq_n[ 3-1: 0] ,  sequence_acquisitionr2_first_last,  sequence_acquisition2_sample_idx_last },

    // 16
    { 4'b0, hw_flags_i } ,

    // 8
    { 8'b10101010 }  // magic
 };







  register_set // #( 32 )
  register_set
    (

    // consider prefix fields with spi_
    . clk(  SCK ),
    . cs_n( spi_register_set_cs),
    . din(  SDI ),
    . dout( SDO ),


    // inputs
    . reg_4094_oe(reg_4094_oe ) ,
    . reg_cr(reg_cr),
    . reg_direct(reg_direct),

    // outputs
    . reg_status( reg_status ),


    // sample/sequence acquisition
    . reg_sa_p_clk_count_precharge( reg_sa_p_clk_count_precharge),

    . reg_sa_p_seq_n( reg_sa_p_seq_n),    // n == count == limit.  not invert.
    . reg_sa_p_seq0( reg_sa_p_seq0),
    . reg_sa_p_seq1( reg_sa_p_seq1),
    . reg_sa_p_seq2( reg_sa_p_seq2),
    . reg_sa_p_seq3( reg_sa_p_seq3),

    // adc outputs
    . reg_adc_p_clk_count_aperture( reg_adc_p_clk_count_aperture),
    . reg_adc_p_clk_count_reset( reg_adc_p_clk_count_reset ),


    // adc inputs
    // pad to match register_set 32bit regs.
    .  reg_adc_clk_count_refmux_neg( adc_clk_count_refmux_neg_last) ,
    .  reg_adc_clk_count_refmux_pos( adc_clk_count_refmux_pos_last) ,
    .  reg_adc_clk_count_refmux_both( { 8'b0, adc_clk_count_refmux_both_last } ) ,

    .  reg_adc_clk_count_rstmux( { 8'b0, adc_clk_count_rstmux_last } ) ,
    .  reg_adc_clk_count_sigmux( adc_clk_count_sigmux_last ),
    .  reg_adc_clk_count_aperture( adc_clk_count_aperture_last),


    .  reg_adc_stat_count_refmux_pos_up( { 8'b0, adc_stat_count_refmux_pos_up_last } ),
    .  reg_adc_stat_count_refmux_neg_up( { 8'b0, adc_stat_count_refmux_neg_up_last } ) ,
    .  reg_adc_stat_count_cmpr_cross_up( { 8'b0, adc_stat_count_cmpr_cross_up_last } )

  );



endmodule




