TOP=vga
SRCS=src/$(TOP).vhd
CCF=src/$(TOP).ccf

all: $(TOP).bit

$(TOP).json: $(SRCS)
	yosys -ql yosys.log -m ghdl -p "ghdl $(SRCS) -e $(TOP); synth_gatemate -top $(TOP) -luttree -nomx8 -nomult; write_json $@; write_verilog $(TOP).netlist.v"

$(TOP).impl: $(TOP).json
	nextpnr-himbaechel --device=CCGM1A1 --json $(TOP).json -o ccf=$(CCF) -o out=$@ --router router2

$(TOP).bit: $(TOP).impl
	gmpack $< $@

load: $(TOP).bit
	@echo "you might need sudo..."
	openFPGALoader -b dirtyJtag $(TOP).bit

clean:
	$(RM) -f $(TOP).json $(TOP).impl $(TOP).bit $(TOP).netlist.v yosys.log

.SILENT: load clean
