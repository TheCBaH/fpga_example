
module top (
    input wire logic clk,
    btnc,
    sw,
    output logic [3:0] anode,
    output logic [7:0] segment
);

  clock TOP (
      .clk(clk),
      .reset(btnc),
      .anode(anode),
      .segment(segment)
  );

endmodule
