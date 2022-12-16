
// - can have heartbeat timer. over spi.
// - if have more than one dac. then just create another register. very clean.
// - we can actually handle a toggle. if both set and clear bit are hi then toggle
// - instead of !cs or !cs2.  would be good if can write asserted(cs)  asserted(cs2)


`default_nettype none

module blinker    (
  input clk,

  output reg [4-1:0] reg_vec

);

  localparam BITS = 4;
  // localparam LOG2DELAY = 21;
  localparam LOG2DELAY = 20;

  reg [BITS+LOG2DELAY-1:0] counter = 0;
  reg [BITS-1:0] outcnt;

  always@(posedge clk) begin
    counter <= counter + 1;
    outcnt <= counter >> LOG2DELAY;
  end

  // assign { led1, led2, LED3, LED4, LED5 } = outcnt ^ (outcnt >> 1);
  // assign {  led1, led2 } = outcnt ^ (outcnt >> 1);

  assign reg_vec = outcnt ^ (outcnt >> 1);

endmodule


// should be completely combinatorial.


/*
function [7:0] sum (input [7:0] a, b);
  begin
   sum = a + b;
  end
endfunction
*/

function [7:0] sum (input [7:0] a, b);
  begin
   j = a;   // issue is if try to use?
   sum = j + b;
  end
endfunction





function [8-1:0] update (input [8-1:0] x, input [8-1:0]  val);
  begin
    if( (val & 4'b1111) & (val >> 4) /*!= 0*/  ) // if both set and clear bits, then its a toggle
      update =  ((val & 4'b1111) & (val >> 4))  ^ x ; // xor. to toggle.
    else
      update = ~(~  (x | (val & 4'b1111)) | (val >> 4));
  end
endfunction

/*

function [8-1:0] update (input [8-1:0] x, input [8-1:0]  val);
  begin
    tmp = x | (val & 4'b1111);        // set
    update = ~(~  (tmp) | (val >> 4));    // clear
  end
endfunction
*/


function [8-1:0] setbit(input [8-1:0] x, input [8-1:0]  val);
  begin
    setbit = (1 << val ) >> 1;
  end
endfunction





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
module my_register_bank   #(parameter MSB=16)   (
  input  clk,
  input  cs,
  input  din,       // sdi
  output reg dout,   // sdo

  // latched val, rename
  output reg [4-1:0] reg_led,     // need to be very careful. only 4 bits. or else screws set/reset calculation ...

  output reg [8-1:0] reg_mux,       // change name reg_spi_mux

  output reg [4-1:0] reg_dac = 4'b1111,
  output reg [4-1:0] reg_rails,   /* reg_rails_initital */
  output reg [4-1:0] reg_dac_ref_mux,
  output reg [4-1:0] reg_adc

);


  reg [MSB-1:0] dinput;      // input value
  reg [MSB-1:0] ret  ;    // return/output value
  reg [4-1:0]   count;    // number of bits, in spi



  //wire [8-1:0] val   = dinput;   // change name to input.


  /*
    remember
      - we don't get another clk edge at the end of the spi sequence, to sample the cs.
      - we must avoid two drivers (ie always@ blocks) for all variables.  eg. the count variable.
      - so we count the clk, and take actions on the clock count values,

  */

  // clock value into dinput var
  always @ (negedge clk )
  begin

    if( ! cs)  // cs asserted
      begin

        // shift data din into the dinput toward msb
        dinput = {dinput[MSB-2:0], din};

        // anything to do at the start
        if(count == 0)
          begin
            ;
          end

        // after we have read in the register of interest, we can setup the output value. for reads
        if(count == 7)
          begin

            // ret = 4'b0101 << 7; test

            case ( dinput[ 7:0]   )   // register to read
              // leds
              7 :  ret = reg_led << 7;
              8 :  ret = reg_mux << 7;      // this will only return the low bits unfortunatley.
              9 :  ret = reg_dac << 7;
            endcase

          end

        dout  = ret[MSB-2];

        ret   = ret << 1; // this *is* zero fill operator.

        if(count == 16 )
            // we are finished
            // reset the count var. rather than in posedge cs, to avoid having two drivers for var.
          count = 0;
        else
          count = count + 1;

      end
  end


  always @ (posedge cs)   // cs done.
    begin

      case (dinput[ MSB-1:8 ])   // register to write
        // leds
        7 :  reg_led          = update(reg_led, dinput);

        // 8 :  reg_mux          = (val == 0) ? 0 : (1 << val )   ; // update(reg_mux, val);


        // 8 :  reg_mux          =  (1 << val ) >> 1;    // this screws up blinking...  because it overflows inito the led register flip-flops
        // 8 :  reg_mux          =  (1 << val ) ;    // this is ok
        8 :  reg_mux          =  setbit( reg_mux, dinput);


        9 :  reg_dac          = update(reg_dac, dinput );
        14 : reg_adc          = update(reg_adc, dinput );

        // soft reset
        // should be the same as initial starting
        11 :
          begin
            reg_led           = 0;
            reg_mux           = 0;            // TODO. should leave. eg. don't change the muxing in the middle of spi
            reg_dac           = 0;
            reg_adc           = 0;
          end

        // powerup contingent upon checking rails
        6 :
          begin
            reg_led           = 0;
            // reg_mux        = 0;            // should just be 0b
            // reg_dac        = 0;            // dac is already configured. before turning on rails, so don't touch again!!
            reg_adc           = 0;
          end

      endcase
    end
endmodule


module my_cs_mux    (
  input wire [8-1:0] reg_mux,
  input cs2,
  output reg [8-1:0] cs_vec
);

  always @ (cs2) // both edges...

    if(cs2)   // cs2 = high = not asserted
        cs_vec = ~( reg_mux & 8'b00000000 );  // turn off cs for all.
      else
        cs_vec = ~( reg_mux & 8'b11111111 );  // turn on
endmodule




module my_miso_mux    (
  input wire [8-1:0] reg_mux,
  input cs2,
  input dout,
  input wire [8-1:0] miso_vec,
  output reg miso
);

 always @ (cs2)

    if(cs2)     // cs2 = high = not asserted
      miso = dout;
    else
      miso = (reg_mux & miso_vec) != 0 ;   // hmmm seems ok.
                                          // TODO should just be able to express without !=
                                          // eg. (reg_mux & miso_vec)
                                            // NOPE.
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


  ////////////////////////////////////////
  // spi muxing

  wire [8-1:0] reg_mux ;// = 8'b00000001; // test

  wire [8-1:0] cs_vec ;
  assign { A_STROBE_CTL,  ADC02_CS,   FLASH_SS,   DAC_SPI_CS,  ADC03_CS } = cs_vec;
  // HEADER_SS

  wire [8-1:0] miso_vec ;
  assign { U706_MISO_CTL, ADC02_MISO, ICE_MISO,  DAC_SPI_SDO,  ADC03_MISO } = miso_vec;

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
    . reg_mux(reg_mux),
    . cs2(CS2),
    . dout(dout),
    . miso_vec(miso_vec),
    . miso(MISO)
  );


  my_cs_mux #( )
  my_cs_mux
  (
    . reg_mux(reg_mux),
    . cs2(CS2),
    . cs_vec(cs_vec)
  );


  ////////////////////////////////////////
  // register

  // wire = no state preserved between clocks.


  wire [4-1:0] reg_led;
  assign { LED2, LED1, LED0 } = reg_led;

  // reg_mux

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
    . reg_mux(reg_mux),

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

