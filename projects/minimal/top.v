
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



// `include "../../common/mux_assign.v"

`include "register_set.v"


// `include "adc-mock.v"
// `include "refmux-test.v"

`include "adc_modulation_06.v"
`include "sequence_acquisition.v"

// `include "dual_port_ram.v"
// `include "register_set2.v"

`include "blinker.v"



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
  output reg [ 4-1: 0 ] leds_o,

  output reg [ 8-1: 0]  monitor_o,

  // input [4-1: 0]    hw_flags_i,





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


  input sa_trig_i,

  //////////////


  output [2-1:0] adc_zgjc_sw_o,

  /*
    comparators.
    consider should prefix with cmpr to be consistent
  */
  input cmpr_amp_zero_i,
  input cmpr_amp_ovld_i,
  input cmpr_amp_unld_i,
  input cmpr_boot_ch1_ovld_i,
  input cmpr_boot_ch2_ovld_i,


);



  // Feb. 2026. changed polarity handling in adc module
  wire cmpr_val = adc_cmpr_i;

  // default driver
  assign adc_zgjc_sw_o = 2'b00;


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


  wire register_set_sdo;

  assign SDO                      = ! spi_register_set_cs ? register_set_sdo : 0 ;      // park miso hi or lo ?
                                                                                        // seems to definitely like LO


  /////////////////////////


  /*
    // can use this to test spi liines

    assign monitor_o[0]  = spi_glb_clk;
    assign monitor_o[1]  = spi_glb_mosi;
    assign monitor_o[2]  = SPI_DAC_SS     ;
  */




  /////////////////////////////////////////////
  // 4094 OE
  // JA. changed feb 2026. only tested briefly with dmm. not 4094 function.
  wire [32-1:0] reg_4094_oe;
  assign spi_4094_oe = reg_4094_oe[ 0 ] ;





  ////////////////////////////////////////
  // registers

  wire [32-1:0] reg_cr;

  wire [32-1:0] reg_direct;



  // sample aquisition
  wire [32-1:0] reg_sa_p_clk_count_trig_delay;
  wire [32-1:0] reg_sa_p_clk_count_precharge;

  wire [32-1:0] reg_sa_p_seq_n;
  wire [32-1:0] reg_sa_p_seq0;
  wire [32-1:0] reg_sa_p_seq1;
  wire [32-1:0] reg_sa_p_seq2;
  wire [32-1:0] reg_sa_p_seq3;

  // adc
  wire [32-1:0] reg_adc_p_clk_count_aperture;  // 32/31 bit nice. for long sample.
  wire [32-1:0] reg_adc_p_clk_count_reset;
  wire [32-1:0] reg_adc_p_clk_count_aperture_oob;





  reg [32-1:0] reg_sr ;
/*
  // operating mode
  wire [3-1:0 ] cr_mode = reg_cr[ 3-1 : 0 ];
*/

  // adc, flag to control whether to switch sigmux on
  wire cr_adc_p_active_sigmux = reg_cr[ 3 ];

  // sa, noaz flag
  wire cr_sa_p_noaz = reg_cr[ 4 ];






  ////////////////////////////


  // adc
  wire            adc_reset_n;
  wire            adc_conversion_valid;

  wire [8-1: 0 ]  adc_monitor;
  // wire [4-1:0]  adc_status;      // TODO


  wire [2-1: 0 ]  adc_refmux;
  wire            adc_sigmux;
  wire            adc_rstmux;


  wire            adc_cmpr_latch_ctl;




  // adc input - control
  reg [32-1:0] adc_p_clk_count_aperture;


  // adc output registers to hold snapshot values

  // should all be 32 bit. to match the register_set
  reg [32-1:0] reg_adc_clk_count_rstmux;
  reg [32-1:0] reg_adc_clk_count_refmux_neg;
  reg [32-1:0] reg_adc_clk_count_refmux_pos;
  reg [32-1:0] reg_adc_clk_count_refmux_both;
  reg [32-1:0] reg_adc_clk_count_sigmux;
  reg [32-1:0] reg_adc_clk_count_aperture;

  reg [32-1:0] reg_adc_stat_count_refmux_pos_up;
  reg [32-1:0] reg_adc_stat_count_refmux_neg_up;
  reg [32-1:0] reg_adc_stat_count_cmpr_cross_up;




  // adc outputs
  wire [24-1:0] adc_clk_count_rstmux;
  wire [32-1:0] adc_clk_count_refmux_neg;
  wire [32-1:0] adc_clk_count_refmux_pos;
  wire [24-1:0] adc_clk_count_refmux_both;
  wire [32-1:0] adc_clk_count_sigmux;
  wire [32-1:0] adc_clk_count_aperture;

  wire [24-1:0] adc_stat_count_refmux_pos_up;
  wire [24-1:0] adc_stat_count_refmux_neg_up;
  wire [24-1:0] adc_stat_count_cmpr_cross_up;




  adc_modulation
  adc(

    .clk(CLK),
    .reset_n( adc_reset_n),


    .cmpr_val( cmpr_val ),                  // OK.  fan in-  rename top_cmpr_val ?

    . p_clk_count_aperture( adc_p_clk_count_aperture),

    . p_clk_count_reset( reg_adc_p_clk_count_reset[ 24-1: 0  ]  ) ,
    // . p_clk_count_fix( 24'd15 ) ,         // +-15V. reduced integrator swing.
    // . p_clk_count_var( 24'd100 ) ,

    . p_clk_count_fix( 24'd67 ) ,           // 1.5nF. 4x counts of 330p. oct. 2023. test.
    . p_clk_count_var( 24'd450 ) ,

    . p_use_slow_rundown( 1'b1 ),
    . p_use_fast_rundown( 1'b1 ),
    . p_active_sigmux( cr_adc_p_active_sigmux),

    // outputs - ctrl
    .adc_conversion_valid( adc_conversion_valid),    // OK, fan out back to the sa controllers
    .cmpr_latch_ctl( adc_cmpr_latch_ctl   ),
    .monitor(  adc_monitor  ),


    .rstmux( adc_rstmux ),
    .refmux( adc_refmux ),
    .sigmux( adc_sigmux ),

    // adc clk counts for last sample conversion
    .clk_count_rstmux(         adc_clk_count_rstmux),
    .clk_count_refmux_neg(     adc_clk_count_refmux_neg),
    .clk_count_refmux_pos(     adc_clk_count_refmux_pos),
    .clk_count_refmux_both(    adc_clk_count_refmux_both),
    .clk_count_sigmux(         adc_clk_count_sigmux),
    .clk_count_aperture(       adc_clk_count_aperture),

    // stats
    .stat_count_refmux_pos_up( adc_stat_count_refmux_pos_up),
    .stat_count_refmux_neg_up( adc_stat_count_refmux_neg_up),
    .stat_count_cmpr_cross_up( adc_stat_count_cmpr_cross_up)

  );





  /*
    status_o should be treated/managed generically - just like monitor_o and leds_o.  for each controller (sequence,adc etc).
      like a generic service to a module
    eg. try to conform to same/standard bit width.
    - call it status_last ... because it is for the completed conversion, not current.
  */

  //////////////////

  wire [2-1:0]  sequence_acquisition2_pc_sw;
  wire [4-1:0]  sequence_acquisition2_azmux;


  wire [3-1:0]  sequence_acquisition2_sample_idx;
  wire          sequence_acquisitionr2_sample_first;

  wire          sequence_acquisition2_adc_reset_n;
  wire          sequence_acquisition2_adc_conversion_start;



  wire [7-1:0]  sequence_acquisition2_state;



  sequence_acquisition
  sequence_acquisition2 (

    .clk(CLK),
    .reset_n( sa_trig_i ),

    // inputs
    .adc_conversion_valid_i( adc_conversion_valid ),

    .p_clk_count_trig_delay_i( reg_sa_p_clk_count_trig_delay),
    .p_clk_count_precharge_i( reg_sa_p_clk_count_precharge[ 24-1:0]),

    .p_seq_n_i( reg_sa_p_seq_n[ 3-1: 0]  ),
    .p_seq0_i( reg_sa_p_seq0[ 6-1: 0]  ),
    .p_seq1_i( reg_sa_p_seq1[ 6-1: 0]  ),
    .p_seq2_i( reg_sa_p_seq2[ 6-1: 0] ),
    .p_seq3_i( reg_sa_p_seq3[ 6-1: 0] ),

    .p_noaz_i( cr_sa_p_noaz ),


    // outputs

    .state(       sequence_acquisition2_state),

    .pc_sw_o(     sequence_acquisition2_pc_sw  ),
    .azmux_o (    sequence_acquisition2_azmux  ),


    .sample_idx_o(   sequence_acquisition2_sample_idx),       // careful/tricky - because  will be initialized to 0.  which is the same as if the first reading.
    .sample_first_o( sequence_acquisitionr2_sample_first),

    // control the adc
    .adc_reset_no( sequence_acquisition2_adc_reset_n ),
    .adc_conversion_start_o ( sequence_acquisition2_adc_conversion_start)


    /*

      pass reg_direct here.  to support a modeal control and register control of outputs.

    .reg_direct( sequence_acquisition2_reg_direct)
    */

  );






  reg [ 4-1:0] blinker_out;

  blinker
  blinker /* (  4 )*/  (

    .clk(CLK),
    // .reset_n( sa_trig
    .out( blinker_out)
  );





  /*
      try to make leds and monitor should be non-intrusive  on modules
      means must be instantiated top level
  */


  always @(posedge CLK)
    begin

      // non-intrusive
      // note clock delay
      monitor_o[ 0]       <= sequence_acquisition2_adc_conversion_start;
      monitor_o[ 1]       <= adc_conversion_valid;

      // eg. other inputs
      // monitor_o[ 2]       <= adc_reset_no;
      // monitor_o[ 2]       <= pc_sw_o[ 0 ];


      // intrusive. the adc code the monitor state
      monitor_o[ 2 +: 6]  <= adc_monitor;
    end



  always @(posedge CLK)
    begin

      /* in reset drive leds with blinker pattern
        note the copy involves a clock propagation delay
          so this approach - of selecting inputs does not generalize
      */

      if( sequence_acquisition2_state == 0)
        leds_o  <= blinker_out;

      else
        leds_o  <= 4'd1 << sequence_acquisition2_sample_idx;

    end








  reg oob_aperture;

  always @(posedge CLK)
    begin


      // adc conversion start
      if( sequence_acquisition2_adc_conversion_start)
        begin

          // set adc aperture.
          if( sequence_acquisitionr2_sample_first)
            begin

            adc_p_clk_count_aperture  <= reg_adc_p_clk_count_aperture_oob;
            oob_aperture              <= 1'b1;
            end
          else
            begin

            adc_p_clk_count_aperture  <= reg_adc_p_clk_count_aperture;
            oob_aperture              <= 1'b0;
            end
        end
    end



  reg interrupt_valid;

  // record comparator states seen during sample using 2 bit state
  reg [2-1:0] cmpr_amp_zero;
  reg [2-1:0] cmpr_amp_ovld;
  reg [2-1:0] cmpr_amp_unld;


  // it makes sense to maintain the concept of a hi here
  wire is_hi ;
  assign is_hi = sequence_acquisition2_sample_idx == 3'b0
            || sequence_acquisition2_sample_idx == 3'd2;


  always @(posedge CLK)
    begin

      /* HI is even by convention.
          consider change  this to idx modulo 2 == 0
          no hard code since modulo can be expensive to synthesize if not power of 2.
      */

      if( sequence_acquisition2_adc_reset_n && is_hi)
        begin

          // normal HI sample
          if( cmpr_amp_ovld_i)  cmpr_amp_ovld[ 0] <= 1'b1;
          else                  cmpr_amp_ovld[ 1] <= 1'b1;

          if( cmpr_amp_unld_i)  cmpr_amp_unld[ 0] <= 1'b1;
          else                  cmpr_amp_unld[ 1] <= 1'b1;

          if( cmpr_amp_zero_i)  cmpr_amp_zero[ 0] <= 1'b1;
          else                  cmpr_amp_zero[ 1] <= 1'b1;

        end
        else
        begin

          // any other state
          // clear ready for next HI sample
          cmpr_amp_ovld   <= 2'b00;
          cmpr_amp_unld   <= 2'b00;
          cmpr_amp_zero   <= 2'b00;

        end





      // only assert interrupt for one clock cycle
      interrupt_valid                   <= 1'b0;
      // interrupt_flags <= { 4'b0000 };


      // wait for adc conversion
      if( adc_conversion_valid)
        begin

          // snapshot register state after a valid conversion
          // handle padding for 24 bit registers here

          // counts
          reg_adc_clk_count_rstmux        <= { 8'b0, adc_clk_count_rstmux };
          reg_adc_clk_count_refmux_neg    <= adc_clk_count_refmux_neg;
          reg_adc_clk_count_refmux_pos    <= adc_clk_count_refmux_pos;
          reg_adc_clk_count_refmux_both   <= { 8'b0, adc_clk_count_refmux_both } ;
          reg_adc_clk_count_sigmux        <= adc_clk_count_sigmux;
          reg_adc_clk_count_aperture      <= adc_clk_count_aperture;

          // stats
          reg_adc_stat_count_refmux_pos_up <= { 8'b0, adc_stat_count_refmux_pos_up } ;
          reg_adc_stat_count_refmux_neg_up <= { 8'b0, adc_stat_count_refmux_neg_up } ;
          reg_adc_stat_count_cmpr_cross_up <= { 8'b0, adc_stat_count_cmpr_cross_up } ;


          /*
          stat_count_var_up_last      <= stat_count_var_up;
          stat_count_var_down_last    <= stat_count_var_down;
          stat_count_fix_up_last      <= stat_count_fix_up;
          stat_count_fix_down_last    <= stat_count_fix_down;
          stat_count_flip_last        <= stat_count_flip;
          */


          /*  snapshot sa, adc conversion, and comparator state
          */
          reg_sr <= {
            // 32
            {
                4'b0,
                cr_adc_p_active_sigmux,
                cr_sa_p_noaz,
                is_hi,            // dynamic
                oob_aperture      // dynamic
            },
            // 24
            {   1'b0,                                     // 1
                reg_sa_p_seq_n[ 3-1: 0] ,                 // 3      // this is dumb.  should just record the azmux state in 4 bits.
                sequence_acquisitionr2_sample_first,      // 1 bit
                sequence_acquisition2_sample_idx          // 3 bits.
            },
            // 16
            {   //  3'b0,
                cmpr_boot_ch2_ovld_i,
                cmpr_boot_ch1_ovld_i,
                cmpr_amp_unld,
                cmpr_amp_ovld,
                cmpr_amp_zero                             // 2
            },
            // 8
            { 4'b0001 },  // interrupt source flags
            { 4'b1010 }   // magic
          };


          interrupt_valid <= 1'b1;
          // interrupt_flags[ 0]  <= 1'b1;

        end
        else
        begin

          /* put any other interrupts that are drivers for the status register and interupt_valid flag.
              here
          */


        end           // not completed a vaid adc conversion
    end               // synchronous block








    /*
      - avoid combinatorial logic after registers on outputs
        less possibility of sub-clk timing variation/issues
        and makes timing analysis harder
        ---
        also the az sequencer - is the place to implement direct control over
        azmux,pc for slow running tests.
        rather than using reg_direct.
        ----
        just need a register to select the start state/pattern.

        the az-sequencer - can include several patterns.
        the state-machine can load the required input, at the start of the cycle
    */

    assign adc_reset_n          = sequence_acquisition2_adc_reset_n;  // adc_reset_n      // 25 + 1
    assign spi_interrupt_ctl_o  = interrupt_valid;                    // spi_interupt     // 23 + 1

    assign adc_cmpr_latch_ctl_o = adc_cmpr_latch_ctl;                 // adc_cmpr_latch   // 22+1

    assign adc_sigmux_o         = adc_sigmux;
    assign adc_rstmux_o         = adc_rstmux;
    assign adc_refmux_o         = adc_refmux;                         // adc muxes // 18+4

    assign azmux_o              = sequence_acquisition2_azmux;        // azmux            // 14+4
    assign pc_sw_o              = sequence_acquisition2_pc_sw;        // precharge            // 12+2



  /*
    note mcu can write data into the status flags from mode,
    this is a simple way to communicate back from fpga to mcu
    and maintainis good event sequence - hi,lo, 4 cycle. etc.
    -----
  */



  // spi fills without this ? memory alignment issue?
  // does not see the addr properly
  reg dummy;
  reg dummy2;
  reg dummy3;

/*

  register_set2 // #( 32 )
  register_set2
    (
    .system_clk( CLK),

    // consider prefix fields with spi_
    .clk(  SCK ),
    .cs_n( spi_register_set_cs),
    .din(  SDI ),
    .dout( dummy    )

  );
*/


  register_set // #( 32 )
  register_set
    (

    // consider prefix fields with spi_
    .clk(  SCK ),
    .cs_n( spi_register_set_cs),
    .din(  SDI ),
    .dout(  register_set_sdo /* SDO  */ ),


    // inputs
    .reg_4094_oe(    reg_4094_oe ) ,
    .reg_cr(         reg_cr),
    .reg_direct(     reg_direct),

    // outputs
    .reg_sr(     reg_sr ),


    // parameter inputs - sample acquisition.
    .reg_sa_p_clk_count_trig_delay(      reg_sa_p_clk_count_trig_delay),
    .reg_sa_p_clk_count_precharge(       reg_sa_p_clk_count_precharge),

    .reg_sa_p_seq_n( reg_sa_p_seq_n),
    .reg_sa_p_seq0(  reg_sa_p_seq0),
    .reg_sa_p_seq1(  reg_sa_p_seq1),
    .reg_sa_p_seq2(  reg_sa_p_seq2),
    .reg_sa_p_seq3(  reg_sa_p_seq3),

    // parameter inputs - adc
    .reg_adc_p_clk_count_aperture(       reg_adc_p_clk_count_aperture),
    .reg_adc_p_clk_count_reset(          reg_adc_p_clk_count_reset ),
    .reg_adc_p_clk_count_aperture_oob(   reg_adc_p_clk_count_aperture_oob),


    // adc outputs
    .reg_adc_clk_count_refmux_neg(      reg_adc_clk_count_refmux_neg) ,
    .reg_adc_clk_count_refmux_pos(      reg_adc_clk_count_refmux_pos) ,
    .reg_adc_clk_count_refmux_both(     reg_adc_clk_count_refmux_both) ,
    .reg_adc_clk_count_rstmux(          reg_adc_clk_count_rstmux),
    .reg_adc_clk_count_sigmux(          reg_adc_clk_count_sigmux),
    .reg_adc_clk_count_aperture(        reg_adc_clk_count_aperture),


    .reg_adc_stat_count_refmux_pos_up(  reg_adc_stat_count_refmux_pos_up),
    .reg_adc_stat_count_refmux_neg_up(  reg_adc_stat_count_refmux_neg_up) ,
    .reg_adc_stat_count_cmpr_cross_up(  reg_adc_stat_count_cmpr_cross_up)

  );



endmodule


/*

  // only need to raise one interrupt per measurement cycle. this is
  reg cmpr_amp_oob_raised = 1'b0;


          if( !
              ( sequence_acquisition2_adc_reset_n
              && (sequence_acquisition2_sample_idx == 3'b0        // HI is even by convention. change  this to idx modulo 2 == 0
              ||  sequence_acquisition2_sample_idx == 3'd2))
            )
            begin

              // not an active high conversion - keep flag cleared - ready for next active hi
              cmpr_amp_oob_raised <= 1'b0;
            end
            else
            begin

              /*
                during active phase of adc HI conversion, we monitor the amp_ovld for transitions
                - behavior is now to generate max, one interrupt for an input overload condition for the duration of the conversion.
              * /


              if((cmpr_amp_ovld_i             // amp-out out of range. above abs max
                || ! cmpr_amp_unld_i)         // amp-out out of range. dip below abs min
                && ! cmpr_amp_oob_raised      // and no interrupt raised
                )
                begin

                  // set that we already raised an interrupt for this measure
                  cmpr_amp_oob_raised             <= 1'b1;

                  // clear adc counts from last conversion, avoid confusion

                  // counts
                  reg_adc_clk_count_rstmux        <= 32'b0;
                  reg_adc_clk_count_refmux_neg    <= 32'b0;
                  reg_adc_clk_count_refmux_pos    <= 32'b0;
                  reg_adc_clk_count_refmux_both   <= 32'b0;
                  reg_adc_clk_count_sigmux        <= 32'b0;
                  reg_adc_clk_count_aperture      <= 32'b0;

                  // stats
                  reg_adc_stat_count_refmux_pos_up <= 32'b0;
                  reg_adc_stat_count_refmux_neg_up <= 32'b0;
                  reg_adc_stat_count_cmpr_cross_up <= 32'b0;


                  reg_sr <= {
                    // 32
                    8'b0,
                    // 24
                    {   1'b0,                                 // 1
                        reg_sa_p_seq_n[ 3-1: 0] ,             // 3 // this is dumb.  should just record the azmux state in 4 bits.
                        sequence_acquisitionr2_sample_first,         // 1 bit
                        sequence_acquisition2_sample_idx      // 3 bits.
                    },
                    // 16
                    { 3'b0, cmpr_boot_ch2_ovld_i, cmpr_boot_ch1_ovld_i, cmpr_amp_unld_i, cmpr_amp_ovld_i, cmpr_amp_zero_i },
                    // 8
                    { 4'b0010 },  // interrupt source flags
                    { 4'b1010 }   // magic
                  };


                  interrupt_valid <= 1'b1;
                  // interrupt_flags[ 1 ]  <= 1'b1;

                end   // ovld transition

            end       // active HI sample

*/




  /*
     note - if a controller is unused in a mode - it would be nice to hold it in reset.
      can do by exposing the reset_n, and only turning it on, if active within the specific mode.
  */

  /*
    note - hanging this combinatorial logic on the output registers
    may increase variation in output propagation delay
  */

/*

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


    // mode  6  sample/sequence acquisition with mocked adc.  and better monitor
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
          sequence_acquisition_pc_sw,         // 12+2
          sequence_acquisition_monitor[ 0 +: 8],    // 4+8
          sequence_acquisition_leds           // 0+1
        } ),



    // mode 7. sequence acquisition controller and full adc.
    // needs trig asserted.
   .h( {  { 32 - 26 { 'b0 }},
                                              // 26
          sequence_acquisition2_adc_reset_n,  // adc_reset_n      // 25 + 1

          1'b0,                               // dummy bit.       // 24+1
          interrupt_valid,                       // spi_interupt     // 23 + 1

          adc_cmpr_latch_ctl,                 // adc_cmpr_latch   // 22+1

          adc_sigmux,
          adc_rstmux,
          adc_refmux,                         // adc muxes // 18+4

          sequence_acquisition2_azmux,        // azmux            // 14+4
          sequence_acquisition2_pc_sw,        // precharge            // 12+2
          // adc_monitor[ 0 +: 6], sequence_acquisition2_monitor[ 0 +: 2],    // 4+8
          adc_monitor[ 0 +: 6],  sequence_acquisition2_monitor[ 4],  sequence_acquisition2_monitor[ 0],    // 4+8.   eg. hi/lo, if ch1 pc is active
          sequence_acquisition_leds           // 0+4
        } ),


    .sel( cr_mode ),

    // leds and monitor go first, since they are the most generic functionality

    .out( {
          dummy_bits_o,                       // 26

          adc_reset_n,                        // 25 + 1

          dummy_bit2_o,                       // 24+1     // interupt_ctl *IS* generic so should be at start, and connects straight to adum. so place at beginning. same argument for meas_complete
          spi_interrupt_ctl_o,                // 23+1     todo rename. drop the 'ctl'.
          adc_cmpr_latch_ctl_o,               // 22+1

          adc_sigmux_o,
          adc_rstmux_o,
          adc_refmux_o,                       // adc muxes 18+4

          azmux_o,                            // 14+4
          pc_sw_o,                            // 12+2
          monitor_o,                          // 4+8
          leds_o                              // 0+4
        }  )

  );

  */




