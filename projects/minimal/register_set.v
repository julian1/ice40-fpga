/*
  rewrite. apr. 2026

  - it may be better to pack the write flag after the addr.
    instead of the high bit. like this,

  eg. pack    { addr[7-1:0], wr flag,  data }

  this delays knowledge about operation type,
  but gains a clock cycle, after receiving the address, to perform a 2-cycle port read
  in order to load the output shift register in time

  also knowledge about a decision to write is only needed write after receiving all bytes.

  But a write might also be tricky - and need both the clk cycle and the cs going hi - to work.

*/

`default_nettype none

`include "defines.v"    // `CLK_FREQ for default calculation

`define REG_4094_OE                     9
`define REG_CR                          12
`define REG_DIRECT                      14
`define REG_SR                          17


///////////////////////

//  sample acquisition.
`define REG_SA_P_CLK_COUNT_TRIG_DELAY   19
`define REG_SA_P_CLK_COUNT_PRECHARGE    20

`define REG_SA_P_SEQ0                   22
`define REG_SA_P_SEQ1                   23
`define REG_SA_P_SEQ2                   24
`define REG_SA_P_SEQ3                   25


`define REG_SA_SEQ_ELT                  26


// adc control parameters
`define REG_ADC_P_CLK_COUNT_APERTURE    30
`define REG_ADC_P_CLK_COUNT_RESET       31
`define REG_ADC_P_CLK_COUNT_APERTURE_OOB 32


// adc counts
`define REG_ADC_CLK_COUNT_REFMUX_NEG    40
`define REG_ADC_CLK_COUNT_REFMUX_POS    41
`define REG_ADC_CLK_COUNT_REFMUX_BOTH   42
`define REG_ADC_CLK_COUNT_RSTMUX        43
`define REG_ADC_CLK_COUNT_SIGMUX        44
`define REG_ADC_CLK_COUNT_APERTURE      45


