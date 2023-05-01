create_debug_core u_ila_0 ila




set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
startgroup 
set_property C_EN_STRG_QUAL true [get_debug_cores u_ila_0 ]
set_property C_ADV_TRIGGER true [get_debug_cores u_ila_0 ]
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0 ]
set_property ALL_PROBE_SAME_MU_CNT 4 [get_debug_cores u_ila_0 ]
endgroup
connect_debug_port u_ila_0/clk [get_nets CPUCLK]

set_property port_width 64 [get_debug_ports u_ila_0/probe0]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {wallypipelinedsoc/core/PCM[0]} {wallypipelinedsoc/core/PCM[1]} {wallypipelinedsoc/core/PCM[2]} {wallypipelinedsoc/core/PCM[3]} {wallypipelinedsoc/core/PCM[4]} {wallypipelinedsoc/core/PCM[5]} {wallypipelinedsoc/core/PCM[6]} {wallypipelinedsoc/core/PCM[7]} {wallypipelinedsoc/core/PCM[8]} {wallypipelinedsoc/core/PCM[9]} {wallypipelinedsoc/core/PCM[10]} {wallypipelinedsoc/core/PCM[11]} {wallypipelinedsoc/core/PCM[12]} {wallypipelinedsoc/core/PCM[13]} {wallypipelinedsoc/core/PCM[14]} {wallypipelinedsoc/core/PCM[15]} {wallypipelinedsoc/core/PCM[16]} {wallypipelinedsoc/core/PCM[17]} {wallypipelinedsoc/core/PCM[18]} {wallypipelinedsoc/core/PCM[19]} {wallypipelinedsoc/core/PCM[20]} {wallypipelinedsoc/core/PCM[21]} {wallypipelinedsoc/core/PCM[22]} {wallypipelinedsoc/core/PCM[23]} {wallypipelinedsoc/core/PCM[24]} {wallypipelinedsoc/core/PCM[25]} {wallypipelinedsoc/core/PCM[26]} {wallypipelinedsoc/core/PCM[27]} {wallypipelinedsoc/core/PCM[28]} {wallypipelinedsoc/core/PCM[29]} {wallypipelinedsoc/core/PCM[30]} {wallypipelinedsoc/core/PCM[31]} {wallypipelinedsoc/core/PCM[32]} {wallypipelinedsoc/core/PCM[33]} {wallypipelinedsoc/core/PCM[34]} {wallypipelinedsoc/core/PCM[35]} {wallypipelinedsoc/core/PCM[36]} {wallypipelinedsoc/core/PCM[37]} {wallypipelinedsoc/core/PCM[38]} {wallypipelinedsoc/core/PCM[39]} {wallypipelinedsoc/core/PCM[40]} {wallypipelinedsoc/core/PCM[41]} {wallypipelinedsoc/core/PCM[42]} {wallypipelinedsoc/core/PCM[43]} {wallypipelinedsoc/core/PCM[44]} {wallypipelinedsoc/core/PCM[45]} {wallypipelinedsoc/core/PCM[46]} {wallypipelinedsoc/core/PCM[47]} {wallypipelinedsoc/core/PCM[48]} {wallypipelinedsoc/core/PCM[49]} {wallypipelinedsoc/core/PCM[50]} {wallypipelinedsoc/core/PCM[51]} {wallypipelinedsoc/core/PCM[52]} {wallypipelinedsoc/core/PCM[53]} {wallypipelinedsoc/core/PCM[54]} {wallypipelinedsoc/core/PCM[55]} {wallypipelinedsoc/core/PCM[56]} {wallypipelinedsoc/core/PCM[57]} {wallypipelinedsoc/core/PCM[58]} {wallypipelinedsoc/core/PCM[59]} {wallypipelinedsoc/core/PCM[60]} {wallypipelinedsoc/core/PCM[61]} {wallypipelinedsoc/core/PCM[62]} {wallypipelinedsoc/core/PCM[63]} ]]

create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe1]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list wallypipelinedsoc/core/TrapM ]]

