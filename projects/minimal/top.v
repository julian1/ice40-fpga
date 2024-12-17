
/*
  - can have heartbeat timer. over spi.
      but don't want to spew spi tranmsission emi during acquisition.

  - if have more than one dac. then just create another register. very clean.
   - perhaps instead of !cs or !cs2.  could write macro  or asserted_n(cs ) etc
*/



`include "../../common/mux_assign.v"

`include "register_set.v"


`include "adc-mock.v"
`include "refmux-test.v"

`include "adc_modulation_05.v"
`include "sequence_acquisition.v"

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


  input  SPI_CS2,


  ///////////
  output [ 4-1: 0 ] leds_o,

  output [ 8-1: 0]  monitor_o,

  input [4-1: 0]    hw_flags_i,





  // spi lines.
  output spi_glb_mosi,
  output spi_glb_clk,

  // 4094
  output spi_4094_strobe_ctl,
  output spi_4094_oe_ctl,
  input U1008_4094_DATA,

  // other cs lines
  output SPI_DAC_SS,
  output SPI_ISO_DAC_CS,
  output SPI_ISO_DAC_CS2,


  // xtal
  input  CLK,


  output [ 2-1: 0 ] pc_sw_o,

  // az mux, u410
  output [ 4-1: 0 ] azmux_o,


  // U902. adc ref current mux
  output [ 4-1: 0 ] adc_refmux_o,

  input adc_cmpr_out,

  output adc_cmpr_latch_ctl_o,


  /////////////////




  // output unused3_o,

  // input trigger_source_external_i,   // trigger_ext_out   - need to re
  // input trigger_source_internal_i,   // trigger_int_out 38
  // input unused1_i,                    // 39
  input trig_sa_i,




  output spi_interrupt_ctl_o,
  // output meas_complete_o,

);


  // dec 2024. after changing pcb comparator output
  wire adc_cmpr_p_i;
  assign adc_cmpr_p_i = ! adc_cmpr_out;



  // avoid leaving output floating. else digital isolator will see floating cmos input, and draw excess current.
  // TODO review. this. july 2024.
  // assign unused3_o  = 1;


  ////////////////////////////////////////
  // spi muxing

  /*
    TODO. rather than pulling all these out in vectors.
          we should combine in line/place. the same way we do mux align.
          eg.

      . vec_cs(  {  dummy,  spi_4094_strobe_ctl  }   ),
      ote. we are already doing this for polarity
  */

  wire [32-1:0] reg_spi_mux ;// = 8'b00000001; // test

  assign spi_glb_clk          = reg_spi_mux == 8'b0 ? 1 : SCK;      // park hi
  assign spi_glb_mosi         = reg_spi_mux == 8'b0 ? 1 : SDI;      // park hi

  assign spi_4094_strobe_ctl  = reg_spi_mux ==   8'b01 ?  (~ SPI_CS2)  : 0;     // active hi, park lo
  assign SPI_DAC_SS           = reg_spi_mux ==   8'b10 ?  SPI_CS2 : 1;     // active lo
  assign SPI_ISO_DAC_CS       = reg_spi_mux ==  8'b100 ?  SPI_CS2 : 1;     // active lo
  assign SPI_ISO_DAC_CS2      = reg_spi_mux == 8'b1000 ?  SPI_CS2 : 1;     // active lo




  wire w_dout ;

  assign w_dout = SDO;




