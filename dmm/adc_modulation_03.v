

`default_nettype none

////////////////////////////


/*
  see,
    https://www.eevblog.com/forum/projects/multislope-design/75/
    https://patentimages.storage.googleapis.com/e2/ba/5a/ff3abe723b7230/US5200752.pdf
*/

// advantage of macros over localparam enum, is that they generate errors if not defined.
// disdvantage is that it is easy to forget the backtick



`define STATE_DONE          0  // initial state

`define STATE_RESET_START    1    
`define STATE_RESET          2
`define STATE_SIG_SETTLE_START 3
`define STATE_SIG_SETTLE    4
`define STATE_SIG_START     5
`define STATE_FIX_POS_START 6
`define STATE_FIX_POS       7
`define STATE_VAR_START     8
`define STATE_VAR           9
`define STATE_FIX_NEG_START 10
`define STATE_FIX_NEG       11
`define STATE_VAR2_START    12
`define STATE_VAR2          14
`define STATE_RUNDOWN_START 15
`define STATE_RUNDOWN       16

`define STATE_PRERUNDOWN    18
`define STATE_PRERUNDOWN_START 19

`define STATE_FAST_BELOW_START 20
`define STATE_FAST_BELOW    21

`define STATE_FAST_ABOVE_START 22
`define STATE_FAST_ABOVE    23



/*
  ref mux state.
  Note that this combines two 4053 switch..
*/

`define MUX_REF_NONE        3'b000      // TODO review - not sure if ever wanted. use reset state as default state.
`define MUX_REF_POS         3'b001
`define MUX_REF_NEG         3'b010
`define MUX_REF_SLOW_POS    3'b011
`define MUX_REF_RESET       3'b100






