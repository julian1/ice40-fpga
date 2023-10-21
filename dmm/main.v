
// change name top.v

// - can have heartbeat timer. over spi.
// - if have more than one dac. then just create another register. very clean.
// - we can actually handle a toggle. if both set and clear bit are hi then toggle
// - instead of !cs or !cs2.  would be good if can write asserted(cs)  asserted(cs2)



`include "register_set.v"
`include "mux_spi.v"
//`include "blinker.v"


`include "modulation_az.v"
`include "modulation_pc.v"
`include "modulation_no_az.v"
`include "modulation_em.v"

`include "adc.v"

`include "mux_assign.v"








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

`define IDX_AZMUX             0     // 0,1,2,3
`define IDX_HIMUX             4     // 4,5,6,7
`define IDX_HIMUX2            8     // 8,9,10,11
`define IDX_SIG_PC_SW_CTL     12
`define IDX_LED0              13
`define IDX_MONITOR           14    // 14,15,16,17,  18,19,20,21   think pin 14.
`define IDX_ADCMUX            22    // 22,23,24,25
`define IDX_CMPS_LATCH_CTL    26
`define IDX_MEAS_COMPLETE_CTL 27
`define IDX_SPI_INTERUPT_CTL  28


// change name IDX_END...???  main output vector
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




  // spi
  input  SPI_CLK,
  input  SPI_CS,
  input  SPI_MOSI,
  input  SPI_CS2,
  output SPI_MISO,
  // output b



  //////////////////////////
  // 4094
  output _4094_OE_CTL,

  output GLB_4094_CLK,
  output GLB_4094_DATA,
  output GLB_4094_STROBE_CTL,
  input  U1004_4094_DATA,   // this is unused. but it's an input


  ///////////////
  // outputs - used modally.

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

  input U1004_4094_DATA,
  input LINE_SENSE_OUT,
  input SWITCH_SENSE_OUT,
  input DCV_OVP_OUT,
  input OHMS_OVP_OUT,
  input SUPPLY_SENSE_OUT,
  input UNUSED_2                    // change name UNUSED_2_OUT



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

  wire [32-1:0] reg_mode;     // two bits

  wire [32 - 1 :0] reg_direct;
  wire [32 - 1 :0] reg_direct2;
  wire [32-1 : 0] reg_clk_sample_duration;  // 32/31 bit nice. for long sample.

  wire [32 - 1 :0] reg_status ;


  // input U1004_4094_DATA,
  // input LINE_SENSE_OUT,
  // assign reg_status = 32'b0 ;
  assign reg_status = { 27'b0 , SWITCH_SENSE_OUT, DCV_OVP_OUT, OHMS_OVP_OUT, SUPPLY_SENSE_OUT, UNUSED_2 };



  register_set // #( 32 )   // register bank  . change name 'registers'
  register_set
    (
    . clk(SPI_CLK),
    . cs(SPI_CS),
    . din(SPI_MOSI),
    . dout( w_dout ),            // drive miso from via muxer
    // . dout( SPI_MISO ),        // drive miso output pin directly.

    // registers
    . reg_led(reg_led),        // required as test register
    . reg_spi_mux(reg_spi_mux),
    . reg_4094(reg_4094 ) ,

    . reg_mode( reg_mode ),      // ok.

    . reg_direct( reg_direct ),
    . reg_direct2( reg_direct2 ),

    . reg_clk_sample_duration( reg_clk_sample_duration),

    . reg_status( reg_status )
  );

  ///////////////////////////




  // prefix these with v_ or vec_ ?
  // should perhaps be registers.
  wire [4-1:0 ] himux2 = { U402_EN_CTL, U402_A2_CTL, U402_A1_CTL, U402_A0_CTL};     // U402
  wire [4-1:0 ] himux =  { U413_EN_CTL, U413_A2_CTL, U413_A1_CTL, U413_A0_CTL };    // U413
  wire [4-1:0 ] azmux =  { U414_EN_CTL, U414_A2_CTL, U414_A1_CTL, U414_A0_CTL };    // U414

  wire [8-1: 0] monitor = { MON7, MON6, MON5,MON4, MON3, MON2, MON1, MON0 } ;

  wire [4-1:0 ] adcmux =  { U902_SW3_CTL, U902_SW2_CTL, U902_SW1_CTL, U902_SW0_CTL };    // U902


  // 4x4=16 + 8mon + 5 = 29 bits.

  wire [`NUM_BITS-1:0 ] w_conditioning_out = {

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


  wire adc_take_measure;
  wire adc_take_measure_done;

  adc
  adc (
    // inputs
    .clk(CLK),
    .reset( 1'b0 ),
    .clk_sample_duration( reg_clk_sample_duration ),
    .adc_take_measure( adc_take_measure),  // wire

    // outputs
    .adc_take_measure_done(adc_take_measure_done)
  );




  wire [ `NUM_BITS-1:0 ]  modulation_az_out ;
  modulation_az
  modulation_az (

    // remember himux is not manipulated, or passed to this module.
    // instead the hi signal is selected by the AZ mux, via the pre-charge switch
    // and himux is controlled using reg-direct.

    // inputs
    .clk(CLK),
    .reset( 1'b0 ),
    .azmux_lo_val(  reg_direct[  `IDX_AZMUX +: 4 ] ),       // expand width for fpga control of himux/himux2. for ratiometric, and AG cycle.  (boot,or sig).
    // .clk_sample_duration( reg_clk_sample_duration ),
    .adc_take_measure_done(adc_take_measure_done),



    // outputs
    .sw_pc_ctl( modulation_az_out[ `IDX_SIG_PC_SW_CTL ]  ),
    .azmux (    modulation_az_out[ `IDX_AZMUX +: 4] ),
    .led0(      modulation_az_out[ `IDX_LED0 ] ),
    .monitor(   modulation_az_out[ `IDX_MONITOR +: 2  ] ),    // only pass 2 bit to the az monitor

    .adc_take_measure( adc_take_measure)
  );

  assign modulation_az_out[ `IDX_HIMUX +: 8 ]  = reg_direct[ `IDX_HIMUX +: 8 ];     // himux and hiimux 2.
  assign modulation_az_out[ `IDX_ADCMUX +: 7 ] = reg_direct[ `IDX_ADCMUX +: 7   ];  // eg. to the end.

  // pass other bits of monitor to the adc
  assign modulation_az_out[ `IDX_MONITOR + 2 +: 6 ] = { 6 { 1'b0 } };




  // TODO move up. before the az stuff.
  // only switch pc charge. other muxes  are controlled by direct register
  wire [ `NUM_BITS-1:0 ]  modulation_pc_out ;
  modulation_pc
  modulation_pc (
    // inputs
    .clk(CLK),
    .reset( 1'b0 ),
    .clk_sample_duration( reg_clk_sample_duration ),
    // outputs
    .sw_pc_ctl( modulation_pc_out[ `IDX_SIG_PC_SW_CTL ]  ),
    .led0(      modulation_pc_out[ `IDX_LED0 ] ),
    .monitor(   modulation_pc_out[ `IDX_MONITOR +: 8  ] )    // we could pass subset of monitor if watned. eg. only 4 pins...
  );

  assign modulation_pc_out[ `IDX_AZMUX +: 4]   = reg_direct[ `IDX_AZMUX +: 4];     // azmux
  assign modulation_pc_out[ `IDX_HIMUX +: 8 ]  = reg_direct[ `IDX_HIMUX +: 8 ];     // himux and hiimux 2.
  assign modulation_pc_out[ `IDX_ADCMUX +: 7 ] = reg_direct[ `IDX_ADCMUX +: 7   ];  // eg. to the end.




  wire [ `NUM_BITS-1:0 ]  modulation_no_az_out ;
  modulation_no_az
  modulation_no_az (
    // inputs
    .clk(CLK),
    .reset( 1'b0 ),
    .clk_sample_duration( reg_clk_sample_duration ),
    // outputs
    .sw_pc_ctl( modulation_no_az_out[ `IDX_SIG_PC_SW_CTL ]  ),
    .azmux (    modulation_no_az_out[ `IDX_AZMUX +: 4] ),
    .led0(      modulation_no_az_out[ `IDX_LED0 ] ),
    .monitor(   modulation_no_az_out[ `IDX_MONITOR +: 8  ] )    // we could pass subset of monitor if watned. eg. only 4 pins...
  );

  assign modulation_no_az_out[ `IDX_HIMUX +: 8 ]  = reg_direct[ `IDX_HIMUX +: 8 ];     // himux and hiimux 2.
  assign modulation_no_az_out[ `IDX_ADCMUX +: 7 ] = reg_direct[ `IDX_ADCMUX +: 7   ];  // eg. to the end.



  wire [ `NUM_BITS-1:0 ]  modulation_em_out ;
  modulation_em
  modulation_em (
    // inputs
    .clk(CLK),
    .reset( 1'b0 ),
    .clk_sample_duration( reg_clk_sample_duration ),
    // outputs
    .sw_pc_ctl( modulation_em_out[ `IDX_SIG_PC_SW_CTL ]  ),
    .azmux (    modulation_em_out[ `IDX_AZMUX +: 4] ),
    .led0(      modulation_em_out[ `IDX_LED0 ] ),
    .monitor(   modulation_em_out[ `IDX_MONITOR +: 8  ] )    // we could pass subset of monitor if watned. eg. only 4 pins...
  );

  assign modulation_em_out[ `IDX_HIMUX +: 8 ]  = reg_direct[ `IDX_HIMUX +: 8 ];     // himux and hiimux 2.
  assign modulation_em_out[ `IDX_ADCMUX +: 7 ] = reg_direct[ `IDX_ADCMUX +: 7   ];  // eg. to the end.





  mux_8to1_assign #( `NUM_BITS )
  mux_8to1_assign_1  (

    // when we change the order of these things - it fucks up.

    // default mode.
    // actually not sure, if shouldn't blink led on own counter.
    // actually might be better 0 - blink on counter, while cpu can set to mode 1. to blink in response to reg.
    // .a( { `NUM_BITS { 1'b0 } } ),            // 0 .
    .a(  {   { 15 { 1'b0 } },  reg_led[ 0],   { 13 { 1'b0 } } }    ),        // 0. it's easier to see what is going on if fpga comes up under mcu control.

    .b( { `NUM_BITS { 1'b1 } } ),            // 1.
    .c( test_pattern_out ),                  // 2
    .d( reg_direct[ `NUM_BITS - 1 :  0 ]   ),  // 3.    // when we pass a hard-coded value in here...  then read/write reg_direct works.  // it is very strange.
    // .e( test_pattern_2_out ),
    .e( modulation_pc_out),                   // 4
    .f( modulation_az_out),                   // 5
    .g( modulation_no_az_out),                // 7
    .h( modulation_em_out ),                  // 8

    .sel( reg_mode[ 2 : 0 ]),

    .out( w_conditioning_out )
  );


endmodule









/*
  reg[ `NUM_BITS-1:0 ]  test_pattern_out_2;
  test_pattern
  test_pattern_2 (
    .clk( CLK),

    .out(  test_pattern_out_2 )
  );

*/


/*
module test_pattern (
  input   clk,


  input [`NUM_BITS-1:0 ]      default_out ,       // gets passed reg_direct...   why not just set a bit???? in
  output reg  [`NUM_BITS-1:0 ] out   // wire.kk
);

  // clk_count for the current phase. 31 bits is faster than 24 bits. weird. ??? 36MHz v 32MHz
  reg [31:0]   counter = 0;

  always@(posedge clk  )
      begin

        counter <= counter + 1;
        if( default_out)       // non zero.
          begin
            out  <= default_out ;                         //   ok. this works on first mux. but 4094 relay doesn't work.  how?. why?
          end
        else
          begin

            // works all monitor pins.
            // remove the himux2  reg_direct value is not working.
            out[ 17 : 0 ]  <= out [ 17  : 0   ] + 1;

          end
      end

endmodule

*/


/*
  // assign w_conditioning_out = reg_direct ;

  // TODO. try putting the register set last.   then can pass the w_conditioning_out straight into the block.


  // mux_4to1_assign #( `NUM_BITS )
  mux_4to1_assign #( 24 )
  mux_4to1_assign_1  (

   .a( reg_direct ),  // 00
   .b( reg_direct ),        // 01  mcu controllable... needs a better name  mode_test_pattern. .   these are modes...
   .c( reg_direct ),     // 10
   .d( reg_direct ),         // 11

    // when we changed this from 32 bit int default to 22 bit it worked.
   .sel( 24'b0 ),                           // So. we want to assign this to a mode register.   and then set it.
   // .sel( reg_mode ),                           // So. we want to assign this to a mode register.   and then set it.
   .out( w_conditioning_out )
  );
*/


/*
module mux_4to1_assign #(parameter MSB =24)   (
   input [MSB-1:0] a,
   input [MSB-1:0] b,
   input [MSB-1:0] c,
   input [MSB-1:0] d,

   // input [1:0] sel,               // 2bits. input sel used to select between a,b,c,d
   input [24-1 :0] sel,               // 2bits. input sel used to select between a,b,c,d
   // output [MSB-1:0] out
   output [22-1:0] out

  );

  //  also fails
   // assign out = sel[1] ? (sel[0] ? d : c) : (sel[0] ? b : a);

   // assign out = a;  // ok.  now fails.... bizarre
   // assign out = b;  // ok.

   assign out = sel[0] ? a : a;     // works.
   // assign out = sel[0] ? a : b;     // relay fails????



  //  this doesn't work - led doesn't reflect change. and it generates a warning about a wire assignment.
  // even though combinatority
//  always @  *  begin
 //   case (sel)
//
 //     0 :       out = a;
  //    default : out = a;
   // endcase
//  end



endmodule

*/



/*
    "reg cannot be assigned with a continuous assignment"
    so this is wrong.

  reg [`NUM_BITS-1:0 ] w_conditioning_out ;
  assign  {
      monitor,
      LED0,
      SIG_PC_SW_CTL,
      himux2,
      himux,
      azmux
    } = w_conditioning_out;
*/

  /*
    we probably want to add the led to this. and the pre-charge switch.
    and the monitor.
    for the monitor.   eg. monitor could just be assigned at top level. rather than be mode specific
    OR. just use another mux_4to1. for the monitor.
  */

/*
  // change name counter0_out
  reg [`NUM_BITS-1:0] counter0_out;
  counter  #( `NUM_BITS )    // MSB is number of bits
  counter0
  (
    .clk(CLK),
    .out( counter0_out)
  );


  reg [`NUM_BITS-1:0] test_pattern_out;
  test_pattern
  test_pattern (
    .clk( CLK),
    .out(  test_pattern_out)
  );



  //
  // change reg name to test_accumulation_cap_out.
  reg [`NUM_BITS-1:0] test_accumulation_cap_out;  // for test accumulation.
  test_accumulation_cap
  test_accumulation_cap (
    .clk( CLK),
    .reset(0),    // active hi. reconsider... but we lose timing anaylysis
    . out(  test_accumulation_cap_out)

  );




*/


/*


  mux_4to1_assign #( `NUM_BITS )
  mux_4to1_assign_1  (

   .a( test_pattern_out ),  // 00
   .b( reg_direct ),        // 01  mcu controllable... needs a better name  mode_test_pattern. .   these are modes...
   .c( test_pattern_out ),     // 10
   .d( test_pattern_out ),         // 11

   // .sel( 2'b00 ),                           // So. we want to assign this to a mode register.   and then set it.
   .sel( reg_mode ),                           // So. we want to assign this to a mode register.   and then set it.
   .out( w_conditioning_out )
  );
*/


  // reg [3:0] vec_dummy;

/*
  blinker #(  )
  blinker
    (
    .clk( CLK ),
    // .vec_leds( { MON7, MON6, MON5, MON4, MON3 , MON2, MON1, dummy  } )
    .vec_leds( { LED0, vec_dummy } )
  );
*/




  // conditioning.
  // I think we do want to pass the pre-charge switch.  remember thiso
  // EXCEPT  - not all test functions will need it.

  // think it makes sense to pass logically together as group..
  // likewise. adc.  will be the four current switches. and adc latch.

  // output led. can be passed in separate muxer.

  // it may be better to group by mux .
  // TODO . should have enable pin.   last - same as when controlled by 4094.


  /*
      conditioning switching outputs.
      these are not the complete set of outputs for a module. but eases  handling of mode muxing.
      en. order inputs the same as

      structure and  pattern destructure on the otherside like .
      ----------

      Actually it might be easier to group everything.
      add the led.
      add the adc switches.
      comparator latch.
      monitor.
      ext interupt.  that data is ready.
      ---
      the led is a useful visual indicator. fpga wants to take control of it.
      -------

      REMEMBER inputs (comparator) line-sense etc. are easy. they just fan out to whatever module needs them.

  */





  // Put the strobe as first.
  // monitor isolator/spi,                                                  D4          D3       D2       D1        D0
  // assign { MON7, MON6, MON5, MON4, MON3 , MON2, MON1 /* MON0 */ } = {  SPI_MISO, SPI_MOSI, SPI_CLK,  SPI_CS  /* RAW-CLK */} ;

//  assign { MON7, MON6, /*MON5,*/ MON4, MON3 , MON2, MON1 /* MON0 */ } = {  SPI_MISO, SPI_MOSI, SPI_CLK,  SPI_CS  /* RAW-CLK */} ;

  // assign { MON7, MON6, MON5, MON4, MON3 , MON2, MON1 /* MON0 */ } = {  _4094_OE_CTL  /* RAW-CLK */} ;

  // monitor the 4094 spi                                                 D6       D5             D4            D3              D2              D1                 D0
  // assign { MON7, MON6, MON5, MON4, MON3 , MON2, MON1 /* MON0 */ } = {  SPI_CLK, SPI_CS2, U1004_4094_DATA, GLB_4094_DATA, GLB_4094_CLK, GLB_4094_STROBE_CTL  /* RAW-CLK */} ;


  // monitor the 4094 spi                                               D4            D3              D2              D1                 D0
  // assign { MON7, MON6, MON5, MON4, MON3 , MON2, MON1 /* MON0 */ } = {  _4094_OE_CTL, GLB_4094_DATA, GLB_4094_CLK, GLB_4094_STROBE_CTL  /* RAW-CLK */} ;

  //                                                                       D5           D4        D3        D2       D1        D0
  // assign { MON7, MON6, MON5, MON4, MON3 , MON2, MON1 /* MON0 */ } = { _4094_OE_CTL,   SPI_MISO, SPI_MOSI, SPI_CLK,  SPI_CS  /* RAW-CLK */} ;
  // assign { MON7, MON6, MON5, MON4, MON3 , MON2, MON1 /* MON0 */ } = 0  ;

  // ok. this does work.
  // assign SPI_MISO = 1;


/*
  /////////////////////////////////////////////
  //

  // Now we probably don't want the

  wire [8-1: 0] monitor = { MON7, MON6, MON5,MON4, MON3, MON2, MON1, MON0 } ;


  reg [8-1:0] vec_mon_counter;      // mode0_w_conditioning_out

  // change name counter_mon.
  counter  counter1(
    .clk(CLK),
    .out( vec_mon_counter )
  );


  reg [8-1:0] vec_dummy8 = 0;   // mode0_w_conditioning_out

  mux_4to1_assign  #( 8 )
  mux_4to1_assign_2 (

   .a( vec_dummy8),
   .b( vec_dummy8),
   .c( vec_mon_counter),      // mode.
   .d( vec_dummy8),

   .sel( 2'b10 ),
   .out( monitor )
  );


*/



/*

  // mux_hi  does not need to gokkkkkkkkkkkk
  reg [6-1:0 ] mux_hi ;
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

  */



/*
  // mux hi
  reg [3-1: 0] u413 = 3'b110; // s7 == DCV-IN
  assign { U413_A2_CTL, U413_A1_CTL, U413_A0_CTL } = u413;    //  turn on DCV. 7 - 1?   on for test.  nice. measures 125R.

  // mux hi 2.
  reg [3-1: 0] u402 = 3 - 1 ; // s3 == unconnected/ hi-z input == off.
  assign { U402_A2_CTL, U402_A1_CTL, U402_A0_CTL } = u402;
*/


