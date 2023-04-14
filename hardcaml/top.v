
module top (
    input clk,
    input btnc,
    input sw,
    output [3:0] anode,
    output [7:0] segment
);

  clock TOP (
      .clk(clk),
      .reset(btnc),
      .anode(anode),
      .segment(segment)
  );

endmodule
