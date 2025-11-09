NEXTPNR=nextpnr-himbaechel
GHDL=ghdl

all: $(TOP).bit

# Synthesis
$(TOP).json: $(SRCS)
	yosys -ql yosys.log -m ghdl -p "ghdl --vendor-library=colognechip --work=colognechip ../common/cc_components.vhdl --work=work $(SRCS) -e $(TOP); synth_gatemate -top $(TOP) -luttree -nomx8 -nomult; write_json $@; write_verilog $(TOP).netlist.v"

# Concat all the pin constraints
# (nextpnr warns on constraints for unused pins)
COMMON_CCF=../common/GateMateA1-EVB.ccf
$(TOP).ccf: $(COMMON_CCF) $(CCF) Makefile
	cat $(COMMON_CCF) $(CCF) > $@

$(TOP).impl: $(TOP).json $(TOP).ccf
	$(NEXTPNR) --device=CCGM1A1 --json $(TOP).json -o fpga_mode=2 -o ccf=$(TOP).ccf -o out=$@ --router router2 -l pnr.log

$(TOP).bit: $(TOP).impl
	gmpack $< $@

load: $(TOP).bit
	@echo "you might need sudo..."
	openFPGALoader -b dirtyJtag $(TOP).bit

clean:
	$(RM) -f $(TOP).json $(TOP).ccf $(TOP).impl $(TOP).bit $(TOP).netlist.v yosys.log pnr.log

.SILENT: load clean
