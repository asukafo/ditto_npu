
#HDMI
set_property -dict {PACKAGE_PIN G19  IOSTANDARD TMDS_33 } [get_ports {TMDS_tmds_data_p[2]}]
set_property -dict {PACKAGE_PIN J20  IOSTANDARD TMDS_33 } [get_ports {TMDS_tmds_data_p[1]}]
set_property -dict {PACKAGE_PIN L19  IOSTANDARD TMDS_33 } [get_ports {TMDS_tmds_data_p[0]}]
set_property -dict {PACKAGE_PIN M19  IOSTANDARD TMDS_33 } [get_ports  TMDS_tmds_clk_p]

#OV5640
set_property -dict {PACKAGE_PIN V13 IOSTANDARD LVCMOS33} [get_ports cam_rst_n]
set_property -dict {PACKAGE_PIN Y17 IOSTANDARD LVCMOS33} [get_ports cam_pwdn]
set_property -dict {PACKAGE_PIN U12 IOSTANDARD LVCMOS33} [get_ports {cam_data[0]}]
set_property -dict {PACKAGE_PIN Y16 IOSTANDARD LVCMOS33} [get_ports {cam_data[1]}]
set_property -dict {PACKAGE_PIN T14 IOSTANDARD LVCMOS33} [get_ports {cam_data[2]}]
set_property -dict {PACKAGE_PIN T11 IOSTANDARD LVCMOS33} [get_ports {cam_data[3]}]
set_property -dict {PACKAGE_PIN R14 IOSTANDARD LVCMOS33} [get_ports {cam_data[4]}]
set_property -dict {PACKAGE_PIN U13 IOSTANDARD LVCMOS33} [get_ports {cam_data[5]}]
set_property -dict {PACKAGE_PIN T15 IOSTANDARD LVCMOS33} [get_ports {cam_data[6]}]
set_property -dict {PACKAGE_PIN T10 IOSTANDARD LVCMOS33} [get_ports {cam_data[7]}]
set_property -dict {PACKAGE_PIN P14 IOSTANDARD LVCMOS33} [get_ports cam_href]
set_property -dict {PACKAGE_PIN T19 IOSTANDARD LVCMOS33} [get_ports cam_pclk]
set_property -dict {PACKAGE_PIN W13 IOSTANDARD LVCMOS33} [get_ports cam_vsync]
set_property -dict {PACKAGE_PIN T12 IOSTANDARD LVCMOS33} [get_ports cam_xclk]
#cam_scl:
set_property -dict {PACKAGE_PIN R19 IOSTANDARD LVCMOS33} [get_ports {emio_sccb_tri_io[0]}]
#cam_sda:
set_property -dict {PACKAGE_PIN V12 IOSTANDARD LVCMOS33} [get_ports {emio_sccb_tri_io[1]}]


#----------------------摄像头接口的时钟---------------------------
#72M
create_clock -period 13.888 -name cam_pclk [get_ports cam_pclk]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets cam_pclk_IBUF]

set_input_delay -clock cam_pclk -min -1.000 [get_ports {cam_data[*]}]
set_input_delay -clock cam_pclk -max 3.000 [get_ports {cam_data[*]}]

set_input_delay -clock cam_pclk -min -1.000 [get_ports cam_href]
set_input_delay -clock cam_pclk -max 3.000 [get_ports cam_href]

set_input_delay -clock cam_pclk -min -1.000 [get_ports cam_vsync]
set_input_delay -clock cam_pclk -max 3.000 [get_ports cam_vsync]
