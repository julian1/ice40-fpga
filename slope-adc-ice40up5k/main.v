/*
  switching of the high-side mux is a little tricky.
    eg. do we switch the feedback signal to reset integrator - at the start of rundown or the finish of rundown?
    there will be a small leakage current current through the low side mux. but better to not have the integrator loop and buffer op swinging around during this time.
    ------

  it is a two variable model,
    reset-time (op buffers slope feedback).  then setup-time (op buffers signal ).

  ----------
  - under 30MHz. and it seems to be unstable / the integration  starts to have slight timing deviations observable on scope.
  - need to try nextpnr.  see if it improves.
  - removing unused counts used for test/debug. appears that may actually improve speed. and reduce power consumption
  - still need to add the reset phase to integrator

  - the registerbank/spi code. probably should be more synchronous/ pipelined.

  - we could in fact get rid of the counts. and just count the total pos/neg clks. for all phases - fixed/var/rundown.
      this wold be fast and simple.
  - one-hot encoding
      http://asics.chuckbenz.com/OneHotCodingBestPractices.htm
  -----------


  Auto-zero and Auto-cal.

    auto-zero
      - need the switching to be done in the fpga.
      just swapping the input.
      or should only be a couple of lines of code.

    and acal/gain.
      is just measuring the ref-hi .  every so often. eg. once every 10obs.

      - think this would just need to be a separate verilog module.
      either switchable state machine.  on every data generated.

    - then the data read - will have a flag as to what is loaded.
      - NO. not separate state-machine strategies.  because may want to do both together.
      - eg.   autozero every second measurement.
      - and   acal     every 10th   measurement.

    - we need a flag with the returned data. as to what the value represents.

    - having modes - for what is sampled - ref-hi, ref-lo, sig-hi is usefulful.
        then just add two numbers. and use modulus as to when to do azero, acal .


*/




// ‘default_nettype none  // turn off implicit data types


// so it doesn't matter where it goes
// general,mix start 0
`define REG_LED                 7
`define REG_TEST                8

// control/param vars
// we don't necessarily need to expose all these
// just set once in pattern controller.
// modulation control parameters, start 30.
`define REG_CLK_COUNT_RESET_N   10
`define REG_CLK_COUNT_FIX_N     11
// `define REG_CLK_COUNT_VAR_N  12
`define REG_CLK_COUNT_VAR_POS_N 13
`define REG_CLK_COUNT_VAR_NEG_N 14
`define REG_CLK_COUNT_APER_N_LO 15
`define REG_CLK_COUNT_APER_N_HI 16

`define REG_USE_SLOW_RUNDOWN    17
`define REG_HIMUX_SEL           18       // keep in register bank. pass dummy var, if don't use.
`define REG_PATTERN             19
`define REG_RESET               20// hold modulation in reset.


// meas/run vars
`define REG_COUNT_UP            30  // need to start at 30
`define REG_COUNT_DOWN          31
`define REG_COUNT_TRANS_UP      32
`define REG_COUNT_TRANS_DOWN    33
`define REG_COUNT_FIX_UP        34
`define REG_COUNT_FIX_DOWN      35
`define REG_CLK_COUNT_RUNDOWN   37


// treat as param variable
`define REG_LAST_HIMUX_SEL           40 // what was being muxed for integration. sig, azero, acal .
`define REG_LAST_CLK_COUNT_FIX_N     41
`define REG_LAST_CLK_COUNT_VAR_POS_N 42
`define REG_LAST_CLK_COUNT_VAR_NEG_N 43
`define REG_LAST_CLK_COUNT_APER_N_LO 44
`define REG_LAST_CLK_COUNT_APER_N_HI 45


`define REG_MEAS_COUNT          50

// we don't need this... only required, if do permute
//  and we could just write bit flags into himux_sel



/*
  --------
    We shouldn't need to read the control parameters used back.
    if instead we always write. and have proper sequencing control with mcu.
    -----
    but fast changing parameters (eg. azero, again ) need lost of work.

  ********
  - returning last_himux_sel enables support for pattern controller.
  - and easier handling of collect_obs()  because we just record the himux_sel as a variable.

  ********

*/




`define HIMUX_SEL_SIG_HI      4'b1110
`define HIMUX_SEL_REF_HI      4'b1101
`define HIMUX_SEL_REF_LO      4'b1011
`define HIMUX_SEL_ANG         4'b0111




/*
  registers
    - verilog reg should be defined in top
    - injected into register_bank as inout if read/writable
    - injected into controllers as readable.

*/

