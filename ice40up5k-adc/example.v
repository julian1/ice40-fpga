

module top (
  input  clk,
  output LED_R,
  output LED_G,
  output LED_B,

  output INT_IN_P_CTL,
  output INT_IN_N_CTL,
  output INT_IN_SIG_CTL,

  output CMPR_LATCH_CTL,

  /* should configure as differential input.
    https://stackoverflow.com/questions/40096272/how-do-i-use-set-lvds-mode-on-lattice-ice40-pins-using-icestorm-tools
    https://github.com/YosysHQ/icestorm/issues/36
  */
  input CMPR_OUT_CTL_P,
  input CMPR_OUT_CTL_N



);

  localparam BITS = 5;
  localparam LOG2DELAY = 21;

  reg [BITS+LOG2DELAY-1:0] counter = 0;
  reg [BITS-1:0] outcnt;


  always@(posedge clk) begin
    counter <= counter + 1;
    outcnt <= counter >> LOG2DELAY;
  end

  // assign { LED_R, LED_G, LED_B } = outcnt ^ (outcnt >> 1);



  //////////////////////////////////////////////////////
  // counters and settings  ...
  reg [31:0] count = 0;

  // we can probe the leds for signals....

  // should be differential input
  // assign LED_B = CMPR_LATCH_CTL;
  // assign LED_B = CMPR_OUT_CTL_P;
  // assign LED_B = CMPR_OUT_CTL_N;

  // rgb. top,middle,bottom.
  // leds are open drain. 1 is on. 1 is off.
  // reg [2:0] leds = 3'b001;        // red/ top
  // reg [2:0] leds = 3'b010;        // g / middle
  // reg [2:0] leds = 3'b100;        // b / bottom
  reg [2:0] leds = 3'b000;        // b / bottom


  assign { /*LED_B, */ LED_G, LED_R } = ~ leds;        // note. INVERTED for open-drain..
  // assign { LED_B, LED_G, LED_R } = count >> 22 ;      // ok. working. if remove the case block..
                                                          // but this does't...


  // might be easier to assign things individually.

  assign { INT_IN_SIG_CTL, INT_IN_N_CTL, INT_IN_P_CTL } = leds;

  // OK. so want to make sure. that the

  /*
    must be lo to trigger.
    on +-4.8V . latch must be off... else it's held low.
  */
  // assign CMPR_LATCH_CTL = 0;   //  works!



  `define STATE_INIT    0    // initialsation state
  // `define STATE_WAITING 1
  `define STATE_RUNUP    2
  `define STATE_NREF    3
  // `define STATE_RUNDOWN 4

  reg [4:0] state = `STATE_INIT;

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
            // transition.
            state <= `STATE_RUNUP;
            count <= 0;
            leds <= 3'b001; // R
            // CMPR_LATCH_CTL <= 1;
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
                if(leds == 3'b010 )
                  begin
                    leds <= 3'b001; // R
                  end
 /*
                // these blocks cancel i think...
                // need a case? perhaps
                if(leds == 3'b001 )
                  begin
                  leds <= 3'b010; // G
                  end
*/
              end

            if(count == 10000 )
              begin
              /*
                ok. here would would do a small backtrack count. then we test integrator comparator
                for next direction.
              */

              count <= 0;   // reset count
              LED_B <= ~ LED_B;     // eg. comparator test.

              if( CMPR_OUT_CTL_P)
                  begin
                      // swap to reference input for rundown
                      // state <= `STATE_NREF;
                    leds <= 3'b010; // G
                    // p_count <= p_count + 1;
                  end
                else
                    leds <= 3'b001; // R
                    // n_count <= n_count + 1;
                end
            end


      endcase
    end


endmodule







  // the count is kind of correct. but we are setkkkkk
  // not sure we are using correct....
  // it's not an arm/disarm.   instead when we get the cross, we should set latch high ..
  // but that if two crossings very close together.  which will happen.