/*
  // would be nice to project these in a mode,
  // but if there's a spi problem - we are unlikely to get it into a mode.

  assign monitor_o[0]  = spi_glb_clk;
  assign monitor_o[1]  = spi_glb_mosi;
  assign monitor_o[2]  = SPI_DAC_SS     ;
*/



  // verilog literals are hard!.
  // 4'b1                         == 0001
  // { 1,1,1,1}                   == 0001
  // { 1'b1, 1'b1, 1'b1, 1'b1 }   == 1111
  // 4 { 1'b1 }                   == 1111
  // 4'b1111                      == 1111



  /////////////////////////////////////////////
  // 4094 OE
  wire [32-1:0] reg_4094;   // TODO rename
  assign { spi_4094_oe_ctl } = reg_4094;    //  lo. start up not enabled.

  ////////////////////////////////////////



  wire [32-1 :0] reg_mode;     // _mode or AF reg_af alternate function  two bits

  wire [32-1:0] reg_direct;

  wire [32-1:0] reg_seq_mode;    // just pass-through communcation. from reg to the status register out.





  wire [32-1:0] reg_sa_p_clk_count_precharge;

  wire [32-1:0] reg_sa_p_seq_n;
  wire [32-1:0] reg_sa_p_seq0;
  wire [32-1:0] reg_sa_p_seq1;
  wire [32-1:0] reg_sa_p_seq2;
  wire [32-1:0] reg_sa_p_seq3;



  wire [32-1 :0] reg_adc_p_clk_count_aperture;  // 32/31 bit nice. for long sample.
  wire [32-1 :0] reg_adc_p_clk_count_reset;





  // TODO consider rename adc_refmux_test.
  wire [8-1:0] refmux_test_monitor;
  wire [4-1:0] refmux_test_refmux;

  refmux_test refmux_test (

    .clk(CLK),
    // JA.   add a reset_n.  and only activate in the corresponding mode.
    // we don't care about reset here

    . p_clk_count_reset_i( $rtoi(  `CLK_FREQ * 500e-6 )  ), // 500us.
    . p_clk_count_fix_i(   $rtoi( `CLK_FREQ * 150e-6 )) ,  // 100us. initial but too long

    . cmpr_val_i( adc_cmpr_p_i ),

    .monitor_o( refmux_test_monitor),
    /* ie. refmux order pos,neg,source,reset.
      do we want to change this in main.pcf.. no keep ic sw pinout order.  */
    .refmux_o ( { refmux_test_refmux[  3  ],  refmux_test_refmux[ 0 +: 2 ]   }  ),
    .sigmux_o( refmux_test_refmux[ 2] )
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
    .reset_n( trig_sa_i ),

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
    .azmux_o (    sequence_acquisition_azmux  ),

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


  wire [4-1: 0 ] adc_mux;
  wire           adc_cmpr_latch_ctl;


  wire [24-1:0] adc_clk_count_refmux_reset_last;
  wire [32-1:0] adc_clk_count_refmux_neg_last;    // maybe add reg_ prefix. No. they are not registers, until they are in the register_bank context.
  wire [32-1:0] adc_clk_count_refmux_pos_last;
  wire [24-1:0] adc_clk_count_refmux_rd_last;
  wire [32-1:0] adc_clk_count_mux_sig_last;

  wire [24-1 :0] adc_stat_count_refmux_pos_up_last;
  wire [24-1 :0] adc_stat_count_refmux_neg_up_last;
  wire [24-1 :0] adc_stat_count_cmpr_cross_up_last;





  adc_modulation
  adc(

    .clk(CLK),
    .reset_n( adc_reset_n),


    .cmpr_val( adc_cmpr_p_i ),                  // OK.  fan in-  rename top_adc_cmpr_p_i ?

    . p_clk_count_aperture( reg_adc_p_clk_count_aperture /*reg_adc_p_aperture */),
    . p_clk_count_reset( reg_adc_p_clk_count_reset[ 24-1: 0  ]  ) ,
    // . p_clk_count_fix( 24'd15 ) ,         // +-15V. reduced integrator swing.
    // . p_clk_count_var( 24'd100 ) ,

    . p_clk_count_fix( 24'd67 ) ,           // 1.5nF. 4x counts of 330p. oct. 2023. test.
    . p_clk_count_var( 24'd450 ) ,

    . p_use_slow_rundown( 1'b1 ),
    . p_use_fast_rundown( 1'b1 ),

    // outputs - ctrl
    .adc_measure_valid( adc_measure_valid),    // OK, fan out back to the sa controllers
    .cmpr_latch_ctl( adc_cmpr_latch_ctl   ),
    .monitor(  adc_monitor  ),
    .refmux(  { adc_mux[  3  ],  adc_mux[ 0 +: 2 ]   } ),           // pos, neg, reset. are on two different 4053,
    .sigmux(    adc_mux[  2  ] ),                                    // perhaps clearer if split into adcrefmux and adcsigmux in the wire assignment. but it would then need two vars.
                                                                      // which isn't representative of the single synchronizer. so do it here instead.
    // adc clk counts for last sample measurement
    .clk_count_refmux_reset_last(adc_clk_count_refmux_reset_last),
    .clk_count_refmux_neg_last(  adc_clk_count_refmux_neg_last),
    .clk_count_refmux_pos_last(  adc_clk_count_refmux_pos_last),
    .clk_count_refmux_rd_last(   adc_clk_count_refmux_rd_last),
    .clk_count_mux_sig_last(  adc_clk_count_mux_sig_last ),

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
  // wire [4-1:0]  sequence_acquisition2_status;

  // with two sequence modules,
  // we would need to encode this in output vector if we wanted both values available.
  wire [3-1:0]  sequence_acquisition2_sample_idx_last;

  wire  sequence_acquisition2_adc_reset_n;


  sequence_acquisition
  sequence_acquisition2 (

    .clk(CLK),
    .reset_n( trig_sa_i ),    // we want this to remove. the old edge triggered stuff.

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
    // .status_last_o(  sequence_acquisition2_status ),

    . sample_idx_last_o( sequence_acquisition2_sample_idx_last),

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

    /* TODO remove.
        the modes for output lo, and output hi - are not really needed. eg. mode 0; direct 0xffffffff ; or 0x00000000; etc.
        and there maybe chance of damage, if parts are populated
      */
    .b(  32'b0  ),
    .c(  32'b0  ),
    .d(  32'b0  ),
    .e(  32'b0  ),

    // mode  5. adc refmux test
    // limited modulation of ref currents, useful when populating pcb, don't need slope-amp/comparator etc.
    .f( {  { 32 - 22 { 'b0 }},
                                              // 22
          refmux_test_refmux,                 // 18+4
          4'b0,    // azmux                   // 14+4
          2'b0 ,  // precharge                // 12+2
          refmux_test_monitor,                // 4+8
          4'b0   // leds                      // 0+4
        } ),


    // mode  6  sequence acquisition with mocked adc.  and better monitor
    // very useful - allows testing precharge/az switching, without adc populated
    // and verifying timing sequences, with better monitor
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
   .h( {  { 32 - 26 { 'b0 }},
                                              // 26
          sequence_acquisition2_adc_reset_n,  // adc_reset_n     // 25 + 1
          adc_measure_valid,                  // meas_complete              // 24+1
          adc_measure_valid,                  // spi_interupt   // 23 + 1
          adc_cmpr_latch_ctl,                 // adc_cmpr_latch   // 22+1
          adc_mux,                            // adc_refmux     // 18+4
          sequence_acquisition2_azmux,        // azmux      // 14+4
          sequence_acquisition2_pc_sw,    // precharge    // 12+2
          // adc_monitor[ 0 +: 6], sequence_acquisition2_monitor[ 0 +: 2],    // 4+8
          adc_monitor[ 0 +: 6],  sequence_acquisition2_monitor[ 4],  sequence_acquisition2_monitor[ 0],    // 4+8.   eg. hi/lo, if ch1 pc is active
          sequence_acquisition_leds           // 0+4
        } ),


    .sel( reg_mode[ 3-1 : 0 ]),

    // leds and monitor go first, since they are the most generic functionality

    .out( {   dummy_bits_o,               // 26

          adc_reset_n,        // 25 + 1

          meas_complete_o,          // 24+1     // interupt_ctl *IS* generic so should be at start, and connects straight to adum. so place at beginning. same argument for meas_complete
          spi_interrupt_ctl_o,      // 23+1     todo rename. drop the 'ctl'.
          adc_cmpr_latch_ctl_o,         // 22+1
          adc_refmux_o,             // 18+4     // better name adc_refmux   adc_cmpr_latch
          azmux_o,                  // 14+4
          pc_sw_o,              // 12+2
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

    {  4'b0, reg_seq_mode[ 4-1 : 0]  } ,    // 4 bits

    {  1'b0,  reg_sa_p_seq_n[ 3-1: 0] ,  1'b0,  sequence_acquisition2_sample_idx_last },

    { reg_spi_mux [ 4-1: 0 ],  hw_flags_i } ,

    { 8'b10101010 }  // magic
 };



/*
    8'b0 ,
    monitor,                          // don't see having the monitor readable through a different register is useful.   a git commit or crc would be useful.
                                      // add a count, as a transactional read lock.
    HW2,  HW1,  HW0,

    reg_sa_arm_trigger[0],            // ease having to do a separate register read, to retrieve state.
    sequence_acquisition_status_out, // 3 bits
    adc_measure_valid,

    // HW2,  HW1,  HW0 ,   4'b0,  outputs_vec[ `IDX_SPI_INTERRUPT_CTL ] ,

    3'b0,
    SWITCH_SENSE_OUT, DCV_OVP_OUT, OHMS_OVP_OUT, SUPPLY_SENSE_OUT, UNUSED_2
*/






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
    . reg_seq_mode ( reg_seq_mode  ) ,

    // inputs
    . reg_status( reg_status ),

    // sequence acquisition
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
    // note we have to pad, to match register_set 32bit regs.
    // perhaps change register_set.
    .  reg_adc_clk_count_refmux_reset( { 8'b0, adc_clk_count_refmux_reset_last } ) ,
    .  reg_adc_clk_count_refmux_neg( adc_clk_count_refmux_neg_last) ,
    .  reg_adc_clk_count_refmux_pos( adc_clk_count_refmux_pos_last) ,
    .  reg_adc_clk_count_refmux_rd( { 8'b0, adc_clk_count_refmux_rd_last } ) ,
    .  reg_adc_clk_count_mux_sig( adc_clk_count_mux_sig_last ),

    .  reg_adc_stat_count_refmux_pos_up( { 8'b0, adc_stat_count_refmux_pos_up_last } ),
    .  reg_adc_stat_count_refmux_neg_up( { 8'b0, adc_stat_count_refmux_neg_up_last } ) ,
    .  reg_adc_stat_count_cmpr_cross_up( { 8'b0, adc_stat_count_cmpr_cross_up_last } )

  );



endmodule



/*

  // OLD.

  // spi
  input  SPI_CLK,
  input  SPI_CS,
  input  SPI_MOSI,
  input  SPI_CS2,
  output SPI_MISO,
  // output b

  input U1008_4094_DATA,
  input LINE_SENSE_OUT,
  input SWITCH_SENSE_OUT,
  input DCV_OVP_OUT,
  input OHMS_OVP_OUT,
  input SUPPLY_SENSE_OUT,
  input UNUSED_2,                    // change name UNUSED_2_OUT

  //
  output SPI_INTERRUPT_CTL,    // should be modeal. eg. same as meas complete
  output MEAS_COMPLETE_CTL,
    output CMPR_LATCH_CTL,

  ////////////
*/

