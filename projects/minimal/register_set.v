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


`default_nettype none

`include "defines.v"    // `CLK_FREQ for default calculation

// prefix REG_GEN_ ?
// no.  just create a generic. general CR / control register.  for 4094 oe, perhaps the spi_mux.
// `define REG_SPI_MUX                     8
`define REG_4094_OE                     9
`define REG_MODE                        12
`define REG_DIRECT                      14
`define REG_STATUS                      17
// `define REG_SEQ_MODE                    18   // just pass-through communcation. from input reg to the status register out.
                                              // treat as general register, since not used as a parameter that controls/influences any fsm.



///////////////////////

//  sample acquisition.
`define REG_SA_P_CLK_COUNT_PRECHARGE    20

`define REG_SA_P_SEQ_N                  21
`define REG_SA_P_SEQ0                   22
`define REG_SA_P_SEQ1                   23
`define REG_SA_P_SEQ2                   24
`define REG_SA_P_SEQ3                   25

// `define REG_SA_P_TRIG                     26


// adc parameters
`define REG_ADC_P_CLK_COUNT_APERTURE    30
`define REG_ADC_P_CLK_COUNT_RESET       31



// adc counts
`define REG_ADC_CLK_COUNT_REFMUX_RESET  40
`define REG_ADC_CLK_COUNT_REFMUX_NEG    41
`define REG_ADC_CLK_COUNT_REFMUX_POS    42
`define REG_ADC_CLK_COUNT_REFMUX_RD     43      // CONSIDER rename _BOTH
`define REG_ADC_CLK_COUNT_SIGMUX       44


// extra stat counts.
`define REG_ADC_STAT_COUNT_REFMUX_POS_UP  50
`define REG_ADC_STAT_COUNT_REFMUX_NEG_UP  51
`define REG_ADC_STAT_COUNT_CMPR_CROSS_UP  52


