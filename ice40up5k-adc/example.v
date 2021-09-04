

module top (
  input  clk,
  output LED_R,
  output LED_G,
  output LED_B,

  output INT_IN_P_CTL, 
  output INT_IN_N_CTL,     
  output INT_IN_SIG_CTL   

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
 

  // leds are open drain. 0 is on. 1 is off.
  // reg [2:0] leds = 0;// 3'b101;        // middle on.
  // reg [2:0] leds = 3'b001;        // red/ top 
  // reg [2:0] leds = 3'b010;        // g / middle
  reg [2:0] leds = 3'b100;        // b / bottom



  // assign { LED_B, LED_G, LED_R } = count >> 22 ;      // ok. working. if remove the case block.. 
                                                          // but this does't... 



  // Think we want to reverse these bits 1

  assign { LED_B, LED_G, LED_R } = ~ leds;        // INVERTED
/*
  assign { INT_IN_SIG_CTL, INT_IN_N_CTL, INT_IN_P_CTL } = leds;      
*/

  `define STATE_INIT    0    // initialsation state
  // `define STATE_WAITING 1
  `define STATE_PREF    2
  `define STATE_NREF    3
  `define STATE_RUNDOWN 4

  reg [4:0] state = `STATE_INIT;

  // we don't have to keep the pos,neg count of slow count. because it's implied by oscillation count.
  // but might be easier.

  // ok. so pos count and neg count will be independent. 

  always @(posedge clk)
    begin
      // we use the same count - always increment clock
      count <= count + 1;

      case (state)
        `STATE_INIT:
          begin
            // initialize count
            count <= 0;
            state <= `STATE_PREF;
          end

      
        `STATE_PREF:
          begin
            // should use dedicated pref count... and accumulate.
            // or have a count dedicated....

            if(count == 20000000 )
              /*
                ok. here would would do a small backtrack count. then we test integrator comparator 
                for next direction.
              */
              begin
                // swap to reference input for rundown
                state <= `STATE_NREF;
                // leds <= ~ 3'b001;
              end
          end


        `STATE_NREF:  // neg backtrack.
          begin

            if(count == 20000000 + 4000000 )
              begin
                // swap to reference input for rundown
                state <= `STATE_INIT;
                // leds <= ~ 3'b010;
                // can avoid state init. by just setting count to 0 again here...
                // if want.
                // not. sure we need. integration will toggle 
              end
          end

      endcase
    end


endmodule

