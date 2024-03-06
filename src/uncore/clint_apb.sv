///////////////////////////////////////////
// clint_apb.sv
//
// Written: David_Harris@hmc.edu 14 January 2021
// Modified: 
//
// Purpose: Core-Local Interruptor
//   See FE310-G002-Manual-v19p05 for specifications
// 
// Documentation: RISC-V System on Chip Design Chapter 15
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

module clint_apb import cvw::*;  #(parameter cvw_t P) (
  input  logic                PCLK, PRESETn,
  input  logic                PSEL,
  input  logic [15:0]         PADDR, 
  input  logic [P.XLEN-1:0]   PWDATA,
  input  logic [P.XLEN/8-1:0] PSTRB,
  input  logic                PWRITE,
  input  logic                PENABLE,
  output logic [P.XLEN-1:0]   PRDATA,
  output logic                PREADY,
  output logic [63:0] MTIME, 
  output logic                MTimerInt, MSwInt
);

  logic                       MSIP;
  logic [15:0]                entry;
  logic                       memwrite;
  logic [63:0] MTIMECMP;
  integer                     i, j;
  
  assign memwrite = PWRITE & PENABLE & PSEL;  // only write in access phase
  assign PREADY   = 1'b1;                     // CLINT never takes >1 cycle to respond

  // word aligned reads
  if (P.XLEN==64) assign #2 entry = {PADDR[15:3], 3'b000};
  else            assign #2 entry = {PADDR[15:2], 2'b00}; 
  
  // DH 2/20/21: Eventually allow MTIME to run off a separate clock
  // This will require synchronizing MTIME to the system clock
  // before it is read or compared to MTIMECMP.
  // It will also require synchronizing the write to MTIMECMP.
  // Use req and ack signals synchronized across the clock domains.

  // register access
  if (P.XLEN==64) begin:clint // 64-bit
    always @(posedge PCLK) begin
      case(entry)
        16'h0000: PRDATA <= {63'b0, MSIP};
        16'h4000: PRDATA <= MTIMECMP;
        16'hBFF8: PRDATA <= MTIME;
        default:  PRDATA <= 0;
      endcase
    end 
    always_ff @(posedge PCLK or negedge PRESETn) 
      if (~PRESETn) begin
        MSIP <= 0;
        MTIMECMP <= 64'hFFFFFFFFFFFFFFFF; // Spec says MTIMECMP is not reset, but we reset to maximum value to prevent spurious timer interrupts
      end else if (memwrite) begin
        if (entry == 16'h0000) MSIP <= PWDATA[0];
        if (entry == 16'h4000) begin
          for(i=0;i<P.XLEN/8;i++)
            if(PSTRB[i])
              MTIMECMP[i*8 +: 8] <= PWDATA[i*8 +: 8]; // ***dh: this notation isn't in book yet - maybe from Ross
        end
      end

// eventually replace MTIME logic below with timereg
//    timereg tr(PCLK, PRESETn, TIMECLK, memwrite & (entry==16'hBFF8), 1'b0, PWDATA, MTIME, done);

    always_ff @(posedge PCLK or negedge PRESETn) 
      if (~PRESETn) begin
        MTIME <= 0;
      end else if (memwrite & entry == 16'hBFF8) begin
        // MTIME Counter.  Eventually change this to run off separate clock.  Synchronization then needed
        for(j=0;j<P.XLEN/8;j++)
          if(PSTRB[j])
            MTIME[j*8 +: 8] <= PWDATA[j*8 +: 8];
      end else MTIME <= MTIME + 1; 
  end else begin:clint // 32-bit
    always @(posedge PCLK) begin
      case(entry)
        16'h0000: PRDATA <= {31'b0, MSIP};
        16'h4000: PRDATA <= MTIMECMP[31:0];
        16'h4004: PRDATA <= MTIMECMP[63:32];
        16'hBFF8: PRDATA <= MTIME[31:0];
        16'hBFFC: PRDATA <= MTIME[63:32];
        default:  PRDATA <= 0;
      endcase
    end 
    always_ff @(posedge PCLK or negedge PRESETn) 
      if (~PRESETn) begin
        MSIP <= 0;
        MTIMECMP <= 0;
        // MTIMECMP is not reset ***?
      end else if (memwrite) begin
        if (entry == 16'h0000) MSIP <= PWDATA[0];
        if (entry == 16'h4000) 
          for(j=0;j<P.XLEN/8;j++)
            if(PSTRB[j])
              MTIMECMP[j*8 +: 8] <= PWDATA[j*8 +: 8];
        if (entry == 16'h4004) 
          for(j=0;j<P.XLEN/8;j++)
            if(PSTRB[j])
              MTIMECMP[32 + j*8 +: 8] <= PWDATA[j*8 +: 8];
        // MTIME Counter.  Eventually change this to run off separate clock.  Synchronization then needed
      end

// eventually replace MTIME logic below with timereg
//     timereg tr(PCLK, PRESETn, TIMECLK, memwrite & (entry==16'hBFF8), memwrite & (entry == 16'hBFFC), PWDATA, MTIME, done);
    always_ff @(posedge PCLK or negedge PRESETn) 
      if (~PRESETn) begin
        MTIME <= 0;
        // MTIMECMP is not reset
      end else if (memwrite & (entry == 16'hBFF8)) begin
        for(i=0;i<P.XLEN/8;i++)
          if(PSTRB[i])
            MTIME[i*8 +: 8] <= PWDATA[i*8 +: 8];
      end else if (memwrite & (entry == 16'hBFFC)) begin
        // MTIME Counter.  Eventually change this to run off separate clock.  Synchronization then needed
        for(i=0;i<P.XLEN/8;i++)
          if(PSTRB[i])
            MTIME[32 + i*8 +: 8]<= PWDATA[i*8 +: 8];
      end else MTIME <= MTIME + 1;
  end 

  // Software interrupt when MSIP is set
  assign MSwInt = MSIP;
  // Timer interrupt when MTIME >= MTIMECMP
  assign MTimerInt = ({1'b0, MTIME} >= {1'b0, MTIMECMP}); // unsigned comparison

endmodule

