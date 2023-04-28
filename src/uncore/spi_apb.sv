///////////////////////////////////////////
// spi_apb.sv
//
// Written: nwhyteaguayo@g.hmc.edu 11/16/2022

//
// Purpose: SPI peripheral
//   See FU540-C000-v1.0 for specifications
// 
// A component of the Wally configurable RISC-V project.
// 
// Copyright (C) 2022 Harvey Mudd College & Oklahoma State University
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

// CREATE HARDWARE INTERLOCKS FOR MODE CHANGES / CONTROL REGISTER UPDATES
// scksc delay, intercs cs deassert


`include "wally-config.vh"

module spi_apb (
    input  logic             PCLK, PRESETn,
    input  logic             PSEL,
    input  logic [7:0]       PADDR,
    input  logic [`XLEN-1:0] PWDATA,
    input  logic [`XLEN/8-1:0] PSTRB,
    input  logic             PWRITE,
    input  logic             PENABLE,
    output logic             PREADY,
    output logic [`XLEN-1:0] PRDATA,
    output logic [3:0]          SPIOut,
    input  logic [3:0]          SPIIn,
    output logic [3:0]          SPICS,
    output logic                SPIIntr

    );

    //SPI registers

    logic [11:0] SckDiv;
    logic [1:0] SckMode;
    logic [1:0] ChipSelectID;
    logic [3:0] ChipSelectDef; 
    logic [1:0] ChipSelectMode;
    logic [15:0] Delay0, Delay1;
    logic [7:0] Format;
    logic [8:0] ReceiveData;
    logic [2:0] TransmitWatermark, ReceiveWatermark;
    logic [8:0] TransmitData;
    logic [1:0] InterruptEnable, InterruptPending;

    //bus interface signals
    logic [7:0] Entry;
    logic Memwrite;
    logic [31:0] Din, Dout;
    logic busy;

    //FIFO FSM signals
    logic TransmitWriteMark, TransmitReadMark, RecieveWriteMark, RecieveReadMark;
    logic TransmitFIFOWriteFull, TransmitFIFOReadEmpty;
    logic TransmitFIFOWriteIncrement, TransmitFIFOReadIncrement;
    logic ReceiveFIFOWriteIncrement, ReceiveFIFOReadIncrement;
    
    logic ReceiveFIFOWriteFull, ReceiveFIFOReadEmpty;
    logic [7:0] TransmitFIFOReadData, ReceiveFIFOWriteData;
    logic [2:0] TransmitWriteWatermarkLevel, ReceiveReadWatermarkLevel;

    logic TransmitFIFOReadEmptyDelay;
    logic [7:0] ReceiveShiftRegEndian;

    //transmission signals
    logic sck;
    logic [12:0] DivCounter;
    logic SCLKDuty;
    logic [8:0] Delay0Count;
    logic [8:0] Delay1Count;
    logic Delay0Compare;
    logic Delay1Compare;
    logic InterCSCompare;
    logic [8:0] InterCSCount;
    logic InterXFRCompare;
    logic [8:0] InterXFRCount;
    logic [3:0] ChipSelectInternal;
    logic [5:0] FrameCount;
    logic [5:0] FrameCompare;

    logic FrameCompareBoolean;
    logic [5:0] FrameCountShifted;
    logic [5:0] ReceivePenultimateFrame;
    logic [5:0] ReceivePenultimateFrameCount;
    logic ReceivePenultimateFrameBoolean;
    logic [5:0] FrameCompareProtocol;
    logic ReceiveShiftFull;
    logic TransmitShiftEmpty;
    logic HoldModeDeassert;


    //state fsm signals
    logic Active;
    logic Active0;
    logic Inactive;

    //shift reg signals
    logic TransmitFIFOWriteIncrementDelay;
    logic sckPhaseSelect;
    logic [7:0] TransmitShiftReg;
    logic [7:0] ReceiveShiftReg;
    logic SampleEdge;
    logic [7:0] TransmitDataEndian;
    logic TransmitShiftRegLoad;

    //CS signals
    logic [3:0] ChipSelectAuto, ChipSelectHold, CSoff;
    logic ChipSelectHoldSingle;


    assign Entry = {PADDR[7:2],2'b00};  // 32-bit word-aligned accesses
    assign Memwrite = PWRITE & PENABLE & PSEL;  // only write in access phase
    assign PREADY = 1'b1; // spi never takes >1 cycle to respond (float module)

    // account for subword read/write circuitry
    // -- Note GPIO registers are 32 bits no matter what; access them with LW SW.
    //    (At least that's what I think when FE310 spec says "only naturally aligned 32-bit accesses are supported")
    if (`XLEN == 64) begin
        assign Din =    Entry[2] ? PWDATA[63:32] : PWDATA[31:0];
        assign PRDATA = Entry[2] ? {Dout,32'b0}  : {32'b0,Dout};
    end else begin // 32-bit
        assign Din = PWDATA[31:0];
        assign PRDATA = Dout;
    end

    // register access
    //starting with single lane module no flash control
    always_ff@(posedge PCLK, negedge PRESETn)
        if (~PRESETn) begin 
            SckDiv <= #1 11'd3;
            SckMode <= #1 0;
            ChipSelectID <= #1 2'b0;
            ChipSelectDef <= #1 4'b1;
            ChipSelectMode <= #1 0;
            Delay0 <= #1 {8'b1,8'b1};
            Delay1 <= #1 {8'b0,8'b1};
            Format <= #1 {8'b10000000};
            TransmitData <= #1 8'b0;
            TransmitWatermark <= #1 0;
            ReceiveWatermark <= #1 0;
            InterruptEnable <= #1 0;
            InterruptPending <= #1 0;
        end else begin //writes
            //According to FU540 spec: Once interrupt is pending, it will remain set until number 
            //of entries in tx/rx fifo is strictly more/less than tx/rxmark

            //From spec. "Hardware interlocks ensure that the current transfer completes before mode transitions and control register updates take effect"
            // Interpreting 'current transfer' as one frame
            /* verilator lint_off CASEINCOMPLETE */
            if (Memwrite)
                case(Entry) //flop to sample inputs
                    8'h00: SckDiv <= Din[11:0];
                    8'h04: SckMode <= Din[1:0];
                    8'h10: ChipSelectID <= Din[1:0];
                    8'h14: ChipSelectDef <= Din[3:0];
                    8'h18: ChipSelectMode <= Din[1:0];
                    8'h28: Delay0 <= Din[15:0];
                    8'h2C: Delay1 <= Din[15:0];
                    8'h40: Format <= Din[7:0];
                    8'h48: if (~TransmitFIFOWriteFull) TransmitData <= Din[7:0];
                    8'h50: TransmitWatermark <= Din[2:0];
                    8'h54: ReceiveWatermark <= Din[2:0];
                    8'h70: InterruptEnable <= Din[1:0];
                endcase
            /* verilator lint_off CASEINCOMPLETE */
            //interrupt clearance
            InterruptPending[0] <= TransmitReadMark;
            InterruptPending[1] <= RecieveWriteMark;  
            case(Entry) // flop to sample inputs
                8'h00: Dout <= #1 SckDiv;
                8'h04: Dout <= #1 SckMode;
                8'h10: Dout <= #1 ChipSelectID;
                8'h14: Dout <= #1 ChipSelectDef;
                8'h18: Dout <= #1 ChipSelectMode;
                8'h28: Dout <= #1 Delay0;
                8'h2C: Dout <= #1 Delay1;
                8'h40: Dout <= #1 Format;
                8'h48: Dout <= #1 {TransmitFIFOWriteFull, 8'b0};
                8'h4C: if (~ReceiveData[8]) Dout <= #1 ReceiveData;
                8'h50: Dout <= #1 TransmitWatermark;
                8'h54: Dout <= #1 ReceiveWatermark;
                8'h70: Dout <= #1 InterruptEnable;
                8'h74: Dout <= #1 InterruptPending;
                default: Dout <= #1 0;
            endcase
        end

    //SCK_CONTROL
    

    always_comb
        case(Format[1:0])
            2'b00: FrameCountShifted = FrameCount;
            2'b01: FrameCountShifted = {FrameCount[4:0], 1'b0};
            2'b10: FrameCountShifted = {FrameCount[3:0], 2'b0};
            default: FrameCountShifted = FrameCount;
        endcase
    

    always_comb
        case(Format[1:0])
            2'b00: begin
                    ReceivePenultimateFrame = 6'b000001;
                    FrameCompareProtocol = FrameCompare;
                    end
            2'b01: begin
                    ReceivePenultimateFrame = 6'b000010;
                    FrameCompareProtocol = Format[4] ? FrameCompare + 6'b1 : FrameCompare;
                    end
            2'b10: begin 
                    ReceivePenultimateFrame = 6'b000100;
                    if (Format[7:4] > 4'b0100) FrameCompareProtocol = 6'b010000;
                    else FrameCompareProtocol = 6'b001000;
                    end
            default: begin
                    ReceivePenultimateFrame = 6'b000001;
                    FrameCompareProtocol = FrameCompare;
                    end

        endcase
    
    assign FrameCompareBoolean = (FrameCountShifted < FrameCompareProtocol);
    assign ReceivePenultimateFrameCount = FrameCountShifted + ReceivePenultimateFrame;
    assign ReceivePenultimateFrameBoolean = (ReceivePenultimateFrameCount >= FrameCompareProtocol);

    assign SCLKDuty = (DivCounter >= (SckDiv));
    assign Delay0Compare = SckMode[0] ? (Delay0Count >= ({Delay0[7:0], 1'b0})) : (Delay0Count == ({Delay0[7:0], 1'b0} + 9'b1));
    assign Delay1Compare = SckMode[0] ? (Delay1Count >= (({Delay0[15:8], 1'b0}) + 9'b1)) : (Delay1Count == ({Delay0[15:8], 1'b0}));
    assign InterCSCompare = (InterCSCount >= ({Delay1[7:0],1'b0}));
    assign InterXFRCompare = (InterXFRCount >= ({Delay1[15:8], 1'b0}));
    // double number of frames in dual or quad mode because we must wait for peripheral to send back
    assign FrameCompare = (Format[0] | Format[1]) ? ({1'b0,Format[7:4], 1'b0}) : {2'b0,Format[7:4]};

    typedef enum logic [2:0] {CS_INACTIVE, DELAY_0, ACTIVE_0, ACTIVE_1, DELAY_1,INTER_CS, INTER_XFR} statetype;
    statetype state;

    //producing signal high every (2*scc_div)+1) cycles
    always_ff @(posedge PCLK, negedge PRESETn)
        if (~PRESETn) DivCounter <= #1 0;
        else if (SCLKDuty) DivCounter <= 0;
        else DivCounter <= DivCounter + 13'b1;

    

    always_ff @(posedge SCLKDuty, negedge PRESETn)
        if (~PRESETn) begin state <= CS_INACTIVE;
                            FrameCount <= 6'b0;                      
        
        /* verilator lint_off CASEINCOMPLETE */
        end else case (state)
                CS_INACTIVE: begin
                        Delay0Count <= 9'b1;
                        Delay1Count <= 9'b10;
                        FrameCount <= 6'b0;
                        InterCSCount <= 9'b10;
                        InterXFRCount <= 9'b1;
                        if ((~TransmitFIFOReadEmpty | ~TransmitShiftEmpty) & ((|(Delay0[7:0])) | ~SckMode[0])) state <= DELAY_0;
                        else if ((~TransmitFIFOReadEmpty | ~TransmitShiftEmpty)) state <= ACTIVE_0;
                        end
                DELAY_0: begin
                        Delay0Count <= Delay0Count + 9'b1;
                        if (Delay0Compare) state <= ACTIVE_0;
                        end
                ACTIVE_0: begin 
                        FrameCount <= FrameCount + 6'b1;
                        state <= ACTIVE_1;
                        end
                ACTIVE_1: begin
                        InterXFRCount <= 9'b1;
                        if (FrameCompareBoolean) state <= ACTIVE_0;
                        else if (HoldModeDeassert) state <= CS_INACTIVE;
                        else if ((ChipSelectMode[1:0] == 2'b10) & ~|(Delay1[15:8]) & (~TransmitFIFOReadEmpty)) begin
                            state <= ACTIVE_0;
                            Delay0Count <= 9'b1;
                            Delay1Count <= 9'b10;
                            FrameCount <= 6'b0;
                            InterCSCount <= 9'b10;
                        end
                        else if (ChipSelectMode[1:0] == 2'b10) state <= INTER_XFR;
                        else if ((~|(Delay0[15:8])) & ~SckMode[0]) state <= INTER_CS;
                        else state <= DELAY_1;
                        end
                DELAY_1: begin
                        Delay1Count <= Delay1Count + 9'b1;
                        if (Delay1Compare) state <= INTER_CS;
                        end
                INTER_CS: begin
                        InterCSCount <= InterCSCount + 9'b1;
                        if (InterCSCompare ) state <= CS_INACTIVE;
                        end
                INTER_XFR: begin
                        Delay0Count <= 9'b1;
                        Delay1Count <= 9'b10;
                        FrameCount <= 6'b0;
                        InterCSCount <= 9'b10;
                        InterXFRCount <= InterXFRCount + 9'b1;
                        if (HoldModeDeassert) state <= CS_INACTIVE;
                        else if (InterXFRCompare & ~TransmitFIFOReadEmptyDelay) state <= ACTIVE_0;
                        else if (~|ChipSelectMode[1:0]) state <= CS_INACTIVE;
                        
                        end
            endcase
            /* verilator lint_off CASEINCOMPLETE */
    assign ChipSelectInternal = SckMode[0] ? ((state == CS_INACTIVE | state == INTER_CS) ? ChipSelectDef[3:0] : ~ChipSelectDef[3:0]) : ((state == CS_INACTIVE | state == INTER_CS | (state == ACTIVE_1 & ~|(Delay0[15:8]) & ReceiveShiftFull)) ? ChipSelectDef[3:0] : ~ChipSelectDef[3:0]);
    assign sck = (state == ACTIVE_0) ? ~SckMode[1] : SckMode[1];
    assign busy = (state == DELAY_0 | state == ACTIVE_0 | ((state == ACTIVE_1) & ~((|(Delay1[15:8]) & (ChipSelectMode[1:0]) == 2'b10) & ((FrameCount << Format[1:0]) >= FrameCompare))) | state == DELAY_1);
    assign Active = (state == ACTIVE_0 | state == ACTIVE_1);

    

    assign Active0 = (state == ACTIVE_0);
    assign Inactive = (state == CS_INACTIVE);
    
    always_ff @(posedge PCLK, negedge PRESETn, posedge Inactive)
        if (~PRESETn) HoldModeDeassert <= 0;
        else if (Inactive) HoldModeDeassert <= 0;
        else if (((ChipSelectMode[1:0] == 2'b10) & (Entry == (8'h18 | 8'h10) | ((Entry == 8'h14) & ((PWDATA[ChipSelectID]) != ChipSelectDef[ChipSelectID])))) & Memwrite) HoldModeDeassert <= 1;

    assign TransmitFIFOWriteIncrement = (Memwrite & (Entry == 8'h48) & ~TransmitFIFOWriteFull);
    always_ff @(posedge PCLK, negedge PRESETn)
        if (~PRESETn) TransmitFIFOWriteIncrementDelay <= 0;
        else TransmitFIFOWriteIncrementDelay <= TransmitFIFOWriteIncrement;
    assign TransmitFIFOReadIncrement = TransmitShiftEmpty;

    assign ReceiveFIFOWriteIncrement = ReceiveShiftFull;
    always_ff @(posedge PCLK, negedge PRESETn)
        if (~PRESETn) ReceiveFIFOReadIncrement <= 0;
        else if (~ReceiveFIFOReadIncrement)    ReceiveFIFOReadIncrement <= ((Entry == 8'h4C) & ~ReceiveData[8]);
        else            ReceiveFIFOReadIncrement <= 0;
    assign ReceiveData[8] = ReceiveFIFOReadEmpty;

    assign SampleEdge = SckMode[0] ? (state == ACTIVE_1) : (state == ACTIVE_0);
    assign TransmitDataEndian =  Format[2] ? {TransmitData[0], TransmitData[1], TransmitData[2], TransmitData[3], TransmitData[4], TransmitData[5], TransmitData[6], TransmitData[7]} : TransmitData[7:0];
    

    FIFO_async #(3,8) txFIFO(PCLK, SCLKDuty, PRESETn, TransmitFIFOWriteIncrementDelay, TransmitFIFOReadIncrement, TransmitDataEndian,TransmitWriteWatermarkLevel, TransmitWatermark[2:0], TransmitFIFOReadData[7:0], TransmitFIFOWriteFull, TransmitFIFOReadEmpty, TransmitWriteMark, TransmitReadMark);
    FIFO_async #(3,8) rxFIFO(SCLKDuty, PCLK, PRESETn, ReceiveFIFOWriteIncrement, ReceiveFIFOReadIncrement, ReceiveShiftRegEndian, ReceiveWatermark[2:0], ReceiveReadWatermarkLevel, ReceiveData[7:0], ReceiveFIFOWriteFull, ReceiveFIFOReadEmpty, RecieveWriteMark, RecieveReadMark);

    TransmitShiftFSM TransmitShiftFSM_1 (PCLK, PRESETn, TransmitFIFOReadEmpty, ReceivePenultimateFrameBoolean, Active0, TransmitShiftEmpty);
    ReceiveShiftFSM ReceiveShiftFSM_1 (SCLKDuty, PRESETn, ReceivePenultimateFrameBoolean, SampleEdge, SckMode[0], ReceiveShiftFull);

    always_ff @(posedge SCLKDuty, negedge PRESETn)
        if (~PRESETn) TransmitFIFOReadEmptyDelay <= 1;
        else TransmitFIFOReadEmptyDelay <= TransmitFIFOReadEmpty;
    
    always_comb
        case(SckMode[1:0])
            2'b00: sckPhaseSelect = ~sck;
            2'b01: sckPhaseSelect = (sck & |(FrameCount));
            2'b10: sckPhaseSelect = sck;
            2'b11: sckPhaseSelect = (~sck & |(FrameCount));
            default: sckPhaseSelect = sck;
        endcase
    


    
    assign TransmitShiftRegLoad = ~TransmitShiftEmpty & ~Active;
    always_ff @(posedge sckPhaseSelect, negedge PRESETn, posedge TransmitShiftRegLoad)
        if(~PRESETn) begin 
                TransmitShiftReg <= 8'b0;
            end
        else if (TransmitShiftRegLoad) TransmitShiftReg <= TransmitFIFOReadData;
        else begin
            if ((ChipSelectMode[1:0] == 2'b10) & ~|(Delay1[15:8]) & (~TransmitFIFOReadEmpty) & TransmitShiftEmpty) TransmitShiftReg <= TransmitFIFOReadData;
            else if (Active) begin
                case (Format[1:0])
                    2'b00: TransmitShiftReg <= {TransmitShiftReg[6:0], 1'b0};
                    2'b01: TransmitShiftReg <= {TransmitShiftReg[5:0], 2'b0};
                    2'b10: TransmitShiftReg <= {TransmitShiftReg[3:0], 4'b0};
                    default: TransmitShiftReg <= {TransmitShiftReg[6:0], 1'b0}; 
                endcase
            end
        end
    always_comb
    if (Active | Delay0Compare | ~TransmitShiftEmpty) begin
            case(Format[1:0])
                2'b00: SPIOut = {3'b0,TransmitShiftReg[7]}; 
                2'b01: SPIOut = {2'b0,TransmitShiftReg[6], TransmitShiftReg[7]};
                // assuming SPIOut[0] is first bit transmitted etc
                2'b10: SPIOut = {TransmitShiftReg[3], TransmitShiftReg[2], TransmitShiftReg[1], TransmitShiftReg[0]};
                default: SPIOut = {3'b0, TransmitShiftReg[7]};
            endcase
        end else SPIOut = 4'b0;
    always_ff @(posedge SampleEdge, negedge PRESETn)
        if(~PRESETn)  ReceiveShiftReg <= 8'b0;
        else if (~Active) ReceiveShiftReg <= 8'b0;
        else if (~Format[3]) begin
            if(`SPI_LOOPBACK_TEST) begin
                case(Format[1:0])
                    2'b00: ReceiveShiftReg <= { ReceiveShiftReg[6:0], SPIOut[0]};
                    2'b01: ReceiveShiftReg <= { ReceiveShiftReg[5:0], SPIOut[0],SPIOut[1]};
                    2'b10: ReceiveShiftReg <= { ReceiveShiftReg[3:0], SPIOut[0], SPIOut[1], SPIOut[2], SPIOut[3]};
                    default: ReceiveShiftReg <= { ReceiveShiftReg[6:0], SPIOut[0]};
                endcase

            end else begin
                case(Format[1:0])
                    2'b00: ReceiveShiftReg <= { ReceiveShiftReg[6:0], SPIIn[0]};
                    2'b01: ReceiveShiftReg <= { ReceiveShiftReg[5:0], SPIIn[0],SPIIn[1]};
                    2'b10: ReceiveShiftReg <= { ReceiveShiftReg[3:0], SPIIn[0], SPIIn[1], SPIIn[2], SPIIn[3]};
                    default: ReceiveShiftReg <= { ReceiveShiftReg[6:0], SPIIn[0]};
                endcase
            end
        end
    always_comb
        if (Format[2]) begin 
            case(Format[7:4])
                4'b0001: ReceiveShiftRegEndian = {7'b0, ReceiveShiftReg[0]};
                4'b0010: ReceiveShiftRegEndian = {6'b0, ReceiveShiftReg[1:0]};
                4'b0011: ReceiveShiftRegEndian = {5'b0, ReceiveShiftReg[2:0]};
                4'b0100: ReceiveShiftRegEndian = {4'b0, ReceiveShiftReg[3:0]};
                4'b0101: ReceiveShiftRegEndian = {3'b0, ReceiveShiftReg[4:0]};
                4'b0110: ReceiveShiftRegEndian = {2'b0, ReceiveShiftReg[5:0]};
                4'b0111: ReceiveShiftRegEndian = {1'b0, ReceiveShiftReg[6:0]};
                4'b1000: ReceiveShiftRegEndian = ReceiveShiftReg;
                default: ReceiveShiftRegEndian = ReceiveShiftReg;
            endcase
        end else begin
            case(Format[7:4])
                4'b0001: ReceiveShiftRegEndian = {ReceiveShiftReg[0], 7'b0};
                4'b0010: ReceiveShiftRegEndian = {ReceiveShiftReg[1:0], 6'b0};
                4'b0011: ReceiveShiftRegEndian = {ReceiveShiftReg[2:0], 5'b0};
                4'b0100: ReceiveShiftRegEndian = {ReceiveShiftReg[3:0], 4'b0};
                4'b0101: ReceiveShiftRegEndian = {ReceiveShiftReg[4:0], 3'b0};
                4'b0110: ReceiveShiftRegEndian = {ReceiveShiftReg[5:0], 2'b0};
                4'b0111: ReceiveShiftRegEndian = {ReceiveShiftReg[6:0], 1'b0};
                4'b1000: ReceiveShiftRegEndian = ReceiveShiftReg;
                default: ReceiveShiftRegEndian = ReceiveShiftReg;
            endcase
        end


    




                


    assign SPIIntr = ((InterruptPending[0] & InterruptEnable[0]) | (InterruptPending[1] & InterruptEnable[1]));
    
    always_comb
        case(ChipSelectID[1:0])
            2'b00: begin ChipSelectAuto = {ChipSelectDef[3], ChipSelectDef[2], ChipSelectDef[1], ChipSelectInternal[0]};
                         ChipSelectHold = {ChipSelectDef[3], ChipSelectDef[2], ChipSelectDef[1], ChipSelectHoldSingle};
                    end
            2'b01: begin ChipSelectAuto = {ChipSelectDef[3],ChipSelectDef[2], ChipSelectInternal[1], ChipSelectDef[0]};
                         ChipSelectHold = {ChipSelectDef[3],ChipSelectDef[2], ChipSelectHoldSingle, ChipSelectDef[0]};
                    end
            2'b10: begin ChipSelectAuto = {ChipSelectDef[3],ChipSelectInternal[2], ChipSelectDef[1], ChipSelectDef[0]};
                         ChipSelectHold = {ChipSelectDef[3], ChipSelectHoldSingle, ChipSelectDef[1], ChipSelectDef[0]};
                    end
            2'b11: begin ChipSelectAuto = {ChipSelectInternal[3],ChipSelectDef[2], ChipSelectDef[1], ChipSelectDef[0]};
                         ChipSelectHold = {ChipSelectHoldSingle, ChipSelectDef[2], ChipSelectDef[1], ChipSelectDef[0]};
                    end
        endcase
    
    assign ChipSelectHoldSingle = (state == CS_INACTIVE);
    assign SPICS = ChipSelectMode[0] ? 4'b1111 : ChipSelectAuto;


