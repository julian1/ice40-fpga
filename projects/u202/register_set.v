/*

*/


`default_nettype none

`include "defines.v"    // `CLK_FREQ for default calculation


`define REG_SPI_MUX                     8
`define REG_4094                        9
`define REG_MODE                        12
`define REG_DIRECT                      14
`define REG_STATUS                      17
`define REG_SEQ_MODE                    18  // treat as general register, since not used as a parameter that controls/influences any fsm.



///////////////////////

//  sample acquisition.


module register_set #(parameter MSB=40)   (   // 1 byte address, and write flag,   4 bytes data.

  // inputs
  // spi
  input  clk,
  input  cs_n,
  input  din,       // sdi
  output dout,      // sdo - NO. we assign it to last bit of the output.


  // inputs - status, externally driven
  input wire [32-1:0] reg_status,

  // outputs
  // output/writable regs, driven by this module
  output reg [32-1:0] reg_spi_mux,
  output reg [32-1:0] reg_4094,     // TODO change name it's a state register for OE. status .  or SR. reg_4094_.   or SR_4094,   sr_4094.
  output reg [32-1:0] reg_mode,
  output reg [32-1:0] reg_direct,
  output reg [32-1:0] reg_seq_mode,




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
    reg_4094      = 0;
    reg_mode      = 0;
    reg_direct    = 0  ;
    reg_seq_mode  <= 0; // AZ

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


              `REG_SPI_MUX:   out <= reg_spi_mux << 8;
              `REG_4094:      out <= reg_4094 << 8;
              `REG_MODE:      out <= reg_mode << 8;   // ok..
              `REG_DIRECT:    out <= reg_direct << 8;
              `REG_SEQ_MODE:      out <= reg_seq_mode << 8;

              `REG_STATUS:    out <= reg_status << 8;



              default:        out <=  24'b000011110000111100001111 << 8;
              // default:     out <=  32'b00001111000011110000111100001111<< 8;     // 32 bit value appears to work.

            endcase
          end // count == 8


        if(bcount == MSB && bin[ MSB- 1]  == 0  )   // have all bits and write flag is set.

          // OK. it is being set
          // reg_led     <= 24'b000011110000111100001111 ;   // this is right....
          // reg_led     <= bin[MSB-2 : MSB-8 ] ;      // works to return the address that was passed.

          case (  bin[MSB-2 : MSB-8 ] )

            `REG_SPI_MUX:   reg_spi_mux <= bin;
            `REG_4094:      reg_4094    <= bin;
            `REG_MODE:      reg_mode    <= bin;
            `REG_DIRECT:    reg_direct  <= bin;
            `REG_SEQ_MODE:  reg_seq_mode <= bin;

            //////////

          endcase


      end
  end


endmodule


