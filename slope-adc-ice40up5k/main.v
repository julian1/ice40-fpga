



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


// ‘default_nettype none  // turn off implicit data types

module my_register_bank   #(parameter MSB=32)   (
  input  clk,
  input  cs,
  // input  special,   // TODO swap order specia/din
  input  din,       // sdi
  output dout,       // sdo

  // latched val, rename
  // this is both input and output????
  // output wire [24-1:0] reg_led ,    // need to be very careful. only 4 bits. or else screws set/reset calculation ...
  inout wire [24-1:0] reg_led ,    // need to be very careful. only 4 bits. or else screws set/reset calculation ...

  input wire [24-1:0] count_up,
  input wire [24-1:0] count_down,
  input wire [24-1:0] clk_count_rundown,

  input wire [24-1:0] count_trans_up,
  input wire [24-1:0] count_trans_down,

  input wire          rundown_dir,
  input wire [3-1:0]  count_flip    // should be a count. possible could require two up modulations
);

  // TODO rename these...
  // MSB is not correct here...
  reg [MSB-1:0] in;      // could be MSB-8-1 i think.
  reg [MSB-1:0] out  ;    // register for output.  should be size of MSB due to high bits
  reg [8-1:0]   count;

  wire dout = out[MSB- 1];

  // clock value into in var
  always @ (negedge clk or posedge cs)
  begin
    if(cs)
      // cs not asserted, so reset regs
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

        // this must be sequential, for equality test...
        count = count + 1;

        if(count == 8)
          begin
            // ignore hi bit.
            // allows us to read a register, without writing, by setting hi bit of addr
            case (in[8 - 1 - 1: 0 ] )

              7:  out = reg_led << 8;
              9:  out = count_up << 8;
              10: out = count_down << 8;
              11: out = clk_count_rundown << 8;

              12: out = count_trans_up << 8;
              14: out = count_trans_down << 8;

              // fixed value, test value
              15: out = 24'hffffff << 8;

              16: out = rundown_dir << 8;   // correct for single bit?
              17: out = count_flip << 8;

            endcase
          end

      end
  end


  wire [8-1:0] addr  = in[ MSB-1: MSB-8 ];  // single byte for reg/address,
  wire [MSB-8-1:0] val   = in;              // lo bytes


  always @ (posedge cs)   // cs done.
  begin
    if(count == MSB ) // MSB
      begin

        case (addr)
          // use high bit - to do a xfer (read+writ) while avoiding actually writing a register
          // leds
          7 :
            begin
              // reg_led = update(reg_led, val);
              reg_led <= val;
            end

          // soft reset
          11 :
            /*
              No. just pass the reset value as a vec, just like pass the reg.
              eg.  output reg_rails,  input reg_rails_init.
              but. note that everything comes up hi anyway before flash load
              OR. just those that are *not* to be set to zer.
            */
            begin
              // none of this is any good... we need mux ctl pulled high etc.
              // does verilog expand 0 constant to fill all bits?
              reg_led <= 3'b101;
            end

        endcase
      end
  end
endmodule

// ‘default_nettype wire

/*
  -noautowire
  95 make the default of ‘default_nettype be "none" instead of "wire".

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





////////////////////////////

/*
  see,
    https://www.eevblog.com/forum/projects/multislope-design/75/
    https://patentimages.storage.googleapis.com/e2/ba/5a/ff3abe723b7230/US5200752.pdf
*/


