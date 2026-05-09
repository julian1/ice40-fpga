


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
    input [ADDR_WIDTH-1:0] addr_b,
    output reg [DATA_WIDTH-1:0] dout_b
);
    // Memory Array
    reg [DATA_WIDTH-1:0] ram [0:(1<<ADDR_WIDTH)-1];

    // Port A Write
    always @(posedge clk) begin
        if (we)
            ram[addr_a] <= din_a;
    end

    // Port B Read
    always @(posedge clk) begin
        dout_b <= ram[addr_b];
    end
endmodule