endmodule

module FIFO_async #(parameter M = 3, N = 8)(
    input logic wclk, rclk, PRESETn,
    input logic winc,rinc,
    input logic [N-1:0] wdata,
    input logic [M-1:0] wwatermarklevel, rwatermarklevel,
    output logic [N-1:0] rdata,
    output logic wfull, rempty,
    output logic wwatermark, rwatermark);

    logic [N-1:0] mem[2**M];
    logic [M:0] wq1_rptr, wq2_rptr, rptr;
    logic [M:0] rq1_wptr, rq2_wptr, wptr;
    logic [M:0] rbin, rgraynext, rbinnext;
    logic [M:0] wbin, wgraynext, wbinnext;
    logic rempty_val;
    logic wfull_val;
    logic [M:0]  wq2_rptr_bin, rq2_wptr_bin;
    logic [M-1:0] raddr;
    logic [M-1:0] waddr;

    assign rdata = mem[raddr];
    always_ff @(posedge wclk)
        if(winc & ~wfull) mem[waddr] <= wdata;

    always_ff @(posedge wclk, negedge PRESETn)
        if (~PRESETn) begin
            wq2_rptr <= 0;
            wq1_rptr <= 0;
        end
        else begin
            wq2_rptr <= wq1_rptr;
            wq1_rptr <= rptr;
        end
    
    always_ff @(posedge rclk, negedge PRESETn)
        if (~PRESETn) begin
            rq2_wptr <= 0;
            rq1_wptr <= 0;
        end
        else begin
            rq2_wptr <= rq1_wptr;
            rq1_wptr <= wptr;
        end

    always_ff @(posedge rclk, negedge PRESETn)
        if(~PRESETn) begin
            rbin <= 0;
            rptr <= 0;
        end
        else begin
            rbin <= rbinnext;
            rptr <= rgraynext;
        end
    assign rq2_wptr_bin = {rq2_wptr[3], (rq2_wptr[3]^rq2_wptr[2]),(rq2_wptr[3]^rq2_wptr[2]^rq2_wptr[1]), (rq2_wptr[3]^rq2_wptr[2]^rq2_wptr[1]^rq2_wptr[0]) };
    assign rwatermark = ((rbin[M-1:0] - rq2_wptr_bin[M-1:0]) < rwatermarklevel);
    assign raddr = rbin[M-1:0];
    assign rbinnext = rbin + {3'b0, (rinc & ~rempty)};
    assign rgraynext = (rbinnext >> 1) ^ rbinnext;
    assign rempty_val = (rgraynext == rq2_wptr);

    always_ff @(posedge rclk, negedge PRESETn)
        if (~PRESETn) rempty <= 1'b1;
        else          rempty <= rempty_val;
    
    always_ff @(posedge wclk, negedge PRESETn)
        if (~PRESETn) begin 
            wbin <= 0;
            wptr <= 0;
        end else begin               
            wbin <= wbinnext;
            wptr <= wgraynext;
        end
    assign waddr = wbin[M-1:0];
    assign wq2_rptr_bin = {wq2_rptr[3], (wq2_rptr[3]^wq2_rptr[2]),(wq2_rptr[3]^wq2_rptr[2]^wq2_rptr[1]), (wq2_rptr[3]^wq2_rptr[2]^wq2_rptr[1]^wq2_rptr[0]) };
    assign wwatermark = ((wbin[M-1:0] - wq2_rptr_bin[M-1:0]) > wwatermarklevel);
    assign wbinnext = wbin + {3'b0, (winc & ~wfull)};
    assign wgraynext = (wbinnext >> 1) ^ wbinnext;

    assign wfull_val = (wgraynext == {(~wq2_rptr[M:M-1]),wq2_rptr[M-2:0]});

    always_ff @(posedge wclk, negedge PRESETn)
        if (~PRESETn) wfull <= 1'b0;
        else          wfull <= wfull_val;
    
endmodule

module TransmitShiftFSM(
    input logic SCLKDuty, PRESETn,
    input logic TransmitFIFOReadEmpty, ReceivePenultimateFrameBoolean, Active0,
    output logic TransmitShiftEmpty);

    typedef enum logic [1:0] {TransmitShiftEmptyState, TransmitShiftHoldState, TransmitShiftNotEmptyState} statetype;
    statetype TransmitState, TransmitNextState;
    always_ff @(posedge SCLKDuty, negedge PRESETn)
        if (~PRESETn) TransmitState <= TransmitShiftEmptyState;
        else          TransmitState <= TransmitNextState;

        always_comb
            case(TransmitState)
                TransmitShiftEmptyState: begin
                    if (TransmitFIFOReadEmpty | (~TransmitFIFOReadEmpty & (ReceivePenultimateFrameBoolean & Active0))) TransmitNextState <= TransmitShiftEmptyState;
                    else if (~TransmitFIFOReadEmpty) TransmitNextState <= TransmitShiftNotEmptyState;
                end
                TransmitShiftNotEmptyState: begin
                    if (ReceivePenultimateFrameBoolean & Active0) TransmitNextState <= TransmitShiftEmptyState;
                    else TransmitNextState <= TransmitShiftNotEmptyState;
                end
            endcase
        assign TransmitShiftEmpty = (TransmitNextState == TransmitShiftEmptyState);
endmodule



module ReceiveShiftFSM(
    input logic SCLKDuty, PRESETn,
    input logic ReceivePenultimateFrameBoolean, SampleEdge, SckMode,
    output logic ReceiveShiftFull
);
    typedef enum logic [1:0] {ReceiveShiftFullState, ReceiveShiftNotFullState, ReceiveShiftDelayState} statetype;
    statetype ReceiveState, ReceiveNextState;
    always_ff @(posedge SCLKDuty, negedge PRESETn)
        if (~PRESETn) ReceiveState <= ReceiveShiftNotFullState;
        else          ReceiveState <= ReceiveNextState;
        
        always_comb
            case(ReceiveState)
                ReceiveShiftFullState: ReceiveNextState <= ReceiveShiftNotFullState;
                ReceiveShiftNotFullState: if (ReceivePenultimateFrameBoolean & (SampleEdge)) ReceiveNextState <= ReceiveShiftDelayState;
                                     else ReceiveNextState <= ReceiveShiftNotFullState;
                ReceiveShiftDelayState: ReceiveNextState <= ReceiveShiftFullState;
            endcase

        assign ReceiveShiftFull = SckMode ? (ReceiveState == ReceiveShiftFullState) : (ReceiveNextState == ReceiveShiftFullState);
endmodule


    
    



             
