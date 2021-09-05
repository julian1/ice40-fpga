

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
  assign LED_B = CMPR_OUT_CTL_P;
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
  assign CMPR_LATCH_CTL = 0;   //  works!


/*
  // i don't think we need this
  // trigger zerocross
  reg [2:0] zerocrossr;
  always @(posedge clk) 
    zerocrossr <= {zerocrossr[1:0], CMPR_LATCH_CTL};
  wire zerocross_up     = (zerocrossr[2:1]==2'b10);
  wire zerocross_down   = (zerocrossr[2:1]==2'b01);
  wire zerocross_any    = zerocross_up || zerocross_down ;
*/



  `define STATE_INIT    0    // initialsation state
  // `define STATE_WAITING 1
  `define STATE_PREF    2
  `define STATE_NREF    3
  // `define STATE_RUNDOWN 4

  reg [4:0] state = `STATE_INIT;

  // we don't have to keep the pos,neg count of slow count. because it's implied by oscillation count.
  // but might be easier.

  // ok. so pos count and neg count will be independent.

  /*
    Actually not sure we do have to get it into the clock domain.
    simplest thing. if above, then drive lo. if below then drive hi.
    ----
    what is the reason for the small backtrack? just to better fit the integration range within the voltage range?
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
            state <= `STATE_PREF;
            count <= 0;
            leds <= 3'b001; // R
          end


        `STATE_PREF:
          begin
            // should use dedicated pref count... and accumulate.
            // or have a count dedicated....

            if(count == 10000 )
              begin
              /*
                ok. here would would do a small backtrack count. then we test integrator comparator
                for next direction.
              */

              count <= 0;   // reset count

              if( CMPR_OUT_CTL_P)
                  begin
                      // swap to reference input for rundown
                      // state <= `STATE_NREF;
                    leds <= 3'b010; // G
                  end
                else

                    leds <= 3'b001; // R
                end
            end

/*
        `STATE_NREF:  // neg backtrack.
          begin

            if(count == 40000 + 40000 )
              begin
                // swap to reference input for rundown
                state <= `STATE_INIT;
                // can avoid state init. by just setting count to 0 again here...
                // if want.
                // not. sure we need. integration will toggle
              end
          end
*/
      endcase
    end


endmodule


