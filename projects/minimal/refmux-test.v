
/*
  simple modulation, to test the refmux
  works without slope-amp and comparator populated..
  but should add the comparator output to the monitor.
  --
  we have written this several times already as a test, so should keep it.
*/

`default_nettype none

////////////////////////////



// change one-hot?.
// `define STATE_DONE          0  // initial state

`define STATE_RESET_START    0
`define STATE_RESET          2
`define STATE_FIX_POS_START 6
`define STATE_FIX_POS       7
`define STATE_FIX_NEG_START 10
`define STATE_FIX_NEG       11


/*
  ref mux state.
  Note that this combines two 4053 switch..
*/

`define REFMUX_NONE        3'b000      // none - is required, because we turn off both pos-neg ref, to balance. switching.
`define REFMUX_POS         3'b001
`define REFMUX_NEG         3'b010
`define REFMUX_SLOW_POS    3'b011
`define REFMUX_RESET       3'b100





module refmux_test (

  input           clk,

  input [32-1:0]  p_clk_count_reset_i,      // useful if running stand-alone,
  input [32-1:0]  p_clk_count_fix_i,

  // comparator input
  input           cmpr_val_i,


	// now a wire. again.
  output wire [ 8-1:0]  monitor_o,

  output reg [ 3-1:0]  refmux_o,            // reference current mux
  output reg sigmux_o,                      // unused

	output reg cmpr_latch_ctl_o
);


  reg [5-1:0]   state ;

  // odd, this seems to be needed...
  initial begin
    state           = `STATE_RESET_START;   // 0


  end



  // eg. ccombinatorial logic driven off the output of the regs/state/dff.
  assign monitor_o[0] = (state == `STATE_FIX_POS);
  assign monitor_o[1] = (state == `STATE_FIX_NEG);
  assign monitor_o[2] = clk;
  assign monitor_o[3] = cmpr_val_i;

  assign monitor_o[ 4 +: 4 ] = 0 ;


  //////////////////////////////////////////////////////
  // counters and settings  ...

  reg [31:0]  clk_count_down;


  always @(posedge clk)


    begin

      clk_count_down <= clk_count_down - 1;



      case (state)


        `STATE_RESET_START:
          begin

            // reset vars, and transition to runup state
            state           <= `STATE_RESET;

            clk_count_down   <= p_clk_count_reset_i;


            // JA
            sigmux_o          <= 0;
            refmux_o          <= `REFMUX_RESET;

            cmpr_latch_ctl_o   <= 1; // disable comparator, enable latch
          end



        `STATE_RESET:    // let integrator reset.
            if(clk_count_down == 0)
              state <= `STATE_FIX_POS_START;



        // cycle +-ref currents, with/or without signal
        `STATE_FIX_POS_START:
          begin
            state             <= `STATE_FIX_POS;
            clk_count_down    <= p_clk_count_fix_i;

            refmux_o            <= `REFMUX_POS; // initial direction

          end

        `STATE_FIX_POS:
          if(clk_count_down == 0)
            state <= `STATE_FIX_NEG_START;


        `STATE_FIX_NEG_START:
          begin
            state         <= `STATE_FIX_NEG;
            clk_count_down    <= p_clk_count_fix_i;

            refmux_o        <= `REFMUX_NEG;
          end


        `STATE_FIX_NEG:
          // TODO add switch here for 3 phase modulation variation.
          if(clk_count_down == 0)
            state <= `STATE_FIX_POS_START;


      endcase
    end

endmodule


