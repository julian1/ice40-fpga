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


`define REG_LED           7
`define REG_SPI_MUX       8
`define REG_4094          9


`define REG_MODE          12  // 10000
`define REG_DIRECT        14
`define REG_DIRECT2       15      // don't use. deprecate .   was only for initial AZ switching test.

`define REG_CLK_SAMPLE_DURATION 16   // clk sample time. change name aperture.

`define REG_STATUS        17
`define REG_RESET         18   // reset -> hi.  normal -> lo.


//  add the AQUIS or SA for sample acquisition.
`define REG_SA_ARM_TRIGGER   19



`define REG_ADC_CLK_COUNT_MUX_NEG   30
`define REG_ADC_CLK_COUNT_MUX_POS   31
`define REG_ADC_CLK_COUNT_MUX_RD    32


// `define REG_ADC_P_APERTURE          32   // p for control parameter.


module register_set #(parameter MSB=40)   (   // 1 byte address, and write flag,   4 bytes data.

  // inputs
  // spi
  input  clk,
  input  cs,
  input  din,       // sdi
  output dout,      // sdo - NO. we assign it to last bit of the output.


  // input/read only regs, externally driven.
  input wire [32-1:0] reg_status,

  // ADD MONITOR to the reg_status . as read to allow the monitor to be read. could be useful.  or have a separate
  // or just add to reg_status.
  // EXTR.   SIMPLIFY the reg_status .    add hw_flags.   and monitor. at construction poinit
  // then in mcu code.  we selectively filter - onyl the slow things..
  // effectively another status register.

  // adc inputS
  input wire [32-1:0] reg_adc_clk_count_mux_neg,
  input wire [32-1:0] reg_adc_clk_count_mux_pos,
  input wire [32-1:0] reg_adc_clk_count_mux_rd,


  // outputs
  // output/writable regs, driven by this module
  output reg [32-1:0] reg_led ,
  output reg [32-1:0] reg_spi_mux,
  output reg [32-1:0] reg_4094,     // TODO change name it's a state register for OE. status .  or SR. reg_4094_.   or SR_4094,   sr_4094.
  output reg [32-1:0] reg_mode,
  output reg [32-1:0] reg_direct,
  output reg [32-1:0] reg_direct2,     //  unused.
  output reg [32-1:0] reg_reset,      // unused.

  output reg [32-1:0] reg_sa_arm_trigger,

  //
  output reg [32-1:0] reg_clk_sample_duration,    // move


);


  reg [MSB-1:0] in;      // could be MSB-8-1 i think.
  reg [MSB-1:0] out  ;    // register for output.  should be size of MSB due to high bits
  reg [8-1:0]   count;



  reg [MSB-1:0] bin;      // could be MSB-8-1 i think.
  reg [8-1:0]   bcount;


  wire dout = out[MSB- 1 -1 ];


  // To use in an inout. the initial block is a driver. so must be placed here.
  initial begin
    // reg_led       = 24'b101010101010101010101010; // magic, keep. useful test vector
    reg_led       = 24'b101010101010101010101111; // magic, keep. useful test vector
    reg_spi_mux   = 0;          // no spi device active
    reg_4094      = 0;
    reg_mode      = 0;
    reg_direct    = 0  ;
    reg_direct2    = 0  ;

    reg_reset     <= 0;
    reg_sa_arm_trigger <= 0;
    reg_clk_sample_duration = 0;

  end


  always @ (negedge clk or posedge cs)
  begin
    if(cs)
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

              `REG_LED:       out <= reg_led << 8;
              `REG_SPI_MUX:   out <= reg_spi_mux << 8;
              `REG_4094:      out <= reg_4094 << 8;

              `REG_MODE:      out <= reg_mode << 8;   // ok..
              `REG_DIRECT:    out <= reg_direct << 8;
              `REG_DIRECT2:   out <= reg_direct2 << 8;
              `REG_RESET:     out <= reg_reset << 8;


              `REG_CLK_SAMPLE_DURATION:  out <= reg_clk_sample_duration << 8;     // clk_count_sample_n clk_time_sample_clksample_time ??

              // inputs

              `REG_STATUS:    out <= reg_status << 8;
              `REG_SA_ARM_TRIGGER:    out <= reg_sa_arm_trigger << 8;

              `REG_ADC_CLK_COUNT_MUX_NEG:   out <= reg_adc_clk_count_mux_neg << 8;
              `REG_ADC_CLK_COUNT_MUX_POS:   out <= reg_adc_clk_count_mux_pos << 8;
              `REG_ADC_CLK_COUNT_MUX_RD:    out <= reg_adc_clk_count_mux_rd << 8;


              default:        out <=  24'b000011110000111100001111 << 8;
              // default:     out <=  32'b00001111000011110000111100001111<< 8;     // 32 bit value appears to work.

            endcase
          end // count == 8


        if(bcount == MSB && bin[ MSB- 1]  == 0  )   // have all bits and write flag is set.

          // OK. it is being set
          // reg_led     <= 24'b000011110000111100001111 ;   // this is right....
          // reg_led     <= bin[MSB-2 : MSB-8 ] ;      // works to return the address that was passed.

          case (  bin[MSB-2 : MSB-8 ] )

            `REG_LED:       reg_led     <= bin;
            `REG_SPI_MUX:   reg_spi_mux <= bin;
            `REG_4094:      reg_4094    <= bin;

            `REG_MODE:      reg_mode    <= bin;
            `REG_DIRECT:    reg_direct  <= bin;
            `REG_DIRECT2:   reg_direct2  <= bin;
            `REG_RESET:     reg_reset   <= bin;


             `REG_SA_ARM_TRIGGER:  reg_sa_arm_trigger <= bin;

            `REG_CLK_SAMPLE_DURATION:  reg_clk_sample_duration <= bin;

          endcase


      end
  end


endmodule


