
// this doesn't synthesize because led has multiple drivers. even though in practice the arbitrations prevents this.

// better approach is an arbitration module that would just select the output of the desired fsm. and perhaps hold the unused one in reset.

    module my_fsm (
      input  clk,
      input  active ,
      input wire [ 31 - 1 : 0 ] freq ,
      output led
    );
      reg [31:0]  clk_count ;
      always @(posedge clk)
        if(active)
          begin
            clk_count <= clk_count + 1;
            if(clk_count > freq)
              begin
                clk_count <= 0;
                led <= ~ led; 
              end
          end
    endmodule


    module top (
      input  clk,
      output LED_R,
      input COM_CS,
    );

      wire arbitration = COM_CS;

      my_fsm fsm1 (
        . clk(clk),
        . active( arbitration ) ,
        . freq( 1),
        . led( LED_R )
      );


      my_fsm fsm2 (
        . clk(clk),
        . active( ! arbitration) ,
        . freq( 3),
        . led( LED_R )
      );


    endmodule


