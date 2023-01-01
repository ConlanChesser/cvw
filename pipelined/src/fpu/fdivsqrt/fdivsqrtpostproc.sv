///////////////////////////////////////////
// fdivsqrtpostproc.sv
//
// Written: David_Harris@hmc.edu, me@KatherineParry.com, cturek@hmc.edu
// Modified:13 January 2022
//
// Purpose: Combined Divide and Square Root Floating Point and Integer Unit
// 
// A component of the Wally configurable RISC-V project.
// 
// Copyright (C) 2021 Harvey Mudd College & Oklahoma State University
//
// MIT LICENSE
// Permission is hereby granted, free of charge, to any person obtaining a copy of this 
// software and associated documentation files (the "Software"), to deal in the Software 
// without restriction, including without limitation the rights to use, copy, modify, merge, 
// publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons 
// to whom the Software is furnished to do so, subject to the following conditions:
//
//   The above copyright notice and this permission notice shall be included in all copies or 
//   substantial portions of the Software.
//
//   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
//   INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR 
//   PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS 
//   BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, 
//   TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE 
//   OR OTHER DEALINGS IN THE SOFTWARE.
////////////////////////////////////////////////////////////////////////////////////////////////

`include "wally-config.vh"

module fdivsqrtpostproc(
  input  logic              clk, reset,
  input  logic              StallM,
  input  logic [`DIVb+3:0]  WS, WC,
  input  logic [`DIVb-1:0]  D, 
  input  logic [`DIVb:0]    FirstU, FirstUM, 
  input  logic [`DIVb+1:0]  FirstC,
  input  logic              SqrtE,
  input  logic              Firstun, SqrtM, SpecialCaseM, NegQuotM,
	input  logic [`XLEN-1:0]  AM,
  input  logic              RemOpM, ALTBM, BZeroM, AsM, W64M,
  input  logic [`DIVBLEN:0] nM, mM,
  output logic [`DIVb:0]    QmM, 
  output logic              WZeroE,
  output logic              DivSM,
  output logic [`XLEN-1:0]  FPIntDivResultM
);
  
  logic [`DIVb+3:0] W, Sum, DM;
  logic [`DIVb:0] PreQmM;
  logic NegStickyM;
  logic weq0E, weq0M, WZeroM;
  logic [`XLEN-1:0] IntDivResultM;

  //////////////////////////
  // Execute Stage: Detect early termination for an exact result
  //////////////////////////

  // check for early termination on an exact result. 
  aplusbeq0 #(`DIVb+4) wspluswceq0(WS, WC, weq0E);

  if (`RADIX == 2) begin: R2EarlyTerm
    logic [`DIVb+3:0] FZeroE, FZeroSqrtE, FZeroDivE;
    logic [`DIVb+2:0] FirstK;
    logic wfeq0E;
    logic [`DIVb+3:0] WCF, WSF;

    assign FirstK = ({1'b1, FirstC} & ~({1'b1, FirstC} << 1));
    assign FZeroSqrtE = {FirstUM[`DIVb], FirstUM, 2'b0} | {FirstK,1'b0};    // F for square root
    assign FZeroDivE =  {3'b001,D,1'b0};                                    // F for divide
    mux2 #(`DIVb+4) fzeromux(FZeroDivE, FZeroSqrtE, SqrtE, FZeroE);
    csa #(`DIVb+4) fadd(WS, WC, FZeroE, 1'b0, WSF, WCF); // compute {WCF, WSF} = {WS + WC + FZero};
    aplusbeq0 #(`DIVb+4) wcfpluswsfeq0(WCF, WSF, wfeq0E);
    assign WZeroE = weq0E|(wfeq0E & Firstun);
  end else begin
    assign WZeroE = weq0E;
  end 

  //////////////////////////
  // E/M Pipeline register
  //////////////////////////
 
  flopenr #(1) WZeroMReg(clk, reset, ~StallM, WZeroE, WZeroM);
  flopenr #(1) WeqZeroMReg(clk, reset, ~StallM, weq0E, weq0M);

  //////////////////////////
  // Memory Stage: Postprocessing
  //////////////////////////

  //  If the result is not exact, the sticky should be set
  assign DivSM = ~WZeroM & ~(SpecialCaseM & SqrtM); // ***unsure why SpecialCaseM has to be gated by SqrtM, but otherwise fails regression on divide

  // Determine if sticky bit is negative  // *** look for ways to optimize this.  Shift shouldn't be needed.
  assign Sum = WC + WS;
  assign NegStickyM = Sum[`DIVb+3];
  mux2 #(`DIVb+1) preqmmux(FirstU, FirstUM, NegStickyM, PreQmM); // Select U or U-1 depending on negative sticky bit
  mux2 #(`DIVb+1)    qmmux(PreQmM, (PreQmM << 1), SqrtM, QmM);

  // Integer quotient or remainder correctoin, normalization, and special cases
  if (`IDIV_ON_FPU) begin:intpostproc // Int supported
    logic [`DIVBLEN:0] NormShiftM;
    logic [`DIVb+3:0] UnsignedQuotM, NormRemM, NormRemDM, NormQuotM;
    logic signed [`DIVb+3:0] PreResultM, PreIntResultM;

    assign W = $signed(Sum) >>> `LOGR;
    assign DM = {4'b0001, D};
    assign UnsignedQuotM = {3'b000, PreQmM};

    // Integer remainder: sticky and sign correction muxes
    mux2 #(`DIVb+4) normremdmux(W, W+DM, NegStickyM, NormRemDM);
    mux2 #(`DIVb+4) normremsmux(NormRemDM, -NormRemDM, AsM, NormRemM);
    mux2 #(`DIVb+4) quotresmux(UnsignedQuotM, -UnsignedQuotM, NegQuotM, NormQuotM);

    // Select quotient or remainder and do normalization shift
    mux2 #(`DIVBLEN+1) normshiftmux(((`DIVBLEN+1)'(`DIVb) - (nM * (`DIVBLEN+1)'(`LOGR))), (mM + (`DIVBLEN+1)'(`DIVa)), RemOpM, NormShiftM);
    mux2 #(`DIVb+4)   presresultmux(NormQuotM, NormRemM, RemOpM, PreResultM);
    assign PreIntResultM = $signed(PreResultM >>> NormShiftM); 

    // special case logic
    // terminates immediately when B is Zero (div 0) or |A| has more leading 0s than |B|
    always_comb
      if (BZeroM) begin         // Divide by zero
        if (RemOpM) IntDivResultM = AM;  
        else        IntDivResultM = {(`XLEN){1'b1}};
     end else if (ALTBM) begin // Numerator is zero
        if (RemOpM) IntDivResultM = AM;
        else        IntDivResultM = '0;
     end else       IntDivResultM = PreIntResultM[`XLEN-1:0];

    // sign extend result for W64
    if (`XLEN==64) begin
      mux2 #(64) resmux(IntDivResultM[`XLEN-1:0], 
        {{(`XLEN-32){IntDivResultM[31]}}, IntDivResultM[31:0]}, // Sign extending in case of W64
        W64M, FPIntDivResultM);
    end else 
      assign FPIntDivResultM = IntDivResultM[`XLEN-1:0];
  end
endmodule