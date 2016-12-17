
// OK, be nice to separate out the module...


module blinkmodule (
  input  clk,
  output led
);
  reg [31:0] counter2 = 0;

  always@(posedge clk) begin
    counter2 <= counter2 + 1;
  end
  assign {led} = counter2 >> 23;
endmodule




module top (
  input  clk,

  output led1,
  output led2,
  output led3,

  input RS232_Rx_TTL,
  input RS232_Tx_TTL  
);


  blinkmodule #()
  blinkmodule
    (
    .clk(clk),
    .led(led1)
  );


  assign {led2} = RS232_Rx_TTL;  // it may be permanently getting something...
  assign {led3} = clk ;

endmodule


