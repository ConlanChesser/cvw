///////////////////////////////////////////
// spill.sv
//
// Written: Rose Thompson ross1728@gmail.com
// Created: 26 October 2023
// Modified: 26 October 2023
//
// Purpose: This module implements native alignment support for the Zicclsm extension
//          It is simlar to the IFU's spill module and probably could be merged together with 
//          some effort.
//
// Documentation: RISC-V System on Chip Design Chapter 11 (Figure 11.5)
// 
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
// 
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file 
// except in compliance with the License, or, at your option, the Apache License version 2.0. You 
// may obtain a copy of the License at
//
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the 
// License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, 
// either express or implied. See the License for the specific language governing permissions 
// and limitations under the License.
////////////////////////////////////////////////////////////////////////////////////////////////

module align import cvw::*;  #(parameter cvw_t P) (
  input logic                     clk, 
  input logic                     reset,
  input logic                     StallM, FlushM,
  input logic [P.XLEN-1:0]        IEUAdrM, // 2 byte aligned PC in Fetch stage
  input logic [P.XLEN-1:0]        IEUAdrE, // The next IEUAdrM
  input logic [2:0]               Funct3M, // Size of memory operation
  input logic                     FpLoadStoreM, // Floating point Load or Store 
  input logic [1:0]               MemRWM, 
  input logic [P.LLEN*2-1:0]      DCacheReadDataWordM, // Instruction from the IROM, I$, or bus. Used to check if the instruction if compressed
  input logic                     CacheBusHPWTStall, // I$ or bus are stalled. Transition to second fetch of spill after the first is fetched
  input logic                     SelHPTW,

  input logic [(P.LLEN-1)/8:0]    ByteMaskM,
  input logic [(P.LLEN-1)/8:0]    ByteMaskExtendedM,
  input logic [P.LLEN-1:0]        LSUWriteDataM, 

  output logic [(P.LLEN*2-1)/8:0] ByteMaskSpillM,

  output logic [P.XLEN-1:0]       IEUAdrSpillE, // The next PCF for one of the two memory addresses of the spill
  output logic [P.XLEN-1:0]       IEUAdrSpillM, // IEUAdrM for one of the two memory addresses of the spill
  output logic                    SelSpillE, // During the transition between the two spill operations, the IFU should stall the pipeline
  output logic [P.LLEN*2-1:0]     ReadDataWordSpillAllM,
  output logic                    SpillStallM);

  localparam LLENINBYTES = P.LLEN/8;
  localparam OFFSET_BIT_POS =  $clog2(P.DCACHE_LINELENINBITS/8);
  // Spill threshold occurs when all the cache offset PC bits are 1 (except [0]).  Without a cache this is just PCF[1]
  typedef enum logic [1:0]  {STATE_READY, STATE_SPILL, STATE_STORE_DELAY} statetype;

  statetype          CurrState, NextState;
  logic              ValidSpillM;
  logic              SelSpillM;
  logic              SpillSaveM;
  logic [P.LLEN-1:0] ReadDataWordFirstHalfM;
  logic              MisalignedM;

  logic [P.XLEN-1:0]   IEUAdrIncrementM;

  localparam OFFSET_LEN = $clog2(LLENINBYTES);
  logic [OFFSET_LEN-1:0] AccessByteOffsetM;
  logic                  PotentialSpillM;

  /* verilator lint_off WIDTHEXPAND */
  assign IEUAdrIncrementM = IEUAdrM + LLENINBYTES;
  /* verilator lint_on WIDTHEXPAND */
  mux2 #(P.XLEN) ieuadrspillemux(.d0(IEUAdrE), .d1(IEUAdrIncrementM), .s(SelSpillE), .y(IEUAdrSpillE));
  mux2 #(P.XLEN) ieuadrspillmmux(.d0(IEUAdrM), .d1(IEUAdrIncrementM), .s(SelSpillM), .y(IEUAdrSpillM));

  ////////////////////////////////////////////////////////////////////////////////////////////////////
  // Detect spill
  ////////////////////////////////////////////////////////////////////////////////////////////////////

  // spill detection in lsu is more complex than ifu, depends on 3 factors
  // 1) operation size
  // 2) offset
  // 3) access location within the cacheline
  
  // compute misalignement
  always_comb begin
    case (Funct3M & {FpLoadStoreM, 2'b11}) 
      3'b000: AccessByteOffsetM = '0; // byte access
      3'b001: AccessByteOffsetM = {{OFFSET_LEN-1{1'b0}}, IEUAdrM[0]}; // half access
      3'b010: AccessByteOffsetM = {{OFFSET_LEN-2{1'b0}}, IEUAdrM[1:0]}; // word access
      3'b011: AccessByteOffsetM = {{OFFSET_LEN-3{1'b0}}, IEUAdrM[2:0]}; // double access
      3'b100: if(P.LLEN == 128) AccessByteOffsetM = IEUAdrM[OFFSET_LEN-1:0]; // quad access
              else            AccessByteOffsetM = '0; // invalid
      default: AccessByteOffsetM = IEUAdrM[OFFSET_LEN-1:0];
    endcase
    case (Funct3M[1:0]) 
      2'b00: PotentialSpillM = '0; // byte access
      2'b01: PotentialSpillM = IEUAdrM[OFFSET_BIT_POS-1:1] == '1; // half access
      2'b10: PotentialSpillM = IEUAdrM[OFFSET_BIT_POS-1:2] == '1; // word access
      2'b11: PotentialSpillM = IEUAdrM[OFFSET_BIT_POS-1:3] == '1; // double access
      default: PotentialSpillM = '0;
    endcase
  end
  assign MisalignedM = (|MemRWM) & (AccessByteOffsetM != '0);
      
  assign ValidSpillM = MisalignedM & PotentialSpillM & ~CacheBusHPWTStall;   // Don't take the spill if there is a stall
  
  always_ff @(posedge clk)
    if (reset | FlushM)    CurrState <= #1 STATE_READY;
    else CurrState <= #1 NextState;

  always_comb begin
    case (CurrState)
      STATE_READY: if (ValidSpillM)  NextState = STATE_SPILL;       // load spill
                   else                           NextState = STATE_READY;       // no spill
      STATE_SPILL: if(StallM)                     NextState = STATE_SPILL;
                   else                           NextState = STATE_READY;
      default:                                    NextState = STATE_READY;
    endcase
  end

  assign SelSpillM = CurrState == STATE_SPILL;
  assign SelSpillE = (CurrState == STATE_READY & ValidSpillM) | (CurrState == STATE_SPILL & CacheBusHPWTStall);
  assign SpillSaveM = (CurrState == STATE_READY) & ValidSpillM & ~FlushM;
  assign SpillStallM = SelSpillE;

  ////////////////////////////////////////////////////////////////////////////////////////////////////
  // Merge spilled data
  ////////////////////////////////////////////////////////////////////////////////////////////////////

  // save the first native word
  flopenr #(P.LLEN) SpillDataReg(clk, reset, SpillSaveM, DCacheReadDataWordM[P.LLEN-1:0], ReadDataWordFirstHalfM);

  // merge together
  mux2 #(2*P.LLEN) postspillmux(DCacheReadDataWordM, {DCacheReadDataWordM[P.LLEN-1:0], ReadDataWordFirstHalfM}, SelSpillM, ReadDataWordSpillAllM);

  mux3 #(2*P.LLEN/8) bytemaskspillmux({ByteMaskExtendedM, ByteMaskM}, // no spill
                                      {{{P.LLEN/8}{1'b0}}, ByteMaskM}, // spill, first half
                                      {{{P.LLEN/8}{1'b0}}, ByteMaskExtendedM}, // spill, second half
                                      {SelSpillM, SelSpillE}, ByteMaskSpillM);

endmodule
