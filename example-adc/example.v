
// OK, be nice to separate out the module...


module blinkmodule (
  input  clk,
  output LED
);
  reg [31:0] counter2 = 0;
 
  // we need to control this more carefully 
  // being able to control several input is a good thing...
  // as well as ref
  // might want to control the switching - just with spi commands...
  // to test...

  always@(posedge clk) begin
    counter2 <= counter2 + 1;
  end
  assign {LED} = counter2 >> 22;
endmodule





// works!

module SPI_slave(
  input clk, 
  input SCK, 
  input SSEL, 
  input MOSI, 
  output MISO,  
  output LED, 
  output m_reset 
);

  /*input clk;
  input SCK, SSEL, MOSI;  // ssel is slave select
  output MISO;
  output LED;

  output m_reset;
*/


  // reg m_reset =  1'b0;      // short the cap

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


  /////////////////////////////////////
  // read in 8bit message
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

  always @(posedge clk) 
    byte_received <= SSEL_active && SCK_risingedge && (bitcnt==3'b111);



  //////////////////////////////////////////////
  // global clock...
  reg [31:0] count = 0;



  //////////////////////////////////////////////
  // decode messages and process
  reg LED;
  always @(posedge clk) 

    if(byte_received && byte_data_received == 8'hcc) 
    begin 
        // if message 0xcc to reset
        count <= 0;   
    end
    else
    begin
        // otherwise always increment clock
        count <= count + 1;

        if(byte_received) 
        begin 
          if(byte_data_received == 8'hcd)
            LED <= 1'b1; 
          else if (byte_data_received == 8'hce)
            LED <= 1'b0; 
        end
    end


  assign m_reset = LED ;


  //////////////////////////////////////////////
  // write count as output
  reg [31:0] byte_data_sent;

  always @(posedge clk)
  if(SSEL_active)
  begin
    if(SSEL_startmessage)
      byte_data_sent <= count; 
    else
    if(SCK_fallingedge)
    begin
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

  output led1,
  output led2,
  output led3,
  output led4,
  output led5,

  // module SPI_slave(clk, SCK, SSEL, MOSI, MISO,  LED, a);
  input sck,
  input ssel,
  input mosi,
  output miso,

  output m_vl,
  output m_0V,
  output m_plus,
  output m_reset
);

  blinkmodule #()
  blinkmodule
    (
    .clk(clk),
    .LED(led1)
  );


  SPI_slave #()
  SPI_slave
    (
    .clk(clk),
    .SCK(sck),
    .MOSI(mosi),
    .MISO(miso),
    .SSEL(ssel),
    .LED(led2),
    .m_reset(m_reset)// .m_reset(m_reset)
  );


  // set the logic voltage reference, VL of dg444 
  assign m_vl = 1'b1;

  assign m_plus = 1'b1;
  assign m_0V = 1'b0;

  //  reg or wire,
  // reg [31:0] counter2 = 0;



/*
  reg [1:0] m_reset = 1'b0;      // set reset to false
on

initial data_reg = 8'b10101011;
*/

  // assign m_reset = 1'b1;   // it's not a reset, it's actually m_short
                            // pull high to allow to conduct

// issue of polarity?

  // SPI_slave(clk, SCK, MOSI, MISO, SSEL, LED);

endmodule


