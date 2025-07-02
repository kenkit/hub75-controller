module spi_slave #(parameter BITS_PER_PIXEL=16)
    (
        input reset,
        input spi_clk,
        input spi_mosi,
        output [BITS_PER_PIXEL-1:0] data,
        output pixel_clk
    );

    localparam BITS_PER_RGB = BITS_PER_PIXEL / 4;

    reg [31:0] tmp_data = 32'b0;
    reg [4:0] bit_counter =  5'b11111;

    always @ (posedge reset, posedge spi_clk) begin
        if (reset == 1'b1) begin
            bit_counter <= 5'b11111;
        end else begin
            tmp_data[bit_counter] <= spi_mosi;
            bit_counter <= bit_counter - 5'b00001;
        end
    end
    assign data = {
            tmp_data[31 -: BITS_PER_RGB],
            tmp_data[23 -: BITS_PER_RGB],
            tmp_data[15 -: BITS_PER_RGB],
            tmp_data[7  -: BITS_PER_RGB]
            };
    assign pixel_clk = bit_counter[4];

endmodule