// adc extra stat counts.
`define REG_ADC_STAT_COUNT_REFMUX_POS_UP  50
`define REG_ADC_STAT_COUNT_REFMUX_NEG_UP  51
`define REG_ADC_STAT_COUNT_CMPR_CROSS_UP  52


`define REG_TEST1                         60    // 0b111100
`define REG_TEST2                         61




module register_set   (   // 1 byte address, and write flag,   4 bytes data.

  // inputs
  // spi
  input  clk,
  input  cs_n,
  input  din,       // sdi
  output dout,


  /////////////////////
  // outputs -  read/write

  // output reg [32-1:0] reg_spi_mux,
  output reg [32-1:0] reg_cr,
  output reg [32-1:0] reg_4094_oe,     // TODO consider place in generic CR control register. encode 4094-OE and trigger.
  // output reg [32-1:0] reg_direct,
  // output reg [32-1:0] reg_seq_mode,



  // outputs signal acquisition
  output reg [32-1:0] reg_sa_p_clk_count_trig_delay,
  output reg [32-1:0] reg_sa_p_clk_count_precharge,

  /*
    representation is not very efficient.
    encode azmux value 4 bits, and precharge switch 2 bits is 6 bits.
    could use higher bits to encode other control eg. to not change/leave the precharge from previous value. etc.
    better than creating a separate controller module
  */
  output reg [32-1:0] reg_sa_p_seq0,
  output reg [32-1:0] reg_sa_p_seq1,
  output reg [32-1:0] reg_sa_p_seq2,
  output reg [32-1:0] reg_sa_p_seq3,


  // outputs adc
  output reg [32-1:0] reg_adc_p_clk_count_aperture,
  output reg [32-1:0] reg_adc_p_clk_count_reset,    // move
  output reg [32-1:0] reg_adc_p_clk_count_aperture_oob,

  output reg [32-1:0] reg_test1,
  output reg [32-1:0] reg_test2,


  //////////
  // inputs - read only, register state managed externally
  //   generally snapshot
  /*
    making these input wires.
    means we get an error if try to drive/write them here.
  */
  // inputs - status, externally driven

  input wire [32-1:0] reg_sr,

  // inputs from sa
  input wire [32-1:0] reg_sa_seq_elt,


  // inputs adc
  input wire [32-1:0] reg_adc_clk_count_rstmux,
  input wire [32-1:0] reg_adc_clk_count_refmux_neg,
  input wire [32-1:0] reg_adc_clk_count_refmux_pos,
  input wire [32-1:0] reg_adc_clk_count_refmux_both,
  input wire [32-1:0] reg_adc_clk_count_sigmux,
  input wire [32-1:0] reg_adc_clk_count_aperture,

  input wire [32-1:0] reg_adc_stat_count_refmux_pos_up,
  input wire [32-1:0] reg_adc_stat_count_refmux_neg_up,
  input wire [32-1:0] reg_adc_stat_count_cmpr_cross_up,



);

  // reg [ 8-1: 0] dummy;

  reg [32-1:0]  in;
  reg [32-1:0]  out;
  reg [8-1:0]   count;

  // reversing order is problem
  reg [7-1:0]   addr;

  reg           write_flag;

  // wire [32-1:0] bin;


  wire dout = out[ 32- 1];  // last bit


  // To use in an inout. the initial block is a driver. so must be placed here.
  initial begin


    // control
    reg_4094_oe       = 0;
    reg_cr            = 0;
    // reg_direct        = 0;

    // signal acquisition
    // it is nice to have sa defaults...
    // so can just put in az mode, and have something working.

    reg_sa_p_clk_count_trig_delay = $rtoi( `CLK_FREQ * 100e-3 );   // 100ms.  3458a. is 30ms ?
    reg_sa_p_clk_count_precharge  = $rtoi( `CLK_FREQ * 500e-6 );   // 500us.

    // how can express macro constant. of fixed width? does this work?
    // reg_sa_p_seq0 = { 2'b01, ((4'd1<<3)|(3-1))   };  //  `S3

    reg_sa_p_seq0     = { 2'b01, 4'd10   };  //  ((1<<3)|(3-1)) =  10          // S3 dcv   TODO fixme. just use the define S3
    reg_sa_p_seq1     = { 2'b00, 4'd14    };   // ((1<<3)|(7-1)) =  14       // S7  star-gnd.  TODO fixme just use the define S7.
    reg_sa_p_seq2     = 0;
    reg_sa_p_seq3     = 0;

    // reg_sa_p_trig     = 0;

    // adc
    reg_adc_p_clk_count_aperture      =  $rtoi( `CLK_FREQ * 0.2 );      // 200ms.
    reg_adc_p_clk_count_reset         = 24'd10000 ;                    // 20000000 * 0.5e-3 == 10000   500us.
    reg_adc_p_clk_count_aperture_oob  = $rtoi( `CLK_FREQ * 0.02 );

    reg_test1         = 32'b00001111000011110000111100001111;
    reg_test2         = 32'b11110000111100001111000011110000;


  end


  always @ (negedge clk or posedge cs_n)
  begin
    if(cs_n)
      // cs not asserted (active lo), so reset regs
      begin

        // async state on cs, must be constant.
        in      <= 0;
        out     <= 0;
        count   <= 0;
        addr    <= 0;
        write_flag <= 0;
      end
    else
      // cs asserted, clock data in and out
      begin

        // shift din into in register
        in <= {in[ 32-2:0], din};

        // shift data from out register
        out <= out << 1; // this *is* zero fill operator.

        count <= count + 1;

        // we have the write flag here as first bit. ??!!!
/*
        if( count == 0)
          begin

            // write flag
            // it is actually a read_flag... so need the inverse
            write_flag <=  ! din ;
          end
*/
        /*
            we have all 8 bits here, with din as last bit.
          - so load the out register in time, and not miss any bits on the output
          ---------

          slight timing issues for the read?
          perhaps signal-integrity with long spi traces
          and because device reads dout on the trailing/rising clock edge?
        */


        // else if( count ==  7)    // this is the 8th bit, din included

        if( count == 7)    // din == 8th bit. so all addr bits are in 'in' register, and now record din as write flag
          begin

            // consider issue - is that din is metastable at this point - as it is a fpga gpio pin input - that has not gone through any register
            // AND. because it is used as combinatorially (with no clock dependency) to construct the addr - it corrupts.
            // EXTR. - The way to fix. is probably to have an additional clk cycle - and lock din in a register on the clock cycle
            // to freeup /gain this extra clock cycle - pad/place the write_flag after the address.

            // addr <= { in[ 7 -1 -1: 0], din };       // store for later use by write
            addr        <= in[ 7 -1 : 0];             // seems faster? than just truncating???
            // addr        <= in;                          // record the addr for later


            write_flag  <= din ;     // store the write_flag which is LSB
                                      // EXTR.  could also pick this by copying in[ 0] on count == 8.


            // case ( { in[ 7 -1 -1: 0], din } )
            case ( in[ 7 -1 : 0])                // constrain index space of 'in'

              // general
              `REG_4094_OE:                       out <= reg_4094_oe;
              `REG_CR:                            out <= reg_cr;
              // `REG_DIRECT:                        out <= reg_direct;
              `REG_SR:                            out <= reg_sr;

              ////////
              // sa - sample acquisition
              `REG_SA_P_CLK_COUNT_TRIG_DELAY:     out <= reg_sa_p_clk_count_trig_delay;
              `REG_SA_P_CLK_COUNT_PRECHARGE:      out <= reg_sa_p_clk_count_precharge;

              `REG_SA_P_SEQ0:                     out <= reg_sa_p_seq0;
              `REG_SA_P_SEQ1:                     out <= reg_sa_p_seq1;
              `REG_SA_P_SEQ2:                     out <= reg_sa_p_seq2;
              `REG_SA_P_SEQ3:                     out <= reg_sa_p_seq3;

              `REG_SA_SEQ_ELT:                    out <= reg_sa_seq_elt;


              /////
              // adc
              `REG_ADC_P_CLK_COUNT_APERTURE:      out <= reg_adc_p_clk_count_aperture;     // clk_count_sample_n clk_time_sample_clksample_time ??
              `REG_ADC_P_CLK_COUNT_RESET:         out <= reg_adc_p_clk_count_reset;
              `REG_ADC_P_CLK_COUNT_APERTURE_OOB:  out <= reg_adc_p_clk_count_aperture_oob;

              `REG_TEST1:                         out <= reg_test1;
              `REG_TEST2:                         out <= reg_test2;


              // adc inputs to module, and spi readable outputs
              `REG_ADC_CLK_COUNT_REFMUX_NEG:      out <= reg_adc_clk_count_refmux_neg;
              `REG_ADC_CLK_COUNT_REFMUX_POS:      out <= reg_adc_clk_count_refmux_pos;
              `REG_ADC_CLK_COUNT_REFMUX_BOTH:     out <= reg_adc_clk_count_refmux_both;

              `REG_ADC_CLK_COUNT_RSTMUX:          out <= reg_adc_clk_count_rstmux;
              `REG_ADC_CLK_COUNT_SIGMUX:          out <= reg_adc_clk_count_sigmux;
              `REG_ADC_CLK_COUNT_APERTURE:        out <= reg_adc_clk_count_aperture;

              `REG_ADC_STAT_COUNT_REFMUX_POS_UP:  out <= reg_adc_stat_count_refmux_pos_up;
              `REG_ADC_STAT_COUNT_REFMUX_NEG_UP:  out <= reg_adc_stat_count_refmux_neg_up;
              `REG_ADC_STAT_COUNT_CMPR_CROSS_UP:  out <= reg_adc_stat_count_cmpr_cross_up;

              // if get default back, it likely means the addr was not seen correctly
              // default:                            out <= 32'b00001111000011110000111100001111;
              // default:                            out <= 32'b11001100110011001100110011001100;
              default:                            out <= { 16'b1100110011001100, 8'b00000000,  1'b0, in[ 7 -1 : 0] };

            endcase
          end // count == 8


        /*
          we can adjust count and load a new register - for an extended spi operation.

          else if ( count == 32 + 8 - 1 && !write_flag   )
            count   <= 7;
            in      <= next_register
        */

        /*
          may be possible to delay, and use the pos edge of cs to latch values.
          then could use 'in' instead of '{ in[ 32 -1 -1: 0], din }';
          but consider - better to use the clk count

        */

        else if ( count == 32 + 8 - 1 && write_flag   )   // have all bits and write flag is set.

          case (  addr  )

            `REG_4094_OE:                   reg_4094_oe   <= { in[ 32 -1 -1: 0], din };
            `REG_CR:                        reg_cr        <= { in[ 32 -1 -1: 0], din };
            // `REG_DIRECT:                    reg_direct    <= { in[ 32 -1 -1: 0], din };

            //////////

            `REG_SA_P_CLK_COUNT_TRIG_DELAY: reg_sa_p_clk_count_trig_delay <= { in[ 32 -1 -1: 0], din };
            `REG_SA_P_CLK_COUNT_PRECHARGE:  reg_sa_p_clk_count_precharge <= { in[ 32 -1 -1: 0], din };

            `REG_SA_P_SEQ0:                 reg_sa_p_seq0 <= { in[ 32 -1 -1: 0], din };
            `REG_SA_P_SEQ1:                 reg_sa_p_seq1 <= { in[ 32 -1 -1: 0], din };
            `REG_SA_P_SEQ2:                 reg_sa_p_seq2 <= { in[ 32 -1 -1: 0], din };
            `REG_SA_P_SEQ3:                 reg_sa_p_seq3 <= { in[ 32 -1 -1: 0], din };

            // `REG_SA_P_TRIG:                 reg_sa_p_trig <= { in[ 32 -1 -1: 0], din };


            ////
            `REG_ADC_P_CLK_COUNT_APERTURE:  reg_adc_p_clk_count_aperture        <= { in[ 32 -1 -1: 0], din };
            `REG_ADC_P_CLK_COUNT_RESET:     reg_adc_p_clk_count_reset           <= { in[ 32 -1 -1: 0], din };
            `REG_ADC_P_CLK_COUNT_APERTURE_OOB: reg_adc_p_clk_count_aperture_oob <= { in[ 32 -1 -1: 0], din };

            `REG_TEST1:                     reg_test1     <= { in[ 32 -1 -1: 0], din };
            `REG_TEST2:                     reg_test2     <= { in[ 32 -1 -1: 0], din };

          endcase


      end
  end


endmodule



/*
  consider change reg_4094_oe, to a generic CR control register. encode 4094-OE and trigger.
*/
/*
  need to add core reset back.
  possible that a timer reg, is read, while being shifted in spi transfer, and thus sees very large value timer duration
  behavior is to appear to lockup.
*/
/*
  --------------------

  - OK. rewritten/ changed the register_bank strategy. sep 2023.

  rather than use the async cs going high as a final clk pulse on which to set the register values .
  instead use async cs - only to hold values in init/reset when cs is non enabled.
  but when the spi transfer is inititiated by cs going lo, we are become committed to reading/writing values according to the clk count.
  this is because cannot rely on cs edge of cs as async signal together with setting non-constant values.
  there was a yosys error that was masked/not given because the code was split/factored into two always blocks.

  note that if cs goes high early, indicating wrong/or aborted spi, then clk count and input data is reset without reg values being updated which is the desired behavior.
  different spi length transfers are possible with more than once update function, eg. on a second count factor.
  or code register specific transfer count/length

  but all this means we have to use small blocking assignment - to arrange write on the final spi clk pulse. because we are not guaranteed anymore further clk cycles
*/




