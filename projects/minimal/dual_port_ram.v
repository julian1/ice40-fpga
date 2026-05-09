


module dual_port_ram #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32
)(
    input clk,
    // Port A: Write
    input we,
    input [ADDR_WIDTH-1:0] addr_a,
    input [DATA_WIDTH-1:0] din_a,

    // Port B: Read
    input re,
    input [ADDR_WIDTH-1:0] addr_b,
    output reg [DATA_WIDTH-1:0] dout_b          // register
);
    // Memory Array
    reg [DATA_WIDTH-1:0] ram [0:(1<<ADDR_WIDTH)-1];

    // Port A Write
    always @(posedge clk) begin
        if (we)
            ram[addr_a] <= din_a;
    end

    /* use the re to synchronize the driving/write of the output register.
      because want to be able to shift it also for spi output
      probably easier - to instantiate mem locally.
      and can rely on verilog precedence. to synch the different driving
    */
    // Port B Read
    always @(posedge clk) begin
        if( re)
          dout_b <= ram[addr_b];    // write to register
    end
endmodule


