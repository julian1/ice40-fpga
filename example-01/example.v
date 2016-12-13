
// from https://github.com/cliffordwolf/icestorm/tree/master/examples/icestick

// example.v
// module top (input a, b, output y);
//   assign y = a & b;
// endmodule


module inputmodule (
  input  a,
  output b,
  output LED1
);

  assign LED1 = a;
  assign b = a;

endmodule



module anothermodule (
  input  clk,
  output LED1
);

  reg [31:0] counter2 = 0;

  always@(posedge clk) begin
    counter2 <= counter2 + 1;
  end

  // assign {LED1} = counter2 >> 24;
endmodule




module top (
  input  clk,
  output LED1,
  output LED2,
  output LED3,
  output LED4,
  output LED5,
  input a,
  output b
);

  anothermodule #()
  anothermodule
    (
    .clk(clk),
    .LED1(LED2)
  );

  inputmodule #()
  inputmodule 
  (
    .a(a),
    .b(b),
    .LED1(LED1)
  );

  localparam BITS = 5;
  localparam LOG2DELAY = 21;

  reg [BITS+LOG2DELAY-1:0] counter = 0;
  reg [BITS-1:0] outcnt;

  always@(posedge clk) begin
    counter <= counter + 1;
    outcnt <= counter >> LOG2DELAY;
  end

  // assign {LED1} = counter2 >> 22;

  assign { LED5} = outcnt ^ (outcnt >> 1);

endmodule


