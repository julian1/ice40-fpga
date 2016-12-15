
// OK, be nice to separate out the module...


module blinkmodule (
  input  clk,
  output LED
);
  reg [31:0] counter2 = 0;

  always@(posedge clk) begin
    counter2 <= counter2 + 1;
  end
  assign {LED} = counter2 >> 23;
endmodule


// works!

module SPI_slave(clk, SCK, MOSI, MISO, SSEL, LED);

  input clk;
  input SCK, SSEL, MOSI;  // ssel is slave select
  output MISO;
  output LED;

  // ahhh - this works by storing the last two sck states, and then compare them to
  // to determine if it's rising or falling.

  // sync SCK to the FPGA clock using a 3-bits shift register
  reg [2:0] SCKr;  always @(posedge clk) SCKr <= {SCKr[1:0], SCK};
  wire SCK_risingedge = (SCKr[2:1]==2'b01);  // now we can detect SCK rising edges
  wire SCK_fallingedge = (SCKr[2:1]==2'b10);  // and falling edges

  // same thing for SSEL
  reg [2:0] SSELr;  always @(posedge clk) SSELr <= {SSELr[1:0], SSEL};
  wire SSEL_active = ~SSELr[1];  // SSEL is active low
  wire SSEL_startmessage = (SSELr[2:1]==2'b10);  // message starts at falling edge
  wire SSEL_endmessage = (SSELr[2:1]==2'b01);  // message stops at rising edge

  // and for MOSI
  reg [1:0] MOSIr;  always @(posedge clk) MOSIr <= {MOSIr[0], MOSI};
  wire MOSI_data = MOSIr[1];

/*

  // we handle SPI in 8-bits format, so we need a 3 bits counter to count the bits as they come in
  reg [2:0] bitcnt;

  reg byte_received;  // high when a byte has been received
  reg [7:0] byte_data_received;

  always @(posedge clk)
  begin
    if(~SSEL_active)
      bitcnt <= 3'b000;
    else
    if(SCK_risingedge)
    begin
      bitcnt <= bitcnt + 3'b001;

      // implement a shift-left register (since we receive the data MSB first)
      byte_data_received <= {byte_data_received[6:0], MOSI_data};
    end
  end

  always @(posedge clk) byte_received <= SSEL_active && SCK_risingedge && (bitcnt==3'b111);

  // we use the LSB of the data received to control an LED
  reg LED;
  always @(posedge clk) if(byte_received) LED <= byte_data_received[0];
*/


  reg [31:0] byte_data_sent;

//  reg [7:0] cnt;
//  always @(posedge clk) if(SSEL_startmessage) cnt<=cnt+8'h1;  // count the messages

// if we did 32 bit, then we could send back a current clock

  always @(posedge clk)
  if(SSEL_active)
  begin
    if(SSEL_startmessage)
      // byte_data_sent <= cnt;  // first byte sent in a message is the message count
      byte_data_sent <= { 8'hee, 8'hdd, 8'hcc,8'hbb };  // first byte sent in a message is the message count
    else
    if(SCK_fallingedge)
    begin
//      if(bitcnt==3'b000)
//        byte_data_sent <= 8'h00;  // after that, we send 0s
//      else
        byte_data_sent <= {byte_data_sent[30:0], 1'b0};
    end
  end

  assign MISO = byte_data_sent[31];  // send MSB first
  // we assume that there is only one slave on the SPI bus
  // so we don't bother with a tri-state buffer for MISO
  // otherwise we would need to tri-state MISO when SSEL is inactive


endmodule



module top (
  input  clk,

  output LED1,
  output LED2,
  output LED3,
  output LED4,
  output LED5,

  input sck,
  input mosi,
  output miso,
  input ssel
);

  blinkmodule #()
  blinkmodule
    (
    .clk(clk),
    .LED(LED1)
  );


  SPI_slave #()
  SPI_slave
    (
    .clk(clk),
    .SCK(sck),
    .MOSI(mosi),
    .MISO(miso),
    .SSEL(ssel),
    .LED(LED2)
  );


  // SPI_slave(clk, SCK, MOSI, MISO, SSEL, LED);

endmodule


