
// - can have heartbeat timer. over spi.
// - if have more than one dac. then just create another register. very clean.
// - we can actually handle a toggle. if both set and clear bit are hi then toggle
// - instead of !cs or !cs2.  would be good if can write asserted(cs)  asserted(cs2)


`default_nettype none

module blinker    (
  input clk,

  output reg [4-1:0] led_vec

);

  localparam BITS = 4;
  // localparam LOG2DELAY = 21;
  localparam LOG2DELAY = 20;

  reg [BITS+LOG2DELAY-1:0] counter = 0;
  reg [BITS-1:0] outcnt;

  // sequential
  always@(posedge clk) begin
    counter <= counter + 1;
    outcnt <= counter >> LOG2DELAY;
  end

  // assign { led1, led2, LED3, LED4, LED5 } = outcnt ^ (outcnt >> 1);
  // assign {  led1, led2 } = outcnt ^ (outcnt >> 1);

  // continuous. why?
  assign led_vec = outcnt ^ (outcnt >> 1);

endmodule


// should be completely combinatorial.


function [7:0] sum (input [7:0] a, b);
  begin
   j = a;   // issue is if try to use?
   sum = j + b;
  end
endfunction


// function [8-1:0] update (input [8-1:0] x, input [4-1:0] setbits, input [4-1:0] clearbits,);
function [4-1:0] update (input [4-1:0] x, input [4-1:0] setbits, input [4-1:0] clearbits,);
  begin
    if( clearbits & setbits  /*!= 0*/  ) // if both set and clear bits, then its a toggle
      update =  (clearbits & setbits )  ^ x ; // xor. to toggle.
    else
      update = ~(  ~(x | setbits ) | clearbits);
  end
endfunction




function [8-1:0] setbit( input [8-1:0]  val);
  begin
    setbit = (1 << val ) >> 1;
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
  output reg [4-1:0] reg_led,     // need to be very careful. only 4 bits. or else screws set/reset calculation ...

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


  /*
    remember/rules
      - and we must avoid two drivers (ie always@ blocks) for all variables.  eg. the count variable.
      - and we only want to latch value on valid cs deassert
      - so we count the clk, and take actions on the clock count values,
      - so it's effectively a state machine based on the clk.
      ---------

      i think everything can be made non-blocking.  because all the read code is up top, and all the assignment is underneath.
  */

  // sequential
  always @ (negedge clk or posedge cs)
  begin

    if( cs)  // cs not asserted
      begin
        // ok, because cs in sensitivity list
        // EXTR.  THIS IS the synchronization action after bad sequence/frame /clock count.

        // clear on posedge of cs. and while cs is deasserted.
        // these should be able to be non blocking. because no dependence
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

            // ret = 8'b00001111 << 7; /// test
            // ret = 4'b1111 << 7; /// test - think jjjjjj
            // ret = 4'b1010 << 7; /// test doesn't work
            // ret = dinput[ 7:0] << 7; // return the register, to that was passed to read. works.
            // ret = reg_led      << 7 ;   //  return reg_led

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

      // but we lose access to count when cs is added to both (the clk) sensitivity lists.
      // if(1 /*count == 0*/) // ie. sequence has correct number of clk cycles.
      if(  1 ) // ie. sequence has correct number of clk cycles.

        case (dinput[ MSB-1:8 ])   // register to write


          `REG_LED :      reg_led     <= update(reg_led, dinput, dinput >> 4);

          // `REG_SPI_MUX :  reg_spi_mux <= setbit(  dinput & 4'b1111 );
          `REG_SPI_MUX :  reg_spi_mux <= dinput ;


          // TODO fix reg_dac whihc is 9.
          `REG_4094 :     reg_4094    <= update(reg_4094, dinput, dinput >> 4);


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


module my_cs_mux    (
  input wire [8-1:0] reg_spi_mux,
  input cs2,
  input wire [8-1:0] polarity,
  output wire [8-1:0] cs_vec
);


    wire [8-1:0] active = setbit( reg_spi_mux )  & {8 {  ~cs2 } } ;   // cs is active lo.

    // inverting a signal according to a boolean vector - is the same as xor.
    // xor to toggle according to fixed polarity bit. for active_lo.

      // only one bit here is hi. - and we want it xored only if the polarity bit is set.
    // we don't want the lo bits flipped with polarity .

    // assign cs_vec = ~active ; // works
    // assign cs_vec = active ^ polarity;

    assign cs_vec = ~(active ^ polarity );    // works for active hi strobe 4094.   Think that it works for spi.


    // assign cs_vec = ~ active ;  works for active lo.


endmodule