create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe2]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list wallypipelinedsoc/core/InstrValidM ]]

create_debug_port u_ila_0 probe
set_property port_width 32 [get_debug_ports u_ila_0/probe3]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {wallypipelinedsoc/core/InstrM[0]} {wallypipelinedsoc/core/InstrM[1]} {wallypipelinedsoc/core/InstrM[2]} {wallypipelinedsoc/core/InstrM[3]} {wallypipelinedsoc/core/InstrM[4]} {wallypipelinedsoc/core/InstrM[5]} {wallypipelinedsoc/core/InstrM[6]} {wallypipelinedsoc/core/InstrM[7]} {wallypipelinedsoc/core/InstrM[8]} {wallypipelinedsoc/core/InstrM[9]} {wallypipelinedsoc/core/InstrM[10]} {wallypipelinedsoc/core/InstrM[11]} {wallypipelinedsoc/core/InstrM[12]} {wallypipelinedsoc/core/InstrM[13]} {wallypipelinedsoc/core/InstrM[14]} {wallypipelinedsoc/core/InstrM[15]} {wallypipelinedsoc/core/InstrM[16]} {wallypipelinedsoc/core/InstrM[17]} {wallypipelinedsoc/core/InstrM[18]} {wallypipelinedsoc/core/InstrM[19]} {wallypipelinedsoc/core/InstrM[20]} {wallypipelinedsoc/core/InstrM[21]} {wallypipelinedsoc/core/InstrM[22]} {wallypipelinedsoc/core/InstrM[23]} {wallypipelinedsoc/core/InstrM[24]} {wallypipelinedsoc/core/InstrM[25]} {wallypipelinedsoc/core/InstrM[26]} {wallypipelinedsoc/core/InstrM[27]} {wallypipelinedsoc/core/InstrM[28]} {wallypipelinedsoc/core/InstrM[29]} {wallypipelinedsoc/core/InstrM[30]} {wallypipelinedsoc/core/InstrM[31]} ]]

create_debug_port u_ila_0 probe
set_property port_width 32 [get_debug_ports u_ila_0/probe4]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {wallypipelinedsoc/core/lsu/LSUHADDR[0]} {wallypipelinedsoc/core/lsu/LSUHADDR[1]} {wallypipelinedsoc/core/lsu/LSUHADDR[2]} {wallypipelinedsoc/core/lsu/LSUHADDR[3]} {wallypipelinedsoc/core/lsu/LSUHADDR[4]} {wallypipelinedsoc/core/lsu/LSUHADDR[5]} {wallypipelinedsoc/core/lsu/LSUHADDR[6]} {wallypipelinedsoc/core/lsu/LSUHADDR[7]} {wallypipelinedsoc/core/lsu/LSUHADDR[8]} {wallypipelinedsoc/core/lsu/LSUHADDR[9]} {wallypipelinedsoc/core/lsu/LSUHADDR[10]} {wallypipelinedsoc/core/lsu/LSUHADDR[11]} {wallypipelinedsoc/core/lsu/LSUHADDR[12]} {wallypipelinedsoc/core/lsu/LSUHADDR[13]} {wallypipelinedsoc/core/lsu/LSUHADDR[14]} {wallypipelinedsoc/core/lsu/LSUHADDR[15]} {wallypipelinedsoc/core/lsu/LSUHADDR[16]} {wallypipelinedsoc/core/lsu/LSUHADDR[17]} {wallypipelinedsoc/core/lsu/LSUHADDR[18]} {wallypipelinedsoc/core/lsu/LSUHADDR[19]} {wallypipelinedsoc/core/lsu/LSUHADDR[20]} {wallypipelinedsoc/core/lsu/LSUHADDR[21]} {wallypipelinedsoc/core/lsu/LSUHADDR[22]} {wallypipelinedsoc/core/lsu/LSUHADDR[23]} {wallypipelinedsoc/core/lsu/LSUHADDR[24]} {wallypipelinedsoc/core/lsu/LSUHADDR[25]} {wallypipelinedsoc/core/lsu/LSUHADDR[26]} {wallypipelinedsoc/core/lsu/LSUHADDR[27]} {wallypipelinedsoc/core/lsu/LSUHADDR[28]} {wallypipelinedsoc/core/lsu/LSUHADDR[29]} {wallypipelinedsoc/core/lsu/LSUHADDR[30]} {wallypipelinedsoc/core/lsu/LSUHADDR[31]} ]]

