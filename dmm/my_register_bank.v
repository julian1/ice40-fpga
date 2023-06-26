

/*
// we MUST read 8 bits here, to have the lsb bits of the register address.
    but this creates issue for how quickly we can stuff data into dout, so that the value can be read
    one option is to change to non blocking.
    but simpler - is to just padd an extra byte an use a couple of bits.
*/

`define REG_LED                 7
`define REG_SPI_MUX             8
`define REG_4094                9


// could also
`define REG_WHOOT               9




/*

  https://stackoverflow.com/questions/16369698/how-to-pass-array-structure-between-two-verilog-modules
*/

module my_register_bank   #(parameter MSB=32)   (

  // spi
  input  clk,
  input  cs,
  input  din,       // sdi
  output dout,       // sdo

  // input == input wire

  // control read/write control vars
  // use ' inout',  must be inout to write
  inout wire [24-1:0] reg_led ,    // need to be very careful. only 4 bits. or else screws set/reset calculation ...

 output reg [24-1:0] reg_spi_mux,       // 8 bit registerrr
  output reg [24-1:0] reg_4094,


);

  // TODO rename these...
  // MSB is not correct here...
  reg [MSB-1:0] in;      // could be MSB-8-1 i think.
  reg [MSB-1:0] out  ;    // register for output.  should be size of MSB due to high bits
  reg [8-1:0]   count;

  wire dout = out[MSB- 1];



  // reg [ 12 - 1: 0 ] reg_array[ 32 - 1 : 0 ] ;
  // reg [ 7 - 1: 0 ] reg_array[ 32 - 1 : 0 ] ;
  // reg [ 24 - 1: 0 ] reg_array[ 0: (1<<6) - 1  ] ; // eg. 8 bits == 256 registers. 128 registers.
  reg [ 24 - 1: 0 ] reg_array[ 0 : (1<<6) -1  ] ; // 20 registers.

  // To use in an inout. the initial block is a driver. so must be placed here.
  initial begin
    reg_led             = 5'b10101;

    reg_array[  `REG_LED   ]  = 24'b101010101010101010101010; // KEEP. good test vector.

  end



  // wire [8-1:0] addr  = in[ MSB-1: MSB-8 ];  // single byte for reg/address,
  // wire [MSB-8-1:0] val   = in;              // lo 24 bits/


  // reg [8-1:0]   idx;

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

        // idx <= 0;
      end
    else
      // cs asserted, clock data in and out
      begin
        /*
          TODO. would be better as non-blocking.
          but we end up with a losing a bit on addr or value.
          losing a bit on addr is o. though.
        */
        // shift din into in register
        in <= {in[MSB-2:0], din};

        // shift data from out register
        out <= out << 1; // this *is* zero fill operator.

        count <= count + 1;

        // possible - we need a higher count to actually get the damn register address.

        /*
        // we MUST read 8 bits here, to have the lsb bits of the register address.
            but this creates issue for how quickly we can stuff data into dout, so that the value can be read
            one option is to change to non blocking.
            but simpler - is to just padd an extra byte an use a couple of bits.
        */
        // if(count == 8)
        if(count == 8)  // we have read enough of the register, to be able to load the output value
                          // have to be early to use non blocking.

          begin
            case (in[8 - 1 - 1: 0 ] )

              // `REG_LED:        out <= 24'b101 << 9;
              // default:  out <= reg_led  << 9;

              // `REG_LED:        out <= reg_led  << 9;
              // `REG_LED:        out <= reg_array[ in[8 - 1 - 1: 0 ]   ] << 9;
              default:        out <= reg_array[ in[8 - 1 - 1: 0 ]   ] << 9;

            endcase


          end

      end
  end

  // The setting of the hi bit - and it's use in indexing the mem/bitarray is perhaps what caused previous problems.
  // if use mem/bit array, then we would have to explicitly test.


  wire [  (1<<6) -1 : 0 ] addr = in[ MSB-2: MSB-8 ];  // single byte for reg/address,

  wire [24-1 :0] val   = in[ MSB-8- 1  : 0 ] ;              // lo 24 bits/
  wire flag = in[ MSB- 1   ] ;              // lo 24 bits/
  wire flag1 = in[ MSB- 2   ] ;              // lo 24 bits/




  // set/write
  always @ (posedge cs)   // cs done.
  begin
    if(count == MSB ) // MSB
      begin

          // maybe we are just accidently always overwriting the value... and the address construction is fine.

        // OR the issue -
        // IS THAT in is being written - on the new cycle. without blocking.
        // which kills our value.

        if ( flag == 0  )  // 0 means write.

          case (addr)

            // `REG_LED:                 reg_led <= val;
            // `REG_LED:                 reg_array[  addr ] <= val;
            `REG_LED:                 reg_array[  `REG_LED ] <= val;  // OK.  works.
            // `REG_LED:                 reg_array[ addr  ] <= val;  // NOT OK. why? indexing issue?

            // as soon as we try to subscript then we overwrite.

          endcase

      end
  end
endmodule


