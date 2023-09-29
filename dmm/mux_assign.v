
`default_nettype none


module mux_4to1_assign #(parameter MSB =24)   (
   input [MSB-1:0] a,
   input [MSB-1:0] b,
   input [MSB-1:0] c,
   input [MSB-1:0] d,

   // 2 bits
   input [1:0] sel,

   output [MSB-1:0] out

  );

  // if written like this, then there is no error.
  assign out = sel[1] ? (sel[0] ? d : c) : (sel[0] ? b : a);

/*
  // verilog nonblocking. combinatorial assign.  appears to work, even if generates a warning.
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
   input [2:0] sel,

   output [MSB-1:0] out

  );

  // written like this, there is no warning.
   assign out =
      sel[2] ?
        sel[1] ?
            (sel[0] ? h : g) : (sel[0] ? f : e)
        : sel[1] ?

            (sel[0] ? d : c) : (sel[0] ? b : a);


endmodule


