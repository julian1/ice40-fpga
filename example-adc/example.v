
// Important rather than use a diode - to drop - use two npns. emitter follower - and then common emitter

// IMPORTANT - if use the output as 3.3 ref voltage - then we need to know we have enough current
// IMPORTANT could use another op-amp as 3.3V ref power supply....  to avoid using the main 3.3 rail.

// 3.6 sysIO Single-Ended DC Electrical Characteristics
// for 3.3V says 8mA.... with 16 and 24 being led driver pins only.
// can drive a led via 1k (eg 3.3mA) but the voltage goes from 3.2V to 2.95V

// input pin definitely appears to be floating. 55mV. just connecting it
// to the high-impedance of a multimeter input and it will flip.

/*
See page 25 of this document: http://www.latticesemi.com/view_document?document_id=50666
8 mA for LVCMOS 3.3, 6 mA for LVCMOS 2.5, and 4 mA for LVCMOS 1.8.
*/

// how to handle the input - npn has lower turn-on voltage compared with mosfet.
// and can adjust with a 1n4148 .
// think they will have internal pull ups.

// we don't need hysterysis on the op-amp - because we can use digital hysterysis.

// inputs probably have internal pullups so
  // -- just test
  //

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

  output led1,
  output led2,
  output led3,
  output led4,

  output m_reset,
  output m_in,
  output m_ref,

  input t_trigger  // it's not zero cross trigger - it's state

);

  // clk domain crossing - this works by storing the last two sck states, and then compare them to
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
  // IT would be easy to make this longer
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
  // counters and settings  ...
  reg [31:0] count = 0;
  reg [31:0] reset_count = 0;         // set by user - should default...
  reg [31:0] runup_count = 0;         // set by user - should default...
  reg [31:0] integration_count = 0;

  //////////////////////////////////////////////
  // decode messages and process

  // trigger zerocross
  reg [2:0] zerocrossr;  always @(posedge clk) zerocrossr <= {zerocrossr[1:0], t_trigger};
  wire zerocross_up     = (zerocrossr[2:1]==2'b10);  // message starts at falling edge
  wire zerocross_down   = (zerocrossr[2:1]==2'b01);  // message stops at rising edge

  wire zerocross_any    = zerocross_up || zerocross_down ;

  // we could set the 5v power separatee
  //reg init_ = 0;            // https://github.com/cliffordwolf/yosys/issues/103
                            // init_ialized to zero
                            // note - reset can lead to lower f(max)..
                            // 1MHz in this case,

  // dg444 is switched either ref or in
  assign m_ref = !m_in;

  // TODO get rid of init and instead have a state PWR_UP

  `define STATE_HWRESET 0
  `define STATE_WAITING 1
  `define STATE_RESET   2
  `define STATE_RUNUP   3
  `define STATE_RUNDOWN 4

  reg [4:0] state = `STATE_HWRESET;


  // ok, i think we want to set the scope to trigger off of the same thing... 
  // also - we could actually count down.

  always @(posedge clk)
    begin
      // always increment clock
      count <= count + 1;

      case (state)
        `STATE_HWRESET:
          begin
            // init defaults
            reset_count <= 100000;   // 10ms approx
            runup_count <= 1000000;  // 0.1 sec approx
            m_reset <= 0;
            m_in <= 0;

            // set defaults
            state <= `STATE_WAITING;
          end

        `STATE_WAITING:
          if(byte_received && byte_data_received == 8'hcc)
            begin
                count <= 0;
                integration_count <= 0;   // clear ... to indicate not readable state
                m_reset <= 0;    // set reset
                m_in <= 0;       // for 5V
                state <= `STATE_RESET;
            end

        `STATE_RESET:
          if(count == reset_count)
            begin
              // start integration
              m_reset <= 1'b1;
              state <= `STATE_RUNUP;
            end
        `STATE_RUNUP:
          if(count == runup_count)
            begin
              // swap to reference input for rundown
              m_in <= 1'b1;       
              state <= `STATE_RUNDOWN;
            end
        `STATE_RUNDOWN:
          if(zerocross_down)
            begin
              // we're done, so record count...
              integration_count <= count - reset_count;
    
              // and clear
              m_reset <= 0;
              m_in <= 0;       // for 5V
  
              state <= `STATE_WAITING;
           end
      endcase
    end

  // led follows m_reset
  assign led1 = m_reset;
  assign led2 = m_in;
  assign led3 = m_ref;
  assign led4 = t_trigger;



  //////////////////////////////////////////////
  // write count as output
  reg [31:0] byte_data_sent;

  always @(posedge clk)
  if(SSEL_active)
  begin
    if(SSEL_startmessage)
      byte_data_sent <= integration_count;
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
  output m_ref,
  output m_in,
  output m_reset,

  input t_trigger
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

    .led1(led2),
    .led2(led3),
    .led3(led4),
    .led4(led5),

    .m_reset(m_reset),
    .m_in(m_in),
    .m_ref(m_ref),

    .t_trigger(t_trigger)
  );

  // need data structure?

  // set the logic voltage reference, VL of dg444
  assign m_vl = 1'b1;

endmodule


