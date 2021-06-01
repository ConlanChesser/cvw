 ////////////////////////////////////////////////////////////////////////////////
// Block Name:	fmac.v
// Author:		David Harris
// Date:		11/2/1995
//
// Block Description:
//   This is the top level block of a floating-point  multiply/accumulate
//   unit(FMAC).   It instantiates the following sub-blocks:
//
//    array     Booth encoding, partial product generation, product summation
//    expgen    Mxponent summation, compare, and adjust
//    align     Alignment shifter
//    add       Carry-save adder for accumulate, carry propagate adder
//    lza       Leading zero anticipator to control normalization shifter
//    normalize Normalization shifter
//    round     Rounding of result
//    exception Handles exceptional cases
//    bypass    Handles bypass of result to FInput1M or FInput3M input logics
//    sign      One bit sign handling block 
//    special   Catch special cases (input logics = 0  / infinity /  etc.) 
//
//   The FMAC computes FmaResultM=FInput1M*FInput2M+FInput3M, rounded with the mode specified by
//   RN, RZ, RM, or RP.  The result is optionally bypassed back to
//   the FInput1M or FInput3M input logics for use on the next cycle.  In addition,  four signals
//   are produced: trap, overflow, underflow, and inexact.  Trap indicates
//   an infinity, NaN, or denormalized number to be handled in software;
//   the other three signals are IMMM flags.
//
/////////////////////////////////////////////////////////////////////////////

/////////////////////////////////////////////////////////////////////////////
module fma2(FInput1M, FInput2M, FInput3M, FrmM,
			FmaResultM, FmaFlagsM, aligncntM, rM, sM,
			tM,	normcntM, aeM, bsM,killprodM,
			xzeroM,	yzeroM,zzeroM,xdenormM,ydenormM,
			zdenormM,xinfM,yinfM,zinfM,xnanM,ynanM,znanM,
			nanM,sumshiftM,sumshiftzeroM,prodinfM

);
/////////////////////////////////////////////////////////////////////////////
 
	input logic 		[63:0]		FInput1M;		// input logic 1
	input logic		[63:0]		FInput2M;     // input logic 2 
	input logic 		[63:0]		FInput3M;     // input logic 3
	input logic 		[2:0]	 	FrmM;          	// Rounding mode
	input logic 		[12:0]		aligncntM;    	// status flags
	input logic 		[105:0]		rM; 				// one result of partial product sum
	input logic 		[105:0]		sM; 				// other result of partial products
	input logic 		[163:0]		tM;				// output of alignment shifter	
	input logic 		[8:0]		normcntM; 		// shift count for normalizer
	input logic 		[12:0]		aeM; 		// multiplier expoent
	input logic 					bsM;				// sticky bit of addend
	input logic 					killprodM; 		// FInput3M >> product
	input logic					prodinfM;
	input logic					xzeroM;
	input logic					yzeroM;
	input logic					zzeroM;
	input logic					xdenormM;
	input logic					ydenormM;
	input logic					zdenormM;
	input logic					xinfM;
	input logic					yinfM;
	input logic					zinfM;
	input logic					xnanM;
	input logic					ynanM;
	input logic					znanM;
	input logic					nanM;
	input logic			[8:0]		sumshiftM;
	input logic					sumshiftzeroM;


	output logic 		[63:0]		FmaResultM;     // output FmaResultM=FInput1M*FInput2M+FInput3M
	output logic 		[4:0]		FmaFlagsM;    	// status flags
	

// Internal nodes
 	logic 		[163:0]		sum;			// output of carry prop adder
	logic 		[53:0]		v; 				// normalized sum, R, S bits
//	logic 		[12:0]		aligncnt; 		// shift count for alignment
	logic 		[8:0]		normcnt; 		// shift count for normalizer
	logic 					negsum; 		// negate sum
	logic 					invz; 			// invert addend
	logic 					selsum1; 		// select +1 mode of sum
	logic 					negsum0; 		// sum +0 < 0
	logic 					negsum1; 		// sum +1 < 0
	logic 					sumzero; 		// sum = 0
	logic 					infinity; 		// generate infinity on overflow
	logic 					sumof;			// result out of range
	logic					zexpsel;
	logic					denorm0;
	logic					resultdenorm;
	logic					inf;
	logic					specialsel;
	logic					expplus1;
	logic					sumuf;
	logic					psign;
	logic					sticky;
	logic			[12:0]		de0;
	logic					isAdd;
	logic					wsign;
	logic 			[51:0]		wman;
	logic 			[10:0]		wexp;

	assign isAdd = 1;














//   Instantiate fraction datapath

	add				add(.*);
	lza				lza(.*);
	normalize		normalize(.zexp(FInput3M[62:52]),.*); 
	round			round(.xman(FInput1M[51:0]), .yman(FInput2M[51:0]),.zman(FInput3M[51:0]),.*);

// Instantiate exponent datapath

	expgen2			expgen2(.xexp(FInput1M[62:52]),.yexp(FInput2M[62:52]),.zexp(FInput3M[62:52]),.*);


// Instantiate control logic
 
sign				sign(.xsign(FInput1M[63]),.ysign(FInput2M[63]),.zsign(FInput3M[63]),.*); 
flag2				flag2(.xsign(FInput1M[63]),.ysign(FInput2M[63]),.zsign(FInput3M[63]),.vbits(v[1:0]),.*); 

assign FmaResultM = {wsign,wexp,wman};

endmodule

