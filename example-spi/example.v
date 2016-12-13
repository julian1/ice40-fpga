


module blinkmodule (
  input  clk,
  output LED1
);
  reg [31:0] counter2 = 0;

  always@(posedge clk) begin
    counter2 <= counter2 + 1;
  end

  assign {LED1} = counter2 >> 24;

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

  blinkmodule #()
  blinkmodule
    (
    .clk(clk),
    .LED1(LED2)
  );

endmodule


