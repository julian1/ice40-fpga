

module top (
  input  clk,
  output LED_R,
  output LED_G,
  output LED_B,
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
 

 
  // 0 is on or off? 
  // 0 == all bits off, turns leds on.
  // reg [2:0] leds = 3'b111;    // all off.

  reg [2:0] leds = 3'b101;        // middle on.



  // assign { LED_R, LED_G, LED_B } = counter >> 20 ;  // this works???
  // assign { LED_R, LED_G, LED_B } = counter >> 21 ;  // this works???
  // assign { LED_R, LED_G, LED_B } = count >> 21 ;      // ok. working. if remove the case block.. 


  assign { LED_R, LED_G, LED_B } = leds;      


  `define STATE_INIT    0    // initialsation state
  // `define STATE_WAITING 1
  `define STATE_PREF    2
  `define STATE_NREF    3
  `define STATE_RUNDOWN 4

  reg [4:0] state = `STATE_INIT;


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

            if(count == 2000000 )
              begin
                // swap to reference input for rundown
                state <= `STATE_NREF;
                // leds <= 3'b100;

              end
          end


        `STATE_NREF:
          begin

            if(count == 4000000 )
              begin
                // swap to reference input for rundown
                state <= `STATE_INIT;
                // leds <= 3'b001;
              end
          end

      endcase
    end


endmodule


