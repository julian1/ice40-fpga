
// - can have heartbeat timer. over spi.
// - if have more than one dac. then just create another register. very clean.
// - we can actually handle a toggle. if both set and clear bit are hi then toggle
// - instead of !cs or !cs2.  would be good if can write asserted(cs)  asserted(cs2)


`default_nettype none


function [4-1:0] update (input [4-1:0] x, input [4-1:0] set, input [4-1:0] clear,);
  begin
    if( clear & set  /*!= 0*/  ) // if both set and clear bits, then its a toggle
      update =  (clear & set )  ^ x ; // xor. to toggle.
    else
      update = ~(  ~(x | set ) | clear);
  end
endfunction




module bank   #(parameter MSB=16)   (
  input  clk,
  input  cs,
  input  din,       // sdi
  output reg dout,   // sdo


  output wire [4-1:0]  reg7,
  output wire [4-1:0]  reg8,
  output wire [4-1:0]  reg9,
  output wire [4-1:0]  reg10

);

  reg [4-1:0] regs[  0:20 ]   ;

  reg [MSB-1:0] dinput;   // input value
  reg [MSB-1:0] ret  ;    // output value
  reg [5-1:0]   count;    // 1<<4==16. 1<<5==32  number of bits so far, in spi

  assign reg7  = regs[ 7 ];
  assign reg8  = regs[ 8 ];
  assign reg9  = regs[ 9 ];
  assign reg10  = regs[ 10 ];

  // sequential
  always @ (negedge clk or posedge cs)
  begin

    if( cs)  // cs not asserted
      begin
        // ok, because cs in sensitivity list
        // EXTR.  THIS IS the synchronization action after bad sequence/frame /clock count.

        // clear on posedge of cs. and while cs is deasserted.
        // these should be able to be non blocking. because no dependence
        count   <= 0;
        dinput  <= 0;
        ret     <= 0;

      end

    else    // cs asserted
      begin

        // shift data din into the dinput toward msb
        // needs to be blocking, because of subsequent read dependence
        dinput = {dinput[MSB-2:0], din};

        // anything needed at the start of sequence
        if(count == 0)
          begin
            ;
          end

        // after we have read in the register of interest, we can setup the output value. for reads
        if(count == 7)
          begin

            // assign [ 7:0 ] idx  = dinput[ 7:0] ;

            ret = regs[ dinput[ 7:0] ]  << 7;

          end

          dout  <= ret[MSB-2];  // eg. shift data out, highest bit first
          ret   <= ret << 1;    // also a zero fill operator.
          count <= count + 1;
      end


  end


  always @ (posedge cs)   // cs done.
    begin

      // but we lose access to count when cs is added to both (the clk) sensitivity lists.
      // if(1 /*count == 0*/) // ie. sequence has correct number of clk cycles.
      if(  1 ) // ie. sequence has correct number of clk cycles.

        // wire [ 7:0 ] idx = dinput[ MSB-1:8 ];
        regs [  dinput[ MSB-1:8 ] ]   <= update(    regs [  dinput[ MSB-1:8 ]  ] , dinput, dinput >> 4);


    end

endmodule


