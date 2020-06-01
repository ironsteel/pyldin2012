PROJ=pyldin
FPGA_PREFIX ?=
FPGA_SIZE ?= 12
FPGA_KS ?= $(FPGA_PREFIX)$(FPGA_SIZE)k

YOSYS ?= yosys
NEXTPNR-ECP5 ?= nextpnr-ecp5
TRELLIS ?= /home/ironsteel/src/prjtrellis

ECPPLL ?= ecppll
ECPPACK ?= ecppack
TRELLISDB ?= $(TRELLIS)/database
LIBTRELLIS ?= $(TRELLIS)/libtrellis
#YOSYS_OPTIONS ?= 
YOSYS_OPTIONS ?= 
NEXTPNR_OPTIONS ?= --timing-allow-fail

CLK0_NAME = clk_25_100
CLK0_FILE_NAME = $(CLK0_NAME).v
CLK0_OPTIONS = \
  --module=$(CLK0_NAME) \
  --clkin_name=clk25_i \
  --clkin=25 \
  --clkout0_name=clk100_o \
  --clkout0=100 \
  --clkout1_name=clk50_o \
  --clkout1=50 \
  --clkout2_name=clk12_o \
  --clkout2=12.5 \
  --clkout3_name=cl25_o \
  --clkout3=25 \

all: ${PROJ}.bit ${PROJ}.json

$(CLK0_NAME).v:
	$(ECPPLL) $(CLK0_OPTIONS) --file $@

VERILOG_FILES = pyldin.v
VERILOG_FILES += $(CLK0_FILE_NAME) 
VERILOG_FILES += sdram.v
VERILOG_FILES += ram.v
VERILOG_FILES += pll_dvi.v
VERILOG_FILES += vga2dvid.v
VERILOG_FILES += tmds_encoder.v
VERILOG_FILES += clock_divider.v
VERILOG_FILES += flashmem.v
VERILOG_FILES += flash_loader.v

VERILOG_FILES += sump2/core.v
VERILOG_FILES += sump2/mesa2ctrl.v
VERILOG_FILES += sump2/mesa2lb.v
VERILOG_FILES += sump2/mesa_ascii2nibble.v
VERILOG_FILES += sump2/mesa_byte2ascii.v
VERILOG_FILES += sump2/mesa_core.v
VERILOG_FILES += sump2/mesa_decode.v
VERILOG_FILES += sump2/mesa_id.v
VERILOG_FILES += sump2/mesa_phy.v
VERILOG_FILES += sump2/mesa_tx_uart.v
VERILOG_FILES += sump2/mesa_uart.v
VERILOG_FILES += sump2/spi_byte2bit.v
VERILOG_FILES += sump2/spi_prom.v
VERILOG_FILES += sump2/sump2_top.v
VERILOG_FILES += sump2/sump2.v
VERILOG_FILES += sump2/time_stamp.v

VHDL_SOURCES = keyboard.vhd vgachargen.vhd segled.vhd rombios.vhd sd.vhd cpu68.vhd vga6845.vhd pyldin2012.vhd 

%.json: ${VERILOG_FILES} ${VHDL_SOURCES}
	$(YOSYS) -mghdl -q -l synth.log \
	-p "ghdl --std=08 --ieee=synopsys ${VHDL_SOURCES} -e pyldin2012" \
	-p "read_verilog -sv ${VERILOG_FILES}" \
	-p "hierarchy -top pyldin" \
	-p "synth_ecp5 ${YOSYS_OPTIONS} -json $@"

%_out.config: %.json
	$(NEXTPNR-ECP5) $(NEXTPNR_OPTIONS) --json  $< --textcfg $@ --$(FPGA_KS) --freq 21 --package CABGA381 --lpf ulx3s_v20.lpf

%.bit: %_out.config
	$(ECPPACK) --db $(TRELLISDB) --compress $< $@

prog: ${PROJ}.bit
	fujprog $<

prog_flash: ${PROJ}.bit
	fujprog -j FLASH $<

prog_rom: roms/roms
	fujprog -j FLASH -f 0x200000 roms/roms 

.PHONY: prog 

.PHONY: sim
.PRECIOUS: pyldin.vcd
VERILOG_SIM := pyldin.v ram.v verilog.v sdram.v clock_divider.v flashmem.v flash_loader.v sim_spiflash.v
TOPMOD  := pyldin
VLOGFIL := $(TOPMOD).v
VCDFILE := $(TOPMOD).vcd
SIMPROG := $(TOPMOD)_tb
SIMFILE := $(SIMPROG).cpp
VDIRFB  := ./obj_dir

COSIMS  := vgasim.cpp image.cpp sdramsim.cpp
sim: $(VCDFILE)

GCC := g++
CFLAGS = -g -Wall -std=c++17 -lpthread -I$(VINC) -I $(VDIRFB)
GFXFLAGS:= $(FLAGS) `pkg-config gtkmm-3.0 --cflags`
GFXLIBS := `pkg-config gtkmm-3.0 --libs`
CFLAGS  +=  $(GFXFLAGS)
#
# Modern versions of Verilator and C++ may require an -faligned-new flag
# CFLAGS = -g -Wall -faligned-new -I$(VINC) -I $(VDIRFB)

VERILATOR=verilator
VFLAGS := -O3 -MMD --trace -Wall -DSIM

## Find the directory containing the Verilog sources.  This is given from
## calling: "verilator -V" and finding the VERILATOR_ROOT output line from
## within it.  From this VERILATOR_ROOT value, we can find all the components
## we need here--in particular, the verilator include directory
VERILATOR_ROOT ?= $(shell bash -c '$(VERILATOR) -V|grep VERILATOR_ROOT | head -1 | sed -e "s/^.*=\s*//"')
##
## The directory containing the verilator includes
VINC := $(VERILATOR_ROOT)/include

verilog.v:
	yosys -mghdl verilog.ys

$(VDIRFB)/V$(TOPMOD).cpp: $(VERILOG_SIM) verilog.v
	$(VERILATOR) $(VFLAGS) --top-module $(TOPMOD) -cc $(VERILOG_SIM)

$(VDIRFB)/V$(TOPMOD)__ALL.a: $(VDIRFB)/V$(TOPMOD).cpp
	make --no-print-directory -C $(VDIRFB) -f V$(TOPMOD).mk

$(SIMPROG): $(SIMFILE) $(VDIRFB)/V$(TOPMOD)__ALL.a $(COSIMS)
	$(GCC) $(CFLAGS) $(VINC)/verilated.cpp				\
		$(VINC)/verilated_vcd_c.cpp $(SIMFILE) $(COSIMS)	\
		$(VDIRFB)/V$(TOPMOD)__ALL.a $(GFXLIBS) -o $(SIMPROG)

test: $(VCDFILE)

$(VCDFILE): $(SIMPROG)
	./$(SIMPROG) --video --trace
	#./$(SIMPROG) --video 

clean:
	rm -f *.bit *.config *.json

.SECONDARY:
.PHONY: compile clean prog
