
`default_nettype none


module mux_4to1_assign #(parameter MSB =24)   (
   input [MSB-1:0] a,
   input [MSB-1:0] b,
   input [MSB-1:0] c,
   input [MSB-1:0] d,

   // 2 bits
   input [2-1:0] sel,

   output [MSB-1:0] out

  );

  // if written like this, then there is no error.
  assign out = sel[1] ? 
                  (sel[0] ? d : c) 
                  : (sel[0] ? b : a);

/*
  // verilog nonblocking. combinatorial assign.  works in yosys, even if generates a warning.
  always @(*)
     case (sel)
      2'b00 :  out = a;
      2'b01 :  out = b;
      2'b10 :  out = c;
      2'b11 :  out = d;
    endcase
*/

endmodule



module mux_8to1_assign #(parameter MSB =24)   (
   input [MSB-1:0] a,
   input [MSB-1:0] b,
   input [MSB-1:0] c,
   input [MSB-1:0] d,

   input [MSB-1:0] e,
   input [MSB-1:0] f,
   input [MSB-1:0] g,
   input [MSB-1:0] h,

    // 3 bits.
   input [3-1 :0] sel,
   // input [7:0] sel,

   output [MSB-1:0] out

  );


  // 94MHz.
  // using case expression, generates warning. as ternary expression this is none
   assign out =
      sel[2] ?
        sel[1] ?
            (sel[0] ? h : g) : (sel[0] ? f : e)
        : sel[1] ?

            (sel[0] ? d : c) : (sel[0] ? b : a);

  // 5 == 0101


/*
  always @(*)
     case (sel)
      0 :  out = a;
      1 :  out = b;
      2 :  out = c;
      3 :  out = d;
      4 :  out = e;
      5 :  out = f;
      6 :  out = g;
      7 :  out = h;
    endcase
*/

/*
  // one hot.
  // 98.11 MHz.
   assign out =
            (sel[0] ? b :
            (sel[1] ? c :
            (sel[2] ? d :
            (sel[3] ? e :
            (sel[4] ? f :
            (sel[5] ? g :
            (sel[6] ? h :   a)))))));
 */

endmodule



/*
  synch mux also not working.

*/

module sync_mux_8 #(parameter MSB =24)   (

    input   clk,
  // reset.

   input [MSB-1:0] a,
   input [MSB-1:0] b,
   input [MSB-1:0] c,
   input [MSB-1:0] d,

   input [MSB-1:0] e,
   input [MSB-1:0] f,
   input [MSB-1:0] g,
   input [MSB-1:0] h,

    // 3 bits.
   input [3-1 :0] sel,
   // input [7:0] sel,

  // must be reg. for synchronous
   output reg [MSB-1:0] out

  );

  // always @(posedge clk  or posedge reset )
 
  always @(posedge clk)
  // always @(*)
     case (sel)
      0 :  out <= a;
      1 :  out <= b;
      2 :  out <= c;
      3 :  out <= d;
      4 :  out <= e;
      5 :  out <= f;
      6 :  out <= g;
      7 :  out <= h;
    endcase


endmodule