module my_register_bank   #(parameter MSB=32)   (

  // spi
  input  clk,
  input  cs,
  input  din,       // sdi
  output dout,       // sdo

  // input == input wire

  // control read/write control vars
  // use ' inout',  must be inout to write
  inout wire [24-1:0] reg_led ,    // need to be very careful. only 4 bits. or else screws set/reset calculation ...
  inout [24-1:0]      clk_count_reset_n,
  inout [24-1:0]      clk_count_fix_n,
  // inout [24-1:0]  clk_count_var_n,
  inout [24-1:0]      clk_count_var_pos_n,
  inout [24-1:0]      clk_count_var_neg_n,
  inout [31:0]        clk_count_aper_n,

  inout               use_slow_rundown,
  inout [4-1:0]       himux_sel,
  inout [24-1:0]      pattern,          // TODO change to 8-1
  inout               reset,            // register_reset for modulation, not a reset for my_register_bank.

  // readable measurement counts, these are all last
  input wire [24-1:0] count_up,
  input wire [24-1:0] count_down,
  input wire [24-1:0] count_trans_up,
  input wire [24-1:0] count_trans_down,
  input wire [24-1:0] count_fix_up,
  input wire [24-1:0] count_fix_down,
  input wire [24-1:0] clk_count_rundown,


  // readable params
  input wire [24-1:0] last_himux_sel,
  input wire [24-1:0] last_clk_count_fix_n,
  input wire [24-1:0] last_clk_count_var_pos_n,
  input wire [24-1:0] last_clk_count_var_neg_n,
  input wire [32-1:0] last_clk_count_aper_n,


  input wire [24-1:0] meas_count,     // useful to check if stalled
                                      // actually just probe switches with scope.

);

  // TODO rename these...
  // MSB is not correct here...
  reg [MSB-1:0] in;      // could be MSB-8-1 i think.
  reg [MSB-1:0] out  ;    // register for output.  should be size of MSB due to high bits
  reg [8-1:0]   count;

  wire dout = out[MSB- 1];


  // To use in an inout. the initial block is a driver. so must be placed here.
  initial begin
    reg_led             = 3'b101;
    clk_count_reset_n   =  10000;
    clk_count_fix_n     = 700;

    // clk_count_var_n   = 5500;
    clk_count_var_pos_n = 5500;
    clk_count_var_neg_n = 5500;

    clk_count_aper_n    = (2 * 2000000);    // ? 200ms TODO check this.
                                            // yes. 4000000 == 10PNLC, 5 sps.
    use_slow_rundown    = 1;
    himux_sel           = `HIMUX_SEL_REF_HI;   // when not controlled by pattern controller.
    pattern             = 10;
    reset               = 1; // for modulation, active lo

  end


  // read
  // clock value into into out var
  always @ (negedge clk or posedge cs)
  begin
    if(cs)
      // cs not asserted (active lo), so reset regs
      begin
        count <= 0;
        in <= 0;
        out <= 0;
      end
    else
      // cs asserted, clock data in and out
      begin
        /*
          TODO. would be better as non-blocking.
          but we end up with a losing a bit on addr or value.
        */
        // shift din into in register
        in = {in[MSB-2:0], din};

        // shift data from out register
        out = out << 1; // this *is* zero fill operator.

        /*
          // OK. pipelining this, with one clk delay increases speed 33MHz to 38MHz.
        */
        count <= count + 1;

        // if(count == 8)
        if(count == 7)  // we have read the register to use
          begin
            // ignore hi bit.
            // allows us to read a register, without writing, by setting hi bit of register addr
            case (in[8 - 1 - 1: 0 ] )

              `REG_LED:               out <= reg_led << 8;
              `REG_TEST:              out <= 24'hffffff << 8;    // fixed value, test value

              // params
              `REG_CLK_COUNT_RESET_N: out <= clk_count_reset_n << 8;
              `REG_CLK_COUNT_FIX_N:   out <= clk_count_fix_n << 8;
              `REG_CLK_COUNT_VAR_POS_N:  out <= clk_count_var_pos_n << 8;
              `REG_CLK_COUNT_VAR_NEG_N:  out <= clk_count_var_neg_n << 8;
              `REG_CLK_COUNT_APER_N_LO: out <= clk_count_aper_n << 8;           // lo 24 bits  aperture
              `REG_CLK_COUNT_APER_N_HI: out <= (clk_count_aper_n >> 24) << 8;   // hi 8 bits
              `REG_USE_SLOW_RUNDOWN:  out <= use_slow_rundown << 8;

              /* could convert numerical argument - to avoid accidently turning on more than one source.
                no. mux switch has 1.5k impedance. should not break anything
              */
              `REG_HIMUX_SEL:         out <= himux_sel << 8;
              `REG_PATTERN:           out <= pattern << 8;

              // `REG_RESET:             out <= pattern << 8; need to shift 24 bits?

              `REG_MEAS_COUNT:        out <= meas_count << 8;


              // measure/run/counts
              `REG_COUNT_UP:          out <= count_up << 8;
              `REG_COUNT_DOWN:        out <= count_down << 8;
              `REG_COUNT_TRANS_UP:    out <= count_trans_up << 8;
              `REG_COUNT_TRANS_DOWN:  out <= count_trans_down << 8;
              `REG_COUNT_FIX_UP:      out <= count_fix_up << 8;
              `REG_COUNT_FIX_DOWN:    out <= count_fix_down << 8;
              `REG_CLK_COUNT_RUNDOWN: out <= clk_count_rundown << 8;


              // param recorded at last run
              `REG_LAST_HIMUX_SEL:           out <= last_himux_sel << 8;
              `REG_LAST_CLK_COUNT_FIX_N:     out <= last_clk_count_fix_n << 8;
              `REG_LAST_CLK_COUNT_VAR_POS_N: out <= last_clk_count_var_pos_n << 8;
              `REG_LAST_CLK_COUNT_VAR_NEG_N: out <= last_clk_count_var_neg_n << 8;
              `REG_LAST_CLK_COUNT_APER_N_LO: out <= last_clk_count_aper_n << 8;           // lo 24 bits  aperture
              `REG_LAST_CLK_COUNT_APER_N_HI: out <= (last_clk_count_aper_n >> 24) << 8;   // hi 8 bits


              default:                out <= 12345 << 8;

            endcase
          end

      end
  end


  wire [8-1:0] addr  = in[ MSB-1: MSB-8 ];  // single byte for reg/address,
  wire [MSB-8-1:0] val   = in;              // lo 24 bits/


  // set/write
  always @ (posedge cs)   // cs done.
  begin
    if(count == MSB ) // MSB
      begin

        case (addr)
          // soft reset
          // not implemented. - basically would need to pass in integrator state.
          // *and* to have the op slope feedback working - to reset the integrator change.

          // use high bit - to do a xfer (read+writ) while avoiding actually writing a register
          // leds

          `REG_LED:                 reg_led <= val;

          `REG_CLK_COUNT_RESET_N:   clk_count_reset_n <= val;  // aperture
          `REG_CLK_COUNT_FIX_N:     clk_count_fix_n <= val;

          // `REG_CLK_COUNT_VAR_N:  clk_count_var_n <= val;
          `REG_CLK_COUNT_VAR_POS_N: clk_count_var_pos_n <= val;
          `REG_CLK_COUNT_VAR_NEG_N: clk_count_var_neg_n <= val;

          // TODO
          // these slow things down from 40MHz to 34MHz. need piplining.
          // but the PROBLEM - is the sensitivity list does not include clk.

          // SOLUTION - just continuously calculate them. but assign once.

          // 34MHz. aracnne,  38MHz nextpnr. now getting 39MHz.
          `REG_CLK_COUNT_APER_N_LO: clk_count_aper_n <= (clk_count_aper_n & 32'hff000000) | val;          // lo 24 bits
          `REG_CLK_COUNT_APER_N_HI: clk_count_aper_n <= (clk_count_aper_n & 32'h00ffffff) | (val << 24);  // hi 8 bits

          // 39MHz nextpnr
          // this only routes correctly in nextpnr. not arachne-pnr
          // these are not equivalent.
          // REG_CLK_COUNT_APER_N_LO: clk_count_aper_n <=   { clk_count_aper_n[MSB - 1 : MSB - 8 - 1], val  };                  // lo 24 bits
          // REG_CLK_COUNT_APER_N_HI: clk_count_aper_n <=   { val[ MSB - 1: MSB - 8 - 1 ], clk_count_aper_n[ MSB - 8 - 1: 0] };  // hi 8 bits

          `REG_USE_SLOW_RUNDOWN:    use_slow_rundown <= val;
          `REG_HIMUX_SEL:           himux_sel <= val;
          `REG_PATTERN:             pattern <= val;
          `REG_RESET:               reset <= val;

        endcase
      end
  end
endmodule

// ‘default_nettype wire

/*
  -noautowire
  95 make the default of ‘default_nettype be "none" instead of "wire".



*/





////////////////////////////

/*
  see,
    https://www.eevblog.com/forum/projects/multislope-design/75/
    https://patentimages.storage.googleapis.com/e2/ba/5a/ff3abe723b7230/US5200752.pdf
*/

// advantage of macros over localparam enum, is that they generate errors if not defined.
// disdvantage is that it is easy to forget the backtick

`define STATE_RESET_START    0    // initial state
`define STATE_RESET          1
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
`define STATE_DONE          17

// ref mux state.
`define MUX_REF_NONE        2'b00
`define MUX_REF_POS         2'b01
`define MUX_REF_NEG         2'b10
`define MUX_REF_SLOW_POS    2'b11





module my_modulation (

  input           clk,

  // comparator input
  input           comparator_val,

  // modulation parameters/count limits to use
  input [24-1:0]  clk_count_reset_n,
  input [24-1:0]  clk_count_fix_n,
  inout [24-1:0]  clk_count_var_pos_n,
  inout [24-1:0]  clk_count_var_neg_n,
  input [31:0]    clk_count_aper_n,

  // is himux_sel being overwritten?  because wrong length...
  // or reset is being written...

  input           use_slow_rundown,
  input [4-1:0]   himux_sel,
  inout           reset,            // for modulation

  output [4-1:0]  himux,
  input [ 2-1:0]  refmux,
  input           sigmux,

  // values from last run, available in order to read
  output [24-1:0] count_up_last,
  output [24-1:0] count_down_last,
  output [24-1:0] count_trans_up_last,
  output [24-1:0] count_trans_down_last,
  output [24-1:0] count_fix_up_last,
  output [24-1:0] count_fix_down_last,
  output [24-1:0] clk_count_rundown_last,

  // param
  output [24-1:0] last_himux_sel,
  output [24-1:0] last_clk_count_fix_n,
  output [24-1:0] last_clk_count_var_pos_n,
  output [24-1:0] last_clk_count_var_neg_n,
  output [32-1:0] last_clk_count_aper_n,


  // both should be input wires. both are driven.
  input           com_interupt,
  output          cmpr_latch_ctl
);


  /*
    we need to review all this input / output.
    and input wire can still be driven.
  */


  // 2^5 = 32
  reg [5-1:0] state;

  // initial begin does seem to be supported.
  initial begin
    state = `STATE_RESET_START;

    com_interupt    = 1; // active lo move this to an initial condition.
    cmpr_latch_ctl  = 0; // enable comparator

  end

  //////////////////////////////////////////////////////
  // counters and settings  ...

  reg [31:0]  clk_count;           // clk_count for the current phase. 31 bits is faster than 24 bits. weird. ??? 36MHz v 32MHz
  reg [31:0]  clk_count_aper ;      // from the start of the signal integration. eg. 5sec*20MHz=100m count. won't fit in 24 bit value. would need to split between read registers.

  // modulation counts
  reg [24-1:0] count_up;
  reg [24-1:0] count_down;
  reg [24-1:0] count_trans_up;
  reg [24-1:0] count_trans_down;
  reg [24-1:0] count_fix_up;
  reg [24-1:0] count_fix_down;

  /////////////////////////
  // this should be pushed into a separate module...
  // should be possible to set latch hi immediately on any event here...
  // change name  zero_cross.. or just cross_

  // TODO move this into the main block.

  reg [2:0] crossr;
  always @(posedge clk)
    crossr <= {crossr[1:0], comparator_val};

  wire cross_up     = (crossr[2:1]==2'b10);  // message starts at falling edge
  wire cross_down   = (crossr[2:1]==2'b01);  // message stops at rising edge
  wire cross_any    = cross_up || cross_down ;




  // TODO use something like this, instead of done
  // the the period that we are integrating the signal.
  assign sig_active     = himux == himux_sel     && sigmux == 1;    // j


  assign reset_active   = himux === `HIMUX_SEL_ANG && sigmux === 1;

  // OK. it's working with good values at nplc 10, 11, 12. for cal loop. after very heavy refactor mar 13. 2022.

  // IMPORTANT ! is not.   ~ is complement.


  reg comparator_val_last;

  always @(posedge clk)


    // EXTR. use if(!reset) to force, because `STATE_RESET_START only runs for a single clk cycle;
    // it's also slightly faster
    if(!reset)  // external reset, active lo
      begin
        // set up next state, for when reset goes hi.
        state           <= `STATE_RESET_START;

        // keep integrator analog input, and sigmux on, to reset the integrator
        himux           <= `HIMUX_SEL_ANG;
        sigmux          <= 1;
        refmux          <= `MUX_REF_NONE;
      end
    else

    begin

      // always increment clk for the current phase
      clk_count     <= clk_count + 1;

      // sample/bind comparator val once on clock edge. improves speed.
      comparator_val_last <=  comparator_val;



      if(sig_active)
        // while integrating the signal
        begin
          // increment aperture clk count
          clk_count_aper <= clk_count_aper + 1;

          // have we reached end of aperture
          if(clk_count_aper >= clk_count_aper_n)
            begin
              // turn off signal input
              sigmux  <= 0;

              // note himux is set to signal
              // could turn off the himux to ref-lo, to prevent leakage, but switching instability probably worse
            end
        end


      case (state)

        // IMPORTANT. might can improved performance by reducing the reset and sig-settle times
        // reset time is also used for settle time.

        `STATE_RESET_START:
          begin
            // reset vars, and transition to runup state
            state           <= `STATE_RESET;
            clk_count       <= 0;

            // switch op to integrator analog input, and sigmux on, to reset the integrator
            himux           <= `HIMUX_SEL_ANG;
            sigmux          <= 1;
            refmux          <= `MUX_REF_NONE;
          end


        `STATE_RESET:    // let integrator reset.
          if(clk_count >= clk_count_reset_n)
            state <= `STATE_SIG_SETTLE_START;


        `STATE_SIG_SETTLE_START:
          begin
            state         <= `STATE_SIG_SETTLE;
            clk_count     <= 0;

            // switch himux to signal, but lo mux off whlie op settles
            himux         <= himux_sel;
            sigmux        <= 0;
            // refmux     <= `MUX_REF_NONE;
          end

        `STATE_SIG_SETTLE:
          if(clk_count >= clk_count_reset_n)
            state <= `STATE_SIG_START;


        // beginning of signal integration
        `STATE_SIG_START:
          begin
            state <= `STATE_FIX_POS_START;
            clk_count     <= 0;

            // clear the clocks
            count_up        <= 0;
            count_down      <= 0;
            count_trans_up  <= 0;
            count_trans_down <= 0;
            count_fix_up    <= 0;
            count_fix_down  <= 0;


            // clear the aperture counter
            clk_count_aper<= 0;

            // turn on signal input, to start signal integration
            // himux      <= himux_sel;
            sigmux        <= 1;
            // refmux     <= `MUX_REF_NONE;
          end


        // from here on, we are cycling +-ref currents, with/or without signal

        `STATE_FIX_POS_START:
          begin
            state         <= `STATE_FIX_POS;
            clk_count     <= 0;

            count_fix_down <= count_fix_down + 1;
            refmux        <= `MUX_REF_POS; // initial direction
//            if(refmux != `MUX_REF_POS) count_trans_down <= count_trans_down + 1 ;
          end

        `STATE_FIX_POS:
          if(clk_count >= clk_count_fix_n)       // walk up.  dir = 1
            state <= `STATE_VAR_START;


        // variable direction
        `STATE_VAR_START:
          begin
            state         <= `STATE_VAR;
            clk_count     <= 0;

            if( comparator_val_last)   // test below the zero-cross
              begin
                refmux    <= `MUX_REF_NEG;  // add negative ref. to drive up.
                count_up  <= count_up + 1;
//                if(refmux != `MUX_REF_NEG) count_trans_up <= count_trans_up + 1 ;
              end
            else
              begin
                refmux    <= `MUX_REF_POS;
                count_down <= count_down + 1;
//                if(refmux != `MUX_REF_POS) count_trans_down <= count_trans_down + 1 ;
              end
          end

        /*
          should use === for equality. avoids high-z case.
        */
        // we are confusing neg. pos. and up. down.   neg == up. pos == down.

        `STATE_VAR:
          if(clk_count >= clk_count_var_pos_n)
/*
          if(
              ( refmux == `MUX_REF_NEG && clk_count >= clk_count_var_neg_n )
            || (refmux == `MUX_REF_POS && clk_count >= clk_count_var_pos_n )
            )    // should be neg....
*/
            state <= `STATE_FIX_NEG_START;


        `STATE_FIX_NEG_START:
          begin
            state         <= `STATE_FIX_NEG;
            clk_count     <= 0;

            count_fix_up  <= count_fix_up + 1;
            refmux        <= `MUX_REF_NEG;
//            if(refmux != `MUX_REF_NEG) count_trans_up <= count_trans_up + 1 ;
          end

        `STATE_FIX_NEG:
          // TODO add switch here for 3 phase modulation variation.
          if(clk_count >= clk_count_fix_n)
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
                count_up  <= count_up + 1;
 //               if(refmux != `MUX_REF_NEG) count_trans_up <= count_trans_up + 1 ;
              end
            else
              begin
                refmux    <= `MUX_REF_POS;
                count_down <= count_down + 1;
  //              if(refmux != `MUX_REF_POS) count_trans_down <= count_trans_down + 1 ;
              end
          end

        `STATE_VAR2:
          if(clk_count >= clk_count_var_pos_n)
/*
          if(
              ( refmux == `MUX_REF_NEG && clk_count >= clk_count_var_neg_n )
            || (refmux == `MUX_REF_POS && clk_count >= clk_count_var_pos_n )
            )    // should be neg....
*/
            begin
              // integration finished. and above zero cross
              if( !sig_active  && ! comparator_val_last)

                // go straight to the final rundown.
                state <= `STATE_RUNDOWN_START;
              else
                // do another cycle
                state <= `STATE_FIX_POS_START;
            end


        `STATE_RUNDOWN_START:
          begin
            state         <= `STATE_RUNDOWN;
            clk_count     <= 0;

            if( use_slow_rundown )
              // turn on both references - to create +ve bias, to drive integrator down.
              refmux      <= `MUX_REF_SLOW_POS;
            else
              // fast rundown
              refmux      <= `MUX_REF_POS;
          end


        `STATE_RUNDOWN:
          begin

            // zero-cross to finish.
            if(cross_any )
              begin
                // trigger for scope
                // transition
                state         <= `STATE_DONE;
                clk_count     <= 0;    // ok.

                // turn off all inputs. actually should leave. because we will turn on to reset the integrator.
                refmux        <= `MUX_REF_NONE;

                com_interupt  <= 0;   // active lo, set interupt

                // record all the counts and rundown everything
                count_up_last           <= count_up;
                count_down_last         <= count_down;
                count_trans_up_last     <= count_trans_up;
                count_trans_down_last   <= count_trans_down;
                count_fix_up_last       <= count_fix_up;
                count_fix_down_last     <= count_fix_down;
                clk_count_rundown_last  <= clk_count;

                // IMPORTANT - it might be better to record these wwhen the sig integrator starts.
                // because they could be overwritten by register bank writing.
                // except we will decouple them 

                // it's possible all this could be done in the pattern controller.
                // record the params used
                last_himux_sel          <= himux; // we have not turned off the himux yet
                last_clk_count_fix_n    <= clk_count_fix_n;
                last_clk_count_var_pos_n <= clk_count_var_pos_n;
                last_clk_count_var_neg_n <= clk_count_var_neg_n;
                last_clk_count_aper_n   <= clk_count_aper_n ;


              end
          end

        // OK. the timing of the com_interupt is not right either - about 4uS.  too weird.
        // No. we were scoping CS. rather than INT.

        `STATE_DONE:
          begin
            com_interupt  <= 1;   // active hi. turn off.
            state         <= `STATE_RESET_START;
          end


      endcase
    end


endmodule


/*
  // OK. we want to write a module. that whenever we get com_interupt lo. indicating completion
  // then we update a count,   and test it.
  - if can do that. then we can inject and also change the modulation parameters

  --------------
  OK. adding the meas count has slowed it down to 35MHz.
  ----------

  are we doing this wrong. it should be available on next clock. which is ok.
*/

module my_control (
  input           clk,
  input           com_interupt,
  // why is it an input????
  input wire [24-1:0]  count
);

  initial begin
    count = 0;
  end

  always@(posedge clk) begin

    if(!com_interupt)
      begin
        // this is being driven. but it has input type
        count <= count + 1;
      end
  end
endmodule




/*
  - this pattern thing is very interesting.
  - does it make sense - to make it control the timings?
  - eg. we only want to set the timings once - mainly depending on capcitor size, and supply/reference voltage.
    - then perhaps a variation for inl.

    eg. only really need to set once.
    do we really need to write them across from the mcu.
    - when being able to generate sequences quickly and locally on the fpga, might be a lot more interesting.
    - alternatively small programs that run locally might be simpler.
*/

/*
  - perhaps get rid of exposing himux_sel altogether.
  - instead have static patterns for each output

  - so we just have a single pattern control variable.
  - eg. 0 to 4 correspond with himux_sel.
  -------------

  - also - we could just return the internal count - and therefore be able to deduce what the value is
*/


/*

  there are two resets - reset for modulation. / and there is value_reset.

  how to write modulation vars.

  (1) write variables in the interupt handler for the mcu.
        eg. we would have a queue/buffer. or strategy fsm to use in the interupt.
        ensures. no downtime.
        have a delegatinig interupt handler, and can them implement arbitary strategies

        - values - can/could be timestamped on the interupt.  to avoid reading.

  (2) hold reset down. write variables. then release reset.
        this is pretty damn simple and nice.
        the advantage of setting a variable cleanly. is that we don't have to read it back again.

  (3) use pattern controller
      ensures. no downtime.
      extra queries are needed - to discover what parameters were used.

  -----
  TODO
  - we should be synchronizing writes regardless. at the interupt. or by using reset.
  ------

  - rather than try to read bak the hires mux.   why not assign a unique tag id. that can be returned.


  - EXTR>
      no. we can avoid tagging/reading back extra parameters.
      if do the write/update during the interupt/reset period.
      eg. we know what parameters will be used .

      - we don't have to read back to find out what value the pattern controller used. etc
      - or use a tag.

*/

/*

  main issue with pattern_controller.
  - is that we have to duplicate every register variable. - so that mcu can read valid parameters for the run just completed.
  - or else read everything quicly enough. that its correct for the last modulation, before the pattern controller changes things.
    but this doesn't work, because it switches on the interupt.

  - no. it's only 4 or 5 variables. max.
  - and using the pattern controller. for just modulating himux_sel for azero,again is just one variable.
  -----------------

  actually it's only 1 var.  himux_sel   to achieve auto cal.
  and if want to modulate the run timing. then set values.  and then set other bits in himux_sel. as a means to communicate to mcu.

  So implementing a reading mimux_sel_last - enables a lot of behavior.


*/

module my_control_pattern_2 (
  input           clk,
  input           com_interupt,

  input  [8-1:0]  pattern,    // call it reg_pattern? or rb_pattern?

  input [4-1:0]   rb_himux_sel,
  output [4-1:0]  himux_sel,  // output. declares a local register?
);

  // count of interupts, not clk
  reg [5-1:0]  count;

  initial begin
    count   = 0;
    himux_sel <= `HIMUX_SEL_REF_LO;
  end

  always@(posedge clk)
    if(!com_interupt /* || !reset */)
      begin

        // this is being driven. but it has input type
        count <= count + 1;

        case(pattern)

          0:
              himux_sel <= rb_himux_sel ;
              // ie. take all register values directly.
          /*
            - integrator does not seem to be resetting well. eg. countdown there are  runs very well. but it could be DA. rather than issue with reset circuitry.
            - if we added a simple cap for sample and hold, on the reset signal. then could integrate the residual.
          */
          10:
            case (count)
              0:  himux_sel <= `HIMUX_SEL_REF_LO;    // azero
              1:  begin
                  himux_sel <= `HIMUX_SEL_REF_HI;   // change to sig-hi
                  count <= 0;  // should take priorty over the addition.
                  end
            endcase

          11:
            case (count)
              0:  himux_sel <= `HIMUX_SEL_REF_LO;    // azero
              1:  himux_sel <= `HIMUX_SEL_SIG_HI;
              2:  begin
                  himux_sel <= `HIMUX_SEL_REF_HI;    // acal  can change to do acal at different interval
                  count <= 0;
                  end
            endcase

          // what about a value outside the bounds...
          // that cannot be set...

          // OK. it's actually looks like a short. the negative power supply is at limit. weird.
          // is the com_interupt --- staying low - and it's cycling every count?

/*
          default:
            // we need a way to indicate error.
            // eg. an error flag.
            case (count)
              0:  himux_sel <= `HIMUX_SEL_REF_LO;    // azero
              1:  begin
                  himux_sel <= `HIMUX_SEL_REF_HI;   // change to sig-hi
                  count <= 0;  // should take priorty over the addition.
                  end
            endcase
*/


        endcase

  end
endmodule








module blinky (
  input  clk,
  output [4-1:0] out_v
  // output LED1,
  // output LED2,
);

  localparam BITS = 5;
  localparam LOG2DELAY = 22;

  reg [BITS+LOG2DELAY-1:0] counter = 0;
  reg [BITS-1:0] outcnt;

  always@(posedge clk) begin
    counter <= counter + 1;
    outcnt <= counter >> LOG2DELAY;
    out_v  <= outcnt ^ (outcnt >> 1);
  end

  // why doesn't this work?
  // assign out_v  = outcnt ^ (outcnt >> 1);

endmodule





module top (
  input  clk,
  output LED_R,
  output LED_G,
  output LED_B,

  output INT_IN_P_CTL,
  output INT_IN_N_CTL,
  output INT_IN_SIG_CTL,

  output MUX_SIG_HI_CTL,
  output MUX_REF_HI_CTL,
  output MUX_REF_LO_CTL,
  output MUX_SLOPE_ANG_CTL,

  // it should be possible to immediately set high, on the latch transition, to avoid
  // and then reset on some fixed count
  output CMPR_LATCH_CTL,

  /* should configure as differential input.
    https://stackoverflow.com/questions/40096272/how-do-i-use-set-lvds-mode-on-lattice-ice40-pins-using-icestorm-tools
    https://github.com/YosysHQ/icestorm/issues/36
  */
  input CMPR_OUT_CTL_P,
  input CMPR_OUT_CTL_N,


  /////////
  input COM_CLK,
  input COM_CS,
  input COM_MOSI,
  input COM_SPECIAL,
  output COM_MISO,
  output COM_INTERUPT   // active lo


);

  // wire [24-1:0] reg_led ;
  reg [24-1:0] reg_led ;


  // input parameters
  reg [24-1:0]  clk_count_reset_n;
  reg [24-1:0]  clk_count_fix_n;
  // reg [24-1:0]  clk_count_var_n;
  reg [24-1:0]  clk_count_var_pos_n;
  reg [24-1:0]  clk_count_var_neg_n;
  reg [31:0]    clk_count_aper_n;
  reg use_slow_rundown;

  // output counts to read
  reg [24-1:0] count_up;
  reg [24-1:0] count_down;
  reg [24-1:0] count_trans_up ;
  reg [24-1:0] count_trans_down;
  reg [24-1:0] count_fix_up;
  reg [24-1:0] count_fix_down;
  reg [24-1:0] clk_count_rundown;

  reg [24-1:0] last_himux_sel;
  reg [24-1:0] last_clk_count_fix_n;
  reg [24-1:0] last_clk_count_var_pos_n;
  reg [24-1:0] last_clk_count_var_neg_n;
  reg [32-1:0] last_clk_count_aper_n;



  reg [4-1:0] himux_sel;    // himux signal selection
  // reg [4-1:0] himux_sel_dummy;    // himux signal selection
  reg [4-1:0] rb_himux_sel;


  reg [8-1:0] pattern;
  reg         reset;

  reg [24-1:0] meas_count;    // how many actual measurements we have done.


  /*
    registers mux_sel |= 0x ... turn a bit on.
    registers mux_sel &= ~ 0x ... turn a bit on.
  */

  reg [4-1:0] himux;
  assign { MUX_SLOPE_ANG_CTL, MUX_REF_LO_CTL, MUX_REF_HI_CTL, MUX_SIG_HI_CTL } = himux;

  // 3'b010
  // assign himux = 4'b1111;  // active lo. turn all off.
  // assign himux = 4'b1011;  // ref lo in / ie. dead short.
  // assign himux = 4'b1110;  // sig in .
  // assign himux = 4'b1101;  // ref in .

  // we can probe the leds for signals....

  /*
  // start everything off...
  reg [3-1:0] lomux ;
  assign { INT_IN_SIG_CTL, INT_IN_N_CTL, INT_IN_P_CTL } = lomux;
  */


  /*
    blinky blinky_ (
      . clk(clk),
      . out_v( mux_sel)
    );
  */

  assign { LED_B, LED_G, LED_R } = 3'b111 ;   // off, active lo.




  my_control
  control(
    . clk(clk),
    . com_interupt( COM_INTERUPT ),
    . count( meas_count)
  );


  my_register_bank #( 32 )   // register bank  . change name 'registers'
  bank
    (
    // spi
    . clk(COM_CLK),
    . cs(COM_CS),
    . din(COM_MOSI),
    . dout(COM_MISO),

    // modulation parameters
    . reg_led(reg_led),
    . clk_count_reset_n( clk_count_reset_n ) ,
    . clk_count_fix_n( clk_count_fix_n ) ,
    // . clk_count_var_n( clk_count_var_n ) ,
    . clk_count_var_pos_n( clk_count_var_pos_n) ,
    . clk_count_var_neg_n( clk_count_var_neg_n),
    . clk_count_aper_n( clk_count_aper_n ) ,

    . use_slow_rundown( use_slow_rundown),
    . himux_sel( rb_himux_sel ),
    . pattern( pattern),
    . reset( reset),

    // control
    . meas_count( meas_count ),

    // counts
    . count_up(count_up),
    . count_down(count_down),
    . count_trans_up(count_trans_up),
    . count_trans_down(count_trans_down),
    . count_fix_up(count_fix_up),
    . count_fix_down(count_fix_down),
    . clk_count_rundown(clk_count_rundown),

    // params used for run
    . last_himux_sel(last_himux_sel),
    . last_clk_count_fix_n( last_clk_count_fix_n ),
    . last_clk_count_var_pos_n( last_clk_count_var_pos_n),
    . last_clk_count_var_neg_n( last_clk_count_var_neg_n),
    . last_clk_count_aper_n( last_clk_count_aper_n),


  );


/*

module my_control_pattern_2 (
  input           clk,
  input           com_interupt,

  input  [8-1:0]  pattern,    // call it reg_pattern? or rb_pattern?

  input [4-1:0]   rb_himux_sel,
  output [4-1:0]  himux_sel,  // output. declares a local register?
);
*/


  my_control_pattern_2
  p1 (
    . clk(clk),
    . com_interupt(COM_INTERUPT),
    . pattern( pattern),
    . rb_himux_sel( rb_himux_sel),
    . himux_sel( himux_sel),
  );




  my_modulation
  m1 (

    // inputs
    . clk(clk),
    . comparator_val( CMPR_OUT_CTL_P ),

    // parameters
    . clk_count_reset_n( clk_count_reset_n ) ,
    . clk_count_fix_n( clk_count_fix_n ) ,
    // . clk_count_var_n( clk_count_var_n ) ,
    . clk_count_var_pos_n( clk_count_var_pos_n) ,
    . clk_count_var_neg_n( clk_count_var_neg_n),
    . clk_count_aper_n( clk_count_aper_n ) ,

    . use_slow_rundown( use_slow_rundown),
    . himux_sel( himux_sel ),
    . reset( reset),

    . himux(himux),
    . refmux( { INT_IN_N_CTL, INT_IN_P_CTL } ),
    . sigmux( INT_IN_SIG_CTL  ),


    // counts
    . count_up_last(count_up),
    . count_down_last(count_down),
    . count_trans_up_last(count_trans_up),
    . count_trans_down_last(count_trans_down),
    . count_fix_up_last(count_fix_up),
    . count_fix_down_last(count_fix_down),
    . clk_count_rundown_last(clk_count_rundown),

    . last_himux_sel(last_himux_sel),
    . last_clk_count_fix_n( last_clk_count_fix_n ),
    . last_clk_count_var_pos_n( last_clk_count_var_pos_n),
    . last_clk_count_var_neg_n( last_clk_count_var_neg_n),
    . last_clk_count_aper_n( last_clk_count_aper_n),



    . com_interupt(COM_INTERUPT),
    . cmpr_latch_ctl(CMPR_LATCH_CTL)
  );






endmodule



/*
  inputs and outptus. both probably want to be wires.
    https://github.com/icebreaker-fpga/icebreaker-verilog-examples/blob/main/icebreaker/dvi-12bit/vga_core.v


  - need to keep up/down transitions equal.  - to balance charge injection.
  - if end up on wrong side. just abandon, and run again? starting in opposite direction.
*/

// for 24bit values we don't really want these bitmask values.
// we just want to write and read registers.


/*
  - want to change assignement '=' to '<=' in the spi code.
  EXTR.
    change all this to avoid overloading the special.
    instead make special an extra CS.
    ------------

  after we have read 8 bits. then we have the address...
  ----------------------

*/
/*
  EXTR.
    - could almost have exactly the same bank block for 24bit and 4bit regs.
    - only issue is dout. being driven twice.

  we should make this two parameters eg. 8 bit for registers. and 24 bits for val.
  but this is ok.
*/

/*

  we can use. reset. to control the running of a specific modulation.
  --------

  for the simplest application.
  - should be able to just take positive count, and subtract the negative. then multiply by coefficient.
  - the slow slope is more complicated - to handle two coefficients.
  ----

  we could probably do the comparator test and direction update() .
    in a module - with an extra signal.
    or a function.

    probably function is better.
  -----

  no. just needs a function. at every setting of direction.

    update( mux, mux_new, count_tran_up, count_tran_down);

  - The input adc switch .    should be passed as separate wire.
  to make assignment with the two bit easy.

*/
