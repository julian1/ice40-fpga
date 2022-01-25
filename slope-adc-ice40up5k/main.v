



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

  // spi
  input  clk,
  input  cs,
  input  din,       // sdi
  output dout,       // sdo


  // use ' inout',  must be inout to write
  inout wire [24-1:0] reg_led ,    // need to be very careful. only 4 bits. or else screws set/reset calculation ...
  inout [24-1:0]  clk_count_init_n,
  inout [24-1:0]  clk_count_fix_n,
  inout [24-1:0]  clk_count_var_n,
  inout [31:0]    clk_count_int_n,
  inout           use_slow_rundown,
  inout [4-1:0]   himux_sel,

  // outputs only
  input wire [24-1:0] count_up,
  input wire [24-1:0] count_down,
  input wire [24-1:0] count_trans_up,
  input wire [24-1:0] count_trans_down,
  input wire [24-1:0] count_fix_up,
  input wire [24-1:0] count_fix_down,

  input wire [24-1:0] clk_count_rundown,

  input wire          rundown_dir,
  input wire [3-1:0]  count_flip    // should be a count. possible could require two up modulations
);

  // TODO rename these...
  // MSB is not correct here...
  reg [MSB-1:0] in;      // could be MSB-8-1 i think.
  reg [MSB-1:0] out  ;    // register for output.  should be size of MSB due to high bits
  reg [8-1:0]   count;

  wire dout = out[MSB- 1];


  // To use in an inout. the initial block is a driver. so must be placed here.
  initial begin
    reg_led           = 3'b101;
    clk_count_init_n  =  10000;
    clk_count_fix_n   = 700;
    clk_count_var_n   = 5500;
    clk_count_int_n   = (2 * 2000000);    // 200ms
    // clk_count_int_n = (5 * 20000000);   // 5 sec.
    use_slow_rundown  = 1;
    // himux_sel      = 4'b1011;        // ref lo/agnd
    // himux_sel      = 4'b1101;     // ref in
    himux_sel         = 4'b1011;        // ref lo/agnd
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

        // this must be sequential, for equality test...
        count = count + 1;

        if(count == 8)  // we have read the register to use
          begin
            // ignore hi bit.
            // allows us to read a register, without writing, by setting hi bit of register addr
            case (in[8 - 1 - 1: 0 ] )


              7:  out = reg_led << 8;

              9:  out = count_up << 8;
              10: out = count_down << 8;
              12: out = count_trans_up << 8;
              14: out = count_trans_down << 8;

              // TODO reorder.
              26: out = count_fix_up << 8;
              27: out = count_fix_down << 8;


              11: out = clk_count_rundown << 8;

              // fixed value, test value
              15: out = 24'hffffff << 8;

              16: out = rundown_dir << 8;   // correct for single bit?
              17: out = count_flip << 8;

              // read/write registers
              18: out = clk_count_init_n << 8;
              20: out = clk_count_fix_n << 8;
              21: out = clk_count_var_n << 8;
              22: out = clk_count_int_n << 8;           // lo 24 bits
              23: out = (clk_count_int_n >> 24) << 8;   // hi 8 bits
              24: out = use_slow_rundown << 8;

              /* could convert numerical argument - to avoid accidently turning on more than one source.
                no. mux switch has 1.5k impedance. should not break anything
              */
              25: out = himux_sel << 8;

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

          7 : reg_led <= val;

          18: clk_count_init_n <= val;
          20: clk_count_fix_n <= val;
          21: clk_count_var_n <= val;

          // TODO
          // these slow things down from 40MHz to 34MHz. need piplining.
          // PROBLEM - sensitivity list does not include clk.
          // YES. we have the spi clk. so could pipeline on that.

          // 35MHz. test.
          // 22: clk_count_int_n <= { clk_count_int_n[32 -1: 24 -1] ,  val } ;           // lo 24 bits
          // 23: clk_count_int_n <= { val, clk_count_int_n[ 24 -1 : 0 ] };  // hi 8 bits

          // 34MHz.
          22: clk_count_int_n <= (clk_count_int_n & 32'hff000000) | val;           // lo 24 bits
          23: clk_count_int_n <= (clk_count_int_n & 32'h00ffffff) | (val << 24);  // hi 8 bits
          24: use_slow_rundown <= val;

          25: himux_sel <= val;

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

  // comparator input
  input comparator_val,

  // modulation parameters/count limits to use
  input [24-1:0]  clk_count_init_n,
  input [24-1:0]  clk_count_fix_n,
  input [24-1:0]  clk_count_var_n,
  input [31:0]    clk_count_int_n,
  input           use_slow_rundown,
  input [4-1:0]   himux_sel,

  // low mux
  output [3-1:0] lomux,
  // high mux
  output [4-1:0] himux,

  // values from last run, available in order to read
  output [24-1:0] count_up_last,
  output [24-1:0] count_down_last,
  output [24-1:0] count_trans_up_last,
  output [24-1:0] count_trans_down_last,
  output [24-1:0] count_fix_up_last,
  output [24-1:0] count_fix_down_last,

  output [24-1:0] clk_count_rundown_last,

  // could also record the initial dir.
  // these (the outputs) could be combined into single bitfield.
  output rundown_dir_last,
  output [3-1:0] count_flip_last,

  // TODO change lower case
  output COM_INTERUPT,
  output CMPR_LATCH_CTL
);

  /*
  // so need
  //   1. state where switch op - to take slope to reset. and the lomux takes the input .
  //   2. state to switch op back to the signal. while holding the switch at intlomux at gnd.
  // **** actually at the end of the initegration - we would not turn off teh lowlomux.
  // instead just switch the highlomux to feedback and settle
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


  `define MUX_NONE            2'b00
  `define MUX_REF_POS         2'b01
  `define MUX_REF_NEG         2'b10
  `define MUX_REF_SLOW_POS    2'b11


  wire [2-1:0] refmux;
  // assign {  INT_IN_N_CTL, INT_IN_P_CTL } = lomux ;
  assign refmux  = lomux [ 2-1:0] ;

  wire sigmux;
  assign sigmux = lomux [ 3-1 ];


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
  reg [31:0]  clk_count_int ;     // from the start of the signal integration. eg. 5sec*20MHz=100m count. won't fit in 24 bit value. would need to split between read registers.
                                  // could also record clk_count_actual.

  reg         done;

  // modulation counts
  reg [24-1:0] count_up;
  reg [24-1:0] count_down;
  reg [24-1:0] count_trans_up;
  reg [24-1:0] count_trans_down;
  reg [24-1:0] count_fix_up;
  reg [24-1:0] count_fix_down;


  // reg [3-1:0] count_flip;

  /////////////////////////
  // this should be pushed into a separate module...
  // should be possible to set latch hi immediately on any event here...
  // change name  zero_cross.. or just cross_
  reg [2:0] crossr;
  always @(posedge clk)
    crossr <= {crossr[1:0], comparator_val};

  wire cross_up     = (crossr[2:1]==2'b10);  // message starts at falling edge
  wire cross_down   = (crossr[2:1]==2'b01);  // message stops at rising edge
  wire cross_any    = cross_up || cross_down ;


  /*
      - start integration in reverse direction. - eg. it would pautse. won't work. references are not perfectly symmetrical around cross voltage.
      - perturb length. eg. 50,100,200ms.
      - add another count period. But think it should be time of fix+var. so that it can be counted normally.
  */



  always @(posedge clk)
    begin

      // default behavior at top of verilog block.
      clk_count <= clk_count + 1;
      clk_count_int <= clk_count_int + 1;


      // test regardless of state
      if(clk_count_int >= clk_count_int_n)
        begin
          done <= 1; // change name to sigdone.
          sigmux <= 0; // turn off signal
        end


      case (state)

        `STATE_INIT_START:
          begin
            // reset vars, and transition to runup state
            state <= `STATE_INIT;

            clk_count <= 0;
            clk_count_int <= 0;   // start of signal integration time.

            done <= 0;

            count_up <= 0;
            count_down <= 0;
            count_trans_up <= 0;
            count_trans_down <= 0;
            count_fix_up <= 0;
            count_fix_down <= 0;

            COM_INTERUPT <= 1; // active lo
            CMPR_LATCH_CTL <= 0; // enable comparator

            // TODO this is wrong. should be muxing reset signal.
            // select input signal
            // IMPORTANT. buffer op must now be given time to settle to new input.
            himux <= himux_sel;

            sigmux <= 0;
            refmux <= `MUX_NONE;

          end


        `STATE_INIT:
          begin
            if(clk_count == clk_count_init_n)
              begin
                state <= `STATE_FIX_POS_START;
                // turn on signal
                sigmux <= 1;
              end
          end

        `STATE_FIX_POS_START:
          begin
            state <= `STATE_FIX_POS;
            clk_count <= 0;
            refmux <= `MUX_REF_POS; // initial direction
            if(refmux != `MUX_REF_POS) count_trans_down <= count_trans_down + 1 ;
          end

        `STATE_FIX_POS:
          if(clk_count == clk_count_fix_n)       // walk up.  dir = 1
            state <= `STATE_VAR_START;

        // variable direction
        `STATE_VAR_START:
          begin
            state <= `STATE_VAR;
            clk_count <= 0;
            if( comparator_val)   // test below the zero-cross
              begin
                refmux <= `MUX_REF_NEG;  // add negative ref. to drive up.
                if(refmux != `MUX_REF_NEG) count_trans_up <= count_trans_up + 1 ;
                count_up <= count_up + 1;
              end
            else
              begin
                refmux <= `MUX_REF_POS;
                if(refmux != `MUX_REF_POS) count_trans_down <= count_trans_down + 1 ;
                count_down <= count_down + 1;
              end
          end

        `STATE_VAR:
          if(clk_count == clk_count_var_n)
            state <= `STATE_FIX_NEG_START;

        `STATE_FIX_NEG_START:
          begin
            state <= `STATE_FIX_NEG;
            clk_count <= 0;
            refmux <= `MUX_REF_NEG;
            if(refmux != `MUX_REF_NEG) count_trans_up <= count_trans_up + 1 ;
          end

        `STATE_FIX_NEG:
          if(clk_count == clk_count_fix_n)
            state <= `STATE_VAR2_START;

        // variable direction
        `STATE_VAR2_START:
          ///////////
          // EXTR.  actually since we stopped injecting signal - it doesn't matter how many cycles we use to get above zero-cross.
          // and it will happen reasonably quickly. because of the bias.
          // so just keep running complete 4 phase cycles until we get a cross. rather than force positive vars.
          //////////
          begin
            state <= `STATE_VAR2;
            clk_count <= 0;
            if( comparator_val) // below zero-cross
              begin
                refmux <= `MUX_REF_NEG;
                if(refmux != `MUX_REF_NEG) count_trans_up <= count_trans_up + 1 ;
                count_up <= count_up + 1;
              end
            else
              begin
                refmux <= `MUX_REF_POS;
                if(refmux != `MUX_REF_POS) count_trans_down <= count_trans_down + 1 ;
                count_down <= count_down + 1;
              end
          end

        `STATE_VAR2:
          if(clk_count == clk_count_var_n)
            begin
              // end of integration condition. and above zero cross
              if(done && ~ comparator_val)
                // go straight to the final rundown.
                state <= `STATE_RUNDOWN_START;
              else
                // do another cycle
                state <= `STATE_FIX_POS_START;
            end


        `STATE_RUNDOWN_START:
          begin
            state <= `STATE_RUNDOWN;
            clk_count <= 0;

            if( use_slow_rundown )
              // turn on both references - to create +ve bias, to drive integrator down.
              refmux <= `MUX_REF_SLOW_POS;
            else
              // fast rundown
              refmux <= `MUX_REF_POS;
          end


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
                  refmux <= `MUX_NONE;

                  COM_INTERUPT <= 0;   // active lo, set interupt

                  count_up_last       <= count_up;
                  count_down_last     <= count_down;
                  count_trans_up_last <= count_trans_up;
                  count_trans_down_last <= count_trans_down;
                  count_fix_up_last   <= count_fix_up;
                  count_fix_down_last <= count_fix_down;

                  clk_count_rundown_last <= clk_count;// TODO change nmae  clk_clk_count_rundown

                  count_flip_last <= 0; // count_flip;

                  // record last // unused. could remove.
                  rundown_dir_last <= refmux; // up

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



  // input parameters
  reg [24-1:0]  clk_count_init_n;
  reg [24-1:0]  clk_count_fix_n;
  reg [24-1:0]  clk_count_var_n;
  reg [31:0]    clk_count_int_n;
  reg use_slow_rundown;

  // output counts to read
  reg [24-1:0] count_up;
  reg [24-1:0] count_down;
  reg [24-1:0] count_trans_up ;
  reg [24-1:0] count_trans_down;
  reg [24-1:0] count_fix_up;
  reg [24-1:0] count_fix_down;

  reg [24-1:0] clk_count_rundown;

  reg          rundown_dir;
  reg [3-1:0]  count_flip;


  reg [4-1:0] himux_sel;    // himux signal selection


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

  // start everything off...
  reg [3-1:0] lomux ;
  assign { INT_IN_SIG_CTL, INT_IN_N_CTL, INT_IN_P_CTL } = lomux;

  /*
    blinky blinky_ (
      . clk(clk),
      . out_v( mux_sel)
    );
  */

  assign { LED_B, LED_G, LED_R } = 3'b111 ;   // off, active lo.




  my_register_bank #( 32 )   // register bank  . change name 'registers'
  bank
    (
    // spi
    . clk(COM_CLK),
    . cs(COM_CS),
    . din(COM_MOSI),
    . dout(COM_MISO),

    // parameters
    . reg_led(reg_led),
    . clk_count_init_n( clk_count_init_n ) ,
    . clk_count_fix_n( clk_count_fix_n ) ,
    . clk_count_var_n( clk_count_var_n ) ,
    . clk_count_int_n( clk_count_int_n ) ,
    . use_slow_rundown( use_slow_rundown),
    . himux_sel( himux_sel ),

    // counts
    . count_up(count_up),
    . count_down(count_down),
    . count_trans_up(count_trans_up),
    . count_trans_down(count_trans_down),
    . count_fix_up(count_fix_up),
    . count_fix_down(count_fix_down),

    // clk counts
    . clk_count_rundown(clk_count_rundown),

    // other vars
    . rundown_dir(rundown_dir),
    . count_flip(count_flip)

  );




  my_modulation  m1 (

    // inputs
    . clk(clk),
    . comparator_val( CMPR_OUT_CTL_P ),

    // parameters
    . clk_count_init_n( clk_count_init_n ) ,
    . clk_count_fix_n( clk_count_fix_n ) ,
    . clk_count_var_n( clk_count_var_n ) ,
    . clk_count_int_n( clk_count_int_n ) ,
    . use_slow_rundown( use_slow_rundown),
    . himux_sel( himux_sel ),

    // lomux
    . lomux(lomux),
    . himux(himux),

    // counts
    . count_up_last(count_up),
    . count_down_last(count_down),
    . count_trans_up_last(count_trans_up),
    . count_trans_down_last(count_trans_down),
    . count_fix_up_last(count_fix_up),
    . count_fix_down_last(count_fix_down),

    // clk counts
    . clk_count_rundown_last(clk_count_rundown),

    // other vars
    . rundown_dir_last(rundown_dir),
    . count_flip_last(count_flip),

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