module my_miso_mux    (
  input wire [8-1:0] reg_spi_mux,
  input cs2,
  input dout,
  input wire [8-1:0] miso_vec,
  output wire miso
);

  // this code is combinatory but doesnt'

  assign miso = cs2 ? dout : (reg_spi_mux & miso_vec) != 0 ;

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
  input  XTALCLK,

  // leds
  output LED0,
  output LED1,
  output LED2,

  // spi
  input  CLK,
  input  CS,
  input  MOSI,
  input  CS2,
  output MISO,
  // output b

  output INTERUPT_OUT,


  //////////////////////////
  // adc 03
  output ADC03_CLK,
  input  ADC03_MISO,    // input
  output ADC03_MOSI,
  output ADC03_CS,


  //////////////////////////
  // dac
  output DAC_SPI_CS ,
  output DAC_SPI_CLK,
  output DAC_SPI_SDI,
  input  DAC_SPI_SDO,   // input

  output DAC_LDAC,
  output DAC_RST,
  output DAC_UNI_BIP_A,
  output DAC_UNI_BIP_B,


  // flash
  // output FLASH_CS,
  // output FLASH_CLK,
  // output FLASH_MOSI ,
  // input  FLASH_MISO,   // input

  output ICE_SS,
  output FLASH_SS,
  output HEADER_SS,

  output ICE_SCK,
  output ICE_MOSI,
  input  ICE_MISO,


  //////////////////////////
  // adc
  output ADC02_RST,
  input  ADC02_DONE,  // input
  input  ADC02_DRDY,    // input
  output ADC02_MOSI,
  input  ADC02_MISO,   // input
  output ADC02_CLK,

  output ADC02_CS,
  output ADC02_M0,
  output ADC02_M1,
  output ADC02_M2,


  //////////////////////////
  // 4094
  output GLB_4094_OE,

  output GLB_4094_DATA,
  output GLB_4094_CLK,
  output U511_STROBE_CTL,
  output U514_STROBE_CTL,
  output A_STROBE_CTL,

  input  U511_MISO_CTL,
  input  U514_MISO_CTL,
  input  U706_MISO_CTL,



);

/*
  wire C_A_STROBE_CTL;
  assign A_STROBE_CTL =  ~ C_A_STROBE_CTL ;

  wire C_U514_STROBE_CTL;
  assign U514_STROBE_CTL = ~ C_U514_STROBE_CTL;

  wire C_U511_STROBE_CTL;
  assign U511_STROBE_CTL = C_U511_STROBE_CTL;
*/

  ////////////////////////////////////////
  // spi muxing

  wire [8-1:0] reg_spi_mux ;// = 8'b00000001; // test

  // TODO rename cs_vec with vec_cs .. likewise miso_vec

  // rather than doing individual assignments. - should just pass in anoter vector whether it's active low.

  wire [8-1:0] cs_vec ;
  assign { U511_STROBE_CTL, U514_STROBE_CTL, A_STROBE_CTL, ADC02_CS,   FLASH_SS, DAC_SPI_CS,  ADC03_CS } = cs_vec;
  // HEADER_SS

  wire [8-1:0] miso_vec ;
  assign { U706_MISO_CTL,     U514_MISO_CTL,     U706_MISO_CTL,  ADC02_MISO, ICE_MISO, DAC_SPI_SDO, ADC03_MISO } = miso_vec;


  // make sure ice40 programming flash is pulled hi. so that its not asserted.
  // no don't thiink this is issue.
  assign ICE_SS = 1;

   ////////////////////////////////////////
  // spi pass through

  // could mux these also, if we want
  // syntax. {a,b,c,d,e} = {5{value}};
  assign { GLB_4094_CLK,  ADC02_CLK,  DAC_SPI_CLK, ADC03_CLK,  ICE_SCK  } = { 5{CLK }} ;

  assign { GLB_4094_DATA, ADC02_MOSI, DAC_SPI_SDI, ADC03_MOSI, ICE_MOSI } = { 5{MOSI}} ;


  ////////////////////////////////////////
  // connect interupt_out to data ready of adc.
  // to support, multiple interupt source, could use an SR register that is read over spi.
  // but this is sufficient... atm.
  //
  // ads131a04  DYDR Data ready; active low; host interrupt and synchronization for multi-devices
  assign  INTERUPT_OUT = ADC02_DRDY;


  // dout for fpga spi.
  // need to rename. it's an internal dout... that can be muxed out.
  reg dout ;


  my_miso_mux #( )
  my_miso_mux
  (
    . reg_spi_mux(reg_spi_mux),
    . cs2(CS2),
    . dout(dout),
    . miso_vec(miso_vec),
    . miso(MISO)
  );


  my_cs_mux #( )
  my_cs_mux
  (
    . reg_spi_mux(reg_spi_mux),
    . cs2(CS2),
    . polarity( 8'b01110000  ),
    . cs_vec(cs_vec)
  );


  ////////////////////////////////////////
  // register

  // wire = no state preserved between clocks.

  // TODO change prefix to w_

  wire [4-1:0] reg_led;
  assign { LED2, LED1, LED0 } = reg_led;

  wire [4-1:0] reg_4094;
  assign { GLB_4094_OE } = reg_4094;



  // reg_spI_MUX

  wire [4-1:0] reg_dac;
  assign {DAC_RST, DAC_UNI_BIP_B, DAC_UNI_BIP_A, DAC_LDAC } = reg_dac;


  wire [4-1:0] reg_adc;
  assign { ADC02_RST, ADC02_M2, ADC02_M1, ADC02_M0 } = reg_adc;





  // ok.
  my_register_bank #( 16 )   // register bank
  my_register_bank
    (
    . clk(CLK),
    . cs(CS),
    . din(MOSI),
    . dout(dout),

    . reg_led(reg_led),
    . reg_spi_mux(reg_spi_mux),

    . reg_4094(reg_4094 ),
    . reg_dac(reg_dac),
    . reg_adc(reg_adc),


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