module my_modulation (
  input  clk,

  output [2:0] mux,

  // perhaps use tmp instead of last.
  output [24-1:0] count_up_last,
  output [24-1:0] count_down_last,
  output [24-1:0] clk_count_rundown_last,

  output [24-1:0] count_trans_up_last,
  output [24-1:0] count_trans_down_last,
  // output [24-1:0] clk_count_tot,     // could be useful

  // could also record the initial dir.
  // these (the outputs) could be combined into single bitfield.
  output rundown_dir_last,
  output [3-1:0] count_flip_last,

  input CMPR_OUT_CTL_P,

  output COM_INTERUPT,
  output CMPR_LATCH_CTL
);

  /*
  // so need
  //   1. state where switch op - to take slope to reset. and the mux takes the input .
  //   2. state to switch op back to the signal. while holding the switch at intmux at gnd.
  // **** actually at the end of the initegration - we would not turn off teh lowmux.
  // instead just switch the highmux to feedback and settle
  // then
    */

  // advantage of macros is that they generate errors if not defined.
  `define STATE_INIT_START    0
  `define STATE_INIT          1    // initialsation state
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


    // 2^5 = 32
  reg [5-1:0] state;

  // INITIAL BEGIN DOES SEEM TO BE supported.
  initial begin
    state = `STATE_INIT_START;
  end


  //////////////////////////////////////////////////////
  // counters and settings  ...
  // for an individual phase.

  reg [31:0]  clk_count ;         // clk_count for the current phase.
  reg [31:0]  clk_count_tot ;     // from the start of the signal integration. eg. 5sec*20MHz=100m count. won't fit in 24 bit value. would need to split between read registers.
                                  // could also record clk_count_actual.

  // modulation counts
  reg [31:0]  count_tot ;     // TODO. remove. unless use as terminate condition.
  reg [24-1:0] count_up;
  reg [24-1:0] count_down;
  reg [24-1:0] count_trans_up;
  reg [24-1:0] count_trans_down;

  reg [3-1:0] count_flip;

  /////////////////////////
  // this should be pushed into a separate module...
  // should be possible to set latch hi immediately on any event here...
  // change name  zero_cross.. or just cross_
  reg [2:0] crossr;
  always @(posedge clk)
    crossr <= {crossr[1:0], CMPR_OUT_CTL_P};

  wire cross_up     = (crossr[2:1]==2'b10);  // message starts at falling edge
  wire cross_down   = (crossr[2:1]==2'b01);  // message stops at rising edge
  wire cross_any    = cross_up || cross_down ;


  /*
      - start integration in reverse direction. - eg. it would pautse. won't work. references are not perfectly symmetrical around cross voltage.
      - perturb length. eg. 50,100,200ms.
      - add another count period. But think it should be time of fix+var. so that it can be counted normally.
  */

  // modulation freq = 20,000000 / 2 * (7000 + 1000) = 1250Hz. = 1.25kHz. with 10nF.
  // `define CLK_COUNT_VAR 7100
  // `define CLK_COUNT_INT (50 * 2000000) // 5s
  // `define CLK_COUNT_INT (5 * 2000000) // 500ms

  `define CLK_COUNT_INIT 10000  // pause time, to do spi read, and settle.
  `define CLK_COUNT_FIX 700
  `define CLK_COUNT_VAR 5500
  `define CLK_COUNT_INT (2 * 2000000) // ie. 200ms/4PLC. 20000000 * (200ms/ 1000). spi. do hi byte2/lo byte. not multiplcation.
  `define SLOW_RUNDOWN 1

  always @(posedge clk)
    begin
      /*
        EXTR. we could add/inject a is_active wire test here - to control if the module should run.
        or else just control reset.
        except reset - generally should control the outputs.
      */
      // we use the same count - always increment clock

      // this is nested sequntial block. so should be available. in the case statementj.
      // making this non-blocking makes it much faster 26MHz to 39MHz.

      // default behavior at top of verilog block.
      clk_count <= clk_count + 1;
      clk_count_tot <= clk_count_tot + 1;

      /*
        think we want a state init. that holds everything in pause.
        and then state begin. /
      */
      case (state)

        `STATE_INIT_START:
          begin
            // reset vars, and transition to runup state
            state <= `STATE_INIT;

            clk_count <= 0;
            clk_count_tot <= 0;   // start of signal integration time.
            count_tot <= 0;
            count_up <= 0;
            count_down <= 0;
            count_trans_up <= 0;
            count_trans_down <= 0;
            count_flip <= 0;

            COM_INTERUPT <= 1; // active lo
            CMPR_LATCH_CTL <= 0; // enable comparator


            // mux <= 3'b000; // turn off all inputs.
            // mux <= 3'b100; // turn on input signal
          end



        `STATE_INIT:
          begin
            if(clk_count == `CLK_COUNT_INIT)
              begin
                state <= `STATE_FIX_POS_START;
              end
          end

        `STATE_FIX_POS_START:
          begin
            state <= `STATE_FIX_POS;
            clk_count <= 0;
            mux <= 3'b101; // initial direction
            if(mux != 3'b101) count_trans_down <= count_trans_down + 1 ;
          end

        `STATE_FIX_POS:
          if(clk_count == `CLK_COUNT_FIX)       // walk up.  dir = 1
            state <= `STATE_VAR_START;

        // variable direction
        `STATE_VAR_START:
          begin
            state <= `STATE_VAR;
            clk_count <= 0;
            count_tot <= count_tot + 1;
            if( CMPR_OUT_CTL_P)   // test below the zero-cross
              begin
                mux <= 3'b110;  // add negative ref. to drive up.
                count_up <= count_up + 1;
                if(mux != 3'b110) count_trans_up <= count_trans_up + 1 ;
              end
            else
              begin
                mux <= 3'b101;
                count_down <= count_down + 1;
                if(mux != 3'b101) count_trans_down <= count_trans_down + 1 ;
              end
          end

        `STATE_VAR:
          if(clk_count == `CLK_COUNT_VAR)
            state <= `STATE_FIX_NEG_START;

        `STATE_FIX_NEG_START:
          begin
            state <= `STATE_FIX_NEG;
            clk_count <= 0;
            mux <= 3'b110;
            if(mux != 3'b110) count_trans_up <= count_trans_up + 1 ;
          end

        `STATE_FIX_NEG:
          if(clk_count == `CLK_COUNT_FIX)
            state <= `STATE_VAR2_START;

        // variable direction
        `STATE_VAR2_START:
          begin
            state <= `STATE_VAR2;
            clk_count <= 0;
            count_tot <= count_tot + 1;
            if( CMPR_OUT_CTL_P)
              begin
                mux <= 3'b110;
                count_up <= count_up + 1;
                if(mux != 3'b110) count_trans_up <= count_trans_up + 1 ;
              end
            else
              begin
                mux <= 3'b101;
                count_down <= count_down + 1;
                if(mux != 3'b101) count_trans_down <= count_trans_down + 1 ;
              end
          end
/*
    if we're on the wrong side, at end, for upwards slope.
    it is easy - to add an additional phase or two with fixed count to get to the other side for final rundown.
    and we can equalize time with reset period.

    // Timing estimate: 27.54 ns (36.31 MHz)

     run an extra cycle. and count them.
  ----------
    - i think its ok as it is. if add extra fixpos, then should also add fixneg. which is the same as not adding.
    - if add new cycle ( fixpos,fixneg and two var). then we likely end up on the same side we started.
    - as it is - we equalize transitions. and time above cross and time below.
  -----------

  TODO. we must count fixed and var count separately.
        because of the final potential double fixed positive . to get to the correct size for rundown.

  TODO.
*/

        `STATE_VAR2:
          if(clk_count == `CLK_COUNT_VAR)
            begin
              /*
                  End. of integration condition. can be defined.
                    - in terms of global clk count.
                    - or sum of count_up count_down etc.

                  this point should end-up on a PLC multiple eg. 50/60Hz.
                  EXTR. could be be nice to record value at the end.
              */
              // end of integration condition.
              if(clk_count_tot >= `CLK_COUNT_INT)

                if( ~ CMPR_OUT_CTL_P)   // test above zero cross
                  begin
                    // above zero cross
                    // go straight to the final rundown.
                    state <= `STATE_RUNDOWN_START;
                  end
                else
                  begin
                    // below zero cross
                    // do another variable, which should push us to the correct side.
                    // but should we do fixed - first? no because fixed are equalized at this point.
                    // i think we could
                    /*
                      - doing an extra pos + neg is the same as doing neither. actually not quite because it breaks it up.
                      TODO.
                      - just taking on another section. means that we have to keep track of all 4 inputs. fixed and var. because
                      - but if added a fixed pos, and var pos - then we could just add to the positive  count
                    */
                    state <= `STATE_VAR2_START;
                    count_flip <= count_flip + 1;
                  end


              else
                // do another cycle
                state <= `STATE_FIX_POS_START;
            end


        `STATE_RUNDOWN_START:
          begin
            state <= `STATE_RUNDOWN;
            clk_count <= 0;

            // turn on both references - to create +ve bias, to drive integrator down.

            if(`SLOW_RUNDOWN)
              mux <= 3'b011;
            else
              mux <= 3'b001;

            // TODO - the better way to do transitions is with a function. so can test existing state. up/down. then record.

            // count_down <= count_down + 1; don't count
            // TODO - this is not correct. it's possible we did not transition here. eg. we may already be going down.
            // count_trans_down <= count_trans_down + 1 ;

            // NO. - fixed pos and fixed neg - do not cancel. because they are non-ideal. but if they are equal - then a count of the number of cycles could capture the current.

            // no slow slope. - just +ve bias
            // this fails to route?
            // mux <= 3'b001;
          end

        // EXTR. we also have to short the integrator at the start. to begin at a known start position.

        /*
            EXTR.
              the other way to end the integration. - is just to keep running 4 wave sequences.
              until we are above. but that could be a long time.

        */

        `STATE_RUNDOWN:
          begin

            // zero-cross to finish.
            if(cross_any )
              begin
                  // trigger for scope

                  // transition
                  state <= `STATE_DONE;
                  clk_count <= 0;    // ok.

                  // turn off all inputs. actually should leave. because we will turn on to reset the integrator.
                  mux <= 3'b000;
                  COM_INTERUPT <= 0;   // active lo, set interupt
                  count_up_last <= count_up;
                  count_down_last <= count_down;
                  clk_count_rundown_last <= clk_count;// TODO change nmae  clk_clk_count_rundown

                  count_trans_up_last <= count_trans_up;
                  count_trans_down_last <= count_trans_down;

                  count_flip_last <= count_flip;

                  /*
                    TODO can get rid of this. if always drive in the same direction.
                  */
                  case(mux)
                    3'b010: rundown_dir_last = 1; // up
                    3'b001: rundown_dir_last = 0;
                    3'b011: rundown_dir_last = 0;
                  endcase

              end
          end


        `STATE_DONE:
          begin
            COM_INTERUPT <= 1;   // active hi. turn off.
            state <= `STATE_INIT_START;
          end


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

  wire [24-1:0] reg_led ;
  // assign { LED_B, LED_G, LED_R } =   reg_led ;   // not inverted for easier scope probing.inverted for common drain.
  // assign { LED_B, LED_G, LED_R } = 3'b010 ;       // works...
                                                    // Ok. it really looks correct on the leds...
  // assign { COM_MOSI , COM_CLK, COM_CS} =  reg_led ;


  reg [24-1:0] count_up;
  reg [24-1:0] count_down;
  reg [24-1:0] clk_count_rundown;

  reg [24-1:0] count_trans_up ;
  reg [24-1:0] count_trans_down;

  reg          rundown_dir;
  reg [3-1:0]  count_flip;

  my_register_bank #( 32 )   // register bank  . change name 'registers'
  bank
    (
    . clk(COM_CLK),
    . cs(COM_CS),
    . din(COM_MOSI),
    . dout(COM_MISO),

    // rename this as a test register. for 24 bit read/write.
    . reg_led(reg_led),

    . count_up(count_up),
    . count_down(count_down),
    . clk_count_rundown(clk_count_rundown),

    . count_trans_up(count_trans_up),
    . count_trans_down(count_trans_down),

    . rundown_dir(rundown_dir),
    . count_flip(count_flip)

  );



  // we can probe the leds for signals....

  // start everything off...
  reg [2:0] mux ;
  assign { INT_IN_SIG_CTL, INT_IN_N_CTL, INT_IN_P_CTL } = mux;


  reg [3:0] mux_sel;
  assign { MUX_SLOPE_ANG_CTL, MUX_REF_LO_CTL, MUX_REF_HI_CTL, MUX_SIG_HI_CTL } = mux_sel;

  // 3'b010
  // assign mux_sel = 4'b1111;  // active lo. turn all off.

  // assign mux_sel = 4'b1011;  // ref lo in .
  assign mux_sel = 4'b1110;  // sig in .
  // assign mux_sel = 4'b1101;  // ref in .


  // registers mux_sel |= 0x ... turn a bit on.
  // registers mux_sel &= ~ 0x ... turn a bit on.

/*
  blinky blinky_ (
    . clk(clk),
    . out_v( mux_sel)
  );
*/

  assign { LED_B, LED_G, LED_R } = 3'b111 ;   // off



  my_modulation  m1 (

    . clk(clk),
    . mux(mux),

    . count_up_last(count_up),
    . count_down_last(count_down),
    . clk_count_rundown_last(clk_count_rundown),

    . count_trans_up_last(count_trans_up),
    . count_trans_down_last(count_trans_down),

    . rundown_dir_last(rundown_dir),
    . count_flip_last(count_flip),

    . CMPR_OUT_CTL_P(CMPR_OUT_CTL_P),
    . COM_INTERUPT(COM_INTERUPT),
    . CMPR_LATCH_CTL(CMPR_LATCH_CTL)
  );






endmodule



/*
  inputs and outptus. both probably want to be wires.
    https://github.com/icebreaker-fpga/icebreaker-verilog-examples/blob/main/icebreaker/dvi-12bit/vga_core.v


  - need to keep up/down transitions equal.  - to balance charge injection.
  - if end up on wrong side. just abandon, and run again? starting in opposite direction.
*/


