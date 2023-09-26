
/*
// we MUST read 8 bits here, to have the lsb bits of the register address.
    but this creates issue for how quickly we can stuff data into dout, so that the value can be read
    one option is to change to non blocking.
    but simpler - is to just padd an extra byte an use a couple of bits.
*/


/*
    could add back the bitwise set,clear,toggle, for a 8 bit reg, then could aggrevate registers if we wanted.
    error flags etc.

*/

`default_nettype none


`define REG_LED                 7
`define REG_SPI_MUX             8
`define REG_4094                9


// `define REG_MODE                16  // 10000
`define REG_MODE                12  // 10000
`define REG_DIRECT        14





// reg [ 12 - 1: 0 ] reg_array[ 32 - 1 : 0 ] ;    // 12x   32 bit registers


/*
  EXTR.  Be careful.
    passing a register shorter than 24bits. here. corrupts behavior.
    kind of bizarre.
*/


module register_set #(parameter MSB=40)   (

  // spi
  input  clk,
  input  cs,
  input  din,       // sdi
  output dout,      // sdo - NO. we assign it to last bit of the output.


  ////////////
  // regs
  // todo. consider adding bitwidth in name.
  // need to be regs, because assign in sequential code/ always block.

  output reg [32-1:0] reg_led ,
  output reg [32-1:0] reg_spi_mux,
  output reg [32-1:0] reg_4094,     // TODO change name it's a state register for OE. status .  or SR. reg_4094_.   or SR_4094,   sr_4094.
                                                // no it's a state register. not status.

  output reg [32-1:0] reg_mode,

  output reg [32-1:0] reg_direct    // better name?

  // passing a monitor in here, is useful, for monitoring internal. eg. the
  // output reg [7-1:0]   vec_monitor,
);


  reg [MSB-1:0] in;      // could be MSB-8-1 i think.
  reg [MSB-1:0] out  ;    // register for output.  should be size of MSB due to high bits
  reg [8-1:0]   count;

  wire dout = out[MSB- 1 -1 ];


  // To use in an inout. the initial block is a driver. so must be placed here.
  initial begin
    // reg_led       = 24'b101010101010101010101010; // magic, keep. useful test vector
    reg_led       = 24'b101010101010101010101111; // magic, keep. useful test vector
    reg_spi_mux   = 0;          // no spi device active
    reg_4094      = 0;


     // reg_mode = 0;      // thisi doesn't work.  we lose relay.

     // reg_direct = 1<<13 ;   // but relay works, when do this...a absolutely weird.
     reg_direct = 0  ;   // but relay works, when do this...a absolutely weird.     OK. now works.



  end





  // TODO 7 bits, address space, without the write bit set.
  wire [  7 -1 : 0 ] addr = in[ MSB-2: MSB-8 ];  // single byte for reg/address,

  // wire [24-1 :0] val24   = in[ 24 - 1 : 0 ] ;              // lo 24 bits/ ... FIXME. indexing not quite correct.
  wire [32-1 :0] val32   = in[ 32 - 1 : 0 ] ;              // lo 24 bits/ ... FIXME. indexing not quite correct.

  wire flag = in[ MSB- 1   ] ;

/*
  EXTR.  async  - is means for reset. so set a constant default initial value of 0.

        it is not meant to be use for sampling the cs when it return hi at the finish of the sequence.

        BUT - it's an issue. because we don't necessarily get a clk signal after the cs goes high on which to sample.

        OR do we even care......     just clock the value in on the


        So potential solution. is just to always take the value. on the clk.    and not care about the poedge.
        And perhaps

        ACTUALLY WE USE the reset... to set constant 0 values for the registers . so it is useful.
*/

  // read
  // clock value into into out var
  // USING A NEG EDGE CLOCK.
  always @ (negedge clk or posedge cs)
  // always @ (posedge clk or posedge cs)
  begin
    if(cs)
      // cs not asserted (active lo), so reset regs
      begin

        // OK, we are getting an error here...


        count   <= 0;
        in      <= 0;
        out     <= 0;
      end
    else
      // cs asserted, clock data in and out
      begin
        /*
          whoot. now  non-blocking.
        */
        // shift din into in register
        // in <= {in[MSB-2:0], din};
        in <= {in[MSB-2:0], din};

        // shift data from out register
        out <= out << 1; // this *is* zero fill operator.

        count <= count + 1;

        /*
        // we MUST read 8 bits here, in order to get the lsb bits of the register address.
            but this creates issue for how quickly we can stuff data into dout, to be read by the master on the clk cycle,
            one possibility is to use blocking assignment.
            but better/simpler - is to add extra byte, and accept that some of the higher bits are lost
        */
        if(count == 8)
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
              // `REG_DIRECT:    out <= { reg_direct , 8'b0 } ;   // this fails.... weird.

              default:        out <=  24'b000011110000111100001111 << 8;
              // default:        out <=  32'b00001111000011110000111100001111<< 8;     // 32 bit value appears to work.

            endcase
          end // count == 8


        // issue could be count.  or msb or addr decoding.

        // with count == MSB-1 ... it sets everything to 0. weird?????

        if(count == MSB - 1 && in[ MSB- 2   ]  == 0 ) // OK.

          // OK. it is being set
          // reg_led     <= 24'b000011110000111100001111 ;
          // reg_led     <= addr  ;
          reg_led     <= in[MSB-2-1 : MSB-8-1 ] ;      // set to the passed address
/*
          case (addr)

            `REG_LED:       reg_led     <= val32;
            `REG_SPI_MUX:   reg_spi_mux <= val32;
            `REG_4094:      reg_4094    <= val32;

            `REG_MODE:      reg_mode <= val32;      // ok.
            `REG_DIRECT:    reg_direct <= val32   ;   // this works except the top bit. so it's pretty good.
            // `REG_DIRECT:    reg_direct <= { 8'b11111111, val32[ 24-1 : 0 ] }  ;   // this works except the top bit. so it's pretty good.

            // what if write two registers.  and can test values.

          endcase
*/



      end
  end


endmodule


function [4-1:0] update (input [4-1:0] x, input [4-1:0] set, input [4-1:0] clear,);
  begin
    if( clear & set  /*!= 0*/  ) // if both a bit of both set and clear are set, then treat as toggle
      update =  (clear & set )  ^ x ; // xor. to toggle.
    else
      update = ~(  ~(x | set ) | clear);    // clear in priority
  end
endfunction


