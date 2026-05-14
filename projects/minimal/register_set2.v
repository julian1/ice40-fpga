
/*
  - the EBR cannot have the SPI CS, in the block sensitivty list, because it is an asynch signal.
  insetad ERB must be put in own synchronous domain, using the system clk
  and then double flop the control signals across the CDC.

  - there is an issue that spi must be able to load the output shift register in time.
    this puts a limit on the spi speed WRT system clock, and the need to double flop
    the request/ ack.

  - the spi packet encoding should include some padding spi cycles after the addr
    to allow this synchronization.

    putting the write flag after the address (instead of at the start of the header) - will free at least one clock cycle.
    and remember the knowledge of the write flag is not needed until the last bit.
*/


/*
  CDC

  A double-flop (or two-flip-flop) synchronizer is a foundational Clock Domain
  Crossing (CDC) technique used to mitigate metastability when transferring a
  single-bit signal between asynchronous clock domains. It works by passing the
  signal through two cascaded flip-flops in the destination domain, allowing time
  for any metastable state to settle.

  However, for parallel (multi-bit) data, a simple double-flop synchronizer is
  generally inadequate because different bits may settle into stable states at
  different times, leading to data incoherency (sampling a mix of old and new
  data).

  A CDC dual-flop handshake safely transfers multi-bit data between
  asynchronous clock domains by using dual-flop synchronizers to pass control
  signals ("request" and "acknowledge") while keeping the data stable.



  Handshake synchronizer (clock domain crossing)
    https://www.youtube.com/watch?v=DLdzmNkSfG8


  AXI

  The primary purpose of the AXI handshake (VALID/READY) is to synchronize data
  transfer between a source and a destination and provide flow control in
  high-performance System-on-Chip (SoC) designs.

  In a standard AXI system, both the master and slave are expected to sample and
  drive signals using the same global clock, so the distinction between "master
  clock" or "slave clock" rarely applies to the handshake itself, as it is a
  synchronous protocol.

  An AXI ready/valid handshake can be used to cross clocking domains, but
  it cannot be used alone.

  In the AXI handshake, the Master asserts VALID to indicate that address,
  data, or control information is available, and the Slave asserts READY to
  indicate it can accept that information. The transfer occurs only when both
  signals are HIGH on the same rising clock edge.



  Once VALID is asserted, it must remain asserted until the handshake occurs (READY is high).

  READY can be high by default (if the slave can always accept data).

  To avoid deadlocks, a source must never wait for READY to go high before asserting VALID.

   if both VALID and READY are high in the same clock cycle, the transfer occurs, and the slave must accept the data.

  master asserts valid.   whether write_request and read_request

*/

/*

    iCE40 Embedded Block RAM (EBR) must be clocked on the positive edge (posedge) of the clock signal.

    A registered output in Verilog is a module output that passes through a
    flip-flop (storage element) before leaving the module, meaning it only updates
    on the active edge of a clock signal (e.g., posedge clk).

    In Verilog, implementing a RAM block with an asynchronous read signal typically
    forces synthesis tools to use Distributed RAM (LUTs) rather than Block RAM
    (BRAM).

*/

/*
  - design
    - use registers for normal SPI input and output shifting so everything is the same including the async CS reset

    - but run the ram in separate always block.
        and double flop the control signals.

    - rememmber write is not time sensitive - signal can be on rising cs.
    - while read is time sensitive  but just pad extra spi bits to provide time for the control doubling flopping.
      could even extra byte after the addr.

    - the double flop.
      - for write at the end. can be done blind - without caring about an ack. although this will lock up the resource
          until the write_request is cleared. (after CS goes hi).
      - for read  we must double flop the read_request early  in order that the addr is properly asserted in time,
          that we have the data available to put on the output shift register at the 8th byte
*/


`default_nettype none

// `include "dual_port_ram.v"