module register_set #(parameter MSB=40)   (   // 1 byte address, and write flag,   4 bytes data.

  // inputs
  // spi
  input  clk,
  input  cs_n,
  input  din,       // sdi
  output dout,      // sdo - NO. we assign it to last bit of the output.


  // inputs - status, externally driven
  input wire [32-1:0] reg_status,

  // general
  // output/writable regs, driven by this module
  // change name reg_gen_direct,  reg_gen_mode.


  output reg [32-1:0] reg_spi_mux,
  output reg [32-1:0] reg_4094_oe,     // TODO consider change to a generic CR control register. encode 4094-OE and trigger.
  output reg [32-1:0] reg_mode,
  output reg [32-1:0] reg_direct,
  // output reg [32-1:0] reg_seq_mode,


  // outputs signal acquisition
  output reg [32-1:0] reg_sa_p_seq_n,
  output reg [32-1:0] reg_sa_p_clk_count_precharge,

  /*
    this isn't very efficient.
    encode azmux value 4 bits, and precharge switch 2 bits.
    could use higher bits to encode other control eg. to not change/leave the precharge from previous value. etc.
    better than creating a separate controller module
  */
  output reg [32-1:0] reg_sa_p_seq0,
  output reg [32-1:0] reg_sa_p_seq1,
  output reg [32-1:0] reg_sa_p_seq2,
  output reg [32-1:0] reg_sa_p_seq3,

  // output reg [32-1:0] reg_sa_p_trig,



  // outputs adc
  output reg [32-1:0] reg_adc_p_clk_count_aperture,
  output reg [32-1:0] reg_adc_p_clk_count_reset,    // move



  // inputs adc
  input wire [32-1:0] reg_adc_clk_count_refmux_reset,
  input wire [32-1:0] reg_adc_clk_count_refmux_neg,
  input wire [32-1:0] reg_adc_clk_count_refmux_pos,
  input wire [32-1:0] reg_adc_clk_count_refmux_rd,
  input wire [32-1:0] reg_adc_clk_count_sigmux,

  input wire [32-1:0] reg_adc_stat_count_refmux_pos_up,
  input wire [32-1:0] reg_adc_stat_count_refmux_neg_up,
  input wire [32-1:0] reg_adc_stat_count_cmpr_cross_up,



);


  reg [MSB-1:0] in;      // could be MSB-8-1 i think.
  reg [MSB-1:0] out  ;    // register for output.  should be size of MSB due to high bits
  reg [8-1:0]   count;



  reg [MSB-1:0] bin;      // could be MSB-8-1 i think.
  reg [8-1:0]   bcount;


  wire dout = out[MSB- 1 -1 ];


  // To use in an inout. the initial block is a driver. so must be placed here.
  initial begin

    // TODO   review intit block - should be '=' or '<='
    // should be '='

    // control
    reg_spi_mux   = 0;          // no spi device active
    reg_4094_oe      = 0;
    reg_mode      = 0;
    reg_direct    = 0  ;
    // reg_seq_mode  <= 0; // AZ

    // signal acquisition
    // it is nice to have sa defaults...
    // so can just put in az mode, and have something working.
    reg_sa_p_clk_count_precharge  <= $rtoi( `CLK_FREQ * 500e-6 );   // == 10000 ==  500us.

    // how can express macro constant. of fixed width? does this work?
    // reg_sa_p_seq0 <= { 2'b01, ((4'd1<<3)|(3-1))   };  //  `S3

    reg_sa_p_seq_n    <= 2;
    reg_sa_p_seq0     <= { 2'b01, 4'd10   };  //  ((1<<3)|(3-1)) =  10          // S3 dcv   TODO fixme. just use the define S3
    reg_sa_p_seq1     <= { 2'b00, 4'd14    };   // ((1<<3)|(7-1)) =  14       // S7  star-gnd.  TODO fixme just use the define S7.
    reg_sa_p_seq2     <= 0;
    reg_sa_p_seq3     <= 0;

    // reg_sa_p_trig     <= 0;

    // adc
    reg_adc_p_clk_count_aperture  <=  $rtoi( `CLK_FREQ * 0.2 );      // 200ms.
    reg_adc_p_clk_count_reset     <= 24'd10000 ;            // 20000000 * 0.5e-3 == 10000   500us.
  end


  always @ (negedge clk or posedge cs_n)
  begin
    if(cs_n)
      // cs not asserted (active lo), so reset regs
      begin

        // async state on cs, must be constant.
        count   <= 0;
        in      <= 0;
        out     <= 0;
      end
    else
      // cs asserted, clock data in and out
      begin


        // shift din into in register
        in <= {in[MSB-2:0], din};

        // shift data from out register
        out <= out << 1; // this *is* zero fill operator.

        count <= count + 1;

        // blocking so that have the current count and data...
        // but should not be too slow... because references non-blocking state
        bin     = {in[MSB-2:0], din};

        // blocking count. references non-blocking.
        bcount  = count + 1;


        /*
        // we MUST read 8 bits here, in order to get the lsb bits of the register address.
            but this creates issue for how quickly we can stuff data into dout, to be read by the master on the clk cycle,
            one possibility is to use blocking assignment.
            but better/simpler - is to add extra byte, and accept that some of the higher bits are lost
        */
        if(count == 8)    // TODO - THINK WE SHOULDUSE bcount==8 here.  and this might fix the top bit issue.
          begin
            // case (`REG_LED  ) //  correct.
            case (in[8 - 2  : 0 ] )

              // test vectors
              // default:     out <=  24'b000011110000111100001111 << 8;
              // default      out <=  24'b101010101010101010101010 << 8;
              // default:     out <=  in[8 - 2  : 0] << 8;
              // default:     out <=  in[8 - 1  : 0] << 8 ;     // return passed address


              // `REG_SPI_MUX:   out <= reg_spi_mux << 8;
              `REG_4094_OE:      out <= reg_4094_oe << 8;
              `REG_MODE:      out <= reg_mode << 8;   // ok..
              `REG_DIRECT:    out <= reg_direct << 8;
              // `REG_SEQ_MODE:      out <= reg_seq_mode << 8;

              `REG_STATUS:    out <= reg_status << 8;


              ////////
              // sa
              `REG_SA_P_SEQ_N:            out <= reg_sa_p_seq_n << 8;
              `REG_SA_P_CLK_COUNT_PRECHARGE:  out <= reg_sa_p_clk_count_precharge << 8;
              `REG_SA_P_SEQ0:         out <= reg_sa_p_seq0 << 8;
              `REG_SA_P_SEQ1:         out <= reg_sa_p_seq1 << 8;
              `REG_SA_P_SEQ2:         out <= reg_sa_p_seq2 << 8;
              `REG_SA_P_SEQ3:         out <= reg_sa_p_seq3 << 8;

              // `REG_SA_P_TRIG:         out <= reg_sa_p_trig << 8;


              /////
              // adc
              `REG_ADC_P_CLK_COUNT_APERTURE:          out <= reg_adc_p_clk_count_aperture << 8;     // clk_count_sample_n clk_time_sample_clksample_time ??
              `REG_ADC_P_CLK_COUNT_RESET:   out <= reg_adc_p_clk_count_reset << 8;


              // adc inputs to module, and spi readable outputs
              `REG_ADC_CLK_COUNT_REFMUX_RESET: out <= reg_adc_clk_count_refmux_reset << 8;
              `REG_ADC_CLK_COUNT_REFMUX_NEG:   out <= reg_adc_clk_count_refmux_neg << 8;
              `REG_ADC_CLK_COUNT_REFMUX_POS:   out <= reg_adc_clk_count_refmux_pos << 8;
              `REG_ADC_CLK_COUNT_REFMUX_RD:    out <= reg_adc_clk_count_refmux_rd << 8;
              `REG_ADC_CLK_COUNT_SIGMUX:      out <= reg_adc_clk_count_sigmux << 8;

              `REG_ADC_STAT_COUNT_REFMUX_POS_UP:  out <=   reg_adc_stat_count_refmux_pos_up << 8;
              `REG_ADC_STAT_COUNT_REFMUX_NEG_UP:  out <=  reg_adc_stat_count_refmux_neg_up << 8;
              `REG_ADC_STAT_COUNT_CMPR_CROSS_UP:  out <= reg_adc_stat_count_cmpr_cross_up << 8;



              default:        out <=  24'b000011110000111100001111 << 8;
              // default:     out <=  32'b00001111000011110000111100001111<< 8;     // 32 bit value appears to work.

            endcase
          end // count == 8


        if(bcount == MSB && bin[ MSB- 1]  == 0  )   // have all bits and write flag is set.

          // OK. it is being set
          // reg_led     <= 24'b000011110000111100001111 ;   // this is right....
          // reg_led     <= bin[MSB-2 : MSB-8 ] ;      // works to return the address that was passed.

          case (  bin[MSB-2 : MSB-8 ] )

            // `REG_SPI_MUX:   reg_spi_mux <= bin;
            `REG_4094_OE:      reg_4094_oe    <= bin;
            `REG_MODE:      reg_mode    <= bin;
            `REG_DIRECT:    reg_direct  <= bin;
            // ` REG_SEQ_MODE:  reg_seq_mode <= bin;

            //////////

            `REG_SA_P_SEQ_N:                reg_sa_p_seq_n <= bin;
            `REG_SA_P_CLK_COUNT_PRECHARGE:  reg_sa_p_clk_count_precharge <= bin;

            `REG_SA_P_SEQ0:                 reg_sa_p_seq0 <= bin;
            `REG_SA_P_SEQ1:                 reg_sa_p_seq1 <= bin;
            `REG_SA_P_SEQ2:                 reg_sa_p_seq2 <= bin;
            `REG_SA_P_SEQ3:                 reg_sa_p_seq3 <= bin;

            // `REG_SA_P_TRIG:                 reg_sa_p_trig <= bin;


            ////
            `REG_ADC_P_CLK_COUNT_APERTURE:  reg_adc_p_clk_count_aperture <= bin;
            `REG_ADC_P_CLK_COUNT_RESET:     reg_adc_p_clk_count_reset <= bin;

          endcase


      end
  end


endmodule


