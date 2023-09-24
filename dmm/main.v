
// change name top.v

// - can have heartbeat timer. over spi.
// - if have more than one dac. then just create another register. very clean.
// - we can actually handle a toggle. if both set and clear bit are hi then toggle
// - instead of !cs or !cs2.  would be good if can write asserted(cs)  asserted(cs2)



`include "register_set.v"
`include "mux_spi.v"
`include "blinker.v"
// `include "modulation_az.v"





/*
  TODO
  module myreset a soft reset module...
  that decodes an spi command/address/value, and resets all lines.

  need to think how to handle peripheral reset.
*/








`default_nettype none


// set by 4094. set by blinker.  set by test modulation.

// mux choice.
// eg. https://www.chipverify.com/verilog/verilog-4to1-mux

module mux_4to1_assign #(parameter MSB =12)   (
   input [MSB-1:0] a,
   input [MSB-1:0] b,
   input [MSB-1:0] c,
   input [MSB-1:0] d,

   input wire [1:0] sel,               // 2bits. input sel used to select between a,b,c,d
   output [MSB-1:0] out);

   assign out = sel[1] ? (sel[0] ? d : c) : (sel[0] ? b : a);

endmodule


/*
  - for mcu direct control of fpga mode. consider making the register-bank big enough to fit all fpga output bits. if needed.
  - or split into two.
  ----
  - working with single bit-vectors eases things.
*/

// better name.  output control.
// `define NUM_BITS        13
// `define NUM_BITS        14    // with led
`define NUM_BITS        22    // with monitor.   this actually fits in a 24 bit register. just. to allow a mcu control mode.




`define CLK_FREQ        20000000



`define SOFF      4'b0000
`define S1        4'b1000

            // himux2 <= 4'b1011;  // select ground to clear charge on cap.    s4 - A400-5 gnd. / 8|(4-1).

module test_accumulation_cap (

  input   clk,
  input   reset,     // async

  output [`NUM_BITS-1:0 ] out

);

  // clk_count for the current phase. 31 bits is faster than 24 bits. weird. ??? 36MHz v 32MHz
  reg [31:0]    clk_count = 0;

  // destructure
  reg [4-1:0] azmux;
  reg [4-1:0] himux;
  reg [4-1:0] himux2;
  reg sig_pc_sw_ctl;
  reg led0;

  reg [8-1: 0] monitor;//  = { MON7, MON6, MON5,MON4, MON3, MON2, MON1, MON0 } ;

  // nice.
  assign { monitor, led0, sig_pc_sw_ctl, himux2, himux,  azmux } = out;

  /* perhaps create some macros for MUX_1OF8_S1.
    // not sure.  can represent 8|(4-1)   for s4. etc.
    // most code is not going to care. there will just be a register for the zero, and a register for the signal.
  */

  // Can move to reset. but might as well set in the block.
  // assign sig_pc_sw_ctl = clk_count;

  // it would actually be  nice to have control over the led here.  we need a mode state variable.
  // and the interupt. actually.
  // sampling the charge - is a bit difficult.  because this is a kind of input modulation...
  /*
      - actually this functionality - *can* be incorporated into regular AZ switching and measurement.
        the gnd and the off signal.  are just the normal 2 mode AZ.

      - But not charge-injection testing.  actually maybe even charge injection.
  */

  // always @(posedge clk  or posedge reset )
  always @(posedge clk  or posedge reset )
   if(reset)
    begin
      clk_count <= 0;
    end
    else
    begin

      clk_count <= clk_count + 1;   // positive clk

      // we can trigger on these if we want
      case (clk_count)
        0:
          begin
            // off
            monitor <= 0;
            azmux  <= 0;
            sig_pc_sw_ctl <= 0;

            // muxes
            himux   <=  4'b1001;  // s2 select himux2.  for leakage test this should be off.
            himux2  <= 4'b1011;  // select ground to clear charge on cap.    s4 - A400-5 gnd. / 8|(4-1).
            led0    <= 0;
          end

        `CLK_FREQ * 1:
          begin
            himux2 <= 4'b1000;  // s1 select dcv-source-hi.  actually for real.  actually we would turn off to test leakage.
                                // need to be high-z mode to measure.  or measure from op-amp.

            led0    <= 1;
          end

        `CLK_FREQ * 2:
          clk_count <= 0;


      endcase

    end

endmodule





module test_pattern (
  input   clk,
  output [`NUM_BITS-1:0 ] out
);
  // clk_count for the current phase. 31 bits is faster than 24 bits. weird. ??? 36MHz v 32MHz
  reg [31:0]   counter = 0;

  // destructure
  reg [4-1:0] azmux;
  reg [4-1:0] himux;
  reg [4-1:0] himux2;
  reg sig_pc_sw_ctl;
  reg led0;
  reg [8-1: 0] monitor;
  // nice.
  assign { monitor, led0, sig_pc_sw_ctl, himux2, himux,  azmux } = out;

  localparam LOG2DELAY = 22;

  assign  led0  = counter >> LOG2DELAY;  // continuous assignment, generates warning but ok here.

  always@(posedge clk) begin
    counter <= counter + 1;
    monitor <= monitor + 1;
  end

