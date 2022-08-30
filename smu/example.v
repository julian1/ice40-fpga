
// - can have heartbeat timer. over spi.
// - if have more than one dac. then just create another register. very clean.
// - we can actually handle a toggle. if both set and clear bit are hi then toggle
// - instead of !cs or !cs2.  would be good if can write asserted(cs)  asserted(cs2)

module blinker    (
  input clk,
  output led1,
  output led2

);

  localparam BITS = 5;
  // localparam LOG2DELAY = 21;
  localparam LOG2DELAY = 20;

  reg [BITS+LOG2DELAY-1:0] counter = 0;
  reg [BITS-1:0] outcnt;

  always@(posedge clk) begin
    counter <= counter + 1;
    outcnt <= counter >> LOG2DELAY;
  end

  // assign { led1, led2, LED3, LED4, LED5 } = outcnt ^ (outcnt >> 1);
  assign {  led1, led2 } = outcnt ^ (outcnt >> 1);
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
  output dout,   // sdo

  // latched val, rename
  inout [4-1:0] reg_led,     // need to be very careful. only 4 bits. or else screws set/reset calculation ...

  output reg [4-1:0] reg_mux,
  output reg [4-1:0] reg_dac,
  output reg [4-1:0] reg_rails,   /* reg_rails_initital */
  output reg [4-1:0] reg_dac_ref_mux,
  output reg [4-1:0] reg_adc,
  output reg [4-1:0] reg_clamp1,
  output reg [4-1:0] reg_clamp2,
  output reg [4-1:0] reg_relay_com,

  // output or input???
  input [4-1:0] reg_mon_rails,

  output reg [4-1:0] reg_irange_x_sw,
  output reg [4-1:0] reg_rails_oe,
  output reg [4-1:0] reg_ina_vfb_sw,
  output reg [4-1:0] reg_ina_ifb_sw,
  output reg [4-1:0] reg_ina_vfb_atten_sw,
  output reg [4-1:0] reg_isense_mux,
  output reg [4-1:0] reg_relay_out,
  // output reg [4-1:0] reg_relay_vsense,
  output reg [4-1:0] reg_irange_yz_sw
);


  reg [MSB-1:0] tmp;      // input value
  reg [MSB-1:0] ret  ;    // output value
  reg [8-1:0]   count;    // number of bits, in spi



  wire [8-1:0] val   = tmp;



  // clock value into tmp var
  always @ (negedge clk or posedge cs)
  begin
    if(cs)  // cs not asserted
      begin
        count = 0;

        // dummy value
        ret = 255 << 8;

      end
    else
       // cs asserted
      begin

        // d into lsb, shift left toward msb
        tmp = {tmp[MSB-2:0], din};

        // reading stuff.
        if(count == 7)
          begin
            case ( tmp[ 7:0]   )   // register to read
              // leds
              7 :  ret = reg_led << 7;

              19 : ret = reg_mon_rails << 7;
            endcase

          end


        // return value

        // TODO generates a warning....
        dout = ret[MSB-2];    // OK. doing this gets our high bit. but loses the last bit... because its delayed??
        ret = ret << 1; // this *is* zero fill operator.

        count = count + 1;

      end
  end



  always @ (posedge cs)   // cs done.
  begin
    // we can assert a done flag here... and factor this code...
    if(/*cs && !cs2 &&*/ count == 16 )
      begin
        case (tmp[ MSB-1:8 ])   // register to write
          // leds
          7 :
            begin
              reg_led = update(reg_led, val);
            end
          8 :  reg_mux =    update(reg_mux, val);
          9 :  reg_dac =    update(reg_dac, val);
          10 : reg_rails =  update(reg_rails, val);


          // soft reset
          11 :
            /*
              No. just pass the reset value as a vec, just like pass the reg.
              eg.  output reg_rails,  input reg_rails_init.
              but. note that everything comes up hi anyway before flash load
              OR. just those that are *not* to be set to zer.
            */
            begin
              // none of this is any good... we need mux ctl pulled high etc.
              // does verilog expand 0 constant to fill all bits?
              reg_led           = 0;
              reg_mux           = 0;  // should just be 0b
              reg_dac           = 0;
              reg_rails         = 4'b0000;
              // reg_dac_ref_mux   = 4'b1111;  // dg444 active lo
              reg_dac_ref_mux   = 4'b0000;      // aug 29 2022. if high, without rails power, then dg444 ESD diodes activate 
              reg_adc           = 0;
              reg_clamp1        = 4'b1111;  // dg444 active lo. turn off
              reg_clamp2        = 4'b1111;  // dg444 active lo. turn off
              reg_relay_com     = 0;


              // reg_mon_rails,
              reg_irange_x_sw    = 0;   // adg1334
              reg_rails_oe      = 4'b0001;   // active lo. IMPORTANT.  keep hi. until ready to turn on rails.  // weird. for smu09, on first flash. ice40 pins came up lo.
              reg_ina_vfb_sw    = 0;
              reg_ina_ifb_sw    = 4'b1111;
              reg_ina_vfb_atten_sw = 4'b1111; // active lo. dg444 and 74hc04
              reg_isense_mux     = 4'b1111;
              reg_relay_out       = 0;
              // reg_relay_vsense    = 0;
              reg_irange_yz_sw    = 0;  // adg1334
            end

          // dac ref mux
          12 : reg_dac_ref_mux  = update(reg_dac_ref_mux, val);
          14 : reg_adc          = update(reg_adc, val);
          15 : reg_clamp1       = update(reg_clamp1, val);
          16 : reg_clamp2       = update(reg_clamp2, val);
          17 : reg_relay_com    = update(reg_relay_com, val);
          18 : reg_irange_x_sw   = update(reg_irange_x_sw, val);
          24 : reg_rails_oe     = update(reg_rails_oe, val);
          25 : reg_ina_vfb_sw   = update(reg_ina_vfb_sw, val);
          28 : reg_ina_ifb_sw   = update(reg_ina_ifb_sw, val);
          29 : reg_ina_vfb_atten_sw = update(reg_ina_vfb_atten_sw, val);
          30 : reg_isense_mux  = update(reg_isense_mux, val);
          31 : reg_relay_out    = update(reg_relay_out, val);
          // 32 : reg_relay_vsense = update(reg_relay_vsense, val);
          33 : reg_irange_yz_sw = update( reg_irange_yz_sw, val);

        endcase
      end
  end
