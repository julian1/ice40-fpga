/*
  shows trying to use r_bank, and rw_bank.
  issue is that yosys doesn't  allow port export.

- looking at dimensional arrays and ram/mem assignment. again.
- looks like a better way to handle. but export in the module port, may be a system verilog feature, that yosys doesn't support .

  --------

      =================
    OK. defined inside the module. but not in the port.

      unpacked array in ports #2717
        https://github.com/YosysHQ/yosys/issues/2717

      Cannot pass memories in as module ports #3230
        https://github.com/YosysHQ/yosys/issues/3230

      possible workaround.
      https://old.reddit.com/r/yosys/comments/44d7v6/arrays_as_inputs_to_modules/

      =================

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


module register_set #(parameter MSB=40)   (   // 1 byte address, and write flag,   4 bytes data.

  // spi
  input  clk,
  input  cs,
  input  din,       // sdi
  output dout,      // sdo - NO. we assign it to last bit of the output.


  ////////////
  // output regs
  output reg [32-1:0] reg_led ,
  output reg [32-1:0] reg_spi_mux,
  output reg [32-1:0] reg_4094,     // TODO change name it's a state register for OE. status .  or SR. reg_4094_.   or SR_4094,   sr_4094.
  output reg [32-1:0] reg_mode,
  output reg [32-1:0] reg_direct,
  output reg [32-1:0] reg_direct2,     //
  output reg [32-1:0] reg_clk_sample_duration,
  output reg [32-1:0] reg_reset,

  // input regs.
  input wire [32-1:0] reg_status,


 input [ (32-1) * (10-1) : 0  ] dst_vector,

 output [ (32-1) * (10-1) : 0  ] src_vector,


 // output reg [ 32-1 : 0 ]  xxx [ 10 -1 : 0 ];    // multidimensional array doesnt work.

  // passing a monitor in here, is useful, for monitoring internal. eg. the
  // output reg [7-1:0]   vec_monitor,
);

  // this works in yosys
  wire [32-1:0] r_bank [10-1 :0] ;
  reg [32-1:0] rw_bank [10-1 :0] ;


    // assign dst

/*
    following,
        https://github.com/YosysHQ/yosys/issues/2717

        https://old.reddit.com/r/yosys/comments/44d7v6/arrays_as_inputs_to_modules/
*/
    genvar i;

    generate for (i = 0; i < 10 ; i = i+1) begin
        assign dst_vector[i*(10 -1) +: 31 ] = r_bank [i];

    end endgenerate


    generate for (i = 0; i < 10 ; i = i+1) begin
        // assign src_vector[i*(10 -1) +: 31 ] = rw_bank [i];
        assign  rw_bank [i] = src_vector[i*(10 -1) +: 31 ] ;

    end endgenerate




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
    reg_clk_sample_duration = 0;
    reg_reset     <= 0;


    rw_bank[  0  ] = 123; rw_bank[  1  ] = 123; rw_bank[  2  ] = 123;
    rw_bank[  3  ] = 123; rw_bank[  4  ] = 123; rw_bank[  5  ] = 123;
    rw_bank[  6  ] = 123; rw_bank[  7  ] = 123; rw_bank[  8  ] = 123;
    rw_bank[  9  ] = 123;


    r_bank[  0  ] = 123; r_bank[  1  ] = 123; r_bank[  2  ] = 123;
    r_bank[  3  ] = 123; r_bank[  4  ] = 123; r_bank[  5  ] = 123;
    r_bank[  6  ] = 123; r_bank[  7  ] = 123; r_bank[  8  ] = 123;
    r_bank[  9  ] = 123;


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
              // default:        out <=  24'b000011110000111100001111 << 8;
              // default          out <=  24'b101010101010101010101010 << 8;
              // default:        out <=  in[8 - 2  : 0] << 8;
              // default:        out <=  in[8 - 1  : 0] << 8 ;     // return passed address

              `REG_LED:       out <= reg_led << 8;
              `REG_SPI_MUX:   out <= reg_spi_mux << 8;
              `REG_4094:      out <= reg_4094 << 8;

              `REG_MODE:      out <= reg_mode << 8;   // ok..
              `REG_DIRECT:    out <= reg_direct << 8;
              `REG_DIRECT2:    out <= reg_direct2 << 8;
              `REG_CLK_SAMPLE_DURATION:  out <= reg_clk_sample_duration << 8;     // clk_count_sample_n clk_time_sample_clksample_time ??
              `REG_RESET:    out <= reg_reset << 8;


              // `REG_DIRECT:    out <= { reg_direct , 8'b0 } ;   // this fails.... weird.

              `REG_STATUS:    out <= reg_status << 8;

/*
              default:        out <=  24'b000011110000111100001111 << 8;
              // default:        out <=  32'b00001111000011110000111100001111<< 8;     // 32 bit value appears to work.
*/
              default:
                            out <= r_bank[    in[8-2: 0 ]  ] ;

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

            `REG_CLK_SAMPLE_DURATION:  reg_clk_sample_duration <= bin;

              default:

                  rw_bank[ bin[MSB-2 : MSB-8 ] ] <= bin;


          endcase


      end
  end


endmodule


