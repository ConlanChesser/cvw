///////////////////////////////////////////
// dcache (data cache) fsm
//
// Written: ross1728@gmail.com August 25, 2021
//          Implements the L1 data cache fsm
//
// Purpose: Controller for the dcache fsm
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

module cachefsm
  (input logic clk,
   input logic        reset,
   // inputs from IEU
   input logic [1:0]  RW,
   input logic [1:0]  Atomic,
   input logic        FlushCache,
   // hazard inputs
   input logic        CPUBusy,
   // interlock fsm
   input logic        IgnoreRequest,
   // Bus inputs
   input logic        CacheBusAck,
   // dcache internals
   input logic        CacheHit,
   input logic        VictimDirty,
   input logic        FlushAdrFlag,
   input logic        FlushWayFlag, 
  
   // hazard outputs
   output logic       CacheStall,
   // counter outputs
   output logic       CacheMiss,
   output logic       CacheAccess,
   // Bus outputs
   output logic       CacheCommitted,
   output logic       CacheWriteLine,
   output logic       CacheFetchLine,

   // dcache internals
   output logic [1:0] SelAdr,
   output logic       SetValid,
   output logic       ClearValid,
   output logic       SetDirty,
   output logic       ClearDirty,
   output logic       SRAMWordWriteEnable,
   output logic       SRAMLineWriteEnable,
   output logic       SelEvict,
   output logic       LRUWriteEn,
   output logic       SelFlush,
   output logic       FlushAdrCntEn,
   output logic       FlushWayCntEn, 
   output logic       FlushAdrCntRst,
   output logic       FlushWayCntRst,
   output logic       save,
   output logic       restore,
   output logic       VDWriteEnable

   );
  
  logic 			  AnyCPUReqM;
  logic [1:0]         PreSelAdr;
  logic               resetDelay;
  
  typedef enum 		  {STATE_READY,

					   STATE_MISS_FETCH_WDV,
					   STATE_MISS_FETCH_DONE,
					   STATE_MISS_EVICT_DIRTY,
					   STATE_MISS_WRITE_CACHE_LINE,
					   STATE_MISS_READ_WORD,
					   STATE_MISS_READ_WORD_DELAY,
					   STATE_MISS_WRITE_WORD,

					   STATE_CPU_BUSY, // *** Ross will change
					   STATE_CPU_BUSY_FINISH_AMO, // *** Ross will change
  
					   STATE_FLUSH,
					   STATE_FLUSH_CHECK,
					   STATE_FLUSH_INCR,
					   STATE_FLUSH_WRITE_BACK,
					   STATE_FLUSH_CLEAR_DIRTY} statetype;

  (* mark_debug = "true" *) statetype CurrState, NextState;

  assign AnyCPUReqM = |RW | (|Atomic);

  // outputs for the performance counters.
  assign CacheAccess = AnyCPUReqM & CurrState == STATE_READY;
  assign CacheMiss = CacheAccess &  ~CacheHit;

  // special case on reset. When the fsm first exists reset the
  // PCNextF will no longer be pointing to the correct address.
  // But PCF will be the reset vector.
  flop #(1) resetDelayReg(.clk, .d(reset), .q(resetDelay));
  assign SelAdr = resetDelay ? 2'b01 : PreSelAdr;

  always_ff @(posedge clk)
    if (reset)    CurrState <= #1 STATE_READY;
    else CurrState <= #1 NextState;  
  
  // next state logic and some state ouputs.
  // *** Ross simplify: factor out next state and output logic
  always_comb begin
    PreSelAdr = 2'b00;
    SetValid = 1'b0;
    ClearValid = 1'b0;
    SetDirty = 1'b0;    
    ClearDirty = 1'b0;
    SRAMWordWriteEnable = 1'b0;
    SRAMLineWriteEnable = 1'b0;
    SelEvict = 1'b0;
    LRUWriteEn = 1'b0;
    SelFlush = 1'b0;
    FlushAdrCntEn = 1'b0;
    FlushWayCntEn = 1'b0;
    FlushAdrCntRst = 1'b0;
    FlushWayCntRst = 1'b0;	
    VDWriteEnable = 1'b0;
    NextState = STATE_READY;
	CacheFetchLine = 1'b0;
	CacheWriteLine = 1'b0;
    save = 1'b0;
    restore = 1'b0;
    case (CurrState)
      STATE_READY: begin

		PreSelAdr = 2'b00;
		SRAMWordWriteEnable = 1'b0;
		SetDirty = 1'b0;
		LRUWriteEn = 1'b0;

		// TLB Miss	
		if(IgnoreRequest) begin
		  // the LSU arbiter has not yet selected the PTW.
		  // The CPU needs to be stalled until that happens.
		  // If we set CacheStall for 1 cycle before going to
		  // PTW ready the CPU will stall.
		  // The page table walker asserts it's control 1 cycle
		  // after the TLBs miss.
		  PreSelAdr = 2'b01;
		  NextState = STATE_READY;
		end

		// Flush dcache to next level of memory
		else if(FlushCache) begin
		  NextState = STATE_FLUSH;
		  FlushAdrCntRst = 1'b1;
		  FlushWayCntRst = 1'b1;	
		end
		
		// amo hit
		else if(Atomic[1] & (&RW) & CacheHit) begin
		  PreSelAdr = 2'b01;
		  
		  if(CPUBusy) begin 
			NextState = STATE_CPU_BUSY_FINISH_AMO;
			if (`REPLAY) PreSelAdr = 2'b01; 
            else save = 1'b1;
		  end
		  else begin
			SRAMWordWriteEnable = 1'b1;
			SetDirty = 1'b1;
			LRUWriteEn = 1'b1;
			NextState = STATE_READY;
		  end
		end
		// read hit valid cached
		else if(RW[1] & CacheHit) begin
		  LRUWriteEn = 1'b1;
		  
		  if(CPUBusy) begin
			NextState = STATE_CPU_BUSY;
            if(`REPLAY) PreSelAdr = 2'b01;
            else save = 1'b1;
		  end
		  else begin
			NextState = STATE_READY;
	      end
		end
		// write hit valid cached
		else if (RW[0] & CacheHit) begin
		  PreSelAdr = 2'b01;
		  SRAMWordWriteEnable = 1'b1;
		  SetDirty = 1'b1;
		  LRUWriteEn = 1'b1;
		  
		  if(CPUBusy) begin 
			NextState = STATE_CPU_BUSY;
			if(`REPLAY) PreSelAdr = 2'b01;
            else save = 1'b1;
		  end
		  else begin
			NextState = STATE_READY;
		  end
		end
		// read or write miss valid cached
		else if((|RW) & ~CacheHit) begin
		  NextState = STATE_MISS_FETCH_WDV;
		  CacheFetchLine = 1'b1;
		end
		else NextState = STATE_READY;
      end
      
      STATE_MISS_FETCH_WDV: begin
		PreSelAdr = 2'b01;
		
		if (CacheBusAck) begin
          NextState = STATE_MISS_FETCH_DONE;
        end else begin
          NextState = STATE_MISS_FETCH_WDV;
        end
      end

      STATE_MISS_FETCH_DONE: begin
		PreSelAdr = 2'b01;
		if(VictimDirty) begin
		  NextState = STATE_MISS_EVICT_DIRTY;
		  CacheWriteLine = 1'b1;
		end else begin
		  NextState = STATE_MISS_WRITE_CACHE_LINE;
		end
      end

      STATE_MISS_WRITE_CACHE_LINE: begin
		SRAMLineWriteEnable = 1'b1;
		NextState = STATE_MISS_READ_WORD;
		PreSelAdr = 2'b01;
		SetValid = 1'b1;
		ClearDirty = 1'b1;
		//LRUWriteEn = 1'b1;  // DO not update LRU on SRAM fetch update.  Wait for subsequent read/write
      end

      STATE_MISS_READ_WORD: begin
		PreSelAdr = 2'b01;
		if (RW[0] & ~Atomic[1]) begin // handles stores and amo write.
		  NextState = STATE_MISS_WRITE_WORD;
		end else begin
		  NextState = STATE_MISS_READ_WORD_DELAY;
		  // delay state is required as the read signal RW[1] is still high when we
		  // return to the ready state because the cache is stalling the cpu.
		end
      end

      STATE_MISS_READ_WORD_DELAY: begin
		SRAMWordWriteEnable = 1'b0;
		SetDirty = 1'b0;
		LRUWriteEn = 1'b0;
		if(&RW & Atomic[1]) begin // amo write
		  PreSelAdr = 2'b01;
		  if(CPUBusy) begin 
			NextState = STATE_CPU_BUSY_FINISH_AMO;
            if(~`REPLAY) save = 1'b1;
		  end
		  else begin
			SRAMWordWriteEnable = 1'b1;
			SetDirty = 1'b1;
			LRUWriteEn = 1'b1;
			NextState = STATE_READY;
		  end
		end else begin
		  LRUWriteEn = 1'b1;
		  if(CPUBusy) begin 
			NextState = STATE_CPU_BUSY;
			if(`REPLAY) PreSelAdr = 2'b01;
            else save = 1'b1;
		  end
		  else begin
			NextState = STATE_READY;
		  end
		end
      end

      STATE_MISS_WRITE_WORD: begin
		SRAMWordWriteEnable = 1'b1;
		SetDirty = 1'b1;
		PreSelAdr = 2'b01;
		LRUWriteEn = 1'b1;
		if(CPUBusy) begin 
		  NextState = STATE_CPU_BUSY;
		  if(`REPLAY) PreSelAdr = 2'b01;
          else save = 1'b1;
		end
		else begin
		  NextState = STATE_READY;
		end
      end

      STATE_MISS_EVICT_DIRTY: begin
		PreSelAdr = 2'b01;
		SelEvict = 1'b1;
		if(CacheBusAck) begin
		  NextState = STATE_MISS_WRITE_CACHE_LINE;
		end else begin
		  NextState = STATE_MISS_EVICT_DIRTY;
		end	  
      end


      STATE_CPU_BUSY: begin
		PreSelAdr = 2'b00;
        restore = 1'b1;      
		if(CPUBusy) begin
		  NextState = STATE_CPU_BUSY;
		  if(`REPLAY) PreSelAdr = 2'b01;
		end
		else begin
		  NextState = STATE_READY;
		end
      end

      STATE_CPU_BUSY_FINISH_AMO: begin
		PreSelAdr = 2'b01;
		SRAMWordWriteEnable = 1'b0;
		SetDirty = 1'b0;
		LRUWriteEn = 1'b0;
        restore = 1'b1;
		if(CPUBusy) begin
		  NextState = STATE_CPU_BUSY_FINISH_AMO;
		end
		else begin
		  SRAMWordWriteEnable = 1'b1;
		  SetDirty = 1'b1;
		  LRUWriteEn = 1'b1;
		  NextState = STATE_READY;
		end
      end

	  STATE_FLUSH: begin
		// intialize flush counters
		SelFlush = 1'b1;
		PreSelAdr = 2'b10;
		NextState = STATE_FLUSH_CHECK;
	  end		

      STATE_FLUSH_CHECK: begin
		PreSelAdr = 2'b10;
		SelFlush = 1'b1;
		if(VictimDirty) begin
		  NextState = STATE_FLUSH_WRITE_BACK;
		  FlushWayCntEn = 1'b0;
		  CacheWriteLine = 1'b1;
		end else if (FlushAdrFlag & FlushWayFlag) begin
		  NextState = STATE_READY;
		  PreSelAdr = 2'b00;
		  FlushWayCntEn = 1'b0;	
		end else if(FlushWayFlag) begin
		  NextState = STATE_FLUSH_INCR;
		  FlushAdrCntEn = 1'b1;
		  
		  FlushWayCntEn = 1'b1;
		end else begin
		  FlushWayCntEn = 1'b1;
		  NextState = STATE_FLUSH_CHECK;
		end
      end
	  
	  STATE_FLUSH_INCR: begin
		PreSelAdr = 2'b10;
		SelFlush = 1'b1;
		FlushWayCntRst = 1'b1;
		NextState = STATE_FLUSH_CHECK;
	  end

      STATE_FLUSH_WRITE_BACK: begin
		PreSelAdr = 2'b10;
		SelFlush = 1'b1;
		if(CacheBusAck) begin
		  NextState = STATE_FLUSH_CLEAR_DIRTY;
		end else begin
		  NextState = STATE_FLUSH_WRITE_BACK;
		end	  
      end

      STATE_FLUSH_CLEAR_DIRTY: begin
		ClearDirty = 1'b1;
		VDWriteEnable = 1'b1;
		SelFlush = 1'b1;
		PreSelAdr = 2'b10;
		FlushWayCntEn = 1'b0;
		if(FlushAdrFlag & FlushWayFlag) begin
		  NextState = STATE_READY;
		  PreSelAdr = 2'b00;
		end else if (FlushWayFlag) begin
		  NextState = STATE_FLUSH_INCR;
		  FlushAdrCntEn = 1'b1;
		  
		  FlushWayCntEn = 1'b1;	
		end else begin
		  NextState = STATE_FLUSH_CHECK;
		  FlushWayCntEn = 1'b1;	
		end
      end

      default: begin
		NextState = STATE_READY;
      end
    endcase
  end

  assign CacheCommitted = CurrState != STATE_READY;
  assign CacheStall = (CurrState == STATE_READY & (FlushCache | (|RW & ~CacheHit)) & ~IgnoreRequest) |

                      (CurrState == STATE_MISS_FETCH_WDV) |
                      (CurrState == STATE_MISS_FETCH_DONE) |
                      (CurrState == STATE_MISS_WRITE_CACHE_LINE) |
                      (CurrState == STATE_MISS_READ_WORD) |
                      (CurrState == STATE_MISS_EVICT_DIRTY) |
                      (CurrState == STATE_FLUSH) |
                      (CurrState == STATE_FLUSH_CHECK & ~(FlushAdrFlag & FlushWayFlag)) |
                      (CurrState == STATE_FLUSH_INCR) |
                      (CurrState == STATE_FLUSH_WRITE_BACK) |
                      (CurrState == STATE_FLUSH_CLEAR_DIRTY & ~(FlushAdrFlag & FlushWayFlag));


endmodule // cachefsm

