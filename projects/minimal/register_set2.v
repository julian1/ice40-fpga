/*
  rewrite. apr. 2026


*/

`default_nettype none

`include "dual_port_ram.v"


module register_set2   (

  // inputs
  // spi
  input  clk,
  input  cs_n,
  input  din,
  output dout,


);


  reg [32-1:0]  in;
  reg [32-1:0]  out;
  // reg [32-1:0]  tmp;
  reg [8-1:0]   count;


  // 7 bit address.   eg. 128 addresses
  // now 8. because did not instantiate
  reg [8-1:0]   addr;

  reg           write_flag;



  // Memory Array
  // reg [DATA_WIDTH-1:0] ram [0:(1<<ADDR_WIDTH)-1];
  // reg [32-1:0] ram [0:(1<< 8)-1];
  ////////////////////
  //reg [32-1:0] ram [0:(1<< 8)-1];           // 7 bit address

  // works
  //   SB_RAM40_4KNRNW                16
  reg [32-1:0] ram [0:(1<< 16)-1];           // 16 bit works.




  wire dout = out[ 32- 1];  // last bit


  // To use in an inout. the initial block is a driver. so must be placed here.
  initial begin


  end

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




  always @ (negedge clk /*or posedge cs_n*/)
  // always @ (posedge clk or posedge cs_n)
  begin

    // p
    if( cs_n)
      // cs not asserted (active lo), so reset regs
      begin

        // async state on cs, must be constant.
        in      <= 0;
        out     <= 0;
        count   <= 0;
        addr    <= 0;
      end
    else
      // cs asserted, clock data in and out
      begin


        // shift din into in register
        in <= {in[ 32-2:0], din};

        // shift data from out register
        // this *is* zero fill operator.
        out <= out << 1;

        count <= count + 1;


        if( count == 0)
          begin

            // write flag
            // it is actually a read_flag... so need the inverse
            write_flag <=  ! din ;
          end


        // read - load val into out register
        else if( count == 7)    // 8th bit, din included
          begin

            addr <= { 1'b0, in[ 7 -1 -1: 0], din };       // store for later use by write

            // trying to use in this clk cycle, wont work
            // out <= ram[  { 1'b0, in[ 7 -1 -1: 0], din } ];

          end // count == 7

        else if( count == 8)
          begin

            // overrides the default action to just shift data out
            // OK
            out <= ram[ addr ];

          end

        // write - latch in value
        else if ( count == 32 + 8 - 1 && write_flag)   // have all bits and write flag is set.
          begin

            ram[ addr ] <= { in[ 32 -1 -1: 0], din };

          end
      end
    end


endmodule