module register_set2   (

  input system_clk,

  // inputs
  // spi
  input  clk,
  input  cs_n,
  input  din,
  output dout,


);


  reg [32-1:0]  in;
  reg [32-1:0]  out;

  reg [8-1:0]   count;


  // 8 bit address
  reg [8-1:0]   addr;

  reg spi_write_flag;


  reg [32-1:0]  rout;   // read tmp


  // works
  // SB_RAM40_4KNRNW                16
  reg [32-1:0] ram [0:(1<< 16)-1];           // 16 bit works.



  /* change to arrays here
    to interleave multiple reader/writers
    and unroll the control logic
  */
  reg  write_request;   // master writes
  reg  write_ack;       // slave writes
  reg  read_request;   // master writes
  reg  read_ack;       // slave writes



  reg  spi_write_request;
  reg  spi_read_request;
  reg  spi_write_ack;
  reg  spi_read_ack;



  wire dout = out[ 32- 1];  // last bit



  reg [32-1:0]  rout;


  // use posedge because same as rest of system
  always @ ( posedge system_clk)
    begin

      // double flop the control signals
      // use a separaate block. to keep distinct if use arrays for more than one writer/reader
      write_request  <= spi_write_request;
      read_request   <= spi_read_request;

    end




  // use posedge because same as rest of system
  always @ ( posedge system_clk)
    begin


      // write request from master
      if( write_request && ! write_ack)
        begin

          ram[ addr ]   <= in;
          write_ack     <= 1'b1;
        end
      else if( !write_request )
        write_ack     <= 1'b0;



      // read request from master
      if( read_request && ! read_ack)
        begin

          rout          <= ram[ addr ];
          // rout          <=   addr  ;
          read_ack      <= 1'b1;
        end
      else if( !read_request)
        read_ack      <= 1'b0;

    end



  always @ (negedge clk or posedge cs_n)
  begin

    /*
      spi implemented normally,
      using DFF/LUT registers for in/out, and that handle async reset.

    */

    if( cs_n)
      // cs not asserted (active lo), so reset regs
      begin

        // async state on cs, must be constant.
        in      <= 0;
        out     <= 0;
        count   <= 0;
        addr    <= 0;

        // master asserts valid
        spi_write_request   <= 1'b0;
        spi_read_request   <= 1'b0;

        spi_write_ack  <= 0;

        spi_read_ack   <= 0;


      end
    else
      // cs asserted, clock data in and out
      begin


        // shift data in
        in    <= {in[ 32-2:0], din};

        // shift the data out
        out   <= out << 1;

        count <= count + 1;

        // double flop
        // into spi clock domain
        spi_write_ack  <= write_ack;

        spi_read_ack   <= read_ack;



        if( count == 0)
          begin

            // do here.

            // write flag
            // it is actually a read_flag... so need the inverse
            spi_write_flag <=  ! din ;
          end


        // read - load val into out register
        else if( count == 7)    // 8th bit, din included
          begin

            // WE *MUST* wait 8 clock cycles here to get the LSB of the address.
            // because data is sent MSB first.
            // eg. and write is flag first

            // assert address...
            addr <= { 1'b0, in[ 7 -1 -1: 0], din };
            // addr <= 4;    // returns 4
            // addr <= 3;    // returns 3

            // assuming system_clk is fast.
            spi_read_request  <= 1'b1;

          end // count == 7

        else if( count == 9)   // count >= 8 && count <
          begin

            /*
              we require at least two spi clock cycles - to get the ack back.
              consider - pad protocol with extra clk cycles to handle CDC
              or else reduce the addr width as needed.

              FIXME. reduce the addr space so that we are not truncating the data here (using << 2).
              or else use 16 bits for the addr + flags.
            */
            if( spi_read_ack)
              begin

                // shift so we can the lower two bytes.
                out   <= rout << 2;
              end
            else
              begin
                /* we did not receive the read request acknowledgment in time for the spi clock.
                  consider - set an error here, and thereafter always return 0?
                  consider - check for this value in low level mcu code.
                */
                out <= 32'b11001100110011001100110011001100;
              end

            // clear read request regardless whether succeeded
            spi_read_request  <= 1'b0;


          end


          // write - latch in value
        else if ( count == 32 + 8 - 1 && spi_write_flag)   // have all bits and write flag is set.
          begin

            // write request - can be sent blind and does not need to be acknowledged
            // but would be good to clear the write_request flag...
            // it will be cleared on async cs going hi.
            spi_write_request <= 1'b1;

            // the write_request will lock, the resource, until cleared after the write ack.
            // this happens on CS going hi

          end



      end
    end


endmodule