endmodule






module top (

  // these are all treated as wires.

  input  CLK,


  output MON0,
  output MON1,
  output MON2,
  output MON3,
  output MON4,
  output MON5,
  output MON6,
  output MON7,



  // leds
  output LED0,

  // spi
  input  SPI_CLK,
  input  SPI_CS,
  input  SPI_MOSI,
  input  SPI_CS2,
  output SPI_MISO,
  // output b

  output SPI_INTERUPT_OUT,



  //////////////////////////
  // 4094
  output _4094_OE_CTL,

  output GLB_4094_CLK,
  output GLB_4094_DATA,
  output GLB_4094_STROBE_CTL,
  input U1004_4094_DATA,   // this is unused. but it's an input


  ///////////////

  // pre-charge
  output SIG_PC_SW_CTL,


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

  // azmux
  output U414_A0_CTL,
  output U414_A1_CTL,
  output U414_A2_CTL,
  output U414_EN_CTL,

);


  // reg dummy;


  ////////////////////////////////////////
  // spi muxing

  wire [24-1:0] reg_spi_mux ;// = 8'b00000001; // test


  // rather than doing individual assignments. - should just pass in anoter vector whether it's active low.
  // EXTR.  We should use an 8bit mux with 16bit toggle. rather than this complication.


  wire [8-1:0] vec_cs ;
  assign {  GLB_4094_STROBE_CTL  } = vec_cs;

  wire [8-1:0] vec_clk;
  assign { GLB_4094_CLK } = vec_clk ;   // have we changed the clock polarity.

  wire [8-1:0] vec_mosi;
  assign { GLB_4094_DATA } = vec_mosi;

  wire [8-1:0] vec_miso ;
  assign { U1004_4094_DATA } = vec_miso;    // this isn't right ... it is spi_miso?//


  // jeezus.

  // dout for fpga spi.
  // need to rename. it's an internal dout... that can be muxed out.
 //  wire my_dout ;
  reg my_dout ; // should be a register, since it's written to.



  mux_spi #( )      // output from POV of the mcu. ie. fpga as slave.
  mux_spi
  (
    . reg_spi_mux(reg_spi_mux),
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

    . dout(my_dout),                              // use when cs active
    . vec_miso(vec_miso),                         // use when cs2 active
    . miso(SPI_MISO)                              // output pin
  );


  ////////////////////////////////////////
  // register

  // wire = no state preserved between clocks.

  // TODO change prefix to w_

  wire [24-1:0] reg_led;
  // assign {  LED0 } = reg_led;

  wire [24-1:0] reg_4094;   // TODO remove
  // assign { _4094_OE_CTL } = reg_4094;


  // should be a register??cj because not connected to otuput wires.

  // because this is a register rather than a wire?????

  // reg [24-1:0] reg_mode;     // = 8'b00000001; // test
  wire [1:0] reg_mode;     // two bits

  // EXTR. registers MUST have > 24 bits. for writer.
  // test pattern - turn everything off. doesn't need to be a reg.
  // EXTR. pass this to the register bank.
  // reg [`NUM_BITS-1:0] reg_direct ;
  wire [24 - 1 :0] reg_direct ;    // EXTR truncated.


  register_set // #( 32 )   // register bank  . change name 'registers'
  register_set
    (
    . clk(SPI_CLK),
    . cs(SPI_CS),
    . din(SPI_MOSI),
    . dout( my_dout ),            // drive miso from via muxer
    // . dout( SPI_MISO ),        // drive miso output pin directly.

    // registers
    . reg_led(reg_led),        // required as test register
    . reg_spi_mux(reg_spi_mux),
    . reg_4094(reg_4094 ) ,

    . reg_mode( reg_mode ),      // ok.

    . reg_direct( reg_direct )

  );


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


  /////////////////////
  assign { _4094_OE_CTL } = 1;    //  on for test.  should defer to mcu control. after check supplies.



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

  // prefix these with v_ or vec_ ?
  // should perhaps be registers.
  wire [4-1:0 ] himux2 = { U402_EN_CTL, U402_A2_CTL, U402_A1_CTL, U402_A0_CTL};     // U402
  wire [4-1:0 ] himux =  { U413_EN_CTL, U413_A2_CTL, U413_A1_CTL, U413_A0_CTL };    // U413
  wire [4-1:0 ] azmux =  { U414_EN_CTL, U414_A2_CTL, U414_A1_CTL, U414_A0_CTL };    // U414

  wire [8-1: 0] monitor = { MON7, MON6, MON5,MON4, MON3, MON2, MON1, MON0 } ;

  wire [`NUM_BITS-1:0 ] w_conditioning_out = {
      monitor,
      LED0,                   // 1<<13
      SIG_PC_SW_CTL,
      himux2,
      himux,
      azmux
    };



  // TODO. try putting the register set last.   then can pass the w_conditioning_out straight into the block.

  // assign w_conditioning_out = test_pattern_out ;
  assign w_conditioning_out = reg_direct ;




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


endmodule










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


