

`default_nettype none



module mux_spi    (

  // everything is a wire.

  input [8-1:0] reg_spi_mux,     // change name vec_active_device
  // input [24-1:0] reg_spi_mux,     // change name vec_active_device
  input cs,
  input clk,
  input mosi,

  ////////
  // outputs
  input [8-1:0]  cs_polarity,
  output [8-1:0] vec_cs,
  output [8-1:0] vec_clk,
  output [8-1:0] vec_mosi,

  ///////
  // inputs
  input dout,                         // use when cs active.  or at least c2 not active
  input [8-1:0] vec_miso,        // use when cs active
  output miso                    // output pin

);

  // input
  // should be assign?
  wire [8-1:0] cs_active =  reg_spi_mux & {8 {  ~cs } } ;   // cs is active lo.

  assign vec_cs  = ~(cs_active ^ cs_polarity );    // works for active hi strobe 4094.   Think that it works for spi.

  /*
    CAREFUL.
    - when we are writing the reg_spi_mux choice register back to 0 over spi,
    - these signals will continue to propagate on clk,data lines until reg_spi_mux goes lo.
    - we cannot & with cs.  because it may park clk,data at wrong level.
    ----
    - this isn't very good.
    - it means that any write to an spi_peripheral should be followed immediately by a reset of reg_spi_mux
    - in order not to have the extra signal emission on the lines, if the reset is done later on.
  */

  assign vec_clk  = reg_spi_mux & {8 {  clk } } ;   // cs is active lo.
  assign vec_mosi = reg_spi_mux & {8 {  mosi } } ;   // cs is active lo.

  ///////////////
  // output

  // cs is active lo
  assign miso = cs ? dout : (reg_spi_mux & vec_miso) != 0 ;



endmodule





