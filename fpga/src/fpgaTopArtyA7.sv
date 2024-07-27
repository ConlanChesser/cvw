///////////////////////////////////////////
// fpgaTop.sv
//
// Written: ross1728@gmail.com November 17, 2021
// Modified: 
//
// Purpose: This is a top level for the fpga's implementation of wally.
//          Instantiates wallysoc, ddr4, abh lite to axi converters, pll, etc
// 
// A component of the Wally configurable RISC-V project.
// 
// Copyright (C) 2021 Harvey Mudd College & Oklahoma State University
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, 
// modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software 
// is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES 
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS 
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT 
// OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
///////////////////////////////////////////

`include "config.vh"

import cvw::*;

module fpgaTop #(parameter logic RVVI_SYNTH_SUPPORTED = 1)
  (input           default_100mhz_clk,
(* mark_debug = "true" *)   input           resetn,
   input           south_reset,

   input [3:0]     GPI,
   output [4:0]    GPO,

   input           UARTSin,
   output          UARTSout,

   inout [3:0]     SDCDat,
   output          SDCCLK,
   inout           SDCCmd,
   input           SDCCD,

 /*
     * Ethernet: 100BASE-T MII
     */
    output       phy_ref_clk,
    input        phy_rx_clk,
    input  [3:0] phy_rxd,
    input        phy_rx_dv,
    input        phy_rx_er,
    input        phy_tx_clk,
    output [3:0] phy_txd,
    output       phy_tx_en,
    input        phy_col, // nc
    input        phy_crs, // nc
    output       phy_reset_n,

   inout [15:0]    ddr3_dq,
   inout [1:0]     ddr3_dqs_n,
   inout [1:0]     ddr3_dqs_p,
   output [13:0]   ddr3_addr,
   output [2:0]    ddr3_ba,
   output          ddr3_ras_n,
   output          ddr3_cas_n,
   output          ddr3_we_n,
   output          ddr3_reset_n,
   output [0:0]    ddr3_ck_p,
   output [0:0]    ddr3_ck_n,
   output [0:0]    ddr3_cke,
   output [0:0]    ddr3_cs_n,
   output [1:0]    ddr3_dm,
   output [0:0]    ddr3_odt,
   // JTAG signals
   input           tck,
   input           tdi,
   input           tms,
   output          tdo
   );

  wire 			   CPUCLK;
  wire 			   c0_ddr4_ui_clk_sync_rst;
  wire 			   bus_struct_reset;
  wire 			   peripheral_reset;
  wire 			   interconnect_aresetn;
  wire 			   peripheral_aresetn;
  wire 			   mb_reset;
  
  wire 			   HCLKOpen;
  wire 			   HRESETnOpen;
  wire [63:0]      HRDATAEXT;
  wire 			   HREADYEXT;
  wire 			   HRESPEXT;
  wire             HSELEXTSDC; // TEMP BOOT SIGNAL - JACOB
  wire 			   HSELEXT;
  wire [55:0] 	   HADDR;
  wire [63:0]      HWDATA;
  wire [64/8-1:0]  HWSTRB;
  wire 			   HWRITE;
  wire [2:0] 	   HSIZE;
  wire [2:0] 	   HBURST;
  wire [1:0] 	   HTRANS;
  wire 			   HREADY;
  wire [3:0] 	   HPROT;
  wire 			   HMASTLOCK;

  wire [31:0] 	   GPIOIN, GPIOOUT, GPIOEN;

  wire 			   SDCCmdIn;
  wire 			   SDCCmdOE;
  wire 			   SDCCmdOut;

  wire [3:0] 	   m_axi_awid;
  wire [7:0] 	   m_axi_awlen;
  wire [2:0] 	   m_axi_awsize;
  wire [1:0] 	   m_axi_awburst;
  wire [3:0] 	   m_axi_awcache;
  wire [31:0] 	   m_axi_awaddr;
  wire [2:0] 	   m_axi_awprot;
  wire 		   m_axi_awvalid;
  wire 		   m_axi_awready;
  wire 		   m_axi_awlock;
  wire [63:0] 	   m_axi_wdata;
  wire [7:0] 	   m_axi_wstrb;
  wire 		   m_axi_wlast;
  wire 		   m_axi_wvalid;
  wire 		   m_axi_wready;
  wire [3:0] 	   m_axi_bid;
  wire [1:0] 	   m_axi_bresp;
  wire 		   m_axi_bvalid;
  wire 		   m_axi_bready;
  wire [3:0] 	   m_axi_arid;
  wire [7:0] 	   m_axi_arlen;
  wire [2:0] 	   m_axi_arsize;
  wire [1:0] 	   m_axi_arburst;
  wire [2:0] 	   m_axi_arprot;
  wire [3:0] 	   m_axi_arcache;
  wire 		   m_axi_arvalid;
  wire [31:0] 	   m_axi_araddr;
  wire 			   m_axi_arlock;
  wire 		   m_axi_arready;
  wire [3:0] 	   m_axi_rid;
  wire [63:0] 	   m_axi_rdata;
  wire [1:0] 	   m_axi_rresp;
  wire 		   m_axi_rvalid;
  wire 		   m_axi_rlast;
  wire 		   m_axi_rready;

  wire [3:0] 	   BUS_axi_arregion;
  wire [3:0] 	   BUS_axi_arqos;
  wire [3:0] 	   BUS_axi_awregion;
  wire [3:0] 	   BUS_axi_awqos;

  wire [3:0] 	   BUS_axi_awid;
  wire [7:0] 	   BUS_axi_awlen;
  wire [2:0] 	   BUS_axi_awsize;
  wire [1:0] 	   BUS_axi_awburst;
  wire [3:0] 	   BUS_axi_awcache;
  wire [31:0] 	   BUS_axi_awaddr;
  wire [2:0] 	   BUS_axi_awprot;
  wire 			   BUS_axi_awvalid;
  wire 			   BUS_axi_awready;
  wire 			   BUS_axi_awlock;
  wire [63:0] 	   BUS_axi_wdata;
  wire [7:0] 	   BUS_axi_wstrb;
  wire 			   BUS_axi_wlast;
  wire 			   BUS_axi_wvalid;
  wire 			   BUS_axi_wready;
  wire [3:0] 	   BUS_axi_bid;
  wire [1:0] 	   BUS_axi_bresp;
  wire 			   BUS_axi_bvalid;
  wire 			   BUS_axi_bready;
  wire [3:0] 	   BUS_axi_arid;
  wire [7:0] 	   BUS_axi_arlen;
  wire [2:0] 	   BUS_axi_arsize;
  wire [1:0] 	   BUS_axi_arburst;
  wire [2:0] 	   BUS_axi_arprot;
  wire [3:0] 	   BUS_axi_arcache;
  wire 			   BUS_axi_arvalid;
  wire [31:0] 	   BUS_axi_araddr;
  wire 			   BUS_axi_arlock;
  wire 			   BUS_axi_arready;
  wire [3:0] 	   BUS_axi_rid;
  wire [63:0] 	   BUS_axi_rdata;
  wire [1:0] 	   BUS_axi_rresp;
  wire 			   BUS_axi_rvalid;
  wire 			   BUS_axi_rlast;
  wire 			   BUS_axi_rready;
  
  wire 			   BUSCLK;
  wire             sdio_reset_open;
  
  // Crossbar to Bus ------------------------------------------------

  wire s00_axi_aclk;
  wire s00_axi_aresetn;
  wire [3:0] s00_axi_awid;
  wire [31:0]s00_axi_awaddr;
  wire [7:0]s00_axi_awlen;
  wire [2:0]s00_axi_awsize;
  wire [1:0]s00_axi_awburst;
  wire [0:0]s00_axi_awlock;
  wire [3:0]s00_axi_awcache;
  wire [2:0]s00_axi_awprot;
  wire [3:0]s00_axi_awregion;
  wire [3:0]s00_axi_awqos;
   wire s00_axi_awvalid;
   wire s00_axi_awready;
  wire [63:0]s00_axi_wdata;
  wire [7:0]s00_axi_wstrb;
  wire s00_axi_wlast;
  wire s00_axi_wvalid;
  wire s00_axi_wready;
  wire [1:0]s00_axi_bresp;
  wire s00_axi_bvalid;
  wire s00_axi_bready;
  wire [3:0]       s00_axi_arid;
  wire [31:0]s00_axi_araddr;
  wire [7:0]s00_axi_arlen;
  wire [2:0]s00_axi_arsize;
  wire [1:0]s00_axi_arburst;
  wire [0:0]s00_axi_arlock;
  wire [3:0]s00_axi_arcache;
  wire [2:0]s00_axi_arprot;
  wire [3:0]s00_axi_arregion;
  wire [3:0]s00_axi_arqos;
  wire s00_axi_arvalid;
  wire s00_axi_arready;
  wire [63:0]s00_axi_rdata;
  wire [1:0]s00_axi_rresp;
  wire s00_axi_rlast;
  wire s00_axi_rvalid;
  wire s00_axi_rready;

  wire [3:0] s00_axi_bid;
  wire [3:0] s00_axi_rid;
   
  // 64to32 dwidth converter input interface-------------------------
  wire s01_axi_aclk;
  wire s01_axi_aresetn;
  wire [3:0]s01_axi_awid;
  wire [31:0]s01_axi_awaddr;
  wire [7:0]s01_axi_awlen;
  wire [2:0]s01_axi_awsize;
  wire [1:0]s01_axi_awburst;
  wire [0:0]s01_axi_awlock;
  wire [3:0]s01_axi_awcache;
  wire [2:0]s01_axi_awprot;
  wire [3:0]s01_axi_awregion;
  wire [3:0]s01_axi_awqos; // qos signals need to be 0 for SDC
   wire s01_axi_awvalid;
   wire s01_axi_awready;
  wire [63:0]s01_axi_wdata;
  wire [7:0]s01_axi_wstrb;
  wire s01_axi_wlast;
  wire s01_axi_wvalid;
  wire s01_axi_wready;
  wire [1:0]s01_axi_bresp;
  wire s01_axi_bvalid;
  wire s01_axi_bready;
  wire [31:0]s01_axi_araddr;
  wire [7:0]s01_axi_arlen;
  wire [3:0] s01_axi_arid;
  wire [2:0]s01_axi_arsize;
  wire [1:0]s01_axi_arburst;
  wire [0:0]s01_axi_arlock;
  wire [3:0]s01_axi_arcache;
  wire [2:0]s01_axi_arprot;
  wire [3:0]s01_axi_arregion;
  wire [3:0]s01_axi_arqos; //
  wire s01_axi_arvalid;
  wire s01_axi_arready;
  wire [63:0]s01_axi_rdata;
  wire [1:0]s01_axi_rresp;
  wire s01_axi_rlast;
  wire s01_axi_rvalid;
  wire s01_axi_rready;

  // Output Interface
  wire [31:0]axi4in_axi_awaddr;
  wire [7:0]axi4in_axi_awlen;
  wire [2:0]axi4in_axi_awsize;
  wire [1:0]axi4in_axi_awburst;
  wire [0:0]axi4in_axi_awlock;
  wire [3:0]axi4in_axi_awcache;
  wire [2:0]axi4in_axi_awprot;
  wire [3:0]axi4in_axi_awregion;
  wire [3:0]axi4in_axi_awqos;
   wire axi4in_axi_awvalid;
   wire axi4in_axi_awready;
  wire [31:0]axi4in_axi_wdata;
  wire [3:0]axi4in_axi_wstrb;
  wire axi4in_axi_wlast;
  wire axi4in_axi_wvalid;
  wire axi4in_axi_wready;
  wire [1:0]axi4in_axi_bresp;
  wire axi4in_axi_bvalid;
  wire axi4in_axi_bready;
  wire [31:0]axi4in_axi_araddr;
  wire [7:0]axi4in_axi_arlen;
  wire [2:0]axi4in_axi_arsize;
  wire [1:0]axi4in_axi_arburst;
  wire [0:0]axi4in_axi_arlock;
  wire [3:0]axi4in_axi_arcache;
  wire [2:0]axi4in_axi_arprot;
  wire [3:0]axi4in_axi_arregion;
  wire [3:0]axi4in_axi_arqos;
  wire axi4in_axi_arvalid;
  wire axi4in_axi_arready;
  wire [31:0]axi4in_axi_rdata;
  wire [1:0]axi4in_axi_rresp;
  wire axi4in_axi_rlast;
  wire axi4in_axi_rvalid;
  wire axi4in_axi_rready;

  // AXI4 to AXI4-Lite Protocol converter output
   wire [31:0]SDCin_axi_awaddr;
   wire [2:0]SDCin_axi_awprot;
   wire SDCin_axi_awvalid;
   wire SDCin_axi_awready;
   wire [31:0]SDCin_axi_wdata;
   wire [3:0]SDCin_axi_wstrb;
   wire SDCin_axi_wvalid;
   wire SDCin_axi_wready;
   wire [1:0]SDCin_axi_bresp;
   wire SDCin_axi_bvalid;
   wire SDCin_axi_bready;
   wire [31:0]SDCin_axi_araddr;
   wire [2:0]SDCin_axi_arprot;
   wire SDCin_axi_arvalid;
   wire SDCin_axi_arready;
   wire [31:0]SDCin_axi_rdata;
   wire [1:0]SDCin_axi_rresp;
   wire SDCin_axi_rvalid;
   wire SDCin_axi_rready;
  // ----------------------------------------------------------------

  // 32to64 dwidth converter input interface -----------------------
   wire [31:0]SDCout_axi_awaddr;
   wire [7:0]SDCout_axi_awlen;
  wire [2:0]SDCout_axi_awsize;
  wire [1:0]SDCout_axi_awburst;
  wire [0:0]SDCout_axi_awlock;
  wire [3:0]SDCout_axi_awcache;
  wire [2:0]SDCout_axi_awprot;
  wire [3:0]SDCout_axi_awregion;
  wire [3:0]SDCout_axi_awqos;
   wire SDCout_axi_awvalid;
   wire SDCout_axi_awready;
   wire [31:0]SDCout_axi_wdata;
  wire [3:0]SDCout_axi_wstrb;
   wire SDCout_axi_wlast;
   wire SDCout_axi_wvalid;
  wire SDCout_axi_wready;
   wire [1:0]SDCout_axi_bresp;
   wire SDCout_axi_bvalid;
   wire SDCout_axi_bready;
  wire [31:0]SDCout_axi_araddr;
  wire [7:0]SDCout_axi_arlen;
  wire [2:0]SDCout_axi_arsize;
  wire [1:0]SDCout_axi_arburst;
  wire [0:0]SDCout_axi_arlock;
  wire [3:0]SDCout_axi_arcache;
  wire [2:0]SDCout_axi_arprot;
  wire [3:0]SDCout_axi_arregion;
  wire [3:0]SDCout_axi_arqos;
  wire SDCout_axi_arvalid;
  wire SDCout_axi_arready;
  wire [31:0]SDCout_axi_rdata;
  wire [1:0]SDCout_axi_rresp;
  wire SDCout_axi_rlast;
  wire SDCout_axi_rvalid;
  wire SDCout_axi_rready;

  // Output Interface
   wire [3:0]m01_axi_awid;
    wire [31:0]m01_axi_awaddr;
    wire [7:0]m01_axi_awlen;
    wire [2:0]m01_axi_awsize;
    wire [1:0]m01_axi_awburst;
    wire [0:0]m01_axi_awlock;
    wire [3:0]m01_axi_awcache;
    wire [2:0]m01_axi_awprot;
    wire [3:0]m01_axi_awregion;
    wire [3:0]m01_axi_awqos;
   wire m01_axi_awvalid;
   wire m01_axi_awready;
    wire [63:0]m01_axi_wdata;
    wire [7:0]m01_axi_wstrb;
    wire m01_axi_wlast;
    wire m01_axi_wvalid;
    wire m01_axi_wready;
    wire [3:0] m01_axi_bid;
    wire [1:0]m01_axi_bresp;
    wire m01_axi_bvalid;
    wire m01_axi_bready;
    wire [3:0] m01_axi_arid;
    wire [31:0]m01_axi_araddr;
    wire [7:0]m01_axi_arlen;
    wire [2:0]m01_axi_arsize;
    wire [1:0]m01_axi_arburst;
    wire [0:0]m01_axi_arlock;
    wire [3:0]m01_axi_arcache;
    wire [2:0]m01_axi_arprot;
    wire [3:0]m01_axi_arregion;
    wire [3:0]m01_axi_arqos;
    wire m01_axi_arvalid;
    wire m01_axi_arready;
    wire [3:0] m01_axi_rid;
    wire [63:0]m01_axi_rdata;
    wire [1:0]m01_axi_rresp;
    wire m01_axi_rlast;
    wire m01_axi_rvalid;
   wire m01_axi_rready;

  // Old SDC input
  // wire [3:0] SDCDatIn;

  // New SDC Command IOBUF connections
  wire       sd_cmd_i;
  wire        sd_cmd_reg_o;
  wire        sd_cmd_reg_t;

  // SD Card Interrupt signal
   wire        SDCIntr;

  // New SDC Data IOBUF connections
  wire [3:0] sd_dat_i;
  wire  [3:0] sd_dat_reg_o;
  wire        sd_dat_reg_t;
  

    wire 			   c0_init_calib_complete;
  wire 			   dbg_clk;
  wire [511 : 0]   dbg_bus;
     wire             ui_clk_sync_rst;
  
  wire 			   CLK208;
  wire             clk167;
  wire             clk200;

  wire             app_sr_active;
  wire             app_ref_ack;
  wire             app_zq_ack;
    wire             mmcm_locked;
  wire [11:0]      device_temp;
    wire             mmcm1_locked;

(* mark_debug = "true" *)  logic              RVVIStall;

  assign GPIOIN = {28'b0, GPI};
  assign GPO = GPIOOUT[4:0];
  assign ahblite_resetn = peripheral_aresetn;
  assign cpu_reset = bus_struct_reset;
  assign calib = c0_init_calib_complete;

  // mmcm

  // the ddr3 mig7 requires 2 input clocks 
  // 1. sys clock which is 167 MHz = ddr3 clock / 4
  // 2. a second clock which is 200 MHz
  // Wally requires a slower clock.  At this point I don't know what speed the atrix 7 will run so I'm initially targetting 25Mhz.
  // the mig will output a clock at 1/4 the sys clock or 41Mhz which might work with wally so we may be able to simplify the logic a lot.
  xlnx_mmcm xln_mmcm(.clk_out1(clk167),
                     .clk_out2(clk200),
                     .clk_out3(CPUCLK),
                     .clk_out4(phy_ref_clk),
                     .reset(1'b0),
                     .locked(mmcm1_locked),
                     .clk_in1(default_100mhz_clk));
  
/* -----\/----- EXCLUDED -----\/-----
  // SD Card Tristate
  IOBUF iobufSDCMD(.T(~SDCCmdOE), // iobuf's T is active low
				   .I(SDCCmdOut),
				   .O(SDCCmdIn),
				   .IO(SDCCmd));
 -----/\----- EXCLUDED -----/\----- */

   // IOBUFS for new SDC peripheral
   IOBUF IOBUF_cmd (.O(sd_cmd_i), .IO(SDCCmd), .I(sd_cmd_reg_o), .T(sd_cmd_reg_t));
   genvar    i;
   generate
      for (i = 0; i < 4; i = i + 1) begin
         IOBUF iobufSDCDat(.T(sd_dat_reg_t),
                           .I(sd_dat_reg_o[i]),
                           .O(sd_dat_i[i]),
                           .IO(SDCDat[i]) );
      end
   endgenerate
  

  // reset controller XILINX IP
  xlnx_proc_sys_reset xlnx_proc_sys_reset_0
    (.slowest_sync_clk(CPUCLK),
     .ext_reset_in(1'b0),
     .aux_reset_in(south_reset),
     .mb_debug_sys_rst(1'b0),
     .dcm_locked(c0_init_calib_complete),
     .mb_reset(mb_reset),  //open
     .bus_struct_reset(bus_struct_reset),
     .peripheral_reset(peripheral_reset), //open
     .interconnect_aresetn(interconnect_aresetn), //open
     .peripheral_aresetn(peripheral_aresetn));

  // wally
  // RT and JP: FIXME add sdc interrupt and HSELEXTSDC, remove old sdc after the new sdc ahb version is implemented

  `include "parameter-defs.vh"

  wallypipelinedsoc  #(P) 
  wallypipelinedsoc(.clk(CPUCLK), .reset_ext(bus_struct_reset), .reset(), .tck, .tdi, .tms, .tdo,
                    .HRDATAEXT, .HREADYEXT, .HRESPEXT, .HSELEXT,
                    .HSELEXTSDC, .HCLK(HCLKOpen), .HRESETn(HRESETnOpen), 
                    .HADDR, .HWDATA, .HWSTRB, .HWRITE, .HSIZE, .HBURST, .HPROT,
                    .HTRANS, .HMASTLOCK, .HREADY, .TIMECLK(1'b0), 
                    .GPIOIN, .GPIOOUT, .GPIOEN,
                    .UARTSin, .UARTSout, .SDCIntr, .ExternalStall(RVVIStall)); 


  // ahb lite to axi bridge
  xlnx_ahblite_axi_bridge xlnx_ahblite_axi_bridge_0
    (.s_ahb_hclk(CPUCLK),
     .s_ahb_hresetn(peripheral_aresetn),
     .s_ahb_hsel(HSELEXT | HSELEXTSDC),
     .s_ahb_haddr(HADDR[31:0]),
     .s_ahb_hprot(HPROT),
     .s_ahb_htrans(HTRANS),
     .s_ahb_hsize(HSIZE),
     .s_ahb_hwrite(HWRITE),
     .s_ahb_hburst(HBURST),
     .s_ahb_hwdata(HWDATA),
     .s_ahb_hready_out(HREADYEXT),
     .s_ahb_hready_in(HREADY),
     .s_ahb_hrdata(HRDATAEXT),
     .s_ahb_hresp(HRESPEXT),
     .m_axi_awid(m_axi_awid),
     .m_axi_awlen(m_axi_awlen),
     .m_axi_awsize(m_axi_awsize),
     .m_axi_awburst(m_axi_awburst),
     .m_axi_awcache(m_axi_awcache),
     .m_axi_awaddr(m_axi_awaddr),
     .m_axi_awprot(m_axi_awprot),
     .m_axi_awvalid(m_axi_awvalid),
     .m_axi_awready(m_axi_awready),
     .m_axi_awlock(m_axi_awlock),
     .m_axi_wdata(m_axi_wdata),
     .m_axi_wstrb(m_axi_wstrb),
     .m_axi_wlast(m_axi_wlast),
     .m_axi_wvalid(m_axi_wvalid),
     .m_axi_wready(m_axi_wready),
     .m_axi_bid(m_axi_bid),
     .m_axi_bresp(m_axi_bresp),
     .m_axi_bvalid(m_axi_bvalid),
     .m_axi_bready(m_axi_bready),
     .m_axi_arid(m_axi_arid),
     .m_axi_arlen(m_axi_arlen),
     .m_axi_arsize(m_axi_arsize),
     .m_axi_arburst(m_axi_arburst),
     .m_axi_arprot(m_axi_arprot),
     .m_axi_arcache(m_axi_arcache),
     .m_axi_arvalid(m_axi_arvalid),
     .m_axi_araddr(m_axi_araddr),
     .m_axi_arlock(m_axi_arlock),
     .m_axi_arready(m_axi_arready),
     .m_axi_rid(m_axi_rid),
     .m_axi_rdata(m_axi_rdata),
     .m_axi_rresp(m_axi_rresp),
     .m_axi_rvalid(m_axi_rvalid),
     .m_axi_rlast(m_axi_rlast),
     .m_axi_rready(m_axi_rready));

  // AXI Crossbar for arbitrating the SDC and CPU --------------
  xlnx_axi_crossbar xlnx_axi_crossbar_0
   	(.aclk(CPUCLK),
	 .aresetn(peripheral_aresetn),

	 // Connect Masters
	 .s_axi_awid({4'b1000, m_axi_awid}),
	 .s_axi_awaddr({m01_axi_awaddr, m_axi_awaddr}),
	 .s_axi_awlen({m01_axi_awlen, m_axi_awlen}),
	 .s_axi_awsize({m01_axi_awsize, m_axi_awsize}),
	 .s_axi_awburst({m01_axi_awburst, m_axi_awburst}),
	 .s_axi_awlock({m01_axi_awlock, m_axi_awlock}),
	 .s_axi_awcache({m01_axi_awcache, m_axi_awcache}),
	 .s_axi_awprot({m01_axi_awprot, m_axi_awprot}),
	 .s_axi_awqos(8'b0),
	 .s_axi_awvalid({m01_axi_awvalid, m_axi_awvalid}),
	 .s_axi_awready({m01_axi_awready, m_axi_awready}),
	 .s_axi_wdata({m01_axi_wdata, m_axi_wdata}),
	 .s_axi_wstrb({m01_axi_wstrb, m_axi_wstrb}),
	 .s_axi_wlast({m01_axi_wlast, m_axi_wlast}),
	 .s_axi_wvalid({m01_axi_wvalid, m_axi_wvalid}),
	 .s_axi_wready({m01_axi_wready, m_axi_wready}),
	 .s_axi_bid({m01_axi_bid, m_axi_bid}),
	 .s_axi_bresp({m01_axi_bresp, m_axi_bresp}),
	 .s_axi_bvalid({m01_axi_bvalid, m_axi_bvalid}),
	 .s_axi_bready({m01_axi_bready, m_axi_bready}),
	 .s_axi_arid({4'b1000, m_axi_arid}),
	 .s_axi_araddr({m01_axi_araddr, m_axi_araddr}),
	 .s_axi_arlen({m01_axi_arlen, m_axi_arlen}),
	 .s_axi_arsize({m01_axi_arsize, m_axi_arsize}),
	 .s_axi_arburst({m01_axi_arburst, m_axi_arburst}),
	 .s_axi_arlock({m01_axi_arlock, m_axi_arlock}),
	 .s_axi_arcache({m01_axi_arcache, m_axi_arcache}),
	 .s_axi_arprot({m01_axi_arprot, m_axi_arprot}),
	 .s_axi_arqos(8'b0),
	 .s_axi_arvalid({m01_axi_arvalid, m_axi_arvalid}),
	 .s_axi_arready({m01_axi_arready, m_axi_arready}),
	 .s_axi_rid({m01_axi_rid, m_axi_rid}),
	 .s_axi_rdata({m01_axi_rdata, m_axi_rdata}),
	 .s_axi_rresp({m01_axi_rresp, m_axi_rresp}),
	 .s_axi_rlast({m01_axi_rlast, m_axi_rlast}),
	 .s_axi_rvalid({m01_axi_rvalid, m_axi_rvalid}),
	 .s_axi_rready({m01_axi_rready, m_axi_rready}),
	 
	 // Connect Slaves
     .m_axi_awid({s01_axi_awid, s00_axi_awid}),
     .m_axi_awlen({s01_axi_awlen, s00_axi_awlen}),
     .m_axi_awsize({s01_axi_awsize, s00_axi_awsize}),
     .m_axi_awburst({s01_axi_awburst, s00_axi_awburst}),
     .m_axi_awcache({s01_axi_awcache, s00_axi_awcache}),
     .m_axi_awaddr({s01_axi_awaddr, s00_axi_awaddr}),
     .m_axi_awprot({s01_axi_awprot, s00_axi_awprot}),
     .m_axi_awregion({s01_axi_awregion, s00_axi_awregion}),
     .m_axi_awqos({s01_axi_awqos, s00_axi_awqos}),
     .m_axi_awvalid({s01_axi_awvalid, s00_axi_awvalid}),
     .m_axi_awready({s01_axi_awready, s00_axi_awready}),
     .m_axi_awlock({s01_axi_awlock, s00_axi_awlock}),
     .m_axi_wdata({s01_axi_wdata, s00_axi_wdata}),
     .m_axi_wstrb({s01_axi_wstrb, s00_axi_wstrb}),
     .m_axi_wlast({s01_axi_wlast, s00_axi_wlast}),
     .m_axi_wvalid({s01_axi_wvalid, s00_axi_wvalid}),
     .m_axi_wready({s01_axi_wready, s00_axi_wready}),
     .m_axi_bid({4'b1000, s00_axi_bid}),
     .m_axi_bresp({s01_axi_bresp, s00_axi_bresp}),
     .m_axi_bvalid({s01_axi_bvalid, s00_axi_bvalid}),
     .m_axi_bready({s01_axi_bready, s00_axi_bready}),
     .m_axi_arid({s01_axi_arid, s00_axi_arid}),
     .m_axi_arlen({s01_axi_arlen, s00_axi_arlen}),
     .m_axi_arsize({s01_axi_arsize, s00_axi_arsize}),
     .m_axi_arburst({s01_axi_arburst, s00_axi_arburst}),
     .m_axi_arprot({s01_axi_arprot, s00_axi_arprot}),
     .m_axi_arregion({s01_axi_arregion, s00_axi_arregion}),
     .m_axi_arqos({s01_axi_arqos, s00_axi_arqos}),
     .m_axi_arcache({s01_axi_arcache, s00_axi_arcache}),
     .m_axi_arvalid({s01_axi_arvalid, s00_axi_arvalid}),
     .m_axi_araddr({s01_axi_araddr, s00_axi_araddr}),
     .m_axi_arlock({s01_axi_arlock, s00_axi_arlock}),
     .m_axi_arready({s01_axi_arready, s00_axi_arready}),
     .m_axi_rid({4'b1000, s00_axi_rid}),
     .m_axi_rdata({s01_axi_rdata, s00_axi_rdata}),
     .m_axi_rresp({s01_axi_rresp, s00_axi_rresp}),
     .m_axi_rvalid({s01_axi_rvalid, s00_axi_rvalid}),
     .m_axi_rlast({s01_axi_rlast, s00_axi_rlast}),
     .m_axi_rready({s01_axi_rready, s00_axi_rready})
	 );
   
   // -----------------------------------------------------

   // SDC Implementation ----------------------------------
   //
   // The SDC peripheral from Eugene Tarassov takes in an AXI4Lite
   // interface and outputs an AXI4 interface. In order to convert from
   // one to the other, we use these dwidth converters to make sure the
   // bit widths match the rest of the bus.
   
   xlnx_axi_dwidth_conv_64to32 axi_conv_down
	(.s_axi_aclk(CPUCLK),
	 .s_axi_aresetn(peripheral_aresetn),

	 // Slave interface
	 .s_axi_awaddr(s01_axi_awaddr),
	 .s_axi_awlen(s01_axi_awlen),
	 .s_axi_awsize(s01_axi_awsize),
	 .s_axi_awburst(s01_axi_awburst),
	 .s_axi_awlock(s01_axi_awlock),
	 .s_axi_awcache(s01_axi_awcache),
	 .s_axi_awprot(s01_axi_awprot),
	 .s_axi_awregion(s01_axi_awregion),
	 .s_axi_awqos(4'b0),
	 .s_axi_awvalid(s01_axi_awvalid),
	 .s_axi_awready(s01_axi_awready),
	 .s_axi_wdata(s01_axi_wdata),
	 .s_axi_wstrb(s01_axi_wstrb),
	 .s_axi_wlast(s01_axi_wlast),
	 .s_axi_wvalid(s01_axi_wvalid),
	 .s_axi_wready(s01_axi_wready),
	 .s_axi_bresp(s01_axi_bresp),
	 .s_axi_bvalid(s01_axi_bvalid),
	 .s_axi_bready(s01_axi_bready),
	 .s_axi_araddr(s01_axi_araddr),
	 .s_axi_arlen(s01_axi_arlen),
	 .s_axi_arsize(s01_axi_arsize),
	 .s_axi_arburst(s01_axi_arburst),
	 .s_axi_arlock(s01_axi_arlock),
	 .s_axi_arcache(s01_axi_arcache),
	 .s_axi_arprot(s01_axi_arprot),
	 .s_axi_arregion(s01_axi_arregion),
	 .s_axi_arqos(4'b0),
	 .s_axi_arvalid(s01_axi_arvalid),
	 .s_axi_arready(s01_axi_arready),
	 .s_axi_rdata(s01_axi_rdata),
	 .s_axi_rresp(s01_axi_rresp),
	 .s_axi_rlast(s01_axi_rlast),
	 .s_axi_rvalid(s01_axi_rvalid),
	 .s_axi_rready(s01_axi_rready),

	 // Master interface
	 .m_axi_awaddr(axi4in_axi_awaddr),
	 .m_axi_awlen(axi4in_axi_awlen),
	 .m_axi_awsize(axi4in_axi_awsize),
	 .m_axi_awburst(axi4in_axi_awburst),
	 .m_axi_awlock(axi4in_axi_awlock),
	 .m_axi_awcache(axi4in_axi_awcache),
	 .m_axi_awprot(axi4in_axi_awprot),
	 .m_axi_awregion(axi4in_axi_awregion),
	 .m_axi_awqos(axi4in_axi_awqos),
	 .m_axi_awvalid(axi4in_axi_awvalid),
	 .m_axi_awready(axi4in_axi_awready),
	 .m_axi_wdata(axi4in_axi_wdata),
	 .m_axi_wstrb(axi4in_axi_wstrb),
	 .m_axi_wlast(axi4in_axi_wlast),
	 .m_axi_wvalid(axi4in_axi_wvalid),
	 .m_axi_wready(axi4in_axi_wready),
	 .m_axi_bresp(axi4in_axi_bresp),
	 .m_axi_bvalid(axi4in_axi_bvalid),
	 .m_axi_bready(axi4in_axi_bready),
	 .m_axi_araddr(axi4in_axi_araddr),
	 .m_axi_arlen(axi4in_axi_arlen),
	 .m_axi_arsize(axi4in_axi_arsize),
	 .m_axi_arburst(axi4in_axi_arburst),
	 .m_axi_arlock(axi4in_axi_arlock),
	 .m_axi_arcache(axi4in_axi_arcache),
	 .m_axi_arprot(axi4in_axi_arprot),
	 .m_axi_arregion(axi4in_axi_arregion),
	 .m_axi_arqos(axi4in_axi_arqos),
	 .m_axi_arvalid(axi4in_axi_arvalid),
	 .m_axi_arready(axi4in_axi_arready),
	 .m_axi_rdata(axi4in_axi_rdata),
	 .m_axi_rresp(axi4in_axi_rresp),
	 .m_axi_rlast(axi4in_axi_rlast),
	 .m_axi_rvalid(axi4in_axi_rvalid),
	 .m_axi_rready(axi4in_axi_rready)
	 );
   
  xlnx_axi_prtcl_conv axi4tolite
    (.aclk(CPUCLK),
     .aresetn(peripheral_aresetn),

     // AXI4 In
     .s_axi_awaddr(axi4in_axi_awaddr),
     .s_axi_awlen(axi4in_axi_awlen),
     .s_axi_awsize(axi4in_axi_awsize),
     .s_axi_awburst(axi4in_axi_awburst),
     .s_axi_awlock(axi4in_axi_awlock),
     .s_axi_awcache(axi4in_axi_awcache),
     .s_axi_awprot(axi4in_axi_awprot),
     .s_axi_awregion(axi4in_axi_awregion),
     .s_axi_awqos(axi4in_axi_awqos),
     .s_axi_awvalid(axi4in_axi_awvalid),
     .s_axi_awready(axi4in_axi_awready),
     .s_axi_wdata(axi4in_axi_wdata),
     .s_axi_wstrb(axi4in_axi_wstrb),
     .s_axi_wlast(axi4in_axi_wlast),
     .s_axi_wvalid(axi4in_axi_wvalid),
     .s_axi_wready(axi4in_axi_wready),
     .s_axi_bresp(axi4in_axi_bresp),
     .s_axi_bvalid(axi4in_axi_bvalid),
     .s_axi_bready(axi4in_axi_bready),
     .s_axi_araddr(axi4in_axi_araddr),
     .s_axi_arlen(axi4in_axi_arlen),
     .s_axi_arsize(axi4in_axi_arsize),
     .s_axi_arburst(axi4in_axi_arburst),
     .s_axi_arlock(axi4in_axi_arlock),
     .s_axi_arcache(axi4in_axi_arcache),
     .s_axi_arprot(axi4in_axi_arprot),
     .s_axi_arregion(axi4in_axi_arregion),
     .s_axi_arqos(axi4in_axi_arqos),
     .s_axi_arvalid(axi4in_axi_arvalid),
     .s_axi_arready(axi4in_axi_arready),
     .s_axi_rdata(axi4in_axi_rdata),
     .s_axi_rresp(axi4in_axi_rresp),
     .s_axi_rlast(axi4in_axi_rlast),
     .s_axi_rvalid(axi4in_axi_rvalid),
     .s_axi_rready(axi4in_axi_rready),

     // AXI4Lite Out
     .m_axi_awaddr(SDCin_axi_awaddr),
     .m_axi_awprot(SDCin_axi_awprot),
     .m_axi_awvalid(SDCin_axi_awvalid),
     .m_axi_awready(SDCin_axi_awready),
     .m_axi_wdata(SDCin_axi_wdata),
     .m_axi_wstrb(SDCin_axi_wstrb),
     .m_axi_wvalid(SDCin_axi_wvalid),
     .m_axi_wready(SDCin_axi_wready),
     .m_axi_bresp(SDCin_axi_bresp),
     .m_axi_bvalid(SDCin_axi_bvalid),
     .m_axi_bready(SDCin_axi_bready),
     .m_axi_araddr(SDCin_axi_araddr),
     .m_axi_arprot(SDCin_axi_arprot),
     .m_axi_arvalid(SDCin_axi_arvalid),
     .m_axi_arready(SDCin_axi_arready),
     .m_axi_rdata(SDCin_axi_rdata),
     .m_axi_rresp(SDCin_axi_rresp),
     .m_axi_rvalid(SDCin_axi_rvalid),
     .m_axi_rready(SDCin_axi_rready)
     
     );
   

  sdc_controller axiSDC
	(.clock(CPUCLK),
	 .async_resetn(peripheral_aresetn),
	 
	 // Slave Interface
	 .s_axi_awaddr({8'b0, SDCin_axi_awaddr[7:0]}),
	 .s_axi_awvalid(SDCin_axi_awvalid),
	 .s_axi_awready(SDCin_axi_awready),
	 .s_axi_wdata(SDCin_axi_wdata),
	 .s_axi_wvalid(SDCin_axi_wvalid),
	 .s_axi_wready(SDCin_axi_wready),
	 .s_axi_bresp(SDCin_axi_bresp),
	 .s_axi_bvalid(SDCin_axi_bvalid),
	 .s_axi_bready(SDCin_axi_bready),
	 .s_axi_araddr({8'b0, SDCin_axi_araddr[7:0]}),
	 .s_axi_arvalid(SDCin_axi_arvalid),
	 .s_axi_arready(SDCin_axi_arready),
	 .s_axi_rdata(SDCin_axi_rdata),
	 .s_axi_rresp(SDCin_axi_rresp),
	 .s_axi_rvalid(SDCin_axi_rvalid),
	 .s_axi_rready(SDCin_axi_rready),
     .sdio_reset(sdio_reset_open),
	 
	 // Master Interface
	 .m_axi_awaddr(SDCout_axi_awaddr),
	 .m_axi_awlen(SDCout_axi_awlen),
	 .m_axi_awvalid(SDCout_axi_awvalid),
	 .m_axi_awready(SDCout_axi_awready),
	 .m_axi_wdata(SDCout_axi_wdata),
	 .m_axi_wlast(SDCout_axi_wlast),
	 .m_axi_wvalid(SDCout_axi_wvalid),
	 .m_axi_wready(SDCout_axi_wready),
	 .m_axi_bresp(SDCout_axi_bresp),
	 .m_axi_bvalid(SDCout_axi_bvalid),
	 .m_axi_bready(SDCout_axi_bready),
	 .m_axi_araddr(SDCout_axi_araddr),
	 .m_axi_arlen(SDCout_axi_arlen),
	 .m_axi_arvalid(SDCout_axi_arvalid),
	 .m_axi_arready(SDCout_axi_arready),
	 .m_axi_rdata(SDCout_axi_rdata),
	 .m_axi_rlast(SDCout_axi_rlast),
	 .m_axi_rresp(SDCout_axi_rresp),
	 .m_axi_rvalid(SDCout_axi_rvalid),
	 .m_axi_rready(SDCout_axi_rready),

	 // SDC interface
	 //.sdio_cmd(1'b0),
	 //.sdio_dat(4'b0),
	 //.sdio_cd(1'b0)

     .sd_dat_reg_t(sd_dat_reg_t),
     .sd_dat_reg_o(sd_dat_reg_o),
     .sd_dat_i(sd_dat_i),
     
     .sd_cmd_reg_t(sd_cmd_reg_t),
     .sd_cmd_reg_o(sd_cmd_reg_o),
     .sd_cmd_i(sd_cmd_i),

     .sdio_clk(SDCCLK),
     .sdio_cd(SDCCD),

     .interrupt(SDCIntr)
	 );

  xlnx_axi_dwidth_conv_32to64 axi_conv_up
	(.s_axi_aclk(CPUCLK),
	 .s_axi_aresetn(peripheral_aresetn),
	 
	 // Slave interface
	 .s_axi_awaddr(SDCout_axi_awaddr),
	 .s_axi_awlen(SDCout_axi_awlen),
	 .s_axi_awsize(3'b010),
	 .s_axi_awburst(2'b01),
	 .s_axi_awlock(1'b0),
	 .s_axi_awcache(4'b0),
	 .s_axi_awprot(3'b0),
	 .s_axi_awregion(4'b0),
	 .s_axi_awqos(4'b0),
	 .s_axi_awvalid(SDCout_axi_awvalid),
	 .s_axi_awready(SDCout_axi_awready),
	 .s_axi_wdata(SDCout_axi_wdata),
	 .s_axi_wstrb(8'b11111111),
	 .s_axi_wlast(SDCout_axi_wlast),
	 .s_axi_wvalid(SDCout_axi_wvalid),
	 .s_axi_wready(SDCout_axi_wready),
	 .s_axi_bresp(SDCout_axi_bresp),
	 .s_axi_bvalid(SDCout_axi_bvalid),
	 .s_axi_bready(SDCout_axi_bready),
	 .s_axi_araddr(SDCout_axi_araddr),
	 .s_axi_arlen(SDCout_axi_arlen),
	 .s_axi_arsize(3'b010),
	 .s_axi_arburst(2'b01),
	 .s_axi_arlock(1'b0),
	 .s_axi_arcache(4'b0),
	 .s_axi_arprot(3'b0),
	 .s_axi_arregion(4'b0),
	 .s_axi_arqos(4'b0),
	 .s_axi_arvalid(SDCout_axi_arvalid),
	 .s_axi_arready(SDCout_axi_arready),
	 .s_axi_rdata(SDCout_axi_rdata),
	 .s_axi_rresp(SDCout_axi_rresp),
	 .s_axi_rlast(SDCout_axi_rlast),
	 .s_axi_rvalid(SDCout_axi_rvalid),
	 .s_axi_rready(SDCout_axi_rready),

	 // Master interface
	 .m_axi_awaddr(m01_axi_awaddr),
	 .m_axi_awlen(m01_axi_awlen),
	 .m_axi_awsize(m01_axi_awsize),
	 .m_axi_awburst(m01_axi_awburst),
	 .m_axi_awlock(m01_axi_awlock),
	 .m_axi_awcache(m01_axi_awcache),
	 .m_axi_awprot(m01_axi_awprot),
	 .m_axi_awregion(m01_axi_awregion),
	 .m_axi_awqos(m01_axi_awqos),
	 .m_axi_awvalid(m01_axi_awvalid),
	 .m_axi_awready(m01_axi_awready),
	 .m_axi_wdata(m01_axi_wdata),
	 .m_axi_wstrb(m01_axi_wstrb),
	 .m_axi_wlast(m01_axi_wlast),
	 .m_axi_wvalid(m01_axi_wvalid),
	 .m_axi_wready(m01_axi_wready),
	 .m_axi_bresp(m01_axi_bresp),
	 .m_axi_bvalid(m01_axi_bvalid),
	 .m_axi_bready(m01_axi_bready),
	 .m_axi_araddr(m01_axi_araddr),
	 .m_axi_arlen(m01_axi_arlen),
	 .m_axi_arsize(m01_axi_arsize),
	 .m_axi_arburst(m01_axi_arburst),
	 .m_axi_arlock(m01_axi_arlock),
	 .m_axi_arcache(m01_axi_arcache),
	 .m_axi_arprot(m01_axi_arprot),
	 .m_axi_arregion(m01_axi_arregion),
	 .m_axi_arqos(m01_axi_arqos),
	 .m_axi_arvalid(m01_axi_arvalid),
	 .m_axi_arready(m01_axi_arready),
	 .m_axi_rdata(m01_axi_rdata),
	 .m_axi_rresp(m01_axi_rresp),
	 .m_axi_rlast(m01_axi_rlast),
	 .m_axi_rvalid(m01_axi_rvalid),
	 .m_axi_rready(m01_axi_rready)
	 );

  // End SDC signals --------------------------------------------
   
  xlnx_axi_clock_converter xlnx_axi_clock_converter_0
    (.s_axi_aclk(CPUCLK),
     .s_axi_aresetn(peripheral_aresetn),
     .s_axi_awid(s00_axi_awid),
     .s_axi_awlen(s00_axi_awlen),
     .s_axi_awsize(s00_axi_awsize),
     .s_axi_awburst(s00_axi_awburst),
     .s_axi_awcache(s00_axi_awcache),
     .s_axi_awaddr(s00_axi_awaddr[30:0] ),
     .s_axi_awprot(s00_axi_awprot),
     .s_axi_awregion(4'b0), // this could be a bug. bridge does not have these outputs
     .s_axi_awqos(4'b0),    // this could be a bug. bridge does not have these outputs
     .s_axi_awvalid(s00_axi_awvalid),
     .s_axi_awready(s00_axi_awready),
     .s_axi_awlock(s00_axi_awlock),
     .s_axi_wdata(s00_axi_wdata),
     .s_axi_wstrb(s00_axi_wstrb),
     .s_axi_wlast(s00_axi_wlast),
     .s_axi_wvalid(s00_axi_wvalid),
     .s_axi_wready(s00_axi_wready),
     .s_axi_bid(s00_axi_bid),
     .s_axi_bresp(s00_axi_bresp),
     .s_axi_bvalid(s00_axi_bvalid),
     .s_axi_bready(s00_axi_bready),
     .s_axi_arid(s00_axi_arid),
     .s_axi_arlen(s00_axi_arlen),
     .s_axi_arsize(s00_axi_arsize),
     .s_axi_arburst(s00_axi_arburst),
     .s_axi_arprot(s00_axi_arprot),
     .s_axi_arregion(4'b0), // this could be a bug. bridge does not have these outputs
     .s_axi_arqos(4'b0),    // this could be a bug. bridge does not have these outputs
     .s_axi_arcache(s00_axi_arcache),
     .s_axi_arvalid(s00_axi_arvalid),
     .s_axi_araddr(s00_axi_araddr[30:0]),
     .s_axi_arlock(s00_axi_arlock),
     .s_axi_arready(s00_axi_arready),
     .s_axi_rid(s00_axi_rid),
     .s_axi_rdata(s00_axi_rdata),
     .s_axi_rresp(s00_axi_rresp),
     .s_axi_rvalid(s00_axi_rvalid),
     .s_axi_rlast(s00_axi_rlast),
     .s_axi_rready(s00_axi_rready),

     .m_axi_aclk(BUSCLK),
     .m_axi_aresetn(resetn),
     .m_axi_awid(BUS_axi_awid),
     .m_axi_awlen(BUS_axi_awlen),
     .m_axi_awsize(BUS_axi_awsize),
     .m_axi_awburst(BUS_axi_awburst),
     .m_axi_awcache(BUS_axi_awcache),
     .m_axi_awaddr(BUS_axi_awaddr),
     .m_axi_awprot(BUS_axi_awprot),
     .m_axi_awregion(BUS_axi_awregion),
     .m_axi_awqos(BUS_axi_awqos),
     .m_axi_awvalid(BUS_axi_awvalid),
     .m_axi_awready(BUS_axi_awready),
     .m_axi_awlock(BUS_axi_awlock),
     .m_axi_wdata(BUS_axi_wdata),
     .m_axi_wstrb(BUS_axi_wstrb),
     .m_axi_wlast(BUS_axi_wlast),
     .m_axi_wvalid(BUS_axi_wvalid),
     .m_axi_wready(BUS_axi_wready),
     .m_axi_bid(BUS_axi_bid),
     .m_axi_bresp(BUS_axi_bresp),
     .m_axi_bvalid(BUS_axi_bvalid),
     .m_axi_bready(BUS_axi_bready),
     .m_axi_arid(BUS_axi_arid),
     .m_axi_arlen(BUS_axi_arlen),
     .m_axi_arsize(BUS_axi_arsize),
     .m_axi_arburst(BUS_axi_arburst),
     .m_axi_arprot(BUS_axi_arprot),
     .m_axi_arregion(BUS_axi_arregion),
     .m_axi_arqos(BUS_axi_arqos),
     .m_axi_arcache(BUS_axi_arcache),
     .m_axi_arvalid(BUS_axi_arvalid),
     .m_axi_araddr(BUS_axi_araddr),
     .m_axi_arlock(BUS_axi_arlock),
     .m_axi_arready(BUS_axi_arready),
     .m_axi_rid(BUS_axi_rid),
     .m_axi_rdata(BUS_axi_rdata),
     .m_axi_rresp(BUS_axi_rresp),
     .m_axi_rvalid(BUS_axi_rvalid),
     .m_axi_rlast(BUS_axi_rlast),
     .m_axi_rready(BUS_axi_rready));

  xlnx_ddr3 xlnx_ddr3_c0
    (
     // ddr3 I/O
     .ddr3_dq(ddr3_dq),
     .ddr3_dqs_n(ddr3_dqs_n),
     .ddr3_dqs_p(ddr3_dqs_p),
     .ddr3_addr(ddr3_addr),
     .ddr3_ba(ddr3_ba),
     .ddr3_ras_n(ddr3_ras_n),
     .ddr3_cas_n(ddr3_cas_n),
     .ddr3_we_n(ddr3_we_n),
     .ddr3_reset_n(ddr3_reset_n),
     .ddr3_ck_p(ddr3_ck_p),
     .ddr3_ck_n(ddr3_ck_n),
     .ddr3_cke(ddr3_cke),
     .ddr3_cs_n(ddr3_cs_n),
     .ddr3_dm(ddr3_dm),
     .ddr3_odt(ddr3_odt),

     .sys_clk_i(clk167),
     .clk_ref_i(clk200),

     .ui_clk(BUSCLK),
     .ui_clk_sync_rst(ui_clk_sync_rst),
     .aresetn(resetn),
     .sys_rst(resetn),    // omg. this is active low?!?!?? 
     .mmcm_locked(mmcm_locked),

     .app_sr_req(1'b0),  // reserved command
     .app_ref_req(1'b0), // refresh command
     .app_zq_req(1'b0),  // recalibrate command
     .app_sr_active(app_sr_active), // reserved response
     .app_ref_ack(app_ref_ack),     // refresh ack
     .app_zq_ack(app_zq_ack),       // recalibrate ack

     // axi
     .s_axi_awid(BUS_axi_awid),
     .s_axi_awaddr(BUS_axi_awaddr[27:0]),
     .s_axi_awlen(BUS_axi_awlen),
     .s_axi_awsize(BUS_axi_awsize),
     .s_axi_awburst(BUS_axi_awburst),
     .s_axi_awlock(BUS_axi_awlock),
     .s_axi_awcache(BUS_axi_awcache),
     .s_axi_awprot(BUS_axi_awprot),
     .s_axi_awqos(BUS_axi_awqos),
     .s_axi_awvalid(BUS_axi_awvalid),
     .s_axi_awready(BUS_axi_awready),
     .s_axi_wdata(BUS_axi_wdata),
     .s_axi_wstrb(BUS_axi_wstrb),
     .s_axi_wlast(BUS_axi_wlast),
     .s_axi_wvalid(BUS_axi_wvalid),
     .s_axi_wready(BUS_axi_wready),
     .s_axi_bready(BUS_axi_bready),
     .s_axi_bid(BUS_axi_bid),
     .s_axi_bresp(BUS_axi_bresp),
     .s_axi_bvalid(BUS_axi_bvalid),
     .s_axi_arid(BUS_axi_arid),
     .s_axi_araddr(BUS_axi_araddr[27:0]),
     .s_axi_arlen(BUS_axi_arlen),
     .s_axi_arsize(BUS_axi_arsize),
     .s_axi_arburst(BUS_axi_arburst),
     .s_axi_arlock(BUS_axi_arlock),
     .s_axi_arcache(BUS_axi_arcache),
     .s_axi_arprot(BUS_axi_arprot),
     .s_axi_arqos(BUS_axi_arqos),
     .s_axi_arvalid(BUS_axi_arvalid),
     .s_axi_arready(BUS_axi_arready),
     .s_axi_rready(BUS_axi_rready),
     .s_axi_rlast(BUS_axi_rlast),
     .s_axi_rvalid(BUS_axi_rvalid),
     .s_axi_rresp(BUS_axi_rresp),
     .s_axi_rid(BUS_axi_rid),
     .s_axi_rdata(BUS_axi_rdata),

     .init_calib_complete(c0_init_calib_complete),
     .device_temp(device_temp));

  (* mark_debug = "true" *)  logic IlaTrigger;
    
   
  if(RVVI_SYNTH_SUPPORTED) begin : rvvi_synth
    localparam MAX_CSRS = 3;
    localparam TOTAL_CSRS = 36;
    localparam [31:0] RVVI_INIT_TIME_OUT = 32'd100000000;
    localparam [31:0] RVVI_PACKET_DELAY = 32'd400;
    
    // pipeline controlls
    logic                                             StallE, StallM, StallW, FlushE, FlushM, FlushW;
    // required
    logic [P.XLEN-1:0]                                PCM;
    logic                                             InstrValidM;
    logic [31:0]                                      InstrRawD;
    logic [63:0]                                      Mcycle, Minstret;
    logic                                             TrapM;
    logic [1:0]                                       PrivilegeModeW;
    // registers gpr and fpr
    logic                                             GPRWen, FPRWen;
    logic [4:0]                                       GPRAddr, FPRAddr;
    logic [P.XLEN-1:0]                                GPRValue, FPRValue;
    logic [P.XLEN-1:0]                                CSRArray [TOTAL_CSRS-1:0];

    logic                                             valid;
    logic [187+(3*P.XLEN) + MAX_CSRS*(P.XLEN+12)-1:0] rvvi;

    assign StallE         = fpgaTop.wallypipelinedsoc.core.StallE;
    assign StallM         = fpgaTop.wallypipelinedsoc.core.StallM;
    assign StallW         = fpgaTop.wallypipelinedsoc.core.StallW;
    assign FlushE         = fpgaTop.wallypipelinedsoc.core.FlushE;
    assign FlushM         = fpgaTop.wallypipelinedsoc.core.FlushM;
    assign FlushW         = fpgaTop.wallypipelinedsoc.core.FlushW;
    assign InstrValidM    = fpgaTop.wallypipelinedsoc.core.ieu.InstrValidM;
    assign InstrRawD      = fpgaTop.wallypipelinedsoc.core.ifu.InstrRawD;
    assign PCM            = fpgaTop.wallypipelinedsoc.core.ifu.PCM;
    assign Mcycle         = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.counters.counters.HPMCOUNTER_REGW[0];
    assign Minstret       = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.counters.counters.HPMCOUNTER_REGW[2];
    assign TrapM          = fpgaTop.wallypipelinedsoc.core.TrapM;
    assign PrivilegeModeW = fpgaTop.wallypipelinedsoc.core.priv.priv.privmode.PrivilegeModeW;
    assign GPRAddr        = fpgaTop.wallypipelinedsoc.core.ieu.dp.regf.a3;
    assign GPRWen         = fpgaTop.wallypipelinedsoc.core.ieu.dp.regf.we3;
    assign GPRValue       = fpgaTop.wallypipelinedsoc.core.ieu.dp.regf.wd3;
    assign FPRAddr        = fpgaTop.wallypipelinedsoc.core.fpu.fpu.fregfile.a4;
    assign FPRWen         = fpgaTop.wallypipelinedsoc.core.fpu.fpu.fregfile.we4;
    assign FPRValue       = fpgaTop.wallypipelinedsoc.core.fpu.fpu.fregfile.wd4;

    assign CSRArray[0] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MSTATUS_REGW; // 12'h300
    assign CSRArray[1] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MSTATUSH_REGW; // 12'h310
    assign CSRArray[2] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MTVEC_REGW; // 12'h305
    assign CSRArray[3] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MEPC_REGW; // 12'h341
    assign CSRArray[4] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MCOUNTEREN_REGW; // 12'h306
    assign CSRArray[5] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MCOUNTINHIBIT_REGW; // 12'h320
    assign CSRArray[6] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MEDELEG_REGW; // 12'h302
    assign CSRArray[7] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MIDELEG_REGW; // 12'h303
    assign CSRArray[8] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MIP_REGW; // 12'h344
    assign CSRArray[9] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MIE_REGW; // 12'h304
    assign CSRArray[10] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MISA_REGW; // 12'h301
    assign CSRArray[11] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MENVCFG_REGW; // 12'h30A
    assign CSRArray[12] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MHARTID_REGW; // 12'hF14
    assign CSRArray[13] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MSCRATCH_REGW; // 12'h340
    assign CSRArray[14] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MCAUSE_REGW; // 12'h342
    assign CSRArray[15] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MTVAL_REGW; // 12'h343
    assign CSRArray[16] = 0; // 12'hF11
    assign CSRArray[17] = 0; // 12'hF12
    assign CSRArray[18] = {{P.XLEN-12{1'b0}}, 12'h100}; //P.XLEN'h100; // 12'hF13
    assign CSRArray[19] = 0; // 12'hF15
    assign CSRArray[20] = 0; // 12'h34A
    // supervisor CSRs
    assign CSRArray[21] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrs.csrs.SSTATUS_REGW; // 12'h100
    assign CSRArray[22] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MIE_REGW & 12'h222; // 12'h104
    assign CSRArray[23] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrs.csrs.STVEC_REGW; // 12'h105
    assign CSRArray[24] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrs.csrs.SEPC_REGW; // 12'h141
    assign CSRArray[25] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrs.csrs.SCOUNTEREN_REGW; // 12'h106
    assign CSRArray[26] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrs.csrs.SENVCFG_REGW; // 12'h10A
    assign CSRArray[27] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrs.csrs.SATP_REGW; // 12'h180
    assign CSRArray[28] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrs.csrs.SSCRATCH_REGW; // 12'h140
    assign CSRArray[29] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrs.csrs.STVAL_REGW; // 12'h143
    assign CSRArray[30] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrs.csrs.SCAUSE_REGW; // 12'h142
    assign CSRArray[31] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MIP_REGW & 12'h222 & fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrm.MIDELEG_REGW; // 12'h144
    assign CSRArray[32] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csrs.csrs.STIMECMP_REGW; // 12'h14D
    // user CSRs
    assign CSRArray[33] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csru.csru.FFLAGS_REGW; // 12'h001
    assign CSRArray[34] = fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csru.csru.FRM_REGW; // 12'h002
    assign CSRArray[35] = {fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csru.csru.FRM_REGW, fpgaTop.wallypipelinedsoc.core.priv.priv.csr.csru.csru.FFLAGS_REGW}; // 12'h003

    rvvisynth #(P, MAX_CSRS) rvvisynth(.clk(CPUCLK), .reset(bus_struct_reset), .StallE, .StallM, .StallW, .FlushE, .FlushM, .FlushW,
      .PCM, .InstrValidM, .InstrRawD, .Mcycle, .Minstret, .TrapM, 
      .PrivilegeModeW, .GPRWen, .FPRWen, .GPRAddr, .FPRAddr, .GPRValue, .FPRValue, .CSRArray,
      .valid, .rvvi);

    // axi 4 write data channel
    logic [31:0]                                      RvviAxiWdata;
    logic [3:0]                                       RvviAxiWstrb;
    logic                                             RvviAxiWlast;
    logic                                             RvviAxiWvalid;
    logic                                             RvviAxiWready;

    logic [31:0] RvviAxiRdata;
    logic [3:0]                                       RvviAxiRstrb;
    logic RvviAxiRlast;
    logic RvviAxiRvalid;

    logic                                             tx_error_underflow, tx_fifo_overflow, tx_fifo_bad_frame, tx_fifo_good_frame, rx_error_bad_frame;
    logic                                             rx_error_bad_fcs, rx_fifo_overflow, rx_fifo_bad_frame, rx_fifo_good_frame;

    packetizer #(P, MAX_CSRS, RVVI_INIT_TIME_OUT, RVVI_PACKET_DELAY) packetizer(.rvvi, .valid, .m_axi_aclk(CPUCLK), .m_axi_aresetn(~bus_struct_reset), .RVVIStall,
      .RvviAxiWdata, .RvviAxiWstrb, .RvviAxiWlast, .RvviAxiWvalid, .RvviAxiWready);

    eth_mac_mii_fifo #(.TARGET("XILINX"), .CLOCK_INPUT_STYLE("BUFG"), .AXIS_DATA_WIDTH(32), .TX_FIFO_DEPTH(1024)) ethernet(.rst(bus_struct_reset), .logic_clk(CPUCLK), .logic_rst(bus_struct_reset),
      .tx_axis_tdata(RvviAxiWdata), .tx_axis_tkeep(RvviAxiWstrb), .tx_axis_tvalid(RvviAxiWvalid), .tx_axis_tready(RvviAxiWready),
      .tx_axis_tlast(RvviAxiWlast), .tx_axis_tuser('0), .rx_axis_tdata(RvviAxiRdata),
      .rx_axis_tkeep(RvviAxiRstrb), .rx_axis_tvalid(RvviAxiRvalid), .rx_axis_tready(1'b1),
      .rx_axis_tlast(RvviAxiRlast), .rx_axis_tuser(),

      .mii_rx_clk(phy_rx_clk),
      .mii_rxd(phy_rxd),
      .mii_rx_dv(phy_rx_dv),
      .mii_rx_er(phy_rx_er),
      .mii_tx_clk(phy_tx_clk),
      .mii_txd(phy_txd),
      .mii_tx_en(phy_tx_en),
      .mii_tx_er(),

      // status
      .tx_error_underflow, .tx_fifo_overflow, .tx_fifo_bad_frame, .tx_fifo_good_frame, .rx_error_bad_frame,
      .rx_error_bad_fcs, .rx_fifo_overflow, .rx_fifo_bad_frame, .rx_fifo_good_frame, 
      .cfg_ifg(8'd12), .cfg_tx_enable(1'b1), .cfg_rx_enable(1'b1)
      );

    triggergen triggergen(.clk(CPUCLK), .reset(bus_struct_reset), .RvviAxiRdata,
      .RvviAxiRstrb, .RvviAxiRlast, .RvviAxiRvalid, .IlaTrigger);
  end else begin // if (P.RVVI_SYNTH_SUPPORTED)
    assign IlaTrigger = '0;
    assign RVVIStall = '0;
  end
   
  //assign phy_reset_n = ~bus_struct_reset;
   assign phy_reset_n = ~1'b0;
  
endmodule