create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe5]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list wallypipelinedsoc/core/lsu/LSUHREADY ]]

create_debug_port u_ila_0 probe
set_property port_width 28 [get_debug_ports u_ila_0/probe6]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {m_axi_araddr[0]} {m_axi_araddr[1]} {m_axi_araddr[2]} {m_axi_araddr[3]} {m_axi_araddr[4]} {m_axi_araddr[5]} {m_axi_araddr[6]} {m_axi_araddr[7]} {m_axi_araddr[8]} {m_axi_araddr[9]} {m_axi_araddr[10]} {m_axi_araddr[11]} {m_axi_araddr[12]} {m_axi_araddr[13]} {m_axi_araddr[14]} {m_axi_araddr[15]} {m_axi_araddr[16]} {m_axi_araddr[17]} {m_axi_araddr[18]} {m_axi_araddr[19]} {m_axi_araddr[20]} {m_axi_araddr[21]} {m_axi_araddr[22]} {m_axi_araddr[23]} {m_axi_araddr[24]} {m_axi_araddr[25]} {m_axi_araddr[26]} {m_axi_araddr[27]}  ]]

create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe7]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list {m_axi_arready}]]

create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe8]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list {m_axi_arvalid}]]

create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe9]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list {c0_init_calib_complete}]]

create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe10]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list {ui_clk_sync_rst}]]

create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe11]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list {mmcm_locked}]]

create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe12]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list {m_axi_awvalid}]]

create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe13]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list {m_axi_awready}]]

create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe14]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list {BUS_axi_arvalid}]]

create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe15]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe15]
connect_debug_port u_ila_0/probe15 [get_nets [list {BUS_axi_awready}]]

create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe16]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe16]
connect_debug_port u_ila_0/probe16 [get_nets [list {BUS_axi_arvalid}]]

create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe17]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe17]
connect_debug_port u_ila_0/probe17 [get_nets [list {BUS_axi_arready}]]

create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe18]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe18]
connect_debug_port u_ila_0/probe18 [get_nets [list {BUS_axi_rvalid}]]

create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe19]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe19]
connect_debug_port u_ila_0/probe19 [get_nets [list {BUS_axi_rready}]]

create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe20]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe20]
connect_debug_port u_ila_0/probe20 [get_nets [list {BUS_axi_wready}]]

create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe21]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe21]
connect_debug_port u_ila_0/probe21 [get_nets [list {BUS_axi_wvalid}]]

