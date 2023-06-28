

/*
// we MUST read 8 bits here, to have the lsb bits of the register address.
    but this creates issue for how quickly we can stuff data into dout, so that the value can be read
    one option is to change to non blocking.
    but simpler - is to just padd an extra byte an use a couple of bits.
*/


/*
  if we add back the bitwise set,clear,toggle, for a 8 bit reg, then could aggrevate registers if we wanted.
    error flags etc.

*/

`define REG_LED                 7
`define REG_SPI_MUX             8
`define REG_4094                9






function [4-1:0] update (input [4-1:0] x, input [4-1:0] set, input [4-1:0] clear,);
  begin
    if( clear & set  /*!= 0*/  ) // if both a bit of both set and clear are set, then treat as toggle
      update =  (clear & set )  ^ x ; // xor. to toggle.
    else
      update = ~(  ~(x | set ) | clear);    // clear in priority
  end
endfunction







module my_register_bank02   #(parameter MSB=40)   (

  // spi
  input  clk,
  input  cs,
  input  din,       // sdi
  output dout,       // sdo


  // control read/write control vars
  // use ' inout',  must be inout to write

  // todo. consider adding bitwidth in name.
  // inout wire [24-1:0] reg_led ,   // TODO should be a register?
  output reg [24-1:0] reg_led ,   // TODO should be a register?

  output reg [24-1:0] reg_spi_mux,
  output reg [24-1:0] reg_4094,     // TODO change name it's a state register for OE. status .  or SR. reg_4094_.   or SR_4094,   sr_4094.


);

  // TODO rename these...
  // MSB is not correct here...
  reg [MSB-1:0] in;      // could be MSB-8-1 i think.
  reg [MSB-1:0] out  ;    // register for output.  should be size of MSB due to high bits
  reg [8-1:0]   count;

  wire dout = out[MSB- 1];


  // To use in an inout. the initial block is a driver. so must be placed here.
  initial begin
    reg_led       = 5'b10101;   // 24'b10101 ? should specify bitwidth
    reg_spi_mux   = 0;          // no spi device active
    reg_4094      = 0;

  end


  // read
  // clock value into into out var
  always @ (negedge clk or posedge cs)
  begin
    if(cs)
      // cs not asserted (active lo), so reset regs
      begin
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
            case (in[8 - 1 - 1: 0 ] )

              `REG_LED:       out <= reg_led  << 9;
              `REG_SPI_MUX:   out <= reg_spi_mux << 9;
              `REG_4094:      out <= reg_4094 << 9;
              default:        out <= 12345;

            endcase
          end

      end
  end


  wire [  (1<<6) -1 : 0 ] addr = in[ MSB-2: MSB-8 ];  // single byte for reg/address,

  // change to increase bits.
  wire [24-1 :0] val24   = in[ MSB-8- 1  : 0 ] ;              // lo 24 bits/ ... FIXME. indexing not quite correct.
  // wire [32-1 :0] val32   = in[ MSB-8- 1  : 0 ] ;              // lo 24 bits/
  wire flag = in[ MSB- 1   ] ;              // lo 24 bits/



  // set/write
  always @ (posedge cs)   // cs done.
  begin
    if(count == MSB ) // MSB
      begin

        if ( flag == 0  )  // 0 means write.
          case (addr)

            `REG_LED:       reg_led <= val24;
            `REG_SPI_MUX:   reg_spi_mux <= val24;
            `REG_4094:      reg_4094 <= val24;

          endcase
      end

    // we could handle bit set/clear/toggle updates here, if we wanted, for 8 bit registers.
    else if( count ==  8 + 8 + 8 )
      begin

      end
  end


endmodule


