all: build/blink.svf build/blink.bit build/controller.json
# Configuration
BITS_PER_PIXEL = 16
BOARD ?= ice40
IVERILOG = iverilog -g 2012 -g io-range-error -Wall -Ptb.BITS_PER_PIXEL=$(BITS_PER_PIXEL)
VVP = vvp

YOSYS = yosys
PIN_DEF = constraints.pcf
DEVICE = up5k



ICETIME = icetime
ICEPROG = iceprog

VERILATOR_LINT = verilator --lint-only --timing -GBITS_PER_PIXEL=$(BITS_PER_PIXEL)

ifeq ($(BOARD), Colorlight)
	NEXTPNR = nextpnr-ecp5 
	PACKAGE= CABGA256
	LUT=25k
    LFP=Colorlight.lpf
	SYNTH=synth_ecp5
	PACK = ecppack
else
	NEXTPNR = nextpnr-ice40
	PACKAGE= sg48 
	LUT=up5k
    LFP=constraints.pcf
	SYNTH=synth_ice40 
	PACK = icepack
endif

build/sync_pdp_ram: sync_pdp_ram.v sync_pdp_ram_tb.v
	$(VERILATOR_LINT) $^
	$(IVERILOG) -o $@ $^
build/spi_slave: spi_slave.v spi_slave_tb.v
	$(VERILATOR_LINT) $^
	$(IVERILOG) -o $@ $^
build/controller: controller.v controller_tb.v sync_pdp_ram.v spi_slave.v
	$(VERILATOR_LINT) $^
	$(IVERILOG) -o $@ $^

build/sync_pdp_ram-tests: build/sync_pdp_ram
	cd build
	$(VVP) build/sync_pdp_ram
build/spi_slave-tests: build/spi_slave
	cd build
	$(VVP) build/spi_slave
build/controller-tests: build/controller
	cd build
	$(VVP) build/controller

tests: build/sync_pdp_ram-tests build/spi_slave-tests build/controller-tests


build/controller.json:
	$(YOSYS) -p 'chparam -set BITS_PER_PIXEL $(BITS_PER_PIXEL);' \
		-p 'read_verilog controller.v sync_pdp_ram.v spi_slave.v;' \
		-p '${SYNTH}  -top controller -abc9 -json $@' $^
build/blink.config: build/controller.json 
ifeq ($(BOARD), Colorlight)
	$(NEXTPNR) --${LUT} --package $(PACKAGE) --speed 6 --lpf $(LFP) --json $< --textcfg build/blink.config --freq 25
else
	$(NEXTPNR) --${LUT} --package $(PACKAGE) --pcf $(LFP) --json $< --asc build/build.asc
endif

build/blink.svf: build/blink.config
ifeq ($(BOARD), Colorlight)
		$(PACK)  --compress --verbose --input $< --svf $@
		sed -i '27s/.*/		TDO  (0601f10)/' $@
else
		$(PACK) build/build.asc  build/controller.bin
endif

jtag_svf: build/blink.svf
	openocd -f colorlight_5a75b.cfg -c "svf -progress $<; exit"

build/blink.bit: build/blink.config
ifeq ($(BOARD), Colorlight)
	ecppack --compress --input $< --bit $@
endif
flash: build/blink.bit
	# ERASES THE DEFAULT CONTENTS OF THE SPI FLASH!
	openFPGALoader --vid 0x0403 --pid 0x6014 --unprotect-flash -f build/blink.bit
flash_sram: build/blink.svf
	openocd -f colorlight_5a75b.cfg -c "svf -progress $<; exit"
	#openFPGALoader -b colorlight -c usb-blaster --write-sram build/blink.bit --skip-reset
visual:
	$(YOSYS)  -p 'read_verilog $(SYNTH_SRCS); synth ; show -colors 1 -format dot -prefix diagram'

flash_backup:
	#ecpprog -R 2M colorlight_backup.bit
	openFPGALoader -b colorlight  -c usb-blaster --verbose  --dump-flash  colorlight_backup.bit --file-size 4096000

check_reset:
	openFPGALoader -b colorlight  -c usb-blaster --detect -f
clean:
	rm -f build/*


