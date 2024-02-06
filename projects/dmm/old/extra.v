


  /*
    RIGHT. it doesn't like having both a negedge and posedge...
    ok. maybe count is necessary to include in sensitivity list?
  */
  /*
  // these don't work...
  assign address = tmp[ MSB-1:8 ];
  assign value   = tmp[ 8 - 1: 0 ];

  need to put after the sequential block?
    see, http://referencedesigner.com/tutorials/verilog/verilog_32.php
  */

  // need to prevent a peripheral writing mosi. in a different frame .
  // actually don't think it will. will only write mosi. with cs asserted.



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


