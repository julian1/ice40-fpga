/*
   keep the precharge time the same, when taking a low  measurement - for symmetry and to be more generic.

  remember also.
    we need a way to communicate back to the mcu which sample is the one in the sequence.
    so the sample_idx is good.
    and can be encoded in the status regsiter.
    ----
    - think we may want the count. so that the receiver of data. can handle more easily.
    - eg. doesn't have to say   if(mode == modeA &&  count == 0 || count == 2)
    - not sure, it's not that complicated to interpret.
    ------

    EXTR. if we didn't want the pre-charge to switch in in non-AZ mode,
        then could this with another bitvector.   eg. in the two hi bits.
        -----
        that eliminates the need to have a separate no_az controller.

    { wheether to switch pc switch, value of pc switch, azmux val }
    ------
    if we use a count . it might be easier to use registers.  eg.  reg_sa_sample_0  reg_sa_sample_1  etc.
    and just pack the bits.
    simple azcase is just write two registers, and sequence n.

    sample_seq0
    sample_seq1
    sample_seq2
    sample_seq3
*/


// implicit identifiers are only caught when modules have been instantiated
`default_nettype none


// todo change name common. or macros. actually defines is ok.etc
`include "defines.v"




// rename sample_sequence_acquisition
// or sample_acquisition_sequence

module sequence_acquisition (

  // remember hi mux is not manipulated, or given to this module.
  // inistead the hi signal is seleced by the AZ mux, via the pre-charge switch

  input   clk,
  input   reset_n,

  // inputs
  input [24-1:0]    p_clk_count_precharge_i,

  input [ 3-1: 0 ]  p_seq_n_i,    // need at least 3 bits to encode 4.
  input [ 6-1 : 0 ] p_seq0_i,
  input [ 6-1 : 0 ] p_seq1_i,
  input [ 6-1 : 0 ] p_seq2_i,
  input [ 6-1 : 0 ] p_seq3_i,



  input adc_measure_valid_i,

  // outputs.
  output reg adc_reset_no,  // rename _n_o. perhaps or trig. is even ok.

  output reg [ 2-1: 0]  pc_sw_o,      // TODO  fix rename pc_sw_o
  output reg [ 4-1:0 ] azmux_o,


  //  - status_o should be treated generically.  just like monitor_o and leds_o.

  // currently unused.
  // output reg [4-1: 0 ] status_last_o,

  output reg  [3-1: 0] sample_idx_last_o,


  output wire [4-1:0] leds_o,

  /*/ now a wire.  output wire [ 2-1:0]  monitor_o       // driven as wire/assign.
  // think it is ok to be a combinatory logic - wire output - although may slow things down.
  */
  output wire [ 8-1:0]  monitor_o

);

  reg [7-1:0]   state = 0 ;     // should expose in module, not sure.

  reg [31:0]    clk_count_down;           // clk_count for the current phase. using 31 bitss, gives faster timing spec.  v 24 bits. weird. ??? 36MHz v 32MHz


  reg  [3-1: 0] sample_idx = 0;




  assign monitor_o[0] = (azmux_o == `S3);   // (count == 0 ) etc.
  assign monitor_o[1] = (azmux_o == `S7);
  assign monitor_o[2] = (azmux_o == `S1);
  assign monitor_o[3] = (azmux_o == `S8);

  assign monitor_o[4] = pc_sw_o[0 ] ;
  assign monitor_o[5] = pc_sw_o[1 ] ;

  assign monitor_o[6] = adc_reset_no;
  assign monitor_o[7] = adc_measure_valid_i;


  assign leds_o[0] = (sample_idx == 0);
  assign leds_o[1] = (sample_idx == 1);
  assign leds_o[2] = (sample_idx == 2);
  assign leds_o[3] = (sample_idx == 3);

  always @(posedge clk)
    begin

      // always decrement clk for the current phase
      clk_count_down <= clk_count_down - 1;


      case (state)

        // precharge switch - protects the signal. from the charge-injection of the AZ switch.
        0:
          begin
            // having a state like, this may be useful for debuggin, because can put a pulse on the monitor_o.
            state <= 1;

            adc_reset_no    <= 0;

            // avoid 0 which could confuse
            // instead indicate no last sample available state
            sample_idx_last_o <= 3'b111;

            /* TODO  - during reset - should should hold the precharge switches lo.
            // azmux state should probably also be defined.  can use the first value.
            */
            // pc_sw_o       <= 2'b00;
            // azmux_o   <= p_seq0_i[ 0 +: 4 ];
          end



        // switch pre-charge switch to boot to protect signal, and pause.
        1:
          begin
            state           <= 15;
            clk_count_down  <= p_clk_count_precharge_i;

            // TODO REVIEW reset the precharge switches. - shoud do this in final state. instead.
            pc_sw_o       <= 2'b00;

          end

        15:
          if(clk_count_down == 0)
            state <= 2;




        ////////////////////////////
        // switch azmux_o to the signal of interest, which may be a low. and pause
        // precharge phase.
        2:
          begin
            state           <= 25;
            clk_count_down  <= p_clk_count_precharge_i;  // normally pin s1

            case(sample_idx)
              0: azmux_o   <= p_seq0_i[ 0 +: 4 ];
              1: azmux_o   <= p_seq1_i[ 0 +: 4];
              2: azmux_o   <= p_seq2_i[ 0 +: 4 ];
              3: azmux_o   <= p_seq3_i[ 0 +: 4];
            endcase
          end
        25:
          if(clk_count_down == 0)
            state <= 3;



        /////////////////////////
        // switch pc-switch from BOOT to the signal input (which may be a ground), and pause.
        // if we are sampling a ground, and pc_val = 0, then this does nothing.
        // and we could skip it, but probably not unreasonable to keep timing the same.
        3:
          begin
            state           <= 33;
            clk_count_down  <= p_clk_count_precharge_i;  // normally pin s1

            case(sample_idx)
              0: pc_sw_o <= p_seq0_i[4 +: 2];
              1: pc_sw_o <= p_seq1_i[4 +: 2];
              2: pc_sw_o <= p_seq2_i[4 +: 2];
              3: pc_sw_o <= p_seq3_i[4 +: 2];
            endcase
          end
        33:
          if(clk_count_down == 0)
            begin
              state           <= 35;
              // adc start
              adc_reset_no <= 1;
            end


        35:
          // wait for adc to measure
          if( adc_measure_valid_i )
            begin

              // go back to state 1
              state         <= 1;


              sample_idx_last_o  <= sample_idx;

              /*
                avoid modulo
                https://stackoverflow.com/questions/47425729/verilog-modulus-operator-for-wrapping-around-a-range
                needs to be >= in case sample_n is reduced in write.
              */
/*
              if(sample_idx >= p_seq_n_i - 1)
                sample_idx <=  0;
              else
                sample_idx <= sample_idx + 1;
*/

              sample_idx <= (sample_idx >= p_seq_n_i - 1)
                              ? 0
                              : sample_idx + 1;


              // set status for hi sample
              // status_last_o    <= 4'b001; // we moved this.      // set status only after measure, to enable reg reading, during next measurement cycle.

              // put adc in reset again
              adc_reset_no <= 0;
            end




      endcase



      // override all states - if reset_n enabled, then don't advance out-of reset state.
      if(reset_n == 0)      // in reset
        begin

            state <= 0;
        end



    end
endmodule