create_debug_port u_ila_0 probe
set_property port_width 64 [get_debug_ports u_ila_0/probe22]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe22]
connect_debug_port u_ila_0/probe22 [get_nets [list {wallypipelinedsoc/core/lsu/LSUHWDATA[0]} {wallypipelinedsoc/core/lsu/LSUHWDATA[1]} {wallypipelinedsoc/core/lsu/LSUHWDATA[2]} {wallypipelinedsoc/core/lsu/LSUHWDATA[3]} {wallypipelinedsoc/core/lsu/LSUHWDATA[4]} {wallypipelinedsoc/core/lsu/LSUHWDATA[5]} {wallypipelinedsoc/core/lsu/LSUHWDATA[6]} {wallypipelinedsoc/core/lsu/LSUHWDATA[7]} {wallypipelinedsoc/core/lsu/LSUHWDATA[8]} {wallypipelinedsoc/core/lsu/LSUHWDATA[9]} {wallypipelinedsoc/core/lsu/LSUHWDATA[10]} {wallypipelinedsoc/core/lsu/LSUHWDATA[11]} {wallypipelinedsoc/core/lsu/LSUHWDATA[12]} {wallypipelinedsoc/core/lsu/LSUHWDATA[13]} {wallypipelinedsoc/core/lsu/LSUHWDATA[14]} {wallypipelinedsoc/core/lsu/LSUHWDATA[15]} {wallypipelinedsoc/core/lsu/LSUHWDATA[16]} {wallypipelinedsoc/core/lsu/LSUHWDATA[17]} {wallypipelinedsoc/core/lsu/LSUHWDATA[18]} {wallypipelinedsoc/core/lsu/LSUHWDATA[19]} {wallypipelinedsoc/core/lsu/LSUHWDATA[20]} {wallypipelinedsoc/core/lsu/LSUHWDATA[21]} {wallypipelinedsoc/core/lsu/LSUHWDATA[22]} {wallypipelinedsoc/core/lsu/LSUHWDATA[23]} {wallypipelinedsoc/core/lsu/LSUHWDATA[24]} {wallypipelinedsoc/core/lsu/LSUHWDATA[25]} {wallypipelinedsoc/core/lsu/LSUHWDATA[26]} {wallypipelinedsoc/core/lsu/LSUHWDATA[27]} {wallypipelinedsoc/core/lsu/LSUHWDATA[28]} {wallypipelinedsoc/core/lsu/LSUHWDATA[29]} {wallypipelinedsoc/core/lsu/LSUHWDATA[30]} {wallypipelinedsoc/core/lsu/LSUHWDATA[31]} {wallypipelinedsoc/core/lsu/LSUHWDATA[32]} {wallypipelinedsoc/core/lsu/LSUHWDATA[33]} {wallypipelinedsoc/core/lsu/LSUHWDATA[34]} {wallypipelinedsoc/core/lsu/LSUHWDATA[35]} {wallypipelinedsoc/core/lsu/LSUHWDATA[36]} {wallypipelinedsoc/core/lsu/LSUHWDATA[37]} {wallypipelinedsoc/core/lsu/LSUHWDATA[38]} {wallypipelinedsoc/core/lsu/LSUHWDATA[39]} {wallypipelinedsoc/core/lsu/LSUHWDATA[40]} {wallypipelinedsoc/core/lsu/LSUHWDATA[41]} {wallypipelinedsoc/core/lsu/LSUHWDATA[42]} {wallypipelinedsoc/core/lsu/LSUHWDATA[43]} {wallypipelinedsoc/core/lsu/LSUHWDATA[44]} {wallypipelinedsoc/core/lsu/LSUHWDATA[45]} {wallypipelinedsoc/core/lsu/LSUHWDATA[46]} {wallypipelinedsoc/core/lsu/LSUHWDATA[47]} {wallypipelinedsoc/core/lsu/LSUHWDATA[48]} {wallypipelinedsoc/core/lsu/LSUHWDATA[49]} {wallypipelinedsoc/core/lsu/LSUHWDATA[50]} {wallypipelinedsoc/core/lsu/LSUHWDATA[51]} {wallypipelinedsoc/core/lsu/LSUHWDATA[52]} {wallypipelinedsoc/core/lsu/LSUHWDATA[53]} {wallypipelinedsoc/core/lsu/LSUHWDATA[54]} {wallypipelinedsoc/core/lsu/LSUHWDATA[55]} {wallypipelinedsoc/core/lsu/LSUHWDATA[56]} {wallypipelinedsoc/core/lsu/LSUHWDATA[57]} {wallypipelinedsoc/core/lsu/LSUHWDATA[58]} {wallypipelinedsoc/core/lsu/LSUHWDATA[59]} {wallypipelinedsoc/core/lsu/LSUHWDATA[60]} {wallypipelinedsoc/core/lsu/LSUHWDATA[61]} {wallypipelinedsoc/core/lsu/LSUHWDATA[62]} {wallypipelinedsoc/core/lsu/LSUHWDATA[63]} ]]

# the debug hub has issues with the clocks from the mmcm so lets give up an connect to the 100Mhz input clock.
#connect_debug_port dbg_hub/clk [get_nets default_100mhz_clk]
connect_debug_port dbg_hub/clk [get_nets CPUCLK]
