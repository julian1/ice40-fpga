



  /*
    a double flop will work for a single bit - we or re
    if addr/data is asserted in one cycle.  and we/re asserted in another
    that may be OK.


    or
    - axi handshake for cdc

      A double-flop (or two-flip-flop) synchronizer is a foundational Clock Domain
      Crossing (CDC) technique used to mitigate metastability when transferring a
      single-bit signal between asynchronous clock domains. It works by passing the
      signal through two cascaded flip-flops in the destination domain, allowing time
      for any metastable state to settle.

      However, for parallel (multi-bit) data, a simple double-flop synchronizer is
      generally inadequate because different bits may settle into stable states at
      different times, leading to data incoherency (sampling a mix of old and new
      data).

      In the AXI handshake, the Master asserts VALID to indicate that address,
      data, or control information is available, and the Slave asserts READY to
      indicate it can accept that information. The transfer occurs only when both
      signals are HIGH on the same rising clock edge.


      - perhaps the simplest guarantee... is just to always have data (addr, in, out) asserted for an entire spi clock cycle
          before using a single bit  to read.
          and ensure system clock is faster
      ---------
      master asserts valid.
      slave asserts ready


      Once VALID is asserted, it must remain asserted until the handshake occurs (READY is high).

      READY can be high by default (if the slave can always accept data).

      To avoid deadlocks, a source must never wait for READY to go high before asserting VALID.

       if both VALID and READY are high in the same clock cycle, the transfer occurs, and the slave must accept the data.

      master asserts valid.   whether write_request and read_request


      In a standard AXI system, both the master and slave are expected to sample and
      drive signals using the same global clock, so the distinction between "master
      clock" or "slave clock" rarely applies to the handshake itself, as it is a
      synchronous protocol.

      Yes, an AXI ready/valid handshake can be used to cross clocking domains, but it cannot be used alone.


      It looks like one just double flops the valid.
      ------------------

    A CDC dual-flop handshake safely transfers multi-bit data between
    asynchronous clock domains by using dual-flop synchronizers to pass control
    signals ("request" and "acknowledge") while keeping the data stable.


      the
  */


/*
  rewrite. apr. 2026

  consider
    just try writing the actual sequencer module.
    using normal LUT/DFF rather than EBR.  embedded block ram.
    can test the interpreter.
    we already have enough space.

  consider.
    - use registers for shift. and keep spi part the same.co  with async cs reset

    - then run the ram in separate always block.
        and use double flop.    eg. for

    - rememmber write is not time sensitive - signal can be on rising cs.
    - and read is not time sensitive  - if pad extra spi bits - eg. extra bit, or even extra byte after the addr.

    - the double flop.
          - for write at the end. we have addr,output in out reg. -   so would just double flop the input within the always system clk .
          - for read  at 7th/8th bit.   we double flop read  - on the 7th, then 8th clock cycle. set up by the addr two previous cycles before.
    -

    - with a 2 bit read pause/ for CDC..
    - Math.pow(2, 6) =  64

        which is quite enough.

*/

  // always @(posedge clk) begin
  // issue may be negedge...
  /*

    iCE40 Embedded Block RAM (EBR) must be clocked on the positive edge (posedge) of the clock signal.

    A registered output in Verilog is a module output that passes through a
    flip-flop (storage element) before leaving the module, meaning it only updates
    on the active edge of a clock signal (e.g., posedge clk).

    negedge seems ok.
        BUT. doesn't  like the sensitivity on the cs posedge

    fails if

    problem. with synchronous reset - is we are not giving it the clk.

    As soon as add the posedge cs_n
      Warning: Replacing memory \ram with list of registers. See register_set2.v:145


    In Verilog, implementing a RAM block with an asynchronous read signal typically
    forces synthesis tools to use Distributed RAM (LUTs) rather than Block RAM
    (BRAM).

  */


`default_nettype none

`include "dual_port_ram.v"


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


  // 7 bit address.   eg. 128 addresses
  // now 8. because did not instantiate
  reg [8-1:0]   addr;

  reg spi_write_flag;


  // reg [8-1:0]   addr1;    // write available on the second clock. inside the system always block.

  // reg           we;     // write enable


  // reg [32-1:0]  rin;   // write tmp.  (rename out1  - to indicate available on second clock ? )
  reg [32-1:0]  rout;   // read tmp


  // works
  //   SB_RAM40_4KNRNW                16
  reg [32-1:0] ram [0:(1<< 16)-1];           // 16 bit works.



  reg [ 2-1: 0] write_request;   // master writes lo bit
  reg [ 2-1: 0] write_ack;       // slave writes lo bit

  reg [ 2-1: 0] read_request;   // master writes lo bit
  reg [ 2-1: 0] read_ack;       // slave writes lo bit



  wire dout = out[ 32- 1];  // last bit



  reg [32-1:0]  rout;



  // use posedge because same as rest of system
  always @ ( posedge system_clk)
    begin

      // want to request should only be writtewill be

      /* the master - should only write the lo bit.
          the slave only the hi bit. in order to avoid conflicts
          ----
          we have to wait for the ack...
      */
      write_request[1]  <= write_request[0];
      read_request[1]   <= read_request[ 0];


      // from master
      if( write_request[ 1]  == 1'b1 )
        begin

          // double flop - to wait for add and in to be stable
          ram[ addr ]       <= in;
          write_ack[ 0]     <= 1'b1;
        end


      // from master
      if( read_request[ 1]  == 1'b1 )
        begin

          // double flop - to wait addr to be stable
          rout          <= ram[  addr  ];
          read_ack[ 0]  <= 1'b1;
        end


    end


  /*
    issue with two drivers/writers of out.
    is different from the CDC meta stable issues.


  */


  always @ (negedge clk or posedge cs_n)
  begin

    /* this wont work.

      because we are not guaranteed any clks. when cs_n is hi.
      or perhaps the spi device will send a parking clock..
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
        write_request[0]   <= 1'b0;
        read_request[ 0]   <= 1'b0;

      end
    else
      // cs asserted, clock data in and out
      begin


        // shift data in
        in    <= {in[ 32-2:0], din};

        // shift the data out
        out   <= out << 1;

        count <= count + 1;


        write_ack[1]  <= write_ack[0];
        read_ack[1]   <= read_ack[ 0];



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

            // assert address...
            addr <= { 1'b0, in[ 7 -1 -1: 0], din };

            // delay here
            // which gives time for the addr,in to become stable in the system_clk domain
            // assuming system_clk is fast.
            read_request[ 0]  <= 1'b1;

          end // count == 7

        else if( count ==  8)   // count >= 8 && count <
          begin

            // assumption the read worked, because of difference in clk frequency
            // consider - pad protocol with extra clk cycles to handle CDC
            if( read_ack[ 1])
              begin
                out   <= rout;

                          end
            else
              begin

                out <= 32'b11001100110011001100110011001100;
              end

            // clear read request regardless whether succeeded
            read_request[ 0]  <= 1'b0;


          end


          // write - latch in value
        else if ( count == 32 + 8 - 1 && spi_write_flag)   // have all bits and write flag is set.
          begin

            // write request - can be sent blind and does not need to be acknowledged
            // but would be good to clear the write_request flag...
            // it will be cleared on async cs going hi.
            write_request[0] <= 1'b1;

          end



      end
    end


endmodule


