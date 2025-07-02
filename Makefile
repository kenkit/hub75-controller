all: build/blink.svf build/blink.bit build/controller.json
# Configuration
BITS_PER_PIXEL = 16


SYNTH_SRCS=controller.v sync_pdp_ram.v spi_slave.v
SIM_SRCS=blink_tb.v blink.v 

ifndef V70
	//PACKAGE=CABGA381
    //LFP=blink_v61.lpf
		PACKAGE=CABGA256
    LFP=top.lpf
else
	PACKAGE=CABGA256
    LFP=top.lpf
endif

build/controller.json:
	yosys -p 'chparam -set BITS_PER_PIXEL $(BITS_PER_PIXEL);' \
		-p 'read_verilog controller.v sync_pdp_ram.v spi_slave.v;' \
		-p 'synth_ecp5  -top controller -abc9 -json $@' $^
build/blink.config: build/controller.json $(LPF)
	nextpnr-ecp5 --25k --package $(PACKAGE) --speed 6 --lpf $(LFP) --json build/controller.json --textcfg build/blink.config --freq 25

build/blink.svf: build/blink.config
	ecppack --compress --input $< --svf $@

build/blink.bit: build/blink.config
	ecppack --compress --input $< --bit $@

flash: build/blink.bit
	# ERASES THE DEFAULT CONTENTS OF THE SPI FLASH!
	openFPGALoader --vid 0x0403 --pid 0x6014 --unprotect-flash -f build/blink.bit
flash_sram:
	openFPGALoader -b colorlight -c usb-blaster --write-sram build/blink.bit --skip-reset
visual:
	yosys -p 'read_verilog $(SYNTH_SRCS); synth ; show -colors 1 -format dot -prefix diagram'

flash_backup:
	#ecpprog -R 2M colorlight_backup.bit
	openFPGALoader -b colorlight  -c usb-blaster --verbose  --dump-flash  colorlight_backup.bit --file-size 4096000
check_reset:
	openFPGALoader -b colorlight  -c usb-blaster --detect -f
clean:
	rm -f build/*


