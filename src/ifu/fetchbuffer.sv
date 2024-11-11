///////////////////////////////////////////
// fetchbuffer.sv
//
// Written: chickson@hmc.edu ; vkrishna@hmc.edu
// Created: 30 September 2024
// Modified: 3 October 2024
//
// Purpose: Store multiple instructions in a cyclic FIFO
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-24 Harvey Mudd College & Oklahoma State University
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

module fetchbuffer import cvw::*; #(parameter cvw_t P) (
	input  logic        clk, reset,
	input  logic        StallF, StallD, FlushD,
	input  logic [31:0] WriteData,
	output logic [31:0] ReadData,
	output logic        FetchBufferStallF
);
  localparam [31:0] nop = 32'h00000013;
  logic      [31:0] ReadReg [P.FETCHBUFFER_ENTRIES-1:0];
  logic      [31:0] ReadFetchBuffer;
  logic      [P.FETCHBUFFER_ENTRIES-1:0]  ReadPtr, WritePtr;
  logic             Empty, Full;

  assign Empty  = |(ReadPtr & WritePtr); // Bitwise and the read&write ptr, and or the bits of the result together
  assign Full   = |({WritePtr[P.FETCHBUFFER_ENTRIES-2:0], WritePtr[P.FETCHBUFFER_ENTRIES-1]} & ReadPtr); // Same as above but left rotate WritePtr to "add 1"
  assign FetchBufferStallF = Full;

  flopenl #(32) fbEntries[P.FETCHBUFFER_ENTRIES-1:0] (.clk, .load(reset | FlushD), .en(WritePtr), .d(WriteData), .val(nop), .q(ReadReg));

  // Fetch buffer entries anded with read ptr for AO Muxing
  logic [31:0] DaoArr [P.FETCHBUFFER_ENTRIES-1:0];

  for (genvar i = 0; i < P.FETCHBUFFER_ENTRIES; i++) begin
    assign DaoArr[i] = ReadPtr[i] ? ReadReg[i] : '0;
  end

  or_rows #(P.FETCHBUFFER_ENTRIES, 32) ReadFBAOMux(.a(DaoArr), .y(ReadFetchBuffer));

  assign ReadData = Empty ? nop : ReadFetchBuffer;

  always_ff @(posedge clk) begin : shiftRegister
    if (reset) begin
      WritePtr <= {{P.FETCHBUFFER_ENTRIES-1{1'b0}}, 1'b1};
      ReadPtr  <= {{P.FETCHBUFFER_ENTRIES-1{1'b0}}, 1'b1};
    end else begin
      WritePtr <= ~(Full | StallF) ? {WritePtr[P.FETCHBUFFER_ENTRIES-2:0], WritePtr[P.FETCHBUFFER_ENTRIES-1]} : WritePtr;
      ReadPtr <= ~(StallD | Empty) ? {ReadPtr[P.FETCHBUFFER_ENTRIES-2:0], ReadPtr[P.FETCHBUFFER_ENTRIES-1]} : ReadPtr;
    end
  end
endmodule
