module flop #(parameter WIDTH = 8) (
  input  logic             clk,
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q);

endmodule

module flopenl #(parameter WIDTH = 8, parameter type TYPE=logic [WIDTH-1:0]) (
  input  logic clk, load, en,
  input  TYPE d,
  input  TYPE val,
  output TYPE q);

endmodule

module flopenrc #(parameter WIDTH = 8) (
  input  logic             clk, reset, clear, en,
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q);

endmodule

module flopenr #(parameter WIDTH = 8) (
  input  logic             clk, reset, en,
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q);

endmodule

module flopens #(parameter WIDTH = 8) (
  input  logic             clk, set, en,
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q);

endmodule

module flopen #(parameter WIDTH = 8) (
  input  logic             clk, en,
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q);

endmodule

module flopr #(parameter WIDTH = 8) (
  input  logic             clk, reset,
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q);

endmodule

module synchronizer (
  input  logic clk,
  input  logic d,
  output logic q);

  logic mid;

endmodule

// Top module for testing - doesn't drive or check signals itself, meant for use with external testbench

module top_flop(
  input  logic clk, reset, clear, en, load, set,
  input  logic [7:0] d, val, // Assuming WIDTH=8 for all submodules
  output logic [7:0] q_flop, q_flopenl, q_flopenrc, q_flopenr, q_flopens, q_flopen, q_flopr,
  input  logic d_sync, // Separate input for synchronizer
  output logic q_sync
);

  flop    #(.WIDTH(8)) flop_inst (.clk(clk), .d(d), .q(q_flop));
  flopenl #(.WIDTH(8)) flopenl_inst (.clk(clk), .load(load), .en(en), .d(d), .val(val), .q(q_flopenl));
  flopenrc#(.WIDTH(8)) flopenrc_inst(.clk(clk), .reset(reset), .clear(clear), .en(en), .d(d), .q(q_flopenrc));
  flopenr #(.WIDTH(8)) flopenr_inst(.clk(clk), .reset(reset), .en(en), .d(d), .q(q_flopenr));
  flopens #(.WIDTH(8)) flopens_inst(.clk(clk), .set(set), .en(en), .d(d), .q(q_flopens));
  flopen  #(.WIDTH(8)) flopen_inst (.clk(clk), .en(en), .d(d), .q(q_flopen));
  flopr   #(.WIDTH(8)) flopr_inst  (.clk(clk), .reset(reset), .d(d), .q(q_flopr));
  synchronizer synchronizer_inst (.clk(clk), .d(d_sync), .q(q_sync));
endmodule
