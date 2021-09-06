

/*
  - should update. to separate out the mask and val.
  so can use different sizes.
*/

// x is not a mask. it is hi bits and lo bits

function [4-1:0] update (input [4-1:0] x, input [8-1:0]  val);

  reg [4-1:0] lob ;  // 1 and a set b no i think these are the clear bits...
  reg [4-1:0] hib ;
  begin
    lob = val & 4'b1111 ;    // and with lo bits
    hib = val >> 4;          // or with hi bits

    if( lob & hib /*!= 0*/  ) // if any bit is both set and clear, then toggle when both set
      update =  (lob & hib);
    else
      update = ~(  ~(x | lob) | hib );
  end
endfunction


// for 24bit values we don't really want these bitmask values.
// we just want to write and read registers.


/*
  - having the write mask is an effective way to do a read.

  - being able to use different sized spi actions would be very nice....
  - having some automated stm32 driver tests would also be nice.

  - want to change assignement '=' to '<='
  EXTR.
    change all this to avoid overloading the special.
    instead make special an extra CS.
    ------------

  after we have read 8 bits. then we have the address...
  ----------------------

  lets do the simplest thing...
*/

module my_register_bank   #(parameter MSB=16)   (
  input  clk,
  input  cs,
  // input  special,   // TODO swap order specia/din
  input  din,       // sdi
  output dout,       // sdo

  // latched val, rename
  output reg [4-1:0] reg_led     // need to be very careful. only 4 bits. or else screws set/reset calculation ...
);

  // TODO rename these...
  // MSB is not correct here...
  reg [MSB-1:0] in;      // register used to read val
  reg [MSB-1:0] out  ;    // register for output.  should be size of MSB due to high bits 
  reg [8-1:0]   count;

  // these are going to be different depending...
  // does this work? wire is effectively an alias in combinatorial code
  // these are only correct when count == 16...
  
  wire dout = out[MSB- 1];    
                              
                              

  // clock value into in var
  always @ (negedge clk or posedge cs)
  begin
    if(cs)          // cs not asserted, so reset.
      begin
        count = 0;
        in = 0;
        out = 0;
      end
    else
      // cs asserted
      begin

        // shift din into in register
        in = {in[MSB-2:0], din};

        count = count + 1;

        // shift data from out register
        out = out << 1; // this *is* zero fill operator.


        // in holds the address
        if(count == 8)
          begin
            case (in )
              7 :
                begin
                  out = reg_led << 8;
                end
            endcase  
          end

      end
  end


  // these are only correct when count == 16... MSB
  wire [8-1:0] addr  = in[ MSB-1:8 ]; // high byte for reg/address, lo byte for val.
  wire [8-1:0] val   = in;    // lo byte


  always @ (posedge cs)   // cs done.
  begin
    // we can assert a done flag here... and factor this code...
    // special asserted, and 16 received bits

    // Ok. this can handle different sizes... nice.

    if(count == 16 )
      begin
        case (addr)
          // leds
          7 :
            begin
              reg_led = update(reg_led, val);
            end

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
              reg_led           = 3'b101;
            end

        endcase
      end
  end
endmodule








////////////////////////////









