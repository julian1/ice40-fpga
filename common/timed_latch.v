


`default_nettype none


module timed_latch  #(parameter HOLD= 20000000 / 20 ) (
  /* latch the state state of the trigger for a period.
    should pass the period as a configuration variable.
    --
    rename latch_hold?
    --
    // rather than parametize hold time, perhaps should just pass the period?.
  */
  input       clk,
  input       trig_i,   // active hi
  output reg  out
);
  reg [ 32-1:0 ] counter ;

  always@(posedge clk  )
    begin
      out <= counter != 0;

      if( counter)
        counter <= counter - 1;

      if(trig_i)
        counter  <= HOLD ; // 20000000 / 10;    // 10th of second
    end
endmodule



