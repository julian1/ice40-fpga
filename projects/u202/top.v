
/*
  - can have heartbeat timer. over spi.
      but don't want to spew spi tranmsission emi during acquisition.

  - if have more than one dac. then just create another register. very clean.
   - perhaps instead of !cs or !cs2.  could write macro  or asserted_n(cs ) etc
*/



/*
`include "../../common/mux_assign.v"
`include "../../common/test_pattern.v"
`include "../../common/timed_latch.v"

*/
`include "register_set.v"

/*
`include "adc-mock.v"
`include "refmux-test.v"

`include "adc_modulation_05.v"
`include "sequence_acquisition.v"

*/
`default_nettype none




// `define CLK_FREQ        20000000
`define CLK_FREQ        12000000




module fet_driver (

  input   clk,
  input   reset_n,

  output reg [ 4-1: 0 ] fets_o,
);


  reg [7-1:0]   state = 0 ;
  reg [31:0]    clk_count_down;

  /*
    there's a very strange bug lurking here, if we remove this register allocation , that is not even used.
    then get spurious signals on adc_measure_valid in the real adc mode.

  */




  always @(posedge clk   )
    begin

      // if(clk_count_down != 0 )
        // always decrement clk for the current phase
      clk_count_down <= clk_count_down - 1;


      case (state)

        0:
          // reset/park state.
          begin

            // setup next
            clk_count_down  <= 10;     // set positive to avoid wrap around
            state           <= 1;
            fets_o          <= 3'b0000;    // off.
          end

        1:
          if(clk_count_down == 0)
            begin
              clk_count_down  <= `CLK_FREQ / (15000 * 2);   // 15kHz.
              // clk_count_down  <= `CLK_FREQ / 1000;   // 500Hz..   fet bootstrap cap not enough charge.
              state           <= 2;
              fets_o          <= 4'b1001;    // fet1 (hi), fet4
            end

        2:
          if(clk_count_down == 0)
            begin
              clk_count_down  <= `CLK_FREQ / (15000 * 2);   // 15kHz.
              // clk_count_down  <= `CLK_FREQ / 1000;    // 500Hz.
              state           <= 1;
              fets_o          <= 4'b0110;    // fet3 (hi), fet2
            end

      endcase


      // synchronous reset - if reset_n enabled, then don't advance out-of reset state.
      if(reset_n == 0)      // in reset
        begin

            state <= 0;
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


  ///////////
  output [ 4-1: 0 ] fets_o,

  input clk

);

  reg [32-1:0] reg_status = 0;    // initial value


  fet_driver
  fet_driver(
    . clk( clk),
    . reset_n( 1'b1 ),
    . fets_o( fets_o),
  );

  // wire SDO = 1;

  register_set // #( 32 )
  register_set
    (

    // should prefix fields with spi_
    . clk(   SCK ),
    . cs_n(  SS /*SPI_CS */ ),        // rename cs_n
    . din(   SDI /*SPI_MOSI */),

    . dout( SDO /*miso*/ ),


    // outputs
    // . reg_direct( fets_o ),

    // inputs
    . reg_status( reg_status),
  );



endmodule


