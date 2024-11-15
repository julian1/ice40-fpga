
/*
  - can have heartbeat timer. over spi.
      but don't want to spew spi tranmsission emi during acquisition.

  - if have more than one dac. then just create another register. very clean.
   - perhaps instead of !cs or !cs2.  could write macro  or asserted_n(cs ) etc
*/


`include "register_set.v"


`default_nettype none




// 12MHz
`define CLK_FREQ        12000000


// change name simple Timer state or something.
// or square_wave or something.

module fet_driver (

  input   clk,
  input   reset_n,

  input  [ 32-1: 0 ] p_clk_count_n,

  output reg [ 4-1: 0 ] out,
);
  reg [7-1:0]   state = 0 ;
  reg [31:0]    clk_count_down;

  always @(posedge clk   )
    begin

      // if(clk_count_down != 0 )
        // always decrement clk for the current phase
      clk_count_down <= clk_count_down - 1;

      case (state)
        0:
          begin
            // setup next
            clk_count_down  <= 10;     // set positive to avoid wrap around
            state           <= 1;
            out          <= 3'b0000;    // off.
          end

        1:
          if(clk_count_down == 0)
            begin
              clk_count_down  <= p_clk_count_n;
              state           <= 2;
              out          <= 4'b1001;    // fet1 (hi), fet4
            end

        2:
          if(clk_count_down == 0)
            begin
              clk_count_down  <= p_clk_count_n;
              state           <= 1;
              out          <= 4'b0110;    // fet3 (hi), fet2
            end
      endcase

      // synchronous reset - if reset_n enabled, then don't advance out-of reset state.
      if(reset_n == 0)      // in reset
        begin
            state <= 0;
        end
    end
endmodule




module fan_driver (

  input   clk,
  input   reset_n,
  // EXTR. issues on start/ if initialize output at full power.
  output reg  out = 1,    // start turned off, turn fet on, pull out lo.
);

  reg [31:0]    clk_count_up  = 0;

  always @(posedge clk   )
    begin

      clk_count_up <= clk_count_up + 1;

      // turn on pulse/
      if(clk_count_up == `CLK_FREQ  / 25000)  // 480 .  fan DS example uses 25kHz.
        begin
          clk_count_up <= 0;
          out <= 1;
        end

      // finish pulse.  a clock_count up would be easier
      // shorter-pulse is more faster
      // longer-pulse - is less power/slower
      if(clk_count_up == 400 )
        begin
          out <= 0;
        end

      // synchronous reset - if reset_n enabled,
      if(reset_n == 0)      // in reset
        begin
            out <= 1;
        end
    end
endmodule





module fan_tach (

  input   clk,
  input   reset_n,

  input   fan_tach_i,
  output reg [16-1 :0 ] out,    // off, turn fet on, pull out lo.
);

  reg [31:0]    clk_count_up = 0;
  reg [15:0]    rev_count   = 0;
  reg [2-1:0]   cross       = 2'b00;              // edge detect. rename _edge.


  always @(posedge clk   )
    begin

      clk_count_up      <= clk_count_up + 1;

      // we need to count edges.
      cross       <= {cross[0], fan_tach_i};

      if(cross == 2'b01)
        rev_count       <= rev_count + 1;


      if(clk_count_up == `CLK_FREQ  / 1)  // 1 sec.
        begin
          clk_count_up  <= 0;
          rev_count     <= 0;
          out           <= rev_count;
        end


      if(reset_n == 0)      // synchronous reset
        begin
          clk_count_up  <= 0;
          rev_count     <= 0;
          out           <= 0;
        end
    end
endmodule








module top (


  ////////////////////////
  // spi

  /*#A dual-function, serial output pin in both configuration modes.
  #iCE40 LM devices have this pin shared with hardened SPI IP
  #SPI_MISO pin. */
  output SDO,

  /*# A dual-function, serial input pin in both configuration modes.
  # iCE40 LM devices have this pin shared with hardened SPI IP
  # SPI_MOSI pin. */
  input SDI,

  /*#A dual-function clock signal. An output in Master mode and
  #input in Slave mode. iCE40 LM devices have this pin shared with
  # hardened SPI IP SPI_SCK pin.*/
  input SCK,

  /*#An important dual-function, active-low slave select pin. After
  #the device exits POR or CRESET_B is toggled (High-Low-High), it
  #samples the SPI_SS to select the configuration mode (an output
  #in Master mode and an input in Slave mode). iCE40 LM devices
  #have this pin shared with hardened SPI IP SPI1_CSN pin.*/
  input SS,


  // input  SPI_CS2,

  input clk,


  ///////////
  output [ 4-1: 0 ] fets_o,
  output [ 2-1: 0 ] buzzer_o,

  output  fan_pwm_o,
  input   fan_tach_i


);


  wire [32-1:0] reg_direct ;    // can set initial value. initial value


  // fets
  fet_driver
  fet_driver1(
    . clk( clk),
    . reset_n( 1'b1 ),

    . p_clk_count_n( `CLK_FREQ / (15000 * 2)  ),    // 15kHz.

    . out( fets_o),
  );


  reg [2:1] dummy2;

  // buzzer
  fet_driver
  buzzer(
    . clk( clk),
    . reset_n( reg_direct[0]  ),     // first bit controls
    . p_clk_count_n( `CLK_FREQ / (4096 * 2)  ),    // 4kHz.
    . out( { dummy2 , buzzer_o } ),
  );


  // I think there's a resize issue.


  fan_driver
  fan_driver(
    . clk( clk),
    . reset_n( 1'b1 ),
    . out( fan_pwm_o),
  );


  reg [16-1:0]  fan_rev_count;

  fan_tach
  fan_tach(
    . clk( clk),
    . reset_n( 1'b1 ),
    . fan_tach_i( fan_tach_i),
    . out( fan_rev_count),
  );



  wire [32 - 1 :0] reg_status ;

  assign reg_status = {

    { 8'b0 },
    { 8'b10101010 },  // magic
    fan_rev_count
 };





  // wire fan_pwm_o = 0;   // fan full speed.
  // wire fan_pwm_o = 1;     // fan off
  register_set // #( 32 )
  register_set
    (

    // should prefix fields with spi_
    . clk(   SCK ),
    . cs_n(  SS /*SPI_CS */ ),        // rename cs_n
    . din(   SDI /*SPI_MOSI */),

    . dout( SDO /*miso*/ ),


    // outputs
    . reg_direct( reg_direct ),

    // inputs
    . reg_status( reg_status   ),
  );



endmodule


