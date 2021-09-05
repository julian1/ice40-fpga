

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
  input CMPR_OUT_CTL_N

);


  //////////////////////////////////////////////////////
  // counters and settings  ...
  // for an individual phase.
  reg [31:0] count = 0;         // change name phase_count... or something...
  reg [31:0] count_osc = 0;     //
  reg [31:0] count_up = 0;      //
  reg [31:0] count_down = 0;    //
  reg [31:0] count_rundown = 0; //



  // we can probe the leds for signals....

  // start everything off...
  reg [2:0] mux = 3'b000;        // b / bottom


  assign { /*LED_B, */ LED_G, LED_R } = ~ mux;        // note. INVERTED for open-drain..
  // assign { LED_B, LED_G, LED_R } = count >> 22 ;      // ok. working. if remove the case block..
                                                          // but this does't...


  // might be easier to assign things individually.

  assign { INT_IN_SIG_CTL, INT_IN_N_CTL, INT_IN_P_CTL } = mux;

  // OK. so want to make sure. that the



  /////////////////////////
  // this should be pushed into a separate module...
  // should be possible to set latch hi immediately on any event here...
  reg [2:0] zerocrossr;
  always @(posedge clk)
    zerocrossr <= {zerocrossr[1:0], CMPR_OUT_CTL_P};
  wire zerocross_up     = (zerocrossr[2:1]==2'b10);  // message starts at falling edge
  wire zerocross_down   = (zerocrossr[2:1]==2'b01);  // message stops at rising edge
  wire zerocross_any    = zerocross_up || zerocross_down ;




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
            count_osc <= 0;
            count_up <= 0;
            count_down <= 0;
            mux <= 3'b001; // initial direction
            LED_B <= 0;
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
                count_osc <= count_osc + 1;

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
                if(count_osc == 2000 * 5 )     // 2000osc = 1sec.
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

            if(zerocross_down || zerocross_up)
              begin
                  // trigger for scope
                  LED_B <= ~ LED_B;

                  // record/copy the count??? or use a different count variable
                  // OK. we need to have the integrator run from fixed start point.
                  // what's weird...

                  // turn off all inputs
                  // seems to work...
                  mux <= 3'b000;
                  // state to done
                  state <= `STATE_DONE;

              end
          end


        `STATE_DONE:
          begin
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
