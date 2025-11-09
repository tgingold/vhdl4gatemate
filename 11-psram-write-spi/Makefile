TOP=psram_write
SRCS=src/$(TOP).vhdl ../common/pll.vhdl
CCF= ../common/evb-psram.ccf

include ../common/common.make

sim:
	$(GHDL) -c src/psram_write.vhdl src/tb_psram_write.vhdl ../sim/pll.vhdl -r --stop-time=10us --fst=tb.fst
