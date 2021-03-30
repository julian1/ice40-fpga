// assign cs_vec = 1;  // adc03 cs is high.
  // assign cs_vec = 0;  // adc03 cs is lo.

  // want to swapt the led order.
  // assign LED1 = MOSI;
  // assign LED1 = MOSI;
  // assign LED1 = SPECIAL;




  // OK. rather than having separate lines....
  // why not have a single output....

  /*
  // this should be able to be simplified 
  // cs_vector = reg_mux & cs  (where cs is extendedfilled)
  // and this will turn off old outputs.
  // BUT. we lose the ability to change polarity... easily. or play with miso
  // hmmmm.... 
  // default values should be high.... eg. active lo

  //   reg_mux 00001000    cs=0  ==   00000000  
  //   reg_mux 00001000    cs=1  ==   00001000  
  */



                        // EXTREME this should be when cs changes. eg. we copy value.
  always @ (cs)     // eg. whenever reg_mux changes we update ... i think.
    begin

      cs_mux =    reg_mux & excs;

      // 
      // cs_vector

      case (reg_mux)
        1 :
        begin
          adc03_cs = cs;
          dac_cs = 1;
        end

        2 :
        begin
          adc03_cs = 1;
          dac_cs = cs;
        end


        default:
        begin
          adc03_cs = 1;   // active lo. so deassert
          dac_cs = 1;
        end
      endcase
    end





// from https://github.com/cliffordwolf/icestorm/tree/master/examples/icestick

// example.v


// HANG on how does register shadowing work???

// have separate modules for an 8 bit mux.
// versus a 16 bit reg value
// versus propagating.



/*
    we just want a register bank....
  TODO rename mylatch myregister_bank ?

  // use the special flag, to write to the register bank.
*/

module blinker    (
  input clk,
  output led1,
  output led2

);

  localparam BITS = 5;
  // localparam LOG2DELAY = 21;
  localparam LOG2DELAY = 19;

  reg [BITS+LOG2DELAY-1:0] counter = 0;
  reg [BITS-1:0] outcnt;

  always@(posedge clk) begin
    counter <= counter + 1;
    outcnt <= counter >> LOG2DELAY;
  end

  // assign {led1} = counter2 >> 22;
  // assign { led1, led2, LED3, LED4, LED5 } = outcnt ^ (outcnt >> 1);
  assign {  led1, led2 } = outcnt ^ (outcnt >> 1);
endmodule



