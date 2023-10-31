
// change name top.v

// - can have heartbeat timer. over spi.
// - if have more than one dac. then just create another register. very clean.
// - we can actually handle a toggle. if both set and clear bit are hi then toggle
// - instead of !cs or !cs2.  would be good if can write asserted(cs)  asserted(cs2)



//`include "register_set_01.v"
`include "register_set.v"

`include "mux_spi.v"
//`include "blinker.v"

// maybe change name to just sample_az. sample_no_az etc.
`include "sample_acquisition_az.v"
`include "sample_acquisition_pc.v"
`include "sample_acquisition_no_az.v"


`include "adc-test.v"

`include "mux_assign.v"


`include "defines.v"

// `include "adc_modulation_00.v"
`include "adc_modulation_01.v"





`default_nettype none




`define CLK_FREQ        20000000



/*
      SPI_INTERUPT_CTL,
      MEAS_COMPLETE_CTL,
      CMPR_LATCH_CTL,
      adcmux,                 // 23rd bit.  1<<22 = 4194304
      monitor,                // 15th bit.  1<<14 = 16384
      LED0,                   // 14th bit.  1<<13 = 8192.
      SIG_PC_SW_CTL,          // 13th bit.  1<<12.
      himux2,
      himux,
      azmux

*/

// this is the index.  not the bit number. works with +=
// needs a prefix. to distinguish. from any other.  GPO_IDX_AZMUX  or GPO_IDX_AXMUX.
// to ADC_MEAS_IDX_COUNT_UP  or ADC_IDX_COUNT_UP

`define IDX_AZMUX             0     // 0,1,2,3
`define IDX_HIMUX             4     // 4,5,6,7
`define IDX_HIMUX2            8     // 8,9,10,11
`define IDX_SIG_PC_SW_CTL     12
`define IDX_LED0              13
`define IDX_MONITOR           14    // 14,15,16,17,  18,19,20,21   think pin 14.
`define IDX_ADCMUX            22    // 22,23,24,25  .  muxes both reference currents and signal. across 2x '4053.
`define IDX_CMPR_LATCH_CTL    26
`define IDX_MEAS_COMPLETE_CTL 27      // perhaps change name meas_valid,  or sample_valid.  to reflect the trig,valid control interface.
`define IDX_SPI_INTERUPT_CTL  28


// need prefix.  or IDX_BITS   GPO_NUM_BITS IDX_END...???  or GPO_IDX_END  main output vector
`define NUM_BITS        29    //