module top (
  input  clk,
  output LED_R,
  output LED_G,
  output LED_B,

  output INT_IN_P_CTL,
  output INT_IN_N_CTL,
  output INT_IN_SIG_CTL,

  // it should be possible to immediately set high, on the latch transition, to avoid
  // and then reset on some fixed count
  output CMPR_LATCH_CTL,

  /* should configure as differential input.
    https://stackoverflow.com/questions/40096272/how-do-i-use-set-lvds-mode-on-lattice-ice40-pins-using-icestorm-tools
    https://github.com/YosysHQ/icestorm/issues/36
  */
  input CMPR_OUT_CTL_P,
  input CMPR_OUT_CTL_N,


  /////////
  input COM_CLK,
  input COM_CS,
  input COM_MOSI,
  input COM_SPECIAL,
  output COM_MISO,
  output COM_INTERUPT


);


  //////////////////////////////////////////////////////
  // counters and settings  ...
  // for an individual phase.
  reg [31:0] count = 0;         // count_clk.   change name phase_count... or something...
  reg [31:0] count_phase = 0;     // phase not oscillation, because may have 2 in the same direction.
  reg [31:0] count_up = 0;      //
  reg [31:0] count_down = 0;    //
  reg [31:0] count_rundown = 0; //



  /*
    OK. hang on. do we have an issue. with the same registers being sampled in different clk domains?

  */


  wire [4-1:0] reg_led ;
  assign { LED_B, LED_G, LED_R } =   reg_led ;   // not inverted for easier scope probing.inverted for common drain.
  // assign { LED_B, LED_G, LED_R } = 3'b010 ;       // works...
                                                    // Ok. it really looks correct on the leds...

  // assign { COM_MOSI , COM_CLK, COM_CS} =  reg_led ;



  my_register_bank #( 16 )   // register bank
  my_register_bank
    (
    . clk(COM_CLK),
    . cs(COM_CS),
    . din(COM_MOSI),
    . dout(COM_MISO),

    . reg_led(reg_led)
  );




  // we can probe the leds for signals....

  // start everything off...
  reg [2:0] mux = 3'b000;        // b / bottom






  // assign { /*LED_B, */ LED_G, LED_R } = ~ mux;        // note. INVERTED for open-drain..
  // assign { LED_B, LED_G, LED_R } = count >> 22 ;      // ok. working. if remove the case block..
                                                          // but this does't...


  // might be easier to assign things individually.

  assign { INT_IN_SIG_CTL, INT_IN_N_CTL, INT_IN_P_CTL } = mux;

  // OK. so want to make sure. that the



  /////////////////////////
  // this should be pushed into a separate module...
  // should be possible to set latch hi immediately on any event here...
  // change name  zero_cross.. or just cross_
  reg [2:0] crossr;
  always @(posedge clk)
    crossr <= {crossr[1:0], CMPR_OUT_CTL_P};
  wire cross_up     = (crossr[2:1]==2'b10);  // message starts at falling edge
  wire cross_down   = (crossr[2:1]==2'b01);  // message stops at rising edge
  wire cross_any    = cross_up || cross_down ;




  `define STATE_INIT    0    // initialsation state
  // `define STATE_WAITING 1
  `define STATE_RUNUP    2
  `define STATE_RUNDOWN  3
  `define STATE_DONE     4

  reg [4:0] state = `STATE_INIT;


  /*
    - need to keep up/down transitions equal.  - to balance charge injection.
    - if end up on wrong side. just abandon, and run again? starting in opposite direction.
  */
  always @(posedge clk)
    begin
      // we use the same count - always increment clock
      count <= count + 1;

      case (state)
        `STATE_INIT:
          begin
            ///////////
            // reset vars, and transition to runup state
            state <= `STATE_RUNUP;
            count <= 0;
            count_phase <= 0;
            count_up <= 0;
            count_down <= 0;
            mux <= 3'b001; // initial direction
//            LED_B <= 0;
            // enable comparator
            CMPR_LATCH_CTL <= 0;
          end


        // So switching to rundown is just when the count hits a certain amount...
        // having separate clocks means can vary things more easily.
        // OR. just count the periods.  yes.

        `STATE_RUNUP:
          begin
            // should use dedicated pref count... and accumulate.
            // or have a count dedicated....

            if(count == 8000 )
              begin
                if(mux == 3'b010 )
                  begin
                    mux <= 3'b001; // R
                  end
                 /*
                // these blocks cancel i think...
                // need a case? perhaps
                if(mux == 3'b001 )
                  begin
                  mux <= 3'b010; // G
                  end
                */
              end

            if(count == 10000 )
              begin
                /*
                  ok. here would would do a small backtrack count. then we test integrator comparator
                  for next direction.
                */

                // reset count
                count <= 0;
                // inc oscillations
                count_phase <= count_phase + 1;

                // sample the comparator, to determine next direction
                if( CMPR_OUT_CTL_P)
                  begin
                    mux <= 3'b010;
                    count_up <= count_up + 1;
                  end
                else
                  begin
                    mux <= 3'b001; // R
                    count_down <= count_down + 1;
                  end
                end

                // count_up == count
                if(count_phase == 2000 * 5 )     // 2000osc = 1sec.
                  begin

                    state <= `STATE_RUNDOWN;
                    count_rundown <= 0;       // reset...
                  end

              end


        // EXTR. we also have to short the integrator at the start. to begin at a known start position.

        `STATE_RUNDOWN:
          begin
            // need to do the rundown count...
            // so we have to determine the clock cross...
            // probably with want to capture it on a scope.
            // the direction should be correct here. and we just have to run it down
            // we wnat a different clock so we can read it....

            // EXTR. only incrementing the count, in the contextual state,
            // means can avoid copying the variable out, if we do it quickly.
            count_rundown <= count_rundown + 1;

            if(cross_down || cross_up)
              begin
                  // trigger for scope
//                  LED_B <= ~ LED_B;

                  // EXTR. raise interupt that value is ready.

                  // record/copy the count??? or use a different count variable
                  // OK. we need to have the integrator run from fixed start point.
                  // what's weird...

                  // turn off all inputs
                  // seems to work...
                  mux <= 3'b000;
                  // transition to state to done
                  state <= `STATE_DONE;

              end
          end


        `STATE_DONE:
          begin
            // EXTR.   we might  want to hold the interrupt for a bit, to get it to propagate.
            // eg. just use the count.

            // ok. it is hitting exactly the same spot everytime. nice.
            // when immediately restart. because it's hit a zero cross.
            // but we probably want to start from a shorted integrator.
            ///////////////
            // OK. to get the count value.  we have to be able to read it.

            state <= `STATE_INIT;
          end


      endcase
    end


endmodule







  /*
    must be lo to trigger.
    on +-4.8V . latch must be off... else it's held low.
  */
  // assign CMPR_LATCH_CTL = 0;   //  works!



  // we don't have to keep the pos,neg count of slow count. because it's implied by oscillation count.
  // but might be easier.

  // ok. so pos count and neg count will be independent.

  /*
    EXTREME .
      i think the small backtracek reversinig action - avoids two crossing - happing in an instant.
      eg. where the /\  happens right at the apex.

  */

  // actually counting the number of periods. rather than the clock. might be simpler.
  // because the high slope and lo slope are not equal.



  // the count is kind of correct. but we are setkkkkk
  // not sure we are using correct....
  // it's not an arm/disarm.   instead when we get the cross, we should set latch high ..
  // but that if two crossings very close together.  which will happen.

  // should be differential input
  // assign LED_B = CMPR_LATCH_CTL;
  // assign LED_B = CMPR_OUT_CTL_P;
  // assign LED_B = CMPR_OUT_CTL_N;

  // rgb. top,middle,bottom.
  // leds are open drain. 1 is on. 1 is off.
  // reg [2:0] leds = 3'b001;        // red/ top
  // reg [2:0] leds = 3'b010;        // g / middle
  // reg [2:0] leds = 3'b100;        // b / bottom

/*
  localparam BITS = 5;
  localparam LOG2DELAY = 21;

  reg [BITS+LOG2DELAY-1:0] counter = 0;
  reg [BITS-1:0] outcnt;


  always@(posedge clk) begin
    counter <= counter + 1;
    outcnt <= counter >> LOG2DELAY;
  end

  // assign { LED_R, LED_G, LED_B } = outcnt ^ (outcnt >> 1);

*/
