
module top (
    input clk,
    input btnc,
    input sw,
    output [3:0] anode,
    output [7:0] segment
);
  reg [4:0] reset_count = 4'b0;
  wire reset;
  assign reset = !reset_count[4];
  always @(posedge clk) begin
    if (!reset) begin
      reset_count <= reset_count + 1'b1;
    end
  end

  clock TOP (
      .clk(clk),
      .reset(btnc),
      .anode(anode),
      .segment(segment)
  );

endmodule
