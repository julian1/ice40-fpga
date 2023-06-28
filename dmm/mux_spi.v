

`default_nettype none



module mux_spi    (
  input wire [8-1:0] reg_spi_mux,     // change name vec_active_device
  input cs2,
  input clk,
  input mosi,


  input wire [8-1:0]  cs_polarity,
  output wire [8-1:0] vec_cs,
  output wire [8-1:0] vec_clk,
  output wire [8-1:0] vec_mosi,

  ///////
  input dout,                         // use when cs active.  or at least c2 not active
  input wire [8-1:0] vec_miso,        // use when cs2 active
  output wire miso                    // output pin

);

  // input
  // should be assign?
  wire [8-1:0] cs_active =  reg_spi_mux & {8 {  ~cs2 } } ;   // cs is active lo.

  assign vec_cs  = ~(cs_active ^ cs_polarity );    // works for active hi strobe 4094.   Think that it works for spi.


  assign vec_clk  = reg_spi_mux & {8 {  clk } } ;   // cs is active lo.
  assign vec_mosi = reg_spi_mux & {8 {  mosi } } ;   // cs is active lo.

  ///////////////
  // output

  // cs2 is active lo
  assign miso = cs2 ? dout : (reg_spi_mux & vec_miso) != 0 ;



endmodule






  // setbit() is slow. should remove it.

/*
  // should be assign?
  wire [8-1:0] cs_active = setbit( reg_spi_mux )  & {8 {  ~cs2 } } ;   // cs is active lo.

  assign vec_cs  = ~(cs_active ^ cs_polarity );    // works for active hi strobe 4094.   Think that it works for spi.


  assign vec_clk  = setbit( reg_spi_mux )  & {8 {  clk } } ;   // cs is active lo.
  assign vec_mosi = setbit( reg_spi_mux )  & {8 {  mosi } } ;   // cs is active lo.

  ///////////////

  // cs2 is active lo
  assign miso = cs2 ? dout : (reg_spi_mux & vec_miso) != 0 ;
*/





/*

//
function [8-1:0] setbit( input [8-1:0]  val);
  begin
    setbit = (1 << val ) >> 1;
  end
endfunction
*/

/*

  mux_spi #( )      // output from POV of the mcu. ie. fpga as slave.
  mux_spi
  (
    . reg_spi_mux(reg_spi_mux),
    . cs2(SPI_CS2),
    . clk(SPI_CLK),
    . mosi(SPI_MOSI ),
    // . miso(SPI_MISO)                          // WE drive SPI_MISO here.
    . dout(my_dout),                             // default. dout when no spi selected. (eg. register bank.
    // . cs_polarity( 8'b01110000  ),

    . cs_polarity( 8'b00000001  ),  // 4094 strobe should go hi, for output
    . vec_cs(vec_cs),
    . vec_clk(vec_clk),
    . vec_mosi(vec_mosi)
    . vec_miso(vec_miso),
  );

    . dout(my_dout),                              // use when cs active
    . vec_miso(vec_miso),                         // use when cs2 active
    . miso(SPI_MISO)                              // output pin

*/




/*

module my_mux_spi_input    (

  // bloody hell. this has to drive MISO using cs also.

  input wire [8-1:0] reg_spi_mux,
  input cs2,
  output wire miso
);

  // this code is combinatory but doesnt'

  // cs2 not asserted, the just use dout. else whatever is asserted....
  assign miso = cs2 ? dout : (reg_spi_mux & vec_miso) != 0 ;

endmodule
*/

/*
  Hmmm. with separate cs lines.
  remember that mcu only has one nss/cs.
    so even if had separate cs line for each peripheral we would need to toggle.
    but could be simpler than writing a register.
*/


