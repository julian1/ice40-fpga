
// - can have heartbeat timer. over spi.
// - if have more than one dac. then just create another register. very clean.
// - we can actually handle a toggle. if both set and clear bit are hi then toggle
// - instead of !cs or !cs2.  would be good if can write asserted(cs)  asserted(cs2)




`default_nettype none


// `include "bank.v"





function [4-1:0] update (input [4-1:0] x, input [4-1:0] set, input [4-1:0] clear,);
  begin
    if( clear & set  /*!= 0*/  ) // if both set and clear bits, then its a toggle
      update =  (clear & set )  ^ x ; // xor. to toggle.
    else
      update = ~(  ~(x | set ) | clear);
  end
endfunction



`define REG_LED                 7
`define REG_SPI_MUX             8
`define REG_4094                9



module my_register_bank   #(parameter MSB=16)   (
  input  clk,
  input  cs,
  input  din,       // sdi
  output reg dout,   // sdo

  // latched val, rename
  output reg [4-1:0] reg_led  = 4'b0001,     // need to be very careful. only 4 bits. or else screws set/reset calculation ...
  output reg [8-1:0] reg_spi_mux,       // 8 bit register
  output reg [4-1:0] reg_4094,
  output reg [4-1:0] reg_dac = 4'b1111,
  output reg [4-1:0] reg_rails,   /* reg_rails_initital */
  output reg [4-1:0] reg_dac_ref_mux,
  output reg [4-1:0] reg_adc

);


  reg [MSB-1:0] dinput;   // input value
  reg [MSB-1:0] ret  ;    // output value
  reg [5-1:0]   count;    // 1<<4==16. 1<<5==32  number of bits so far, in spi



  // sequential
  always @ (negedge clk or posedge cs)
  begin

    if( cs)  // cs not asserted
      begin

        // clear on posedge of cs. and while cs is deasserted.
        count   <= 0;
        dinput  <= 0;
        ret     <= 0;
      end
    else    // cs asserted
      begin

        // shift data din into the dinput toward msb
        // needs to be blocking, because of subsequent read dependence
        dinput = {dinput[MSB-2:0], din};

        // anything needed at the start of sequence
        if(count == 0)
          begin
            ;
          end

        // after we have read in the register of interest, we can setup the output value. for reads
        if(count == 7)
          begin

            case ( dinput[ 7:0]   )   // register to read
              // MUST be blocking, because of dependence when 'ret' is shifted out.
              // Alternatively change the count
              `REG_LED :      ret = reg_led      << 7;
              `REG_SPI_MUX :  ret = reg_spi_mux  << 7;
              `REG_4094 :     ret = reg_4094     << 7;
              // 9 :  ret = reg_dac      << 7;
            endcase
          end

          dout  <= ret[MSB-2];  // eg. shift data out, highest bit first
          ret   <= ret << 1;    // also a zero fill operator.
          count <= count + 1;
      end
  end


  always @ (posedge cs)   // cs done.
    begin

      case (dinput[ MSB-1:8 ])   // register to write

        `REG_LED :      reg_led     <= update(reg_led, dinput, dinput >> 4);
        `REG_SPI_MUX :  reg_spi_mux <= dinput ;
        `REG_4094 :     reg_4094    <= update(reg_4094, dinput, dinput >> 4);

        // TODO fix reg_dac whihc is 9.
        // 9 :  reg_dac          <= update(reg_dac, dinput, dinput >> 4 );
        14 : reg_adc    <= update(reg_adc, dinput, dinput >> 4 );

        // soft reset
        // should be the same as initial starting
        11 :
          begin
            reg_led     <= 0;
            reg_spi_mux <= 0;            // TODO. should leave. eg. don't change the muxing in the middle of spi
            reg_dac     <= 0;
            reg_adc     <= 0;
          end

        // powerup contingent upon checking rails
        6 :
          begin
            reg_led     <= 0;
            // reg_spi_mux    <= 0;            // should just be 0b
            // reg_dac  <= 0;            // dac is already configured. before turning on rails, so don't touch again!!
            reg_adc     <= 0;
          end

      endcase
    end

endmodule












//
function [8-1:0] setbit( input [8-1:0]  val);
  begin
    setbit = (1 << val ) >> 1;
  end
endfunction





module my_mux_spi_output    (
  input wire [8-1:0] reg_spi_mux,
  input cs2,
  input clk,
  input mosi,
  input wire [8-1:0]  cs_polarity,
  output wire [8-1:0] vec_cs,
  output wire [8-1:0] vec_clk,
  output wire [8-1:0] vec_mosi
);


    // should be assign?
    wire [8-1:0] cs_active = setbit( reg_spi_mux )  & {8 {  ~cs2 } } ;   // cs is active lo.

    assign vec_cs  = ~(cs_active ^ cs_polarity );    // works for active hi strobe 4094.   Think that it works for spi.


    assign vec_clk  = setbit( reg_spi_mux )  & {8 {  clk } } ;   // cs is active lo.
    assign vec_mosi = setbit( reg_spi_mux )  & {8 {  mosi } } ;   // cs is active lo.


    // assign vec_clk  =  {8 {  clk } } ;   // cs is active lo.
    // assign vec_mosi =  {8 {  mosi } } ;   // cs is active lo.



    // assign vec_cs = ~ active ;  simpler approach, works for active lo.


endmodule




module my_mux_spi_input    (
  input wire [8-1:0] reg_spi_mux,
  input cs2,
  input dout,
  input wire [8-1:0] vec_miso,
  output wire miso
);

  // this code is combinatory but doesnt'

  assign miso = cs2 ? dout : (reg_spi_mux & vec_miso) != 0 ;

endmodule


/*
  Hmmm. with separate cs lines.
  remember that mcu only has one nss/cs.
    so even if had separate cs line for each peripheral we would need to toggle.
    but could be simpler than writing a register.
*/

/*
  TODO
  module myreset a soft reset module...
  that decodes an spi command/address/value, and resets all lines.

  need to think how to handle peripheral reset.
*/


module top (
  input  CLK,

  output MON1,
  output MON2,
  output MON3,
  output MON4,
  output MON5,
  output MON6,
  output MON7,



  // leds
  output LED0,

  // spi
  input  SPI_CLK,
  input  SPI_CS,
  input  SPI_MOSI,
  input  SPI_CS2,
  output SPI_MISO,
  // output b

  output SPI_INTERUPT_OUT,



  //////////////////////////
  // 4094
  output GLB_4094_OE,

  output GLB_4094_CLK,
  output GLB_4094_DATA,
  output GLB_4094_STROBE_CTL,
  output GLB_4094_MISO_CTL,



);



  // Put the strobe as first.
  // monitor isolator/spi,                                                  D4          D3       D2       D1        D0
  // assign { MON7, MON6, MON5, MON4, MON3 , MON2, MON1 /* MON0 */ } = {  SPI_MISO, SPI_MOSI, SPI_CLK,  SPI_CS  /* RAW-CLK */} ;

  // assign { MON7, MON6, MON5, MON4, MON3 , MON2, MON1 /* MON0 */ } = {  GLB_4094_OE  /* RAW-CLK */} ;

  // monitor the 4094 spi                                                 D6       D5             D4            D3              D2              D1                 D0
  // assign { MON7, MON6, MON5, MON4, MON3 , MON2, MON1 /* MON0 */ } = {  SPI_CLK, SPI_CS2, GLB_4094_MISO_CTL, GLB_4094_DATA, GLB_4094_CLK, GLB_4094_STROBE_CTL  /* RAW-CLK */} ;


  // monitor the 4094 spi                                               D4            D3              D2              D1                 D0
  // assign { MON7, MON6, MON5, MON4, MON3 , MON2, MON1 /* MON0 */ } = {  GLB_4094_OE, GLB_4094_DATA, GLB_4094_CLK, GLB_4094_STROBE_CTL  /* RAW-CLK */} ;


  // LED0,
  // for somereason this chews through power????
  //                                                                       D5           D4        D3        D2       D1        D0
  assign { MON7, MON6, MON5, MON4, MON3 , MON2, MON1 /* MON0 */ } = { GLB_4094_OE,   SPI_MISO, SPI_MOSI, SPI_CLK,  SPI_CS  /* RAW-CLK */} ;




  ////////////////////////////////////////
  // spi muxing

  wire [8-1:0] reg_spi_mux ;// = 8'b00000001; // test


  // rather than doing individual assignments. - should just pass in anoter vector whether it's active low.
  // EXTR.  We should use an 8bit mux with 16bit toggle. rather than this complication.


  wire [8-1:0] vec_cs ;
  assign {  GLB_4094_STROBE_CTL  } = vec_cs;

  wire [8-1:0] vec_clk;
  assign { GLB_4094_CLK } = vec_clk ;   // have we changed the clock polarity.

  wire [8-1:0] vec_mosi;
  assign { GLB_4094_DATA } = vec_mosi;

  wire [8-1:0] vec_miso ;
  assign { GLB_4094_MISO_CTL } = vec_miso;



  // dout for fpga spi.
  // need to rename. it's an internal dout... that can be muxed out.
  reg dout ;


  my_mux_spi_input #( )
  my_mux_spi_input
  (
    . reg_spi_mux(reg_spi_mux),
    . cs2(SPI_CS2),
    . dout(dout),
    . vec_miso(vec_miso),
    . miso(SPI_MISO)
  );


  my_mux_spi_output #( )
  my_mux_spi_output
  (
    . reg_spi_mux(reg_spi_mux),
    . cs2(SPI_CS2),
    . clk(SPI_CLK),
    . mosi(SPI_MOSI ),
    // . cs_polarity( 8'b01110000  ),
    . cs_polarity( 8'b00000001  ),  // 4094 strobe should go hi, for output
    . vec_cs(vec_cs),
    . vec_clk(vec_clk),
    . vec_mosi(vec_mosi)
  );


  ////////////////////////////////////////
  // register

  // wire = no state preserved between clocks.

  // TODO change prefix to w_

  wire [4-1:0] reg_led;
  assign {  LED0 } = reg_led;

  wire [4-1:0] reg_4094;
  assign { GLB_4094_OE } = reg_4094;




  // ok.
  my_register_bank #( 16 )   // register bank
  my_register_bank
    (
    . clk(SPI_CLK),
    . cs(SPI_CS),
    . din(SPI_MOSI),
    . dout(dout),

    . reg_led(reg_led),
    . reg_spi_mux(reg_spi_mux),

    . reg_4094(reg_4094 )

  );




/*

  blinker #(  )
  blinker
    (
    .clk(XTALCLK),
    .reg_vec( reg_led )

  );

*/



endmodule




/*
function [7:0] sum (input [7:0] a, b);
  begin
   sum = a + b;
  end
endfunction



// should be completely combinatorial.


function [7:0] sum (input [7:0] a, b);
  begin
   j = a;   // issue is if try to use?
   sum = j + b;
  end
endfunction



*/



/*
function [8-1:0] update (input [8-1:0] x, input [8-1:0]  val);
  begin
    if( (val & 4'b1111) & (val >> 4)   ) // if both set and clear bits, then its a toggle
      update =  ((val & 4'b1111) & (val >> 4))  ^ x ; // xor. to toggle.
    else
      update = ~(~  (x | (val & 4'b1111)) | (val >> 4));
  end
endfunction
*/


// (val & 4b1111)  == clearbits .
// val >> 4        == set bits.
//


/*

function [8-1:0] update (input [8-1:0] x, input [8-1:0]  val);
  begin
    tmp = x | (val & 4'b1111);        // set
    update = ~(~  (tmp) | (val >> 4));    // clear
  end
endfunction
*/


/*
  rather than having register bank.
  have one 'cs2' mux register.

  and then have the register bank be it's own spi peripheral.
  that should make reading simpler.
  eg. the cs2 only controls mux.
*/

/*
  CS - must be in clk domain. because it can be de/asserted without spi clk. and
  we want to do stuff in response.
*/






  // relay
  // output RELAY_VRANGE,
  // output RELAY_OUTCOM,
  // output RELAY_SENSE,

  // irange sense
  // output IRANGE_SENSE1,
  // output IRANGE_SENSE2,
  // output IRANGE_SENSE3,
  // output IRANGE_SENSE4,

  // gain fb
  // output GAIN_VFB_OP1,
  // output GAIN_VFB_OP2,
  // output GAIN_IFB_OP1,
  // output GAIN_IFB_OP2,

  // irangex 58
  // deprecate

  // reg_ina_diff_sw
  // output INA_DIFF_SW1_CTL,
  // output INA_DIFF_SW2_CTL,

  // reg_isense_sw
  // output ISENSE_SW1_CTL,
  // output ISENSE_SW2_CTL,
  // output ISENSE_SW3_CTL,



  // wire [4-1:0] reg_relay;
  // assign { RELAY_SENSE, /*RELAY_OUTCOM, */ RELAY_VRANGE } = reg_relay;

//  wire [4-1:0] reg_irange_sense;
//  assign { IRANGE_SENSE4, IRANGE_SENSE3, IRANGE_SENSE2, IRANGE_SENSE1 } = reg_irange_sense;

  // wire [4-1:0] reg_ifb_gain;
  // assign { GAIN_IFB_OP2, GAIN_IFB_OP1 } = reg_ifb_gain;


  // wire [4-1:0] reg_irangex58_sw;
  // assign { IRANGEX_SW8, IRANGEX_SW7, IRANGEX_SW6, IRANGEX_SW5 } = reg_irangex58_sw;


  // wire [4-1:0] reg_vfb_gain;
  // assign { GAIN_VFB_OP2, GAIN_VFB_OP1  } = reg_vfb_gain;
  // wire [4-1:0] reg_ina_diff_sw;
  // assign { INA_DIFF_SW2_CTL, INA_DIFF_SW1_CTL } = reg_ina_diff_sw;

  // wire [4-1:0] reg_isense_sw;
  // assign { ISENSE_SW3_CTL,  ISENSE_SW2_CTL, ISENSE_SW1_CTL } = reg_isense_sw;