endmodule


module my_cs_mux    (
  input wire [8-1:0] reg_mux,
  input cs2,
  output [8-1:0] cs_vec
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
  output miso
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


  // adc 03
  output ADC03_CLK,
  input  ADC03_MISO,    // input
  output ADC03_MOSI,
  output ADC03_CS,


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

  output ICE_SCK,
  output ICE_MOSI,
  input ICE_MISO,




  // rails
  output RAILS_LP5V,
  output RAILS_LP15V,
  output RAILS_LP30V,
  output RAILS_LP50V,

  output RAILS_OE,

  // dac ref mux
  output DAC_REF_MUX_A,
  output DAC_REF_MUX_B,

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

  // clamps
  output CLAMP1_VSET,
  output CLAMP1_ISET,
  output CLAMP1_ISET_INV,
  output CLAMP1_VSET_INV,

  output CLAMP2_MIN,
  output CLAMP2_INJECT_ERR,
  output CLAMP2_INJECT_VFB,
  output CLAMP2_MAX,

  // relay com
  output RELAY_COM_X,
  output RELAY_COM_Y,
  output RELAY_COM_Z,


  //////////////////////////////////////

  // reg_ina_vfb_sw
  output INA_VFB_SW3_CTL,
  output INA_VFB_SW2_CTL,
  output INA_VFB_SW1_CTL,

  // reg_ina_ifb
  output INA_IFB_SW1_CTL,
  output INA_IFB_SW2_CTL,
  output INA_IFB_SW3_CTL,


  // reg_ina_vfb_atten_sw
  output INA_VFB_ATTEN_SW3_CTL,
  output INA_VFB_ATTEN_SW2_CTL,
  output INA_VFB_ATTEN_SW1_CTL,

  // reg_isense_mux
  // better name?
  output ISENSE_MUX1_CTL,
  output ISENSE_MUX2_CTL,
  output ISENSE_MUX3_CTL,

  // reg_relay_out
  // output RELAY_OUT_COM_HC,
  // output RELAY_OUT_COM_LC,

  output RELAY_OUT_COM_HC_CTL,
  output RELAY_GUARD_CTL,
  output RELAY_SENSE_EXT_CTL,
  output RELAY_SENSE_INT_CTL,



  // reg_relay_vsense
  // output RELAY_VSENSE_CTL,


  // irange_x
  output IRANGE_X_SW1_CTL,
  output IRANGE_X_SW2_CTL,
  output IRANGE_X_SW3_CTL,
  output IRANGE_X_SW4_CTL,


  // reg_mon_rails
  input XP15V_UP_OUT,
  input XN15V_UP_OUT,



  // irange_yz
  output IRANGE_YZ_SW1_CTL,
  output IRANGE_YZ_SW2_CTL,
  output IRANGE_YZ_SW3_CTL,
  output IRANGE_YZ_SW4_CTL




);


  ////////////////////////////////////////
  // spi muxing

  wire [8-1:0] reg_mux ;// = 8'b00000001; // test

  wire [8-1:0] cs_vec ;
  assign { ADC02_CS, FLASH_SS, DAC_SPI_CS, ADC03_CS } = cs_vec;

  wire [8-1:0] miso_vec ;
  assign { ADC02_MISO, ICE_MISO,  DAC_SPI_SDO,  ADC03_MISO } = miso_vec;

  // make sure ice40 programming flash is pulled hi. so that its not asserted.
  // no don't thiink this is issue.
  assign ICE_SS = 1;

   ////////////////////////////////////////
  // spi pass through

  // could mux these also, if we want
  // syntax. {a,b,c,d,e} = {5{value}};
  assign { ADC02_CLK, DAC_SPI_CLK, ADC03_CLK, ICE_SCK  } = { 5{CLK }} ;

  assign { ADC02_MOSI, DAC_SPI_SDI, ADC03_MOSI, ICE_MOSI } = { 5{MOSI}} ;


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
  assign { LED2, LED1} = reg_led;

  // reg_mux

  wire [4-1:0] reg_dac;
  assign {DAC_RST, DAC_UNI_BIP_B, DAC_UNI_BIP_A, DAC_LDAC } = reg_dac;

  wire [4-1:0] reg_rails ;
  assign { RAILS_LP50V, RAILS_LP30V, RAILS_LP15V, RAILS_LP5V } = reg_rails;

  // reg_soft_reset

  wire [4-1:0] reg_dac_ref_mux;
  assign { DAC_REF_MUX_B, DAC_REF_MUX_A } = reg_dac_ref_mux;

  wire [4-1:0] reg_adc;
  assign { ADC02_RST, ADC02_M2, ADC02_M1, ADC02_M0 } = reg_adc;

  wire [4-1:0] reg_clamp1;
  assign { CLAMP1_VSET_INV, CLAMP1_ISET_INV, CLAMP1_ISET, CLAMP1_VSET } = reg_clamp1;

  wire [4-1:0] reg_clamp2;
  assign { CLAMP2_MAX, CLAMP2_INJECT_VFB, CLAMP2_INJECT_ERR, CLAMP2_MIN} = reg_clamp2;

  wire [4-1:0] reg_relay_com;
  assign { RELAY_COM_Z, RELAY_COM_Y, RELAY_COM_X } = reg_relay_com;



  wire [4-1:0] reg_mon_rails;
  assign { XN15V_UP_OUT, XP15V_UP_OUT  } = reg_mon_rails;





  wire [4-1:0] reg_irange_x_sw;
  assign { IRANGE_X_SW4_CTL, IRANGE_X_SW3_CTL, IRANGE_X_SW2_CTL, IRANGE_X_SW1_CTL } = reg_irange_x_sw;

  wire [4-1:0] reg_rails_oe;
  assign { RAILS_OE  } = reg_rails_oe;

  wire [4-1:0] reg_ina_vfb_sw;
  assign { INA_VFB_SW3_CTL, INA_VFB_SW2_CTL, INA_VFB_SW1_CTL } = reg_ina_vfb_sw;

  wire [4-1:0] reg_ina_ifb_sw;
  assign { INA_IFB_SW3_CTL, INA_IFB_SW2_CTL, INA_IFB_SW1_CTL } = reg_ina_ifb_sw;

  wire [4-1:0] reg_ina_vfb_atten_sw;
  assign { INA_VFB_ATTEN_SW3_CTL, INA_VFB_ATTEN_SW2_CTL, INA_VFB_ATTEN_SW1_CTL } = reg_ina_vfb_atten_sw;

  wire [4-1:0] reg_isense_mux;
  assign { ISENSE_MUX3_CTL,  ISENSE_MUX2_CTL , ISENSE_MUX1_CTL } = reg_isense_mux;

  wire [4-1:0] reg_relay_out;
  assign {  RELAY_SENSE_INT_CTL, RELAY_SENSE_EXT_CTL, RELAY_GUARD_CTL, RELAY_OUT_COM_HC_CTL } = reg_relay_out;



  // wire [4-1:0] reg_relay_vsense;
  // assign {  RELAY_VSENSE_CTL } = reg_relay_vsense;

  // wire [4-1:0] reg_relay_vsense;
  // assign {  RELAY_VSENSE_CTL } = reg_relay_vsense;

  wire [4-1:0] reg_irange_yz_sw;
  assign {  IRANGE_YZ_SW4_CTL, IRANGE_YZ_SW3_CTL, IRANGE_YZ_SW2_CTL, IRANGE_YZ_SW1_CTL } = reg_irange_yz_sw;




  /*
    input  ADC02_DONE,  // input
    input  ADC02_DRDY,    // input
  */

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
    . reg_rails(reg_rails),
    . reg_dac_ref_mux(reg_dac_ref_mux),
    . reg_adc(reg_adc),
    . reg_clamp1(reg_clamp1),
    . reg_clamp2(reg_clamp2),
    . reg_relay_com(reg_relay_com),

    . reg_mon_rails(reg_mon_rails),

    . reg_irange_x_sw(reg_irange_x_sw),
    . reg_rails_oe(reg_rails_oe),
    . reg_ina_vfb_sw(reg_ina_vfb_sw),
    . reg_ina_ifb_sw(reg_ina_ifb_sw),
    . reg_ina_vfb_atten_sw(reg_ina_vfb_atten_sw),
    . reg_isense_mux(reg_isense_mux),
    . reg_relay_out(reg_relay_out),
    // . reg_relay_vsense(reg_relay_vsense),
    . reg_irange_yz_sw(reg_irange_yz_sw)

  );



/*
  blinker #(  )
  blinker
    (
    .clk(XTALCLK),
    .led1(LED1),
    .led2(LED2)
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