module test_pattern (
  input   clk,


  output reg  [`NUM_BITS-1:0 ] out   // wire.kk
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






module top (

  // these are all treated as wires.

  input  CLK,



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

  // hardware flags
  input HW0,
  input HW1,
  input HW2,



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

  // leds
  output LED0,

  // monitor
  output MON0,
  output MON1,
  output MON2,
  output MON3,
  output MON4,
  output MON5,
  output MON6,
  output MON7,


  //
  output SPI_INTERUPT_CTL,    // should be modeal. eg. same as meas complete

  output MEAS_COMPLETE_CTL,

  //  adc current switches
  output U902_SW0_CTL,
  output U902_SW1_CTL,
  output U902_SW2_CTL,
  output U902_SW3_CTL,
  output CMPR_LATCH_CTL,

  ////////////


);



  ////////////////////////////////////////
  // spi muxing

  wire [32-1:0] reg_spi_mux ;// = 8'b00000001; // test


  // rather than doing individual assignments. - should just pass in anoter vector whether it's active low.
  // EXTR.  We should use an 8bit mux with 16bit toggle. rather than this complication.


  wire [8-1:0] vec_cs ;
  assign {  GLB_4094_STROBE_CTL  } = vec_cs;

  wire [8-1:0] vec_clk;
  assign { GLB_4094_CLK } = vec_clk ;   // have we changed the clock polarity.

  wire [8-1:0] vec_mosi;
  assign { GLB_4094_DATA } = vec_mosi;

  /////

  wire [8-1:0] vec_miso ;

  // only one spi device at the moment
  assign  vec_miso[ 8-1 : 1] = 7'b0;

  assign { U1004_4094_DATA } = vec_miso;


  // should be a wire. since it is only used combinatorially .   from the gpio input wire to the mux_spi where it is a wire, and then the output.
  wire w_dout ; // should be a register, since it's written to.
                  // NO. think it should be moved to mux_spi.
                    // NO. it is only used combinatorially.


  mux_spi #( )      // output from POV of the mcu. ie. fpga as slave.
  mux_spi
  (
    . reg_spi_mux(reg_spi_mux[ 8-1 : 0 ] ),
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

    . dout(w_dout),                              // use when cs active
    . vec_miso(vec_miso),                         // use when cs2 active
    . miso(SPI_MISO)                              // output pin
  );


  ////////////////////////////////////////
  // register

  // wire = no state preserved between clocks.

  // TODO change prefix to w_

  /////////////////////



  wire [32-1:0] reg_led;
  wire [32-1:0] reg_4094;   // TODO remove

  assign { _4094_OE_CTL } = reg_4094;    //  lo. start up not enabled.
  // assign { _4094_OE_CTL } = 1;    //  on for test.  should defer to mcu control. after check supplies.

  wire [32-1 :0] reg_mode;     // two bits
  wire [32-1 :0] reg_direct;
  wire [32-1 :0] reg_direct2;
  wire [32- 1 :0] reg_adc_p_aperture;  // 32/31 bit nice. for long sample.
  wire [32-1 :0] reg_reset;
  wire [32-1 :0] reg_sa_arm_trigger;

  // inputs
  wire [32 - 1 :0] reg_status ;


  // input U1004_4094_DATA,
  // input LINE_SENSE_OUT,
  // assign reg_status = 32'b0 ;



  // assign reg_status = { {(32 - 5){ 1'b0 }}, SWITCH_SENSE_OUT, DCV_OVP_OUT, OHMS_OVP_OUT, SUPPLY_SENSE_OUT, UNUSED_2 };





  // prefix these with v_ or vec_ ?
  // should perhaps be registers.
  wire [4-1:0 ] himux2 = { U402_EN_CTL, U402_A2_CTL, U402_A1_CTL, U402_A0_CTL};     // U402
  wire [4-1:0 ] himux =  { U413_EN_CTL, U413_A2_CTL, U413_A1_CTL, U413_A0_CTL };    // U413
  wire [4-1:0 ] azmux =  { U414_EN_CTL, U414_A2_CTL, U414_A1_CTL, U414_A0_CTL };    // U414

  wire [8-1: 0] monitor = { MON7, MON6, MON5,MON4, MON3, MON2, MON1, MON0 } ;

  wire [4-1:0 ] adcmux =  { U902_SW3_CTL, U902_SW2_CTL, U902_SW1_CTL, U902_SW0_CTL };    // U902





  // 4x4=16 + 8mon + 5 = 29 bits.


  wire [`NUM_BITS-1:0 ] outputs_vec = {

      SPI_INTERUPT_CTL,
      MEAS_COMPLETE_CTL,
      CMPR_LATCH_CTL,
      adcmux,                 // 23rd bit.  1<<22 = 4194304
      monitor,                // 15th bit.  1<<14 = 16384
      LED0,                   // 14th bit.  1<<13 = 8192.
      SIG_PC_SW_CTL,          // 13th bit.  1<<12.
      himux2,
      himux,
      azmux
    };


  // ok. basic function pass through works.


  wire [ `NUM_BITS-1:0 ]  test_pattern_out;
  test_pattern
  test_pattern (
    .clk( CLK),
    .out(  test_pattern_out )
  );






  // only switch pc charge. other muxes  are controlled by direct register
  wire [ `NUM_BITS-1:0 ]  sample_acquisition_pc_out ;
  sample_acquisition_pc
  sample_acquisition_pc (
    // inputs
    .clk(CLK),
    .reset( 1'b0 ), // TODO remove.
    .clk_sample_duration( reg_adc_p_aperture ),
    // outputs
    .sw_pc_ctl( sample_acquisition_pc_out[ `IDX_SIG_PC_SW_CTL ]  ),
    .led0(      sample_acquisition_pc_out[ `IDX_LED0 ] ),
    .monitor(   sample_acquisition_pc_out[ `IDX_MONITOR +: 8  ] )    // we could pass subset of monitor if watned. eg. only 4 pins...
  );

  assign sample_acquisition_pc_out[ `IDX_AZMUX +: 4]   = reg_direct[ `IDX_AZMUX +: 4];     // azmux
  assign sample_acquisition_pc_out[ `IDX_HIMUX +: 8 ]  = reg_direct[ `IDX_HIMUX +: 8 ];     // himux and hiimux 2.
  assign sample_acquisition_pc_out[ `IDX_ADCMUX +: 7 ] = reg_direct[ `IDX_ADCMUX +: 7   ];  // eg. to the end.




  /////////////////////
  /*
    - can have another mux deccoder. to hold/control the adc/modulation - using the reset pin. this would be quite nice.
    ------
    - EXTR. *remember* we want the simple adc. for various leakage/pre-charge tests.  without a real modulation,
        that is a good reason to get the flexibility . for multiple (sampler + adc ) combinations .
    --
    - advantage - is it eliminates extra. muxer for the control signals between sampler + adc.  And fixes issue with hanging.
    - advantage there is only a single mode. muxer.
    - EXTR> just use single reg_mode - to control all combinations . rather than a sample mode, and adc mode. and communication issues.
    - EXTR. advantage. allows different combinations of az-controller and different adc. with only single muxer for the outputs.
    - the adc refmux, sig. should be very easy to wire up - under the same system.
    - we can/could also pass in a reset argument. based on mode.
  */
  wire adc2_measure_trig;
  wire adc2_measure_valid;

  wire [ `NUM_BITS-1:0 ]  sample_acquisition_az_out ;     // beter name ... it is the sample control, and adc.
  wire sample_acquisition_az_adc2_measure_trig;

  sample_acquisition_az
  sample_acquisition_az (

    // inputs
    .clk(CLK),
    .reset( reg_reset[ 0 ] ),   // TODO - remove. should always be interuptable.
    .azmux_lo_val(  reg_direct[  `IDX_AZMUX +: 4 ] ),
    .adc_measure_valid(   adc2_measure_valid ),


    // outputs
    .sw_pc_ctl( sample_acquisition_az_out[ `IDX_SIG_PC_SW_CTL ]  ),
    .azmux (    sample_acquisition_az_out[ `IDX_AZMUX +: 4] ),
    .led0(      sample_acquisition_az_out[ `IDX_LED0 ] ),
    .monitor(   sample_acquisition_az_out[ `IDX_MONITOR +: 2  ] ),    // only pass 2 bit to the az monitor

    .adc_measure_trig( sample_acquisition_az_adc2_measure_trig)
  );

  assign sample_acquisition_az_out[ `IDX_HIMUX +: 8 ]		    = reg_direct[ `IDX_HIMUX +: 8 ];        // himux and hiimux 2.
  assign sample_acquisition_az_out[ `IDX_SPI_INTERUPT_CTL ] = reg_direct[ `IDX_SPI_INTERUPT_CTL ];      // TODO FIXME
  assign sample_acquisition_az_out[ `IDX_MEAS_COMPLETE_CTL] = reg_direct[ `IDX_MEAS_COMPLETE_CTL ];






  wire [ `NUM_BITS-1:0 ]  sample_acquisition_no_az_out ;  // beter name ... it is the sample control, and adc.
  wire sample_acquisition_no_az_adc2_measure_trig;

  sample_acquisition_no_az
  sample_acquisition_no_az (
    // inputs
    .clk(CLK),

    .adc_measure_valid(adc2_measure_valid),

    .arm_trigger( reg_sa_arm_trigger[0 ]  ) ,

    // outputs
    .led0(      sample_acquisition_no_az_out[ `IDX_LED0 ] ),
    .monitor(   sample_acquisition_no_az_out[ `IDX_MONITOR +: 2  ] ),    // we could pass subset of monitor if watned. eg. only 4 pins...
    .adc_measure_trig( sample_acquisition_no_az_adc2_measure_trig),

    .spi_interupt_ctl( sample_acquisition_no_az_out[`IDX_SPI_INTERUPT_CTL ] )

  );

  // pass control for muxes and pc switch to reg_direct
  assign sample_acquisition_no_az_out[ `IDX_SIG_PC_SW_CTL ] = reg_direct[ `IDX_SIG_PC_SW_CTL ];   // eg. azero off - `SW_PC_SIGNAL ;
  assign sample_acquisition_no_az_out[ `IDX_AZMUX +: 4]     = reg_direct[ `IDX_AZMUX +: 4];       // eg. azero off - `S1;  //  pc-out
  assign sample_acquisition_no_az_out[ `IDX_HIMUX +: 8 ]    = reg_direct[ `IDX_HIMUX +: 8 ];     // himux and hiimux 2.

  // we may want to keep under direct_reg control, rather than pass to sampler controller.
  // so mcu can signal after result calculation, not just after counts obtained
  assign sample_acquisition_no_az_out[ `IDX_MEAS_COMPLETE_CTL ] = reg_direct[ `IDX_MEAS_COMPLETE_CTL ];




  /*  use no_az sample acquisition for both - no azero and electrometer modes.
      pushes complexity up the stack from analog to fpga to mcu.  as soon as possible.
  */



  ////////////////


  mux_8to1_assign #( `NUM_BITS + 1 )
  mux_8to1_assign_1  (

    .a( { 1'b0, { 15 { 1'b0 } },  reg_led[ 0], { 13 { 1'b0 } } }    ),        // 0. deffault mode. 0 on all outputs, except follow reg_led, for led.
    .b( { 1'b0, { `NUM_BITS { 1'b1 } } } ),             // 1.
    .c( { 1'b0, test_pattern_out } ),                   // 2
    .d( { 1'b0, reg_direct[ `NUM_BITS - 1 :  0 ]  } ), // 3.    // when we pass a hard-coded value in here...  then read/write reg_direct works.  // it is very strange.
    .e( { 1'b0, sample_acquisition_pc_out} ),                   // 4
    .f( { sample_acquisition_az_adc2_measure_trig,    sample_acquisition_az_out } ),                   // 5
    .g( { sample_acquisition_no_az_adc2_measure_trig, sample_acquisition_no_az_out } ),                // 6
    .h( { 1'b0, { `NUM_BITS { 1'b1 } } } ),             // 7

    .sel( reg_mode[ 2 : 0 ]),
    .out( { adc2_measure_trig,  outputs_vec }  )
  );






 /////////////////////


  // TODO - remove _last suffix.
  wire [24-1:0] adc2_clk_count_mux_neg_last;
  wire [24-1:0] adc2_clk_count_mux_pos_last;
  wire [24-1:0] adc2_clk_count_mux_rd_last;
  wire [32-1:0] adc2_clk_count_mux_sig_last;



  adc_modulation
  adc2(

    .clk(CLK),
    // .reset( 1'b0 ), // not needed. always interuptable.

    // inputs
    .adc_measure_trig( adc2_measure_trig),
    .comparator_val( CMPR_P_OUT ),
/*
    clk_count_reset_n   =  10000;
    // 26MHz ???
    clk_count_var_n     = 185;    // 330pF
    clk_count_fix_n     = 24;   // 24 is faster than 23... weird.

    clk_count_aper_n    = (2 * 2000000);    // ? 200ms TODO check this.
                                            // yes. 4000000 == 10PNLC, 5 sps.
    use_slow_rundown    = 1;
    use_fast_rundown    = 1;
*/
    // ctrl parameters

    . p_clk_count_reset( 24'd10000 ) ,
    . p_clk_count_fix( 24'd24 ) ,
    . p_clk_count_var( 24'd185 ) ,

    // . p_clk_count_aper( 2 * 2000000) ,
    . p_clk_count_aper( reg_adc_p_aperture),

    . use_slow_rundown( 1'b1 ),
    . use_fast_rundown( 1'b1 ),

    // outputs - ctrl
    .adc_measure_valid( adc2_measure_valid),    // fan out.
    .cmpr_latch_ctl(sample_acquisition_no_az_out[ `IDX_CMPR_LATCH_CTL ] ),
    .monitor(   sample_acquisition_no_az_out[ `IDX_MONITOR + 2 +: 6 ] ),
    .refmux(  { sample_acquisition_no_az_out[ `IDX_ADCMUX + 3  ],  sample_acquisition_no_az_out[ `IDX_ADCMUX +: 2 ]   } ),      // pos, neg, reset. on two different 4053,
    .sigmux(    sample_acquisition_no_az_out[ `IDX_ADCMUX + 2  ] ),                                     // change name to switch perhaps?,

    // clk_count outputs, for currents
    .clk_count_mux_neg_last(  adc2_clk_count_mux_neg_last),
    .clk_count_mux_pos_last(  adc2_clk_count_mux_pos_last),
    .clk_count_mux_rd_last(   adc2_clk_count_mux_rd_last),
    .clk_count_mux_sig_last(  adc2_clk_count_mux_sig_last )

  );

  /*
	key insight - the single module adc can fan-out its outputs into two output vecs - to be active across two modes.
	-------
    this is confusing because of naming.  it's not az_out or no_az_out. instead both follow the adc_out that is driver.
    it's actually adc out. that gets outputed - to both both these vectors.
    ---
    it might be eaiser. to have another register. then assign both.
    eg.   adc_monitor, adc_ref_mux.
  */

  // az out follows no-az out -
  assign sample_acquisition_az_out[ `IDX_CMPR_LATCH_CTL ]    = sample_acquisition_no_az_out[ `IDX_CMPR_LATCH_CTL ] ;
  assign sample_acquisition_az_out[ `IDX_MONITOR + 2 +: 6 ]  = sample_acquisition_no_az_out[ `IDX_MONITOR + 2 +: 6 ];
  assign sample_acquisition_az_out[ `IDX_ADCMUX +: 4 ]   = sample_acquisition_no_az_out[ `IDX_ADCMUX +: 4 ]    ;






/*
  - sampler. - can put the valid_signal in the status register.

        mcu can then loop/while/block until changes to to get our samples.
            - eg. put these
            - rather than monitor. perhaps put in the status register. adc_valid. sa_valid.  indicating done .

        this way it is properly named. while the monitor can be configured in other ways.
    ----------
    EXTR - Also put the az stamp - whether hi or lo. in the status . and maybe a count.
          - not sure. az status should probably be read with the clk_counts.
          - or just read from the sa acquisition module state.
*/

  assign reg_status = {
    8'b0 ,
    monitor,
            HW2,  HW1,  HW0 ,   4'b0,  adc2_measure_valid,
    3'b0,   SWITCH_SENSE_OUT, DCV_OVP_OUT, OHMS_OVP_OUT, SUPPLY_SENSE_OUT, UNUSED_2
 };





  register_set // #( 32 )   // register bank  . change name 'registers'
  register_set
    (

    // should prefix fields with spi_
    . clk(SPI_CLK),
    . cs(SPI_CS),
    . din(SPI_MOSI),
    . dout( w_dout ),            // drive miso from via muxer
    // . dout( SPI_MISO ),        // drive miso output pin directly.

      // inputs
    . reg_status( reg_status ),


    // outputs
    . reg_led(reg_led),        // required as test register
    . reg_spi_mux(reg_spi_mux),
    . reg_4094(reg_4094 ) ,
    . reg_mode( reg_mode ),      // ok.
    . reg_direct( reg_direct ),
    . reg_direct2( reg_direct2 ),
    . reg_adc_p_aperture( reg_adc_p_aperture),
    . reg_reset( reg_reset),

    // outputs signal acquisiation
    .reg_sa_arm_trigger ( reg_sa_arm_trigger ),

    // outputs adc
    .reg_adc_clk_count_mux_neg( { { 8 { 1'b0 } }, adc2_clk_count_mux_neg_last }  ) ,
    .reg_adc_clk_count_mux_pos( { { 8 { 1'b0 } }, adc2_clk_count_mux_pos_last } ) ,
    .reg_adc_clk_count_mux_rd(  { { 8 { 1'b0 } }, adc2_clk_count_mux_rd_last }  ),
    .reg_adc_clk_count_mux_sig(                   adc2_clk_count_mux_sig_last   )

    );



endmodule




/*
  adc
  adc2 (
    // inputs
    .clk(CLK),
    .reset( 1'b0 ),
    .clk_sample_duration( reg_adc_p_aperture ),
    .adc_measure_trig( adc2_measure_trig),             // mux in

    // outputs
    .adc_measure_valid(adc2_measure_valid),    // fan out.
    .cmpr_latch(sample_acquisition_no_az_out[ `IDX_CMPR_LATCH_CTL ] ),
    .monitor(   sample_acquisition_no_az_out[ `IDX_MONITOR + 2 +: 6 ] ),
    .refmux(    sample_acquisition_no_az_out[ `IDX_ADCMUX +: 2 ]),      // reference current, better name?
    .sigmux(    sample_acquisition_no_az_out[ `IDX_ADCMUX + 2  ] ),      // change name to switch perhaps?,
    .resetmux(  sample_acquisition_no_az_out[ `IDX_ADCMUX + 3  ] )     // ang mux.
  );
*/


/*

-  adc_test      // this is adc-test.
-  adc1 (
-    // inputs
-    .clk(CLK),
-    .reset( 1'b0 ),   // remove always interuptable.
-    .clk_sample_duration( reg_adc_p_aperture ),
-    .adc_measure_trig( adc1_measure_trig),
-
-    // outputs
-    .adc_measure_valid(adc1_measure_valid),
-
-    .cmpr_latch(sample_acquisition_az_out[ `IDX_CMPR_LATCH_CTL ] ),
-    .monitor(   sample_acquisition_az_out[ `IDX_MONITOR + 2 +: 6 ]  ),
-    .refmux(    sample_acquisition_az_out[ `IDX_ADCMUX +: 2 ]),      // reference current, better name?
-    .sigmux(    sample_acquisition_az_out[ `IDX_ADCMUX + 2  ] ),      // change name to switch perhaps?,
-    .resetmux(  sample_acquisition_az_out[ `IDX_ADCMUX + 3  ] )     // ang mux.
-
-  );
-*/