module adc_modulation (


  input           clk,

  // inout           reset,  // JA


  // JA added
  input adc_measure_trig,         // wire. start measurement.

  // comparator input
  input           comparator_val,

  //
  // rename
  // or  just p_fix , p_var.  p indicates a control parameter, and that using is clock count.
  // or p_clk_count_reset   and drop the _n suffix.
  // or p_cc_reset, p_cc_fix  etc.
  input [24-1:0]  p_clk_count_reset,    // useful if running stand-alone
  input [24-1:0]  p_clk_count_fix,
  inout [24-1:0]  p_clk_count_var,
  input [32-1:0]  p_clk_count_aper,   // eg. clk_count_mux_sig_n
                                          // names are correct. aperture is the control parameter,  and mux_sig_count is the current clk count, and should correspond.


  input           p_use_slow_rundown,     // TODO prefix with p_. to indicate . an adc control parameter.
  input           p_use_fast_rundown,


  // outputs

  output reg adc_measure_valid,     // adc is master, and asserts valid when measurement complete

  // now a wire
  output wire [ 6-1:0]  monitor,

  output reg [ 3-1:0]  refmux,     // reference current, better name?
  output reg sigmux,

  output reg      cmpr_disable_latch_ctl,


  ///////////

  // behavior/transition counts
  output reg [24-1:0] count_var_up_last,        // var_up. perhaps rename.
  output reg [24-1:0] count_var_down_last,
  output reg [24-1:0] count_trans_up_last,
  output reg [24-1:0] count_trans_down_last,
  output reg [24-1:0] count_fix_up_last,
  output reg [24-1:0] count_fix_down_last,
  output reg [24-1:0] count_flip_last,
  output reg [24-1:0] clk_count_rundown_last, // change name. phase rundown.


  // TODO. change to 32 bit counts, for long integrations
  // current source clk counts
  // these are output regs.
  // having visibility over reset clk is good, given ctrl and the reset period.
  output reg [24-1:0] clk_count_mux_reset_last,
  output reg [24-1:0] clk_count_mux_neg_last,
  output reg [24-1:0] clk_count_mux_pos_last,
  output reg [24-1:0] clk_count_mux_rd_last,
  output reg [32-1:0] clk_count_mux_sig_last      // names are correct. aperture is the control parameter,  and mux_sig_count is the current clk count, and should correspond.

);


  /*
    we need to review all this input / output.
    and input wire can still be driven.
  */

  reg [5-1:0]   state;

  /*
     EXTR. could be useful to spi query the current state
    - could then determine that were updated during the reset period. and we don't have to call reset again.
  */

  // initial begin does seem to be supported.
  initial begin
    // state           = `STATE_RESET_START;   // 0
    state           = `STATE_DONE ;   // 0

    cmpr_disable_latch_ctl  = 1; // disable comparator,

  end

  //////////////////////////////////////////////////////
  // counters and settings  ...

  reg [31:0]  clk_count;           // clk_count for the current phase. 31 bits is faster than 24 bits. weird. ??? 36MHz v 32MHz
  reg [31:0]  clk_count_down; 

  // modulation counts
  reg [24-1:0] count_var_up;
  reg [24-1:0] count_var_down;
  reg [24-1:0] count_trans_up;
  reg [24-1:0] count_trans_down;
  reg [24-1:0] count_fix_up;
  reg [24-1:0] count_fix_down;
  reg [24-1:0] count_flip;


  // TODO change to 31 bits.
  reg [24-1:0] clk_count_mux_reset;
  reg [24-1:0] clk_count_mux_neg;
  reg [24-1:0] clk_count_mux_pos;
  reg [24-1:0] clk_count_mux_rd;
  reg [32-1:0] clk_count_mux_sig ;      // should be the same as p_aperture.  eg. 5sec*20MHz=100m count. won't fit in 24 bit value. would need to split between read registers.


  /////////////////////////
  // this should be pushed into a separate module...
  // should be possible to set latch hi immediately on any event here...
  // change name  zero_cross.. or just cross_

  // TODO move this into the main block.

  // TODO  three bits, because comparator_val is not on clock boundary
  // or use comaprator_val_last
  reg [2:0] crossr;
  always @(posedge clk)
    crossr <= {crossr[1:0], comparator_val};

  wire cross_up     = (crossr[2:1]==2'b10);  // message starts at falling edge
  wire cross_down   = (crossr[2:1]==2'b01);  // message stops at rising edge
  wire cross_any    = cross_up || cross_down ;


  ////////

  // to check that
  reg [1:0] pos_ref_cross;
  reg [1:0] neg_ref_cross;


  // reg [ 4-1:0]  monitor_;

  assign monitor[0] = adc_measure_trig;
  assign monitor[1] = adc_measure_valid;

  assign monitor[ 2 +: 4]  = { sigmux, refmux };      // reference current, better name?
  // output reg sigmux,
 //  assign monitor[2 +: 4 ] = monitor_;




  reg comparator_val_last;

  always @(posedge clk)


    begin


      // always increment clk for the current phase
      clk_count     <= clk_count + 1;

      clk_count_down <= clk_count_down - 1;



      // sample/bind comparator val once on clock edge. improves speed.
      comparator_val_last <=  comparator_val;

      // TODO change name ref_sw_pos_cross
      // instrumentation for switch transitions for both pos,neg (and both).
      pos_ref_cross <= { pos_ref_cross[0], refmux[0] }; // old, new
      neg_ref_cross <= { neg_ref_cross[0], refmux[1] };

      // TODO count_pos_trans or cross pos_  or just count_pos_trans
      // TODO must rename. actually represents count of each on switch transiton = count_ref_pos_on and count_ref_neg_on.
      if(pos_ref_cross == 2'b01)
        count_trans_up <= count_trans_up + 1;

      if(neg_ref_cross == 2'b01)
        count_trans_down <= count_trans_down + 1;


      /*
        EI. could actually use this strategy of reading the mux values - to count total clk times.
        and avoid having to return count and clk to mcu separately.
        ----
        it might also be more cycle accurate - given the phase transition setup, and comparator reads etc.
        but would need 32 bit values.
        - reduces spi overhead. if supported 32 byte reads.
        - reduces littering of count_var_up/count_var_down
        - reduces having to multiply out clk_count_var * count_var_up etc.
        - enables having non standar variable periods. eg. to reduce extra cycling to get to the other side.
        ------
            the way to evaluate is to use stderr(regression).
      */

      // synchronous behavior for all states

      case (refmux)

        `MUX_REF_NEG:
            clk_count_mux_neg <= clk_count_mux_neg + 1;

        `MUX_REF_POS:
            clk_count_mux_pos <=  clk_count_mux_pos + 1;

        `MUX_REF_SLOW_POS:  // TODO change name to REF_BOTH. or REF_RD slow.
            clk_count_mux_rd <= clk_count_mux_rd + 1;

        `MUX_REF_NONE:
          ; // switches are turned off at start. and also at prerundown.
            // don't really need to count this

        `MUX_REF_RESET:
            clk_count_mux_reset <= clk_count_mux_reset + 1;


      endcase
      // count_pos_on


      if(sigmux )
        // while integrating the signal
        begin
          // increment aperture clk count
          clk_count_mux_sig <= clk_count_mux_sig + 1;

          // ======================================
          // aperture count termination condition.
          // changed oct 30, 2023..  IMPORTANT. DIFFERENCEs MAY AFFECT calibration calculation.
          // should be a count down
          // now revert.
          // NO. it may have been mcu roudinig. issue. reg_aperture. has the off-by-one. calculation
          // NO. we have it configured differently.
          // OK. it doesn't matter whether aperture runs - for one more extra clk cycle. or one less here.  nov 3. 2023.
          //    eg. clk termination condition doesn't matter.
          //    instead what matters is that the count is recorded in the same way as the counts for the reference currents.
          //    so mcu should use the returned count, rather than the aperture control parameter
          // =======================================

          // have we reached end of aperture
          if(clk_count_mux_sig >= p_clk_count_aper)                  // original. slope-adc-3.
          // if(clk_count_mux_sig >= (p_clk_count_aper - 1) )              // changed oct 30, 2023..  IMPORTANT. DIFFERENCEs MAY AFFECT calibration calculation.

            begin
              // turn off signal input
              sigmux  <= 0;

              // swith himux to ref-lo, to prevent leakage, but switching instability probably worse
              // himux   <= `HIMUX_SEL_REF_LO;
            end
        end


      case (state)

        // IMPORTANT. might can improved performance by reducing the reset and sig-settle times
        // reset time is also used for settle time.


        `STATE_DONE:
          begin
              // default resting state.

              cmpr_disable_latch_ctl          <= 1; // disable comparator,

              // we come here from the default start state.
              // signal valid.
              adc_measure_valid <= 1;

              // turn of sigmux, and reset integrator
              sigmux          <= 0;
              refmux          <= `MUX_REF_RESET;

          end




        `STATE_RESET_START:
          begin

            // de-assert valid measurement, since beginnging new
            adc_measure_valid <= 0;

            // reset vars, and transition to runup state
            state           <= `STATE_RESET;

            clk_count_mux_reset <= 0;   // clear count to start

            // must be set for the reset phase.
            clk_count       <= 0;

            clk_count_down   <= p_clk_count_reset;

            // JA
            sigmux          <= 0;
            refmux          <= `MUX_REF_RESET;

            cmpr_disable_latch_ctl          <= 1; // // disable comparator, enable latch


          end



        `STATE_RESET:    // let integrator reset.
          begin
            // if(clk_count >= p_clk_count_reset)
            if(clk_count_down == 0)
              state <= `STATE_SIG_START;

          end


        // beginning of signal integration
        `STATE_SIG_START:
          begin
            state             <= `STATE_FIX_POS_START;
            clk_count         <= 0;

            /////////////////////////////
            // TODO ... all of these should be setup in the real start condition/ done.
            // clear the counts
            count_var_up      <= 0;
            count_var_down    <= 0;
            count_fix_up      <= 0;
            count_fix_down    <= 0;
            count_trans_up    <= 0;
            count_trans_down  <= 0;
            count_flip        <= 0;

            // clk_count_mux_reset <= 0;  do not overwrite... reset. in other clause.
            clk_count_mux_neg <= 0;
            clk_count_mux_pos <= 0;
            clk_count_mux_rd  <= 0;
            clk_count_mux_sig <= 0;

            // turn on signal input, to start signal integration
            sigmux            <= 1;
            refmux            <= `MUX_REF_NONE; // turn off reset.

          end


        // cycle +-ref currents, with/or without signal
        `STATE_FIX_POS_START:
          begin
            state         <= `STATE_FIX_POS;
            clk_count     <= 0;
            count_fix_down <= count_fix_down + 1;
            refmux        <= `MUX_REF_POS; // initial direction


            cmpr_disable_latch_ctl  <= 0; // enable comparator, // JA correct. 0 means it is transparent.
          end

        `STATE_FIX_POS:
          /*
          // half way through first fix, enable the comparator
          if(clk_count >= (p_clk_count_fix >> 1))
            // cmpr_disable_latch_ctl  <= 0
          */
          if(clk_count >= p_clk_count_fix)       // walk up.  dir = 1
            begin
              state <= `STATE_VAR_START;

              // cmpr_disable_latch_ctl  <= 0; // enable comparator, we test the comparator_last value in the next clock cycle - not enough time...

            end


        // variable direction
        `STATE_VAR_START:
          begin
            state         <= `STATE_VAR;
            clk_count     <= 0;

            if( comparator_val_last)   // test below the zero-cross
              begin
                refmux    <= `MUX_REF_NEG;  // add negative ref. to drive up.
                count_var_up  <= count_var_up + 1;
              end
            else
              begin
                refmux    <= `MUX_REF_POS;
                count_var_down <= count_var_down + 1;
              end
          end

        /*
          should use === for equality. avoids high-z case.
        */
        // we are confusing neg. pos. and up. down.   neg == up. pos == down.

        `STATE_VAR:
          if(clk_count >= p_clk_count_var)
            state <= `STATE_FIX_NEG_START;


        `STATE_FIX_NEG_START:
          begin
            state         <= `STATE_FIX_NEG;
            clk_count     <= 0;
            count_fix_up  <= count_fix_up + 1;
            refmux        <= `MUX_REF_NEG;
          end

        `STATE_FIX_NEG:
          // TODO add switch here for 3 phase modulation variation.
          if(clk_count >= p_clk_count_fix)
            state <= `STATE_VAR2_START;

        // variable direction
        `STATE_VAR2_START:
          ///////////
          // EXTR.  actually since we stopped injecting signal - it doesn't matter how many cycles we use to get above zero-cross.
          // and it will happen reasonably quickly. because of the bias.
          // so just keep running complete 4 phase cycles until we get a cross. rather than force positive vars.
          //////////
          begin
            state         <= `STATE_VAR2;
            clk_count     <= 0;

            if( comparator_val_last) // below zero-cross
              begin
                refmux    <= `MUX_REF_NEG;
                count_var_up  <= count_var_up + 1;
              end
            else
              begin
                refmux    <= `MUX_REF_POS;
                count_var_down <= count_var_down + 1;
              end
          end

        /*
          E. IMPORTANT
          - solution to jump immediately to pre/rundown. without extra cycling.
            is just to keep adding up fix periods until above cross.

        */
        `STATE_VAR2:
          if(clk_count >= p_clk_count_var)
            begin
              // signal integration finished.
              if( !sigmux)

                if(p_use_fast_rundown)
                  begin
                    if(  comparator_val_last) // below cross
                      state <= `STATE_FAST_BELOW_START;
                    else                      // above cross
                      state <= `STATE_FAST_ABOVE_START;
                  end
                else
                  begin
                    // above cross and last var was up phase
                    if( refmux  == `MUX_REF_NEG && ! comparator_val_last)
                      state <= `STATE_PRERUNDOWN_START;
                    else
                      // keep cycling
                      state <= `STATE_FIX_POS_START;

                      count_flip <= count_flip + 1;
                  end

              // signal integration not finished
              else
                  // do another cycle
                  state <= `STATE_FIX_POS_START;
            end


        // fast rundown.
        // add small fix phases until we are in a position to do slow rundown
        // TODO change name FAST_RD

        // add small down phases. until below
        `STATE_FAST_ABOVE_START:
           begin
            state     <= `STATE_FAST_ABOVE;
            clk_count <= 0;
            refmux    <= `MUX_REF_POS;
            end

        `STATE_FAST_ABOVE:
          if(clk_count >= p_clk_count_fix)
            begin
             if( comparator_val_last) // below zero-cross
              state   <= `STATE_FAST_BELOW_START;     // go to the above
            else
              state   <= `STATE_FAST_ABOVE_START;     // do another cycle
            end


        // add small up phases until above
        `STATE_FAST_BELOW_START:
           begin
            state     <= `STATE_FAST_BELOW;
            clk_count <= 0;
            refmux    <= `MUX_REF_NEG;
            end

        `STATE_FAST_BELOW:
          if(clk_count >= p_clk_count_fix)
            begin
             if( ! comparator_val_last) // above zero-cross
              state   <= `STATE_PRERUNDOWN_START;   // go to prerundown
            else
              state   <= `STATE_FAST_BELOW_START;   // do another cycle
            end



        ////////////////////////////////////////////
        // the end of signal integration. is different to the end of the 4 phase cycle.
        // we want a gpio pin. to hit on pre-rundown.

        `STATE_PRERUNDOWN_START:
           begin
            state     <= `STATE_PRERUNDOWN;
            clk_count <= 0;
            /*
                we don't care about landing above the zero-cross. in 4 phase we care about ending on a downward var.
                thatway we can add a up transition.  before doing the downward transition (for slow) rundown.
                to balance the up/down transitions.
                the upward phase - then needs to be enough to push over the zero-cross.  but that is secondary.
                ----------
            */
            refmux    <= `MUX_REF_NONE;
          end

        // It has to be MUX_NONE

        `STATE_PRERUNDOWN:
          // Should drive above the cross.
          // EXTR. this can just keep driving up, without transitions, and testing until hit the zero cross.
          // No. i think it would actually depend on whether the last /
          // then we get
          if(clk_count >= p_clk_count_fix)
            state <= `STATE_RUNDOWN_START;




        `STATE_RUNDOWN_START:
          begin
            state         <= `STATE_RUNDOWN;
            clk_count     <= 0;

            /*
              IMPORTANT. we are not counting a possible switch transition here.
              Bug?
            */
            if( p_use_slow_rundown )
              // turn on both references - to create +ve bias, to drive integrator down.
              refmux      <= `MUX_REF_SLOW_POS;
            else
              // fast rundown
              refmux      <= `MUX_REF_POS;
          end


        `STATE_RUNDOWN:
          begin
            // TODO change to comparator_val test.
            // zero-cross to finish. should probably change to use last_comparator
            if(cross_any )
              begin

                cmpr_disable_latch_ctl          <= 1; // disable comparator,

                // trigger for scope
                // transition
                state                   <= `STATE_DONE;
                clk_count               <= 0;    // ok.

                // turn of sigmux, and reset integrator
                sigmux          <= 0;
                refmux          <= `MUX_REF_RESET;

                // com_interrupt            <= 0;   // active lo, set interrupt

                // record behaviior/transition counts asap. on this immeidate clk cycle.
                count_var_up_last           <= count_var_up;
                count_var_down_last         <= count_var_down;
                count_trans_up_last     <= count_trans_up; // OK. this works.
                count_trans_down_last   <= count_trans_down;
                count_fix_up_last       <= count_fix_up;
                count_fix_down_last     <= count_fix_down;
                count_flip_last         <= count_flip;
                clk_count_rundown_last  <= clk_count;                           // why do we record this

                // counts for current.

                                                // clk_count_mux_reset;
                // clk_count_mux_reset_last <= 456; // this works to communicate
                // clk_count_mux_reset_last <= p_clk_count_reset;    // this works. reports 10,000
                clk_count_mux_reset_last <= clk_count_mux_reset;    // this doesn't work. reports 0.


                clk_count_mux_neg_last  <= clk_count_mux_neg;
                clk_count_mux_pos_last  <= clk_count_mux_pos;
                clk_count_mux_rd_last   <= clk_count_mux_rd;
                clk_count_mux_sig_last  <= clk_count_mux_sig;                  // aperture. is the ctrl parameter for signal introduced..
                                                                            // TODO. rename clk_count_mux_sig.

                // signal valid.
                adc_measure_valid <= 1;

              end
          end



      endcase


        // adc is interruptable/ can be triggered to start at any time.
        if(adc_measure_trig == 1)
          begin

            state <= `STATE_RESET_START;

          end




    end


endmodule


