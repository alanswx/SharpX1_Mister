# Headless shared-machine simulation. Historical GUI artifacts remain untouched.
V ?= verilator
MACHINE_MANIFEST = ../rtl/machine.qip
MACHINE_SRC = $(addprefix ../,$(shell awk '/^set_global_assignment -name (SYSTEMVERILOG_FILE|VERILOG_FILE) / { print $$4 }' $(MACHINE_MANIFEST)))
V_SRC = sim.v $(MACHINE_SRC)
HEADLESS_DIR = obj_dir_headless
HEADLESS_EXE = $(HEADLESS_DIR)/Vtop
VIDEO_TEST_FLAGS ?=
TURBO_DSW ?= 241
TURBO_DSW_FLAGS = -GTURBO_DSW=$(TURBO_DSW) -CFLAGS "-DX1_TURBO_DSW=$(TURBO_DSW)"
FM_MANIFEST = ../rtl/x1_fm.qip
FM_SRC = $(addprefix ../,$(shell awk '/^set_global_assignment -name (SYSTEMVERILOG_FILE|VERILOG_FILE) / { print $$4 }' $(FM_MANIFEST)))
FM_MASTER_HZ ?= 32000000
PSG_SRC = $(wildcard ../references/chip-src/jt49/hdl/jt49*.v)

all: headless

test-psg-mix: $(HEADLESS_DIR)/psg-mix/Vpsg_mix_tb
	./$(HEADLESS_DIR)/psg-mix/Vpsg_mix_tb
$(HEADLESS_DIR)/psg-mix/Vpsg_mix_tb: tests/psg_mix_tb.sv ../rtl/x1_psg_signed.sv ../rtl/x1_fm_mix.sv ../rtl/x1_audio_mix.sv Makefile
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module psg_mix_tb --Mdir $(@D) -j 4 tests/psg_mix_tb.sv ../rtl/x1_psg_signed.sv ../rtl/x1_fm_mix.sv ../rtl/x1_audio_mix.sv
.PHONY: test-psg-mix

test-machine-fm: $(HEADLESS_DIR)/machine-fm/Vmachine_fm_tb $(HEADLESS_DIR)/machine-fm-disabled/Vmachine_fm_tb $(HEADLESS_DIR)/machine-fm-single-nominal/Vmachine_fm_tb $(HEADLESS_DIR)/machine-fm-single-board/Vmachine_fm_tb
	./$(HEADLESS_DIR)/machine-fm/Vmachine_fm_tb
	./$(HEADLESS_DIR)/machine-fm-single-nominal/Vmachine_fm_tb
	./$(HEADLESS_DIR)/machine-fm-single-board/Vmachine_fm_tb
	@ulimit -c 0; if ./$(HEADLESS_DIR)/machine-fm-disabled/Vmachine_fm_tb >$(HEADLESS_DIR)/machine-fm-disabled/negative.log 2>&1; then \
		echo 'ERROR: disabled machine FM unexpectedly passed'; exit 1; \
	fi; rg -q 'shared FM programmed decode/read failed' $(HEADLESS_DIR)/machine-fm-disabled/negative.log || \
		{ echo 'ERROR: wrong disabled machine FM failure'; exit 1; }; \
	echo 'PASS shared-machine disabled-FM negative rejects missing CPU read'
$(HEADLESS_DIR)/machine-fm/Vmachine_fm_tb: tests/machine_fm_tb.sv $(MACHINE_SRC) Makefile
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module machine_fm_tb --Mdir $(@D) -j 4 tests/machine_fm_tb.sv $(MACHINE_SRC) -Wno-fatal
$(HEADLESS_DIR)/machine-fm-disabled/Vmachine_fm_tb: tests/machine_fm_tb.sv $(MACHINE_SRC) Makefile
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module machine_fm_tb -GFM_ENABLED=0 --Mdir $(@D) -j 4 tests/machine_fm_tb.sv $(MACHINE_SRC) -Wno-fatal
$(HEADLESS_DIR)/machine-fm-single-nominal/Vmachine_fm_tb: tests/machine_fm_tb.sv $(MACHINE_SRC) Makefile
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module machine_fm_tb -GSINGLE_CLOCK=1 -GMASTER_HZ=28636364 --Mdir $(@D) -j 4 tests/machine_fm_tb.sv $(MACHINE_SRC) -Wno-fatal
$(HEADLESS_DIR)/machine-fm-single-board/Vmachine_fm_tb: tests/machine_fm_tb.sv $(MACHINE_SRC) Makefile
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module machine_fm_tb -GSINGLE_CLOCK=1 -GMASTER_HZ=28571428 --Mdir $(@D) -j 4 tests/machine_fm_tb.sv $(MACHINE_SRC) -Wno-fatal
.PHONY: test-machine-fm

test-fm-decode: $(HEADLESS_DIR)/fm-decode/Vfm_decode_tb test-fm-cpu $(HEADLESS_DIR)/fm-cpu-disabled-$(FM_MASTER_HZ)/Vfm_cpu_tb
	./$(HEADLESS_DIR)/fm-decode/Vfm_decode_tb
	@ulimit -c 0; if ./$(HEADLESS_DIR)/fm-cpu-disabled-$(FM_MASTER_HZ)/Vfm_cpu_tb >$(HEADLESS_DIR)/fm-cpu-disabled-$(FM_MASTER_HZ)/negative.log 2>&1; then \
		echo 'ERROR: disabled FM decoder unexpectedly passed'; exit 1; \
	fi; rg -q 'CPU FM programmed decode/read failed' $(HEADLESS_DIR)/fm-cpu-disabled-$(FM_MASTER_HZ)/negative.log || \
		{ echo 'ERROR: wrong disabled FM decoder failure'; exit 1; }; \
	echo 'PASS actual CPU disabled-FM decode negative rejects missing read path'
$(HEADLESS_DIR)/fm-decode/Vfm_decode_tb: tests/fm_decode_tb.sv ../rtl/x1_fm_decode.sv
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module fm_decode_tb --Mdir $(@D) -j 4 tests/fm_decode_tb.sv ../rtl/x1_fm_decode.sv -Wno-fatal
$(HEADLESS_DIR)/fm-cpu-disabled-$(FM_MASTER_HZ)/Vfm_cpu_tb: $(FM_SRC) tests/fm_cpu_tb.sv $(FM_MANIFEST) ../rtl/cpu.v $(wildcard ../rtl/tv80/*.v) Makefile
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module fm_cpu_tb -GMASTER_HZ=$(FM_MASTER_HZ) -GDECODE_ENABLED=0 \
		--Mdir $(@D) -j 4 $(FM_SRC) tests/fm_cpu_tb.sv ../rtl/cpu.v $(wildcard ../rtl/tv80/*.v) -Wno-fatal
.PHONY: test-fm-decode

test-sio-x1: $(HEADLESS_DIR)/sio-x1/Vsio_x1_tb
	@for rate in 1 4 7; do ./$(HEADLESS_DIR)/sio-x1/Vsio_x1_tb +CE_PERIOD=$$rate || exit 1; done
$(HEADLESS_DIR)/sio-x1/Vsio_x1_tb: tests/sio_x1_tb.sv ../rtl/x1_sio_async.sv
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module sio_x1_tb --Mdir $(@D) -j 4 tests/sio_x1_tb.sv ../rtl/x1_sio_async.sv -Wno-fatal
.PHONY: test-sio-x1

test-machine-sio: $(HEADLESS_DIR)/machine-sio/Vmachine_sio_tb $(HEADLESS_DIR)/machine-sio-no-dma/Vmachine_sio_tb $(HEADLESS_DIR)/machine-sio-disabled/Vmachine_sio_tb $(HEADLESS_DIR)/machine-sio-x1/Vmachine_sio_tb $(HEADLESS_DIR)/machine-sio-x1-no-dma/Vmachine_sio_tb
	./$(HEADLESS_DIR)/machine-sio/Vmachine_sio_tb
	./$(HEADLESS_DIR)/machine-sio-no-dma/Vmachine_sio_tb
	./$(HEADLESS_DIR)/machine-sio-x1/Vmachine_sio_tb
	./$(HEADLESS_DIR)/machine-sio-x1-no-dma/Vmachine_sio_tb
	@ulimit -c 0; if ./$(HEADLESS_DIR)/machine-sio-disabled/Vmachine_sio_tb >$(HEADLESS_DIR)/machine-sio-disabled/negative.log 2>&1; then \
		echo 'ERROR: disabled SIO machine unexpectedly passed'; exit 1; \
	fi; rg -q 'machine SIO programmed status/read failed' $(HEADLESS_DIR)/machine-sio-disabled/negative.log || \
		{ echo 'ERROR: wrong disabled SIO machine failure'; exit 1; }; \
	echo 'PASS shared machine disabled-SIO negative rejects missing CPU read path'
$(HEADLESS_DIR)/machine-sio/Vmachine_sio_tb: tests/machine_sio_tb.sv $(MACHINE_SRC) Makefile
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module machine_sio_tb --Mdir $(@D) -j 4 tests/machine_sio_tb.sv $(MACHINE_SRC) -Wno-fatal
$(HEADLESS_DIR)/machine-sio-no-dma/Vmachine_sio_tb: tests/machine_sio_tb.sv $(MACHINE_SRC) Makefile
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module machine_sio_tb -GDMA_ENABLED=0 --Mdir $(@D) -j 4 tests/machine_sio_tb.sv $(MACHINE_SRC) -Wno-fatal
$(HEADLESS_DIR)/machine-sio-disabled/Vmachine_sio_tb: tests/machine_sio_tb.sv $(MACHINE_SRC) Makefile
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module machine_sio_tb -GSIO_ENABLED=0 --Mdir $(@D) -j 4 tests/machine_sio_tb.sv $(MACHINE_SRC) -Wno-fatal
$(HEADLESS_DIR)/machine-sio-x1/Vmachine_sio_tb: tests/machine_sio_tb.sv $(MACHINE_SRC) Makefile
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module machine_sio_tb -GSERIAL_X1=1 --Mdir $(@D) -j 4 tests/machine_sio_tb.sv $(MACHINE_SRC) -Wno-fatal
$(HEADLESS_DIR)/machine-sio-x1-no-dma/Vmachine_sio_tb: tests/machine_sio_tb.sv $(MACHINE_SRC) Makefile
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module machine_sio_tb -GSERIAL_X1=1 -GDMA_ENABLED=0 --Mdir $(@D) -j 4 tests/machine_sio_tb.sv $(MACHINE_SRC) -Wno-fatal
.PHONY: test-machine-sio

test-z-text-visibility:
	python3 tests/test_z_text_visibility.py
.PHONY: test-z-text-visibility

test-machine-z-priority-cdc: $(HEADLESS_DIR)/z-priority-machine-cdc/Vz_priority_machine_cdc_tb $(HEADLESS_DIR)/z-priority-machine-cdc-negative/Vz_priority_machine_cdc_tb
	@for half in 17500 11640 25000; do ./$< +VIDEO_HALF_PS=$$half || exit 1; done
	@ulimit -c 0; log=$$(mktemp /tmp/x1-z-priority-cdc-negative-XXXXXX); \
	  ./$(HEADLESS_DIR)/z-priority-machine-cdc-negative/Vz_priority_machine_cdc_tb >$$log 2>&1; result=$$?; \
	  test $$result -ne 0 && rg -q 'CPU sweep incomplete' $$log || { cat $$log; exit 1; }; \
	  echo "PASS disabled-priority negative: unchanged CPU/CDC oracle rejects missing connection (log $$log)"
$(HEADLESS_DIR)/z-priority-machine-cdc/Vz_priority_machine_cdc_tb: $(V_SRC) tests/z_priority_machine_cdc_tb.sv Makefile
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module z_priority_machine_cdc_tb --Mdir $(@D) \
	  -j 4 $(V_SRC) tests/z_priority_machine_cdc_tb.sv -Wno-fatal
$(HEADLESS_DIR)/z-priority-machine-cdc-negative/Vz_priority_machine_cdc_tb: $(V_SRC) tests/z_priority_machine_cdc_tb.sv Makefile
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module z_priority_machine_cdc_tb --Mdir $(@D) \
	  -GPRIORITY_CPU=0 -j 4 $(V_SRC) tests/z_priority_machine_cdc_tb.sv -Wno-fatal
.PHONY: test-machine-z-priority-cdc

test-dam-control: $(HEADLESS_DIR)/dam-control/Vdam_control_tb
	./$(HEADLESS_DIR)/dam-control/Vdam_control_tb
$(HEADLESS_DIR)/dam-control/Vdam_control_tb: tests/dam_control_tb.sv ../rtl/x1_dam_control.sv Makefile
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module dam_control_tb --Mdir $(@D) \
	  -j 4 tests/dam_control_tb.sv ../rtl/x1_dam_control.sv
.PHONY: test-dam-control
test-machine-dam-control: headless
	python3 tests/test_dam_control.py ./$(HEADLESS_EXE)
.PHONY: test-machine-dam-control

test-mister-matrix-safety:
	python3 ../scripts/test_mister_matrix.py
.PHONY: test-mister-matrix-safety

test-z-palette-probe-scripts:
	@for script in probe_z_palette_quartus.sh probe_z_palette_quartus_apple.sh; do \
	  bash -n ../scripts/$$script || exit 1; \
	  bash ../scripts/$$script --invalid >/dev/null 2>&1; result=$$?; \
	  test $$result -eq 2 || exit 1; done
.PHONY: test-z-palette-probe-scripts

test-z-palette-ram: $(HEADLESS_DIR)/z-palette-ram/Vz_palette_ram_tb
	@for half in 17500 11640 25000; do for rate in 1 4 7; do \
	  ./$(HEADLESS_DIR)/z-palette-ram/Vz_palette_ram_tb +VIDEO_HALF_PS=$$half +CE_PERIOD=$$rate || exit 1; done; done
$(HEADLESS_DIR)/z-palette-ram/Vz_palette_ram_tb: tests/z_palette_ram_tb.sv ../rtl/x1_z_palette_ram.sv Makefile
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module z_palette_ram_tb --Mdir $(HEADLESS_DIR)/z-palette-ram \
	  -j 4 tests/z_palette_ram_tb.sv ../rtl/x1_z_palette_ram.sv
.PHONY: test-z-palette-ram
test-z-internal-palette: $(HEADLESS_DIR)/z-internal-palette/Vz_internal_palette_tb
	@for half in 17500 11640 25000; do for rate in 1 4 7; do \
	  ./$(HEADLESS_DIR)/z-internal-palette/Vz_internal_palette_tb +VIDEO_HALF_PS=$$half +CE_PERIOD=$$rate || exit 1; done; done
$(HEADLESS_DIR)/z-internal-palette/Vz_internal_palette_tb: tests/z_internal_palette_tb.sv ../rtl/x1_z_palette_ram.sv Makefile
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module z_internal_palette_tb --Mdir $(@D) \
	  -j 4 tests/z_internal_palette_tb.sv ../rtl/x1_z_palette_ram.sv
.PHONY: test-z-internal-palette
test-z-text-palette: $(HEADLESS_DIR)/z-text-palette/Vz_text_palette_tb
	@for half in 17500 11640 25000; do for hold in 1 4 7; do \
	  ./$(HEADLESS_DIR)/z-text-palette/Vz_text_palette_tb +VIDEO_HALF_PS=$$half +HOLD_EDGES=$$hold || exit 1; done; done
$(HEADLESS_DIR)/z-text-palette/Vz_text_palette_tb: tests/z_text_palette_tb.sv ../rtl/x1_z_text_palette.sv ../rtl/x1_cdc_snapshot.sv Makefile
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module z_text_palette_tb --Mdir $(@D) \
	  -j 4 tests/z_text_palette_tb.sv ../rtl/x1_z_text_palette.sv ../rtl/x1_cdc_snapshot.sv
.PHONY: test-z-text-palette
test-z-layer-order: $(HEADLESS_DIR)/z-layer-order/Vz_layer_order_tb
	./$(HEADLESS_DIR)/z-layer-order/Vz_layer_order_tb
	@negative_log=$$(mktemp $(HEADLESS_DIR)/z-layer-order/negative-XXXXXX); \
	  if (ulimit -c 0; ./$(HEADLESS_DIR)/z-layer-order/Vz_layer_order_tb +NEGATIVE_MIDDLE) >$$negative_log 2>&1; then \
	    echo "FAIL: wrong between-screen order was accepted"; exit 1; \
	  fi; \
	  rg -q 'order raw=.*12 two=1 .*expected 1/2' $$negative_log && \
	  echo "PASS: unchanged ordering oracle rejects text-on-top substitution for field 10"
$(HEADLESS_DIR)/z-layer-order/Vz_layer_order_tb: tests/z_layer_order_tb.sv ../rtl/x1_z_layer_order.sv Makefile
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module z_layer_order_tb --Mdir $(@D) \
	  -j 4 tests/z_layer_order_tb.sv ../rtl/x1_z_layer_order.sv
.PHONY: test-z-layer-order
test-z-priority-register: $(HEADLESS_DIR)/z-priority-register/Vz_priority_register_tb
	@for hold in 1 4 7; do ./$(HEADLESS_DIR)/z-priority-register/Vz_priority_register_tb +HOLD_EDGES=$$hold || exit 1; done
$(HEADLESS_DIR)/z-priority-register/Vz_priority_register_tb: tests/z_priority_register_tb.sv ../rtl/x1_z_priority_register.sv Makefile
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module z_priority_register_tb --Mdir $(@D) \
	  -j 4 tests/z_priority_register_tb.sv ../rtl/x1_z_priority_register.sv
.PHONY: test-z-priority-register

test-z-palette-access: $(HEADLESS_DIR)/z-palette-access/Vz_palette_access_tb
	@for half in 17500 11640 25000; do for rate in 1 4 7; do \
	  ./$(HEADLESS_DIR)/z-palette-access/Vz_palette_access_tb +VIDEO_HALF_PS=$$half +CE_PERIOD=$$rate || exit 1; done; done
$(HEADLESS_DIR)/z-palette-access/Vz_palette_access_tb: tests/z_palette_access_tb.sv ../rtl/x1_z_palette_access.sv ../rtl/x1_z_palette_ram.sv Makefile
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module z_palette_access_tb --Mdir $(HEADLESS_DIR)/z-palette-access \
	  -j 4 tests/z_palette_access_tb.sv ../rtl/x1_z_palette_access.sv ../rtl/x1_z_palette_ram.sv
.PHONY: test-z-palette-access

test-z-gram-fetch: $(HEADLESS_DIR)/z-gram-fetch/Vz_gram_fetch_tb
	@for half in 17500 11640 25000; do \
	  ./$(HEADLESS_DIR)/z-gram-fetch/Vz_gram_fetch_tb +video_half=$$half || exit 1; done
$(HEADLESS_DIR)/z-gram-fetch/Vz_gram_fetch_tb: tests/z_gram_fetch_tb.sv ../rtl/x1_z_gram_fetch.sv ../rtl/x1_video_ram.v ../rtl/x1_video_timing.sv Makefile
	mkdir -p $(@D)
	$(V) --binary --timing --assert --timescale 1ps/1ps --top-module z_gram_fetch_tb --Mdir $(@D) \
	  -j 4 tests/z_gram_fetch_tb.sv ../rtl/x1_z_gram_fetch.sv ../rtl/x1_video_ram.v ../rtl/x1_video_timing.sv
.PHONY: test-z-gram-fetch

test-z-graphics: $(HEADLESS_DIR)/z-graphics/Vz_graphics_tb
	@for half in 17500 11640 25000; do ./$(HEADLESS_DIR)/z-graphics/Vz_graphics_tb +video_half=$$half || exit 1; done
$(HEADLESS_DIR)/z-graphics/Vz_graphics_tb: tests/z_graphics_tb.sv ../rtl/x1_z_graphics.sv ../rtl/x1_z_gram_fetch.sv Makefile
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module z_graphics_tb --Mdir $(@D) \
	  -j 4 tests/z_graphics_tb.sv ../rtl/x1_z_graphics.sv ../rtl/x1_z_gram_fetch.sv
.PHONY: test-z-graphics

test-z-palette-pins: $(HEADLESS_DIR)/z-palette-pins/Vz_palette_pins_tb
	@for half in 17500 11640 25000; do ./$(HEADLESS_DIR)/z-palette-pins/Vz_palette_pins_tb +video_half=$$half || exit 1; done
$(HEADLESS_DIR)/z-palette-pins/Vz_palette_pins_tb: tests/z_palette_pins_tb.sv ../rtl/x1_z_graphics.sv ../rtl/x1_z_gram_fetch.sv ../rtl/x1_video_ram.v ../rtl/x1_z_palette_ram.sv Makefile
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module z_palette_pins_tb --Mdir $(@D) \
	  -j 4 tests/z_palette_pins_tb.sv ../rtl/x1_z_graphics.sv ../rtl/x1_z_gram_fetch.sv ../rtl/x1_video_ram.v ../rtl/x1_z_palette_ram.sv
.PHONY: test-z-palette-pins

test-z-palette-owner: $(HEADLESS_DIR)/z-palette-owner/Vz_palette_owner_tb
	@for half in 17500 11640 25000; do \
	  ./$(HEADLESS_DIR)/z-palette-owner/Vz_palette_owner_tb +video_half=$$half || exit 1; done
$(HEADLESS_DIR)/z-palette-owner/Vz_palette_owner_tb: tests/z_palette_owner_tb.sv ../rtl/x1_z_palette_owner.sv ../rtl/x1_z_palette_access.sv ../rtl/x1_z_palette_ram.sv Makefile
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module z_palette_owner_tb --Mdir $(@D) \
	  -j 4 tests/z_palette_owner_tb.sv ../rtl/x1_z_palette_owner.sv ../rtl/x1_z_palette_access.sv ../rtl/x1_z_palette_ram.sv
.PHONY: test-z-palette-owner

test-turbo-dsw: $(HEADLESS_DIR)/turbo-dsw/Vturbo_dsw_tb
	./$(HEADLESS_DIR)/turbo-dsw/Vturbo_dsw_tb
$(HEADLESS_DIR)/turbo-dsw/Vturbo_dsw_tb: tests/turbo_dsw_tb.sv ../rtl/x1_turbo_dsw.sv Makefile
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module turbo_dsw_tb --Mdir $(HEADLESS_DIR)/turbo-dsw \
		-j 4 tests/turbo_dsw_tb.sv ../rtl/x1_turbo_dsw.sv
.PHONY: test-turbo-dsw

test-machine-turbo-dsw-fast: turbo-kanji-render-fast
	python3 tests/test_machine_turbo_dsw.py ./obj_dir_v12_kanji_render_fast/Vtop --expected $(TURBO_DSW)
test-machine-turbo-dsw-timing: turbo-kanji-render
	python3 tests/test_machine_turbo_dsw.py ./obj_dir_v12_kanji_render/Vtop --expected $(TURBO_DSW)
.PHONY: test-machine-turbo-dsw-fast test-machine-turbo-dsw-timing

test-turbo-dsw-snapshot: test-machine-kanji-render-snapshot
	$(MAKE) turbo-kanji-savable KANJI_VIDEO=1 KANJI_RENDER=1 TURBO_DSW=245 \
		KANJI_SAVE_DIR=obj_dir_v12_dsw_f5_savable KANJI_PLAIN_SAVE_DIR=obj_dir_v12_dsw_f5_plain_savable
	python3 tests/test_turbo_dsw_snapshot.py ./obj_dir_v12_kanji_render_savable/Vtop ./obj_dir_v12_dsw_f5_savable/Vtop
.PHONY: test-turbo-dsw-snapshot

test-kanji-conversion:
	python3 tests/test_prepare_kanji.py
.PHONY: test-kanji-conversion

test-kanji-address: $(HEADLESS_DIR)/kanji-address/Vkanji_address_tb
	./$(HEADLESS_DIR)/kanji-address/Vkanji_address_tb
$(HEADLESS_DIR)/kanji-address/Vkanji_address_tb: tests/kanji_address_tb.sv ../rtl/x1_kanji_address.sv Makefile
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module kanji_address_tb --Mdir $(HEADLESS_DIR)/kanji-address \
		-j 4 tests/kanji_address_tb.sv ../rtl/x1_kanji_address.sv
.PHONY: test-kanji-address

test-kanji-decode: $(HEADLESS_DIR)/kanji-decode/Vkanji_decode_tb
	./$(HEADLESS_DIR)/kanji-decode/Vkanji_decode_tb
$(HEADLESS_DIR)/kanji-decode/Vkanji_decode_tb: tests/kanji_decode_tb.sv ../rtl/x1_kanji_decode.sv ../rtl/x1_kanji_address.sv Makefile
	mkdir -p $(HEADLESS_DIR)/kanji-decode
	$(V) --binary --timing --assert --top-module kanji_decode_tb --Mdir $(HEADLESS_DIR)/kanji-decode \
		-j 4 tests/kanji_decode_tb.sv ../rtl/x1_kanji_decode.sv ../rtl/x1_kanji_address.sv
.PHONY: test-kanji-decode

test-kanji-rom: $(HEADLESS_DIR)/kanji-rom/Vkanji_rom_tb
	@for half in 17500 11640 25000; do ./$(HEADLESS_DIR)/kanji-rom/Vkanji_rom_tb +VIDEO_HALF_PS=$$half || exit 1; done
$(HEADLESS_DIR)/kanji-rom/Vkanji_rom_tb: tests/kanji_rom_tb.sv ../rtl/x1_kanji_rom.sv ../rtl/x1_kanji_address.sv Makefile
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module kanji_rom_tb --Mdir $(HEADLESS_DIR)/kanji-rom \
		-j 4 tests/kanji_rom_tb.sv ../rtl/x1_kanji_rom.sv ../rtl/x1_kanji_address.sv
.PHONY: test-kanji-rom

test-kanji-cg-selector: $(HEADLESS_DIR)/kanji-cg-selector/Vkanji_cg_selector_tb
	./$(HEADLESS_DIR)/kanji-cg-selector/Vkanji_cg_selector_tb
$(HEADLESS_DIR)/kanji-cg-selector/Vkanji_cg_selector_tb: tests/kanji_cg_selector_tb.sv ../rtl/x1_pcg_selector.sv Makefile
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module kanji_cg_selector_tb --Mdir $(HEADLESS_DIR)/kanji-cg-selector \
		-j 4 tests/kanji_cg_selector_tb.sv ../rtl/x1_pcg_selector.sv
.PHONY: test-kanji-cg-selector

test-kanji-cg-access: $(HEADLESS_DIR)/kanji-cg-access/Vkanji_cg_access_tb
	@for half in 17500 11640 25000; do ./$(HEADLESS_DIR)/kanji-cg-access/Vkanji_cg_access_tb +VIDEO_HALF_PS=$$half || exit 1; done
$(HEADLESS_DIR)/kanji-cg-access/Vkanji_cg_access_tb: tests/kanji_cg_access_tb.sv ../rtl/x1_kanji_rom.sv ../rtl/x1_pcg_access.v ../rtl/x1_reset_release.sv Makefile
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module kanji_cg_access_tb --Mdir $(HEADLESS_DIR)/kanji-cg-access \
		-j 4 tests/kanji_cg_access_tb.sv ../rtl/x1_kanji_rom.sv ../rtl/x1_pcg_access.v ../rtl/x1_reset_release.sv
.PHONY: test-kanji-cg-access

KANJI_CG_CPU_SRC = ../rtl/cpu.v ../rtl/tv80/tv80e.v ../rtl/tv80/tv80_core.v ../rtl/tv80/tv80_mcode.v ../rtl/tv80/tv80_alu.v ../rtl/tv80/tv80_reg.v
test-kanji-cg-cpu: $(HEADLESS_DIR)/kanji-cg-cpu/Vkanji_cg_cpu_tb
	@for half in 17500 11640; do for rate in 1 4 8; do ./$(HEADLESS_DIR)/kanji-cg-cpu/Vkanji_cg_cpu_tb +CE_PERIOD=$$rate +VIDEO_HALF_PS=$$half || exit 1; done; done
$(HEADLESS_DIR)/kanji-cg-cpu/Vkanji_cg_cpu_tb: tests/kanji_cg_cpu_tb.sv ../rtl/x1_kanji_rom.sv ../rtl/x1_pcg_selector.sv ../rtl/x1_pcg_access.v ../rtl/x1_reset_release.sv $(KANJI_CG_CPU_SRC) Makefile
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module kanji_cg_cpu_tb --Mdir $(HEADLESS_DIR)/kanji-cg-cpu \
		-j 4 tests/kanji_cg_cpu_tb.sv ../rtl/x1_kanji_rom.sv ../rtl/x1_pcg_selector.sv ../rtl/x1_pcg_access.v \
		../rtl/x1_reset_release.sv $(KANJI_CG_CPU_SRC) -Wno-fatal
.PHONY: test-kanji-cg-cpu

test-fm: $(HEADLESS_DIR)/fm-$(FM_MASTER_HZ)/Vfm_tb
	./$(HEADLESS_DIR)/fm-$(FM_MASTER_HZ)/Vfm_tb +OUTPUT=$(HEADLESS_DIR)/fm-$(FM_MASTER_HZ)/note
	python3 tests/test_fm_audio.py $(HEADLESS_DIR)/fm-$(FM_MASTER_HZ)/note

$(HEADLESS_DIR)/fm-$(FM_MASTER_HZ)/Vfm_tb: $(FM_SRC) tests/fm_tb.sv $(FM_MANIFEST) Makefile
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module fm_tb -GMASTER_HZ=$(FM_MASTER_HZ) \
		--Mdir $(HEADLESS_DIR)/fm-$(FM_MASTER_HZ) -j 4 $(FM_SRC) tests/fm_tb.sv -Wno-fatal
.PHONY: test-fm

test-fm-psg: $(HEADLESS_DIR)/fm-psg-$(FM_MASTER_HZ)/Vfm_tb
	./$(HEADLESS_DIR)/fm-psg-$(FM_MASTER_HZ)/Vfm_tb +OUTPUT=$(HEADLESS_DIR)/fm-psg-$(FM_MASTER_HZ)/mixed
	python3 tests/test_fm_psg_audio.py $(HEADLESS_DIR)/fm-psg-$(FM_MASTER_HZ)/mixed
$(HEADLESS_DIR)/fm-psg-$(FM_MASTER_HZ)/Vfm_tb: $(FM_SRC) $(PSG_SRC) tests/fm_tb.sv $(FM_MANIFEST) Makefile
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module fm_tb -GMASTER_HZ=$(FM_MASTER_HZ) -GMIXED_PSG=1 \
		--Mdir $(@D) -j 4 $(FM_SRC) $(PSG_SRC) tests/fm_tb.sv -Wno-fatal
.PHONY: test-fm-psg

test-fm-cpu: $(HEADLESS_DIR)/fm-cpu-$(FM_MASTER_HZ)/Vfm_cpu_tb
	@for rate in 1 4 8; do ./$(HEADLESS_DIR)/fm-cpu-$(FM_MASTER_HZ)/Vfm_cpu_tb +CE_PERIOD=$$rate || exit 1; done

$(HEADLESS_DIR)/fm-cpu-$(FM_MASTER_HZ)/Vfm_cpu_tb: $(FM_SRC) tests/fm_cpu_tb.sv $(FM_MANIFEST) ../rtl/cpu.v $(wildcard ../rtl/tv80/*.v) Makefile
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module fm_cpu_tb -GMASTER_HZ=$(FM_MASTER_HZ) \
		--Mdir $(HEADLESS_DIR)/fm-cpu-$(FM_MASTER_HZ) -j 4 $(FM_SRC) tests/fm_cpu_tb.sv \
		../rtl/cpu.v $(wildcard ../rtl/tv80/*.v) -Wno-fatal
.PHONY: test-fm-cpu
headless: $(HEADLESS_EXE)

interactive: obj_dir_interactive/Vtop

# Clocked, synthesis-style execution: inherited intra-assignment delays are
# ignored. Keep the headless --timing build as the scheduling reference.
fast: obj_dir_fast/Vtop

# Isolated base savable runner for qualification while a frozen historical
# obj_dir_fast executable remains in use. Same fast/SDL model, separate output.
QUALIFICATION_DIR ?= obj_dir_qualification_fast
qualification-fast: $(QUALIFICATION_DIR)/Vtop
$(QUALIFICATION_DIR)/Vtop: $(V_SRC) sim_headless.cpp frame_capture.h audio_capture.h d88_image.h sdl_frontend.h Makefile $(MACHINE_MANIFEST)
	$(V) -cc --no-timing --savable --assert --trace-fst --exe --build -j 4 --Mdir $(QUALIFICATION_DIR) --top-module top \
		-CFLAGS "-std=c++20 -DX1_SAVABLE -DX1_SDL $(shell sdl2-config --cflags)" -MAKEFLAGS "OPT_FAST=-O3" \
		-LDFLAGS "$(shell sdl2-config --libs)" $(V_SRC) sim_headless.cpp -Wno-fatal -o Vtop
.PHONY: qualification-fast

# Experimental shared-clock model; baseline builds and board default stay intact.
single: obj_dir_single/Vtop
single-fast: obj_dir_single_fast/Vtop

# Partial Turbo peripherals behind an explicit experimental model parameter.
turbo: obj_dir_turbo/Vtop
Z_VIDEO_DIR ?= obj_dir_v13_z_video
Z_MULTIMODE ?= 0
Z_INTERNAL8 ?= 0
Z_TEXT_CPU ?= 0
turbo-z-video: $(Z_VIDEO_DIR)/Vtop
$(Z_VIDEO_DIR)/Vtop: $(V_SRC) sim_headless.cpp frame_capture.h audio_capture.h d88_image.h Makefile $(MACHINE_MANIFEST)
	$(V) -cc --timing --assert --trace-fst --exe --build -j 4 --Mdir $(Z_VIDEO_DIR) --top-module top \
	  -GTURBO=1 -GTURBO_VIDEO_MASTER=1 -GTURBO_Z_PALETTE_CPU=1 -GTURBO_Z_VIDEO=1 \
	  -GTURBO_Z_MULTIMODE=$(Z_MULTIMODE) -GTURBO_Z_INTERNAL8=$(Z_INTERNAL8) -GTURBO_Z_TEXT_CPU=$(Z_TEXT_CPU) \
	  -CFLAGS "-std=c++20 -DX1_TURBO_FOUNDATION -DX1_TURBO_VIDEO_MASTER -DX1_Z_PALETTE_CPU -DX1_Z_VIDEO $(if $(filter 1,$(Z_MULTIMODE)),-DX1_Z_MULTIMODE) $(if $(filter 1,$(Z_INTERNAL8)),-DX1_Z_INTERNAL8) $(if $(filter 1,$(Z_TEXT_CPU)),-DX1_Z_TEXT_CPU)" \
	  -MAKEFLAGS "OPT_FAST=-O3" $(V_SRC) sim_headless.cpp -Wno-fatal -o Vtop
.PHONY: turbo-z-video
turbo-z-paired:
	$(MAKE) turbo-z-video Z_MULTIMODE=1 Z_TEXT_CPU=1 Z_VIDEO_DIR=obj_dir_v13_z_paired
.PHONY: turbo-z-paired
test-machine-z-paired: turbo-z-paired
	@run_root=$$(mktemp -d obj_dir_v13_z_paired/paired-matrix-XXXXXX); \
	  cp tests/test_machine_z_video.py tests/z80_fixture.py obj_dir_v13_z_paired/Vtop $$run_root/ && \
	  for priority in 0x10 0x18 0x11 0x19 0x12 0x1a; do \
	    for palette in identity custom; do \
	      palette_arg=; [ $$palette != custom ] || palette_arg=--custom; \
	      for reset in cold warm; do \
	        reset_arg=; [ $$reset != warm ] || reset_arg=--warm; \
	        python3 $$run_root/test_machine_z_video.py $$run_root/Vtop --mode paired64 \
	          --priority $$priority --screen 1 $$palette_arg $$reset_arg \
	          --output $$run_root/$$priority-$$palette-$$reset || exit $$?; \
	      done; \
	    done; \
	  done
.PHONY: test-machine-z-paired
test-machine-z-paired-text: turbo-z-paired
	@run_root=$$(mktemp -d obj_dir_v13_z_paired/text-matrix-XXXXXX); \
	  cp tests/test_machine_z_video.py tests/z80_fixture.py obj_dir_v13_z_paired/Vtop $$run_root/ && \
	  cp ../rtl/legacy/x1_cg8.v $$run_root/cg8_reference.v && \
	  for priority in 0x10 0x18 0x11 0x19 0x12 0x1a; do \
	    for reset in cold warm; do \
	      reset_arg=; [ $$reset != warm ] || reset_arg=--warm; \
	      python3 $$run_root/test_machine_z_video.py $$run_root/Vtop --mode paired64 \
	        --priority $$priority --screen 1 --custom --text $$reset_arg \
	        --output $$run_root/$$priority-$$reset || exit $$?; \
	    done; \
	  done
.PHONY: test-machine-z-paired-text
test-machine-z-single-text: turbo-z-paired
	@run_root=$$(mktemp -d obj_dir_v13_z_paired/single-text-matrix-XXXXXX); \
	  cp tests/test_machine_z_video.py tests/z80_fixture.py obj_dir_v13_z_paired/Vtop $$run_root/ && \
	  cp ../rtl/legacy/x1_cg8.v $$run_root/cg8_reference.v && \
	  for mode in full dual64; do \
	    for priority in 0x00 0x01 0xea 0xeb; do \
	      for reset in cold warm; do \
	        reset_arg=; [ $$reset != warm ] || reset_arg=--warm; \
	        python3 $$run_root/test_machine_z_video.py $$run_root/Vtop --mode $$mode \
	          --priority $$priority --screen 1 --custom --text $$reset_arg \
	          --output $$run_root/$$mode-$$priority-$$reset || exit $$?; \
	      done; \
	    done; \
	  done
.PHONY: test-machine-z-single-text
test-machine-z-text-reverse: turbo-z-paired
	@run_root=$$(mktemp -d obj_dir_v13_z_paired/reverse-matrix-XXXXXX); \
	  cp tests/test_machine_z_video.py tests/z80_fixture.py obj_dir_v13_z_paired/Vtop $$run_root/ && \
	  cp ../rtl/legacy/x1_cg8.v $$run_root/cg8_reference.v && \
	  python3 $$run_root/test_machine_z_video.py $$run_root/Vtop --mode paired64 \
	    --priority 0x1a --screen 1 --custom --text --reverse --warm --output $$run_root/reverse-middle-warm
.PHONY: test-machine-z-text-reverse
turbo-z-multimode:
	$(MAKE) turbo-z-video Z_MULTIMODE=1 Z_VIDEO_DIR=obj_dir_v13_z_multimode
.PHONY: turbo-z-multimode
turbo-z-internal8:
	$(MAKE) turbo-z-video Z_MULTIMODE=1 Z_INTERNAL8=1 Z_VIDEO_DIR=obj_dir_v13_z_internal8
.PHONY: turbo-z-internal8
test-machine-z-internal8: turbo-z-internal8
	@run_root=$$(mktemp -d obj_dir_v13_z_internal8/internal-matrix-XXXXXX); \
	  cp tests/test_machine_z_video.py tests/z80_fixture.py obj_dir_v13_z_internal8/Vtop $$run_root/ && \
	  for palette in identity custom; do \
	    palette_arg=; [ $$palette != custom ] || palette_arg=--custom; \
	    for reset in cold warm; do \
	      reset_arg=; [ $$reset != warm ] || reset_arg=--warm; \
	      python3 $$run_root/test_machine_z_video.py $$run_root/Vtop \
	        --mode internal8 $$palette_arg $$reset_arg \
	        --output $$run_root/$$palette-$$reset || exit $$?; \
	    done; \
	  done
.PHONY: test-machine-z-internal8
Z_TEXT_DIR ?= obj_dir_v13_z_text_cpu
turbo-z-text-cpu: $(Z_TEXT_DIR)/Vtop
$(Z_TEXT_DIR)/Vtop: $(V_SRC) sim_headless.cpp frame_capture.h audio_capture.h d88_image.h Makefile $(MACHINE_MANIFEST)
	$(V) -cc --timing --assert --trace-fst --exe --build -j 4 --Mdir $(Z_TEXT_DIR) --top-module top \
	  -GTURBO=1 -GTURBO_Z_PALETTE_CPU=1 -GTURBO_Z_TEXT_CPU=1 \
	  -CFLAGS "-std=c++20 -DX1_TURBO_FOUNDATION -DX1_Z_PALETTE_CPU -DX1_Z_TEXT_CPU" \
	  -MAKEFLAGS "OPT_FAST=-O3" $(V_SRC) sim_headless.cpp -Wno-fatal -o Vtop
.PHONY: turbo-z-text-cpu
test-machine-z-text-cpu: turbo-z-text-cpu headless
	@run_root=$$(mktemp -d $(Z_TEXT_DIR)/cpu-matrix-XXXXXX); \
	  cp tests/test_machine_z_text.py tests/z80_fixture.py $(Z_TEXT_DIR)/Vtop $$run_root/ && \
	  cp $(HEADLESS_EXE) $$run_root/Vdisabled && \
	  python3 $$run_root/test_machine_z_text.py $$run_root/Vtop --output $$run_root/cold && \
	  python3 $$run_root/test_machine_z_text.py $$run_root/Vtop --warm --output $$run_root/warm && \
	  python3 $$run_root/test_machine_z_text.py $$run_root/Vtop --mode 0x90 --output $$run_root/c64-cold && \
	  python3 $$run_root/test_machine_z_text.py $$run_root/Vtop --mode 0x90 --warm --output $$run_root/c64-warm && \
	  python3 $$run_root/test_machine_z_text.py $$run_root/Vdisabled --expect-disabled --output $$run_root/disabled
.PHONY: test-machine-z-text-cpu
test-machine-z-priority-cpu: turbo-z-text-cpu headless
	@run_root=$$(mktemp -d $(Z_TEXT_DIR)/priority-matrix-XXXXXX); \
	  cp tests/test_machine_z_priority.py tests/z80_fixture.py $(Z_TEXT_DIR)/Vtop $$run_root/ && \
	  cp $(HEADLESS_EXE) $$run_root/Vdisabled && \
	  python3 $$run_root/test_machine_z_priority.py $$run_root/Vtop --output $$run_root/cold && \
	  python3 $$run_root/test_machine_z_priority.py $$run_root/Vtop --warm --output $$run_root/warm && \
	  python3 $$run_root/test_machine_z_priority.py $$run_root/Vtop --mode 0x90 --output $$run_root/c64-cold && \
	  python3 $$run_root/test_machine_z_priority.py $$run_root/Vtop --mode 0x90 --warm --output $$run_root/c64-warm && \
	  python3 $$run_root/test_machine_z_priority.py $$run_root/Vdisabled --expect-disabled --output $$run_root/disabled
.PHONY: test-machine-z-priority-cpu
test-machine-z-video: turbo-z-video
	@run_root=$$(mktemp -d $(Z_VIDEO_DIR)/pixel-matrix-XXXXXX); \
	  cp tests/test_machine_z_video.py tests/z80_fixture.py $(Z_VIDEO_DIR)/Vtop $$run_root/ && \
	  python3 $$run_root/test_machine_z_video.py $$run_root/Vtop --output $$run_root/identity-cold && \
	  python3 $$run_root/test_machine_z_video.py $$run_root/Vtop --warm --output $$run_root/identity-warm && \
	  python3 $$run_root/test_machine_z_video.py $$run_root/Vtop --custom --output $$run_root/custom-cold && \
	  python3 $$run_root/test_machine_z_video.py $$run_root/Vtop --custom --warm --output $$run_root/custom-warm
.PHONY: test-machine-z-video
test-machine-z-multimode: turbo-z-multimode
	@run_root=$$(mktemp -d obj_dir_v13_z_multimode/mode-matrix-XXXXXX); \
	  cp tests/test_machine_z_video.py tests/z80_fixture.py obj_dir_v13_z_multimode/Vtop $$run_root/ && \
	  for mode in wide64 tall64 dual64; do \
	    screens=0; [ $$mode != dual64 ] || screens="0 1"; \
	    for screen in $$screens; do \
	      for palette in identity custom; do \
	        palette_arg=; [ $$palette != custom ] || palette_arg=--custom; \
	        for reset in cold warm; do \
	          reset_arg=; [ $$reset != warm ] || reset_arg=--warm; \
	          python3 $$run_root/test_machine_z_video.py $$run_root/Vtop \
	            --mode $$mode --screen $$screen $$palette_arg $$reset_arg \
	            --output $$run_root/$$mode-$$screen-$$palette-$$reset || exit $$?; \
	        done; \
	      done; \
	    done; \
	  done
.PHONY: test-machine-z-multimode
Z_PALETTE_DIR ?= obj_dir_v12_z_palette_cpu
Z_PALETTE_CPU ?= 1
turbo-z-palette-cpu: $(Z_PALETTE_DIR)/Vtop
$(Z_PALETTE_DIR)/Vtop: $(V_SRC) sim_headless.cpp frame_capture.h audio_capture.h d88_image.h Makefile $(MACHINE_MANIFEST)
	$(V) -cc --timing --assert --trace-fst --exe --build -j 4 --Mdir $(Z_PALETTE_DIR) --top-module top \
	  -GTURBO=1 -GTURBO_Z_PALETTE_CPU=$(Z_PALETTE_CPU) -CFLAGS "-std=c++20 -DX1_TURBO_FOUNDATION $(if $(filter 1,$(Z_PALETTE_CPU)),-DX1_Z_PALETTE_CPU)" \
	  -MAKEFLAGS "OPT_FAST=-O3" $(V_SRC) sim_headless.cpp -Wno-fatal -o Vtop
test-machine-z-palette-cpu: turbo-z-palette-cpu
	python3 tests/test_machine_z_palette.py ./$(Z_PALETTE_DIR)/Vtop
test-machine-z-palette-video: turbo-z-palette-cpu
	python3 tests/test_machine_z_palette.py ./$(Z_PALETTE_DIR)/Vtop --video
test-machine-z-palette-disabled:
	$(MAKE) turbo-z-palette-cpu Z_PALETTE_CPU=0 Z_PALETTE_DIR=obj_dir_v12_z_palette_disabled
	python3 tests/test_machine_z_palette.py ./obj_dir_v12_z_palette_disabled/Vtop --expect-disabled
.PHONY: turbo-z-palette-cpu test-machine-z-palette-cpu test-machine-z-palette-video test-machine-z-palette-disabled
turbo-single: obj_dir_turbo_single/Vtop
# Match the actual fitted single-master board clock, not the nominal crystal.
# Isolated, non-savable diagnostic runners; existing profiles stay unchanged.
BOARD_SINGLE_DIR ?= obj_dir_v12_board_single
BOARD_SINGLE_TIMING ?= --timing
turbo-board-single: $(BOARD_SINGLE_DIR)/Vtop
$(BOARD_SINGLE_DIR)/Vtop: $(V_SRC) sim_headless.cpp frame_capture.h audio_capture.h d88_image.h Makefile $(MACHINE_MANIFEST)
	$(V) -cc $(BOARD_SINGLE_TIMING) --assert --trace-fst --exe --build -j 4 --Mdir $(BOARD_SINGLE_DIR) --top-module top \
		$(TURBO_DSW_FLAGS) -GTURBO=1 -GSINGLE_CLOCK=1 -GMASTER_HZ=28571428 \
		-CFLAGS "-std=c++20 -DX1_SINGLE_CLOCK -DX1_SINGLE_MASTER_HZ=28571428 -DX1_TURBO_FOUNDATION" \
		-MAKEFLAGS "OPT_FAST=-O3" $(V_SRC) sim_headless.cpp -Wno-fatal -o Vtop
turbo-board-single-fast:
	$(MAKE) turbo-board-single BOARD_SINGLE_DIR=obj_dir_v12_board_single_fast BOARD_SINGLE_TIMING=--no-timing
test-board-single: turbo-board-single
	python3 tests/test_single_clock.py ./$(BOARD_SINGLE_DIR)/Vtop --hz 28571428
	python3 tests/test_keyboard_poll.py ./$(BOARD_SINGLE_DIR)/Vtop
	python3 tests/test_subcpu.py ./$(BOARD_SINGLE_DIR)/Vtop
	python3 tests/test_dual_disk.py ./$(BOARD_SINGLE_DIR)/Vtop
.PHONY: turbo-board-single turbo-board-single-fast test-board-single
turbo-fast: obj_dir_turbo_fast/Vtop
turbo-video: obj_dir_turbo_video/Vtop
turbo-video-fast: obj_dir_turbo_video_fast/Vtop
turbo-video-savable: obj_dir_turbo_video_savable/Vtop

# Physical first-level CG ROM only; no renderer/0E80/Z capability implied.
KANJI_DIR ?= obj_dir_turbo_kanji
KANJI_TIMING ?= --timing
KANJI_VIDEO ?= 0
KANJI_RENDER ?= 0
turbo-kanji: $(KANJI_DIR)/Vtop
$(KANJI_DIR)/Vtop: $(V_SRC) sim_headless.cpp frame_capture.h audio_capture.h d88_image.h Makefile $(MACHINE_MANIFEST)
	$(V) -cc $(KANJI_TIMING) --assert --trace-fst --exe --build -j 4 --Mdir $(KANJI_DIR) --top-module top \
		$(TURBO_DSW_FLAGS) -GTURBO=1 -GTURBO_KANJI=1 -GTURBO_VIDEO_MASTER=$(KANJI_VIDEO) -GTURBO_KANJI_RENDER=$(KANJI_RENDER) \
		-CFLAGS "-std=c++20 -DX1_TURBO_FOUNDATION -DX1_TURBO_KANJI $(if $(filter 1,$(KANJI_VIDEO)),-DX1_TURBO_VIDEO_MASTER) $(if $(filter 1,$(KANJI_RENDER)),-DX1_TURBO_KANJI_RENDER)" \
		-MAKEFLAGS "OPT_FAST=-O3" $(V_SRC) sim_headless.cpp -Wno-fatal -o Vtop
.PHONY: turbo-kanji
turbo-kanji-render-fast:
	$(MAKE) turbo-kanji KANJI_DIR=obj_dir_v12_kanji_render_fast KANJI_VIDEO=1 KANJI_RENDER=1 KANJI_TIMING=--no-timing
turbo-kanji-render:
	$(MAKE) turbo-kanji KANJI_DIR=obj_dir_v12_kanji_render KANJI_VIDEO=1 KANJI_RENDER=1
test-machine-kanji-render: turbo-kanji-render-fast
	python3 tests/test_machine_kanji_render.py ./obj_dir_v12_kanji_render_fast/Vtop
test-machine-kanji-render-timing: turbo-kanji-render
	python3 tests/test_machine_kanji_render.py ./obj_dir_v12_kanji_render/Vtop
.PHONY: turbo-kanji-render-fast turbo-kanji-render test-machine-kanji-render test-machine-kanji-render-timing
test-machine-kanji-mixed: turbo-kanji-render-fast
	python3 tests/test_machine_kanji_mixed.py ./obj_dir_v12_kanji_render_fast/Vtop
test-machine-kanji-mixed-timing: turbo-kanji-render
	python3 tests/test_machine_kanji_mixed.py ./obj_dir_v12_kanji_render/Vtop
.PHONY: test-machine-kanji-mixed test-machine-kanji-mixed-timing
test-machine-kanji: turbo-kanji
	python3 tests/test_machine_kanji.py ./$(KANJI_DIR)/Vtop
.PHONY: test-machine-kanji
test-machine-kanji-fast:
	$(MAKE) test-machine-kanji KANJI_DIR=obj_dir_turbo_kanji_fast KANJI_TIMING=--no-timing
.PHONY: test-machine-kanji-fast
test-machine-kanji-x3:
	$(MAKE) test-machine-kanji KANJI_DIR=obj_dir_v12_kanji_x3 KANJI_VIDEO=1
test-machine-kanji-x3-fast:
	$(MAKE) test-machine-kanji KANJI_DIR=obj_dir_v12_kanji_x3_fast KANJI_VIDEO=1 KANJI_TIMING=--no-timing
.PHONY: test-machine-kanji-x3 test-machine-kanji-x3-fast

test-machine-kanji-reset: $(HEADLESS_DIR)/kanji-machine-reset/Vkanji_machine_reset_tb
	@for kind in 0 1 2 3 4; do ./$(HEADLESS_DIR)/kanji-machine-reset/Vkanji_machine_reset_tb +RESET_KIND=$$kind || exit 1; done
$(HEADLESS_DIR)/kanji-machine-reset/Vkanji_machine_reset_tb: $(V_SRC) tests/kanji_machine_reset_tb.sv Makefile
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module kanji_machine_reset_tb --Mdir $(HEADLESS_DIR)/kanji-machine-reset \
		-j 4 $(V_SRC) tests/kanji_machine_reset_tb.sv -Wno-fatal
.PHONY: test-machine-kanji-reset
test-machine-kanji-loader: $(HEADLESS_DIR)/kanji-machine-reset/Vkanji_machine_reset_tb
	@for kind in 0 1 2 3 4 5 6 7 8; do ./$(HEADLESS_DIR)/kanji-machine-reset/Vkanji_machine_reset_tb +LOADER_KIND=$$kind || exit 1; done
.PHONY: test-machine-kanji-loader
KANJI_SAVE_DIR ?= obj_dir_turbo_kanji_savable
KANJI_PLAIN_SAVE_DIR ?= obj_dir_turbo_kanji_plain_savable
turbo-kanji-savable: $(KANJI_SAVE_DIR)/Vtop $(KANJI_PLAIN_SAVE_DIR)/Vtop
$(KANJI_SAVE_DIR)/Vtop: $(V_SRC) sim_headless.cpp frame_capture.h audio_capture.h d88_image.h Makefile $(MACHINE_MANIFEST)
	$(V) -cc --no-timing --savable --assert --trace-fst --exe --build -j 4 --Mdir $(KANJI_SAVE_DIR) --top-module top \
		$(TURBO_DSW_FLAGS) -GTURBO=1 -GTURBO_KANJI=1 -GTURBO_VIDEO_MASTER=$(KANJI_VIDEO) -GTURBO_KANJI_RENDER=$(KANJI_RENDER) \
		-CFLAGS "-std=c++20 -DX1_SAVABLE -DX1_TURBO_FOUNDATION -DX1_TURBO_KANJI $(if $(filter 1,$(KANJI_VIDEO)),-DX1_TURBO_VIDEO_MASTER) $(if $(filter 1,$(KANJI_RENDER)),-DX1_TURBO_KANJI_RENDER)" \
		-MAKEFLAGS "OPT_FAST=-O3" $(V_SRC) sim_headless.cpp -Wno-fatal -o Vtop
$(KANJI_PLAIN_SAVE_DIR)/Vtop: $(V_SRC) sim_headless.cpp frame_capture.h audio_capture.h d88_image.h Makefile $(MACHINE_MANIFEST)
	$(V) -cc --no-timing --savable --assert --trace-fst --exe --build -j 4 --Mdir $(KANJI_PLAIN_SAVE_DIR) --top-module top \
		$(TURBO_DSW_FLAGS) -GTURBO=1 -GTURBO_VIDEO_MASTER=$(KANJI_VIDEO) \
		-CFLAGS "-std=c++20 -DX1_SAVABLE -DX1_TURBO_FOUNDATION $(if $(filter 1,$(KANJI_VIDEO)),-DX1_TURBO_VIDEO_MASTER)" \
		-MAKEFLAGS "OPT_FAST=-O3" $(V_SRC) sim_headless.cpp -Wno-fatal -o Vtop
test-machine-kanji-snapshot: turbo-kanji-savable
	python3 tests/test_machine_kanji_snapshot.py ./$(KANJI_SAVE_DIR)/Vtop ./$(KANJI_PLAIN_SAVE_DIR)/Vtop
.PHONY: turbo-kanji-savable test-machine-kanji-snapshot
test-machine-kanji-render-snapshot:
	$(MAKE) turbo-kanji-savable KANJI_VIDEO=1 KANJI_RENDER=1 KANJI_SAVE_DIR=obj_dir_v12_kanji_render_savable KANJI_PLAIN_SAVE_DIR=obj_dir_v12_kanji_x3_plain_savable
	$(MAKE) turbo-kanji-savable KANJI_VIDEO=1 KANJI_SAVE_DIR=obj_dir_v12_kanji_x3_savable KANJI_PLAIN_SAVE_DIR=obj_dir_v12_kanji_x3_plain_savable
	python3 tests/test_machine_kanji_render_snapshot.py ./obj_dir_v12_kanji_render_savable/Vtop ./obj_dir_v12_kanji_x3_savable/Vtop
.PHONY: test-machine-kanji-render-snapshot
test-machine-kanji-x3-snapshot:
	$(MAKE) test-machine-kanji-snapshot KANJI_VIDEO=1 KANJI_SAVE_DIR=obj_dir_v12_kanji_x3_savable KANJI_PLAIN_SAVE_DIR=obj_dir_v12_kanji_x3_plain_savable
.PHONY: test-machine-kanji-x3-snapshot

# Separate opt-in DMA profile. Board/default Turbo profiles remain unchanged.
DMA_DIR ?= obj_dir_turbo_dma
DMA_TIMING ?= --timing
DMA_VIDEO ?= 0
DMA_VIDEO_FLAGS = -GTURBO_VIDEO_MASTER=$(DMA_VIDEO) $(if $(filter 1,$(DMA_VIDEO)),-CFLAGS "-DX1_TURBO_VIDEO_MASTER")
turbo-dma: $(DMA_DIR)/Vtop
$(DMA_DIR)/Vtop: $(V_SRC) sim_headless.cpp frame_capture.h audio_capture.h d88_image.h Makefile $(MACHINE_MANIFEST)
	$(V) -cc $(DMA_TIMING) --assert --trace-fst --exe --build -j 4 --Mdir $(DMA_DIR) --top-module top \
		$(TURBO_DSW_FLAGS) $(DMA_VIDEO_FLAGS) -GTURBO=1 -GTURBO_DMA=1 -CFLAGS "-std=c++20 -DX1_TURBO_FOUNDATION -DX1_TURBO_DMA" \
		-MAKEFLAGS "OPT_FAST=-O3" $(V_SRC) sim_headless.cpp -Wno-fatal -o Vtop
.PHONY: turbo-dma

test-machine-dma-x3-fast:
	$(MAKE) turbo-dma DMA_DIR=obj_dir_v12_dma_x3_fast DMA_TIMING=--no-timing DMA_VIDEO=1
	python3 tests/test_machine_dma.py ./obj_dir_v12_dma_x3_fast/Vtop
	python3 tests/test_dma_native_read_stream.py ./obj_dir_v12_dma_x3_fast/Vtop
test-machine-dma-x3-timing:
	$(MAKE) turbo-dma DMA_DIR=obj_dir_v12_dma_x3_timing DMA_VIDEO=1
	python3 tests/test_machine_dma.py ./obj_dir_v12_dma_x3_timing/Vtop
	python3 tests/test_dma_native_read_stream.py ./obj_dir_v12_dma_x3_timing/Vtop
.PHONY: test-machine-dma-x3-fast test-machine-dma-x3-timing

test-machine-dma-x3-snapshot:
	$(MAKE) turbo-dma-savable DMA_VIDEO=1 DMA_SAVE_DIR=obj_dir_v12_dma_x3_savable
	$(MAKE) turbo-dma-savable DMA_SAVE_DIR=obj_dir_v12_dma_baseline_savable
	python3 tests/test_dma_x3_snapshot.py ./obj_dir_v12_dma_x3_savable/Vtop ./obj_dir_v12_dma_baseline_savable/Vtop
.PHONY: test-machine-dma-x3-snapshot

test-dual-snapshot:
	$(MAKE) turbo-dma-savable DMA_VIDEO=1 DMA_SAVE_DIR=obj_dir_v12_dma_dual_savable
	python3 tests/test_dual_snapshot.py ./obj_dir_v12_dma_dual_savable/Vtop
.PHONY: test-dual-snapshot

test-dual-write-snapshot:
	$(MAKE) turbo-dma-savable DMA_VIDEO=1 DMA_SAVE_DIR=obj_dir_v12_dma_dual_savable
	python3 tests/test_dual_write_snapshot.py ./obj_dir_v12_dma_dual_savable/Vtop --first-drive 0
	python3 tests/test_dual_write_snapshot.py ./obj_dir_v12_dma_dual_savable/Vtop --first-drive 1
.PHONY: test-dual-write-snapshot

test-video-dump: headless
	$(MAKE) turbo-dma-savable DMA_VIDEO=1 DMA_SAVE_DIR=obj_dir_v12_dma_dual_savable
	$(MAKE) turbo-dma DMA_DIR=obj_dir_v12_dma_x3_timing DMA_VIDEO=1
	python3 tests/test_video_dump.py ./$(HEADLESS_EXE)
	python3 tests/test_video_dump.py ./obj_dir_v12_dma_dual_savable/Vtop turbo
	python3 tests/test_video_dump.py ./obj_dir_v12_dma_x3_timing/Vtop turbo
.PHONY: test-video-dump

test-continue-native-dual:
	python3 tests/test_continue_native_dual.py
.PHONY: test-continue-native-dual

# Completion IRQ has its own model and output directory; no default promotion.
DMA_IRQ_DIR ?= obj_dir_turbo_dma_irq
DMA_RESTART ?= 0
DMA_RESTART_FLAGS = -GTURBO_DMA_RESTART_IRQ=$(DMA_RESTART) $(if $(filter 1,$(DMA_RESTART)),-CFLAGS "-DX1_TURBO_DMA_RESTART_IRQ")
turbo-dma-irq: $(DMA_IRQ_DIR)/Vtop
$(DMA_IRQ_DIR)/Vtop: $(V_SRC) sim_headless.cpp frame_capture.h audio_capture.h d88_image.h Makefile $(MACHINE_MANIFEST)
	$(V) -cc $(DMA_TIMING) --assert --trace-fst --exe --build -j 4 --Mdir $(DMA_IRQ_DIR) --top-module top \
		$(TURBO_DSW_FLAGS) $(DMA_VIDEO_FLAGS) $(DMA_RESTART_FLAGS) -GTURBO=1 -GTURBO_DMA=1 -GTURBO_DMA_IRQ=1 -CFLAGS "-std=c++20 -DX1_TURBO_FOUNDATION -DX1_TURBO_DMA -DX1_TURBO_DMA_IRQ" \
		-MAKEFLAGS "OPT_FAST=-O3" $(V_SRC) sim_headless.cpp -Wno-fatal -o Vtop
.PHONY: turbo-dma-irq
test-machine-dma-irq: turbo-dma-irq
	python3 tests/test_machine_dma_irq.py ./$(DMA_IRQ_DIR)/Vtop
.PHONY: test-machine-dma-irq
test-machine-dma-irq-nested: turbo-dma-irq
	python3 tests/test_machine_dma_irq_nested.py ./$(DMA_IRQ_DIR)/Vtop
.PHONY: test-machine-dma-irq-nested
test-machine-dma-irq-keyboard: turbo-dma-irq
	python3 tests/test_machine_dma_irq_nested.py ./$(DMA_IRQ_DIR)/Vtop --keyboard
.PHONY: test-machine-dma-irq-keyboard

# Restart service has an explicit independent machine/snapshot profile.
DMA_RESTART_DIR ?= obj_dir_v12_dma_restart_irq
DMA_RESTART_SAVE_DIR ?= obj_dir_v12_dma_restart_irq_save
DMA_RESTART_CONTROL_DIR ?= obj_dir_v12_dma_restart_completion_control
DMA_RESTART_BOARD_DIR ?= obj_dir_v12_dma_restart_board_fast
test-machine-dma-restart-irq:
	$(MAKE) turbo-dma-irq DMA_RESTART=1 DMA_IRQ_DIR=$(DMA_RESTART_DIR)
	python3 tests/test_machine_dma_restart_irq.py ./$(DMA_RESTART_DIR)/Vtop
test-machine-dma-restart-irq-snapshot:
	$(MAKE) turbo-dma-irq-savable DMA_RESTART=1 DMA_IRQ_SAVE_DIR=$(DMA_RESTART_SAVE_DIR)
	$(MAKE) turbo-dma-irq-savable DMA_RESTART=0 DMA_IRQ_SAVE_DIR=$(DMA_RESTART_CONTROL_DIR)
	python3 tests/test_machine_dma_restart_irq.py ./$(DMA_RESTART_SAVE_DIR)/Vtop --completion-only ./$(DMA_RESTART_CONTROL_DIR)/Vtop
test-machine-dma-restart-fdc:
	$(MAKE) turbo-dma-irq DMA_RESTART=1 DMA_IRQ_DIR=$(DMA_RESTART_DIR)
	python3 tests/test_machine_dma_restart_fdc.py ./$(DMA_RESTART_DIR)/Vtop
test-machine-dma-restart-board:
	$(MAKE) turbo-dma-irq-savable DMA_RESTART=1 DMA_IRQ_SAVE_DIR=$(DMA_RESTART_BOARD_DIR) \
	  V='$(V) -GSINGLE_CLOCK=1 -GMASTER_HZ=28571428 -CFLAGS "-DX1_SINGLE_CLOCK -DX1_SINGLE_MASTER_HZ=28571428"'
	python3 tests/test_machine_dma_restart_irq.py ./$(DMA_RESTART_BOARD_DIR)/Vtop --sys-hz 28571428
	python3 tests/test_machine_dma_restart_fdc.py ./$(DMA_RESTART_BOARD_DIR)/Vtop --sys-hz 28571428
.PHONY: test-machine-dma-restart-irq test-machine-dma-restart-irq-snapshot test-machine-dma-restart-fdc test-machine-dma-restart-board

test-machine-dma-restart-visible:
	$(MAKE) turbo-dma-irq-savable DMA_RESTART=1 DMA_IRQ_SAVE_DIR=$(DMA_RESTART_BOARD_DIR) \
	  V='$(V) -GSINGLE_CLOCK=1 -GMASTER_HZ=28571428 -CFLAGS "-DX1_SINGLE_CLOCK -DX1_SINGLE_MASTER_HZ=28571428"'
	$(MAKE) turbo-dma-irq-savable DMA_RESTART=0 DMA_IRQ_SAVE_DIR=$(DMA_RESTART_CONTROL_DIR)
	python3 tests/test_dma_visible_ipl.py ./$(DMA_RESTART_BOARD_DIR)/Vtop \
	  $(DMA_RESTART_BOARD_DIR)/visible-$(shell date -u +%Y%m%dT%H%M%S) --completion-only ./$(DMA_RESTART_CONTROL_DIR)/Vtop
.PHONY: test-machine-dma-restart-visible

# Savable fast DMA profiles: separate artifacts and application identities.
DMA_SAVE_DIR ?= obj_dir_turbo_dma_savable
DMA_IRQ_SAVE_DIR ?= obj_dir_turbo_dma_irq_savable
turbo-dma-savable: $(DMA_SAVE_DIR)/Vtop
$(DMA_SAVE_DIR)/Vtop: $(V_SRC) sim_headless.cpp frame_capture.h audio_capture.h d88_image.h Makefile $(MACHINE_MANIFEST)
	$(V) -cc --no-timing --savable --assert --trace-fst --exe --build -j 4 --Mdir $(DMA_SAVE_DIR) --top-module top \
		$(TURBO_DSW_FLAGS) $(DMA_VIDEO_FLAGS) -GTURBO=1 -GTURBO_DMA=1 -CFLAGS "-std=c++20 -DX1_SAVABLE -DX1_TURBO_FOUNDATION -DX1_TURBO_DMA" \
		-MAKEFLAGS "OPT_FAST=-O3" $(V_SRC) sim_headless.cpp -Wno-fatal -o Vtop
turbo-dma-irq-savable: $(DMA_IRQ_SAVE_DIR)/Vtop
$(DMA_IRQ_SAVE_DIR)/Vtop: $(V_SRC) sim_headless.cpp frame_capture.h audio_capture.h d88_image.h Makefile $(MACHINE_MANIFEST)
	$(V) -cc --no-timing --savable --assert --trace-fst --exe --build -j 4 --Mdir $(DMA_IRQ_SAVE_DIR) --top-module top \
		$(TURBO_DSW_FLAGS) $(DMA_VIDEO_FLAGS) $(DMA_RESTART_FLAGS) -GTURBO=1 -GTURBO_DMA=1 -GTURBO_DMA_IRQ=1 -CFLAGS "-std=c++20 -DX1_SAVABLE -DX1_TURBO_FOUNDATION -DX1_TURBO_DMA -DX1_TURBO_DMA_IRQ" \
		-MAKEFLAGS "OPT_FAST=-O3" $(V_SRC) sim_headless.cpp -Wno-fatal -o Vtop
test-machine-dma-irq-snapshot: turbo-dma-savable turbo-dma-irq-savable
	python3 tests/test_machine_dma_irq_snapshot.py ./$(DMA_IRQ_SAVE_DIR)/Vtop ./$(DMA_SAVE_DIR)/Vtop
.PHONY: turbo-dma-savable turbo-dma-irq-savable test-machine-dma-irq-snapshot

DMA_RELOAD_SAVE_DIR ?= obj_dir_v12_dma_reload_seam
test-dma-reload-snapshot:
	$(MAKE) turbo-dma-savable DMA_SAVE_DIR=$(DMA_RELOAD_SAVE_DIR)
	python3 tests/test_dma_reload_snapshot.py ./$(DMA_RELOAD_SAVE_DIR)/Vtop
.PHONY: test-dma-reload-snapshot

test-machine-dma: turbo-dma test-machine-dma-reset
	python3 tests/test_machine_dma.py ./$(DMA_DIR)/Vtop
test-machine-dma-restart: turbo-dma
	python3 tests/test_machine_dma_restart.py ./$(DMA_DIR)/Vtop
.PHONY: test-machine-dma-restart
test-machine-dma-search-restart: turbo-dma
	python3 tests/test_machine_dma_restart.py ./$(DMA_DIR)/Vtop --search
.PHONY: test-machine-dma-search-restart
test-machine-dma-compare: turbo-dma
	python3 tests/test_machine_dma_compare.py ./$(DMA_DIR)/Vtop
.PHONY: test-machine-dma-compare
test-machine-dma-search: turbo-dma
	python3 tests/test_machine_dma_search.py ./$(DMA_DIR)/Vtop
.PHONY: test-machine-dma-search
test-machine-dma-search-nonbyte: turbo-dma
	python3 tests/test_machine_dma_search.py ./$(DMA_DIR)/Vtop --nonbyte
.PHONY: test-machine-dma-search-nonbyte
test-machine-dma-search-stop: turbo-dma
	python3 tests/test_machine_dma_search.py ./$(DMA_DIR)/Vtop --nonbyte --stop-pipeline
.PHONY: test-machine-dma-search-stop
test-machine-dma-search-nonbyte-boundaries: turbo-dma
	python3 tests/test_machine_dma_search.py ./$(DMA_DIR)/Vtop --nonbyte --short
	python3 tests/test_machine_dma_search.py ./$(DMA_DIR)/Vtop --nonbyte --zero
.PHONY: test-machine-dma-search-nonbyte-boundaries
DMA_TEST_IRQ ?= 0
test-machine-dma-reset: $(HEADLESS_DIR)/dma-machine-reset/Vdma_machine_reset_tb
	@for kind in 0 1 2 3; do ./$(HEADLESS_DIR)/dma-machine-reset/Vdma_machine_reset_tb +RESET_KIND=$$kind || exit 1; done
$(HEADLESS_DIR)/dma-machine-reset/Vdma_machine_reset_tb: $(V_SRC) tests/dma_machine_reset_tb.sv Makefile
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module dma_machine_reset_tb --Mdir $(HEADLESS_DIR)/dma-machine-reset \
		-GDMA_IRQ=$(DMA_TEST_IRQ) -j 4 $(V_SRC) tests/dma_machine_reset_tb.sv -Wno-fatal
.PHONY: test-machine-dma test-machine-dma-reset

test-machine-dma-pcg-reset: $(HEADLESS_DIR)/dma-machine-reset/Vdma_machine_reset_tb
	@for kind in 0 1 2 3 4; do ./$(HEADLESS_DIR)/dma-machine-reset/Vdma_machine_reset_tb +RESET_KIND=$$kind +pcg || exit 1; done
.PHONY: test-machine-dma-pcg-reset

test-machine-dma-sd-reset: $(HEADLESS_DIR)/dma-machine-sd-reset/Vdma_machine_sd_reset_tb
	@for drive in 0 1; do for writing in 0 1; do for phase in 0 1; do \
		./$(HEADLESS_DIR)/dma-machine-sd-reset/Vdma_machine_sd_reset_tb +DRIVE_B=$$drive +WRITING=$$writing +PHASE=$$phase || exit 1; \
	done; done; done
$(HEADLESS_DIR)/dma-machine-sd-reset/Vdma_machine_sd_reset_tb: $(V_SRC) tests/dma_machine_sd_reset_tb.sv Makefile
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module dma_machine_sd_reset_tb --Mdir $(HEADLESS_DIR)/dma-machine-sd-reset \
		-GDMA_IRQ=$(DMA_TEST_IRQ) -j 4 $(V_SRC) tests/dma_machine_sd_reset_tb.sv -Wno-fatal
.PHONY: test-machine-dma-sd-reset

test-machine-dma-sd-short-reset: $(HEADLESS_DIR)/dma-machine-sd-reset/Vdma_machine_sd_reset_tb
	@for drive in 0 1; do for writing in 0 1; do for phase in 0 1; do \
		./$(HEADLESS_DIR)/dma-machine-sd-reset/Vdma_machine_sd_reset_tb +DRIVE_B=$$drive +WRITING=$$writing +PHASE=$$phase +SHORT_RESET=1 || exit 1; \
	done; done; done
test-machine-dma-metadata-reset: $(HEADLESS_DIR)/dma-machine-sd-reset/Vdma_machine_sd_reset_tb
	@for drive in 0 1; do for stage in 1 2; do for pulse in 0 1; do for phase in 0 1; do \
		./$(HEADLESS_DIR)/dma-machine-sd-reset/Vdma_machine_sd_reset_tb +DRIVE_B=$$drive +WRITING=1 +PHASE=$$phase +CAPTURE_STAGE=$$stage +SHORT_RESET=$$pulse || exit 1; \
	done; done; done; done
.PHONY: test-machine-dma-sd-short-reset test-machine-dma-metadata-reset

test-machine-dma-split-metadata-reset: $(HEADLESS_DIR)/dma-machine-sd-reset/Vdma_machine_sd_reset_tb
	@for drive in 0 1; do for stage in 1 2 3 4; do for pulse in 0 1; do for phase in 0 1; do \
		./$(HEADLESS_DIR)/dma-machine-sd-reset/Vdma_machine_sd_reset_tb +DRIVE_B=$$drive +WRITING=1 +PHASE=$$phase +CAPTURE_STAGE=$$stage +SHORT_RESET=$$pulse +SPLIT_HEADER=1 || exit 1; \
	done; done; done; done
.PHONY: test-machine-dma-split-metadata-reset

test-machine-dma-video: turbo-dma
	python3 tests/test_machine_dma_video.py ./$(DMA_DIR)/Vtop
.PHONY: test-machine-dma-video

test-sio-clock-select: $(HEADLESS_DIR)/sio-clock-select/Vsio_clock_select_tb
	./$(HEADLESS_DIR)/sio-clock-select/Vsio_clock_select_tb
$(HEADLESS_DIR)/sio-clock-select/Vsio_clock_select_tb: tests/sio_clock_select_tb.sv ../rtl/x1_sio_clock_select_851.sv ../rtl/x1_sio_clocks_851.sv
	mkdir -p $(@D)
	$(V) --binary --timing --assert --timescale 1ns/1ps --top-module sio_clock_select_tb --Mdir $(HEADLESS_DIR)/sio-clock-select \
		-j 4 tests/sio_clock_select_tb.sv ../rtl/x1_sio_clock_select_851.sv ../rtl/x1_sio_clocks_851.sv
.PHONY: test-sio-clock-select

test-sio-edge-clock: $(HEADLESS_DIR)/sio-edge-clock/Vsio_edge_clock_tb
	@for hz in 32000000 28636364 28571428; do for rate in 1 4 7; do ./$(HEADLESS_DIR)/sio-edge-clock/Vsio_edge_clock_tb +CE_PERIOD=$$rate +MASTER_HZ=$$hz || exit 1; done; done
$(HEADLESS_DIR)/sio-edge-clock/Vsio_edge_clock_tb: tests/sio_edge_clock_tb.sv ../rtl/x1_sio_edge_clock.sv
	mkdir -p $(@D)
	$(V) --binary --timing --assert --timescale 1ps/1ps --top-module sio_edge_clock_tb --Mdir $(HEADLESS_DIR)/sio-edge-clock \
		-j 4 tests/sio_edge_clock_tb.sv ../rtl/x1_sio_edge_clock.sv
.PHONY: test-sio-edge-clock

test-sio-ctc-clock: $(HEADLESS_DIR)/sio-ctc-clock/Vsio_ctc_clock_tb
	@for hz in 32000000 28636364 28571428; do for rate in 1 4 7; do for phase in $$(seq 0 $$((rate-1))); do ./$(HEADLESS_DIR)/sio-ctc-clock/Vsio_ctc_clock_tb +CE_PERIOD=$$rate +PHASE=$$phase +MASTER_HZ=$$hz || exit 1; done; done; done
	@if ./$(HEADLESS_DIR)/sio-ctc-clock/Vsio_ctc_clock_tb +CE_PERIOD=4 +DIRECT=1 > $(HEADLESS_DIR)/sio-ctc-clock/direct-negative.log 2>&1; then echo 'FAIL: direct clock negative unexpectedly passed'; exit 1; fi
	@rg -q 'CTC/SIO clock test missed RX events' $(HEADLESS_DIR)/sio-ctc-clock/direct-negative.log
	@echo 'PASS: direct clock negative rejects lost CTC events'
$(HEADLESS_DIR)/sio-ctc-clock/Vsio_ctc_clock_tb: tests/sio_ctc_clock_tb.sv ../rtl/x1_sio_clocks_851.sv ../rtl/x1_sio_clock_select_851.sv ../rtl/x1_sio_edge_clock.sv ../rtl/x1_sio_async.sv ../rtl/x1_ctc.sv
	mkdir -p $(@D)
	$(V) --binary --timing --assert --timescale 1ps/1ps --top-module sio_ctc_clock_tb --Mdir $(HEADLESS_DIR)/sio-ctc-clock \
		-j 4 tests/sio_ctc_clock_tb.sv ../rtl/x1_sio_clocks_851.sv ../rtl/x1_sio_clock_select_851.sv ../rtl/x1_sio_edge_clock.sv ../rtl/x1_sio_async.sv ../rtl/x1_ctc.sv
.PHONY: test-sio-ctc-clock

test-sio-async: $(HEADLESS_DIR)/sio-async/Vsio_async_tb
	@for rate in 1 4 7; do ./$(HEADLESS_DIR)/sio-async/Vsio_async_tb +CE_PERIOD=$$rate || exit 1; done
$(HEADLESS_DIR)/sio-async/Vsio_async_tb: tests/sio_async_tb.sv ../rtl/x1_sio_async.sv
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module sio_async_tb --Mdir $(HEADLESS_DIR)/sio-async \
		-j 4 tests/sio_async_tb.sv ../rtl/x1_sio_async.sv -Wno-fatal
.PHONY: test-sio-async
test-sio-tx-disable: $(HEADLESS_DIR)/sio-tx-disable/Vsio_tx_disable_tb
	@for rate in 1 4 7; do ./$(HEADLESS_DIR)/sio-tx-disable/Vsio_tx_disable_tb +CE_PERIOD=$$rate || exit 1; done
$(HEADLESS_DIR)/sio-tx-disable/Vsio_tx_disable_tb: tests/sio_tx_disable_tb.sv ../rtl/x1_sio_async.sv
	mkdir -p $(HEADLESS_DIR)/sio-tx-disable
	$(V) --binary --timing --assert --top-module sio_tx_disable_tb --Mdir $(HEADLESS_DIR)/sio-tx-disable \
		-j 4 tests/sio_tx_disable_tb.sv ../rtl/x1_sio_async.sv -Wno-fatal
.PHONY: test-sio-tx-disable

test-sio-auto-enable: $(HEADLESS_DIR)/sio-auto-enable/Vsio_auto_enable_tb $(HEADLESS_DIR)/sio-tx-disable/Vsio_tx_disable_tb
	@for rate in 1 4 7; do ./$(HEADLESS_DIR)/sio-auto-enable/Vsio_auto_enable_tb +CE_PERIOD=$$rate || exit 1; done
	@for rate in 1 4 7; do ./$(HEADLESS_DIR)/sio-tx-disable/Vsio_tx_disable_tb +CE_PERIOD=$$rate +MODEM=1 || exit 1; done
$(HEADLESS_DIR)/sio-auto-enable/Vsio_auto_enable_tb: tests/sio_auto_enable_tb.sv ../rtl/x1_sio_async.sv
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module sio_auto_enable_tb --Mdir $(HEADLESS_DIR)/sio-auto-enable \
		-j 4 tests/sio_auto_enable_tb.sv ../rtl/x1_sio_async.sv -Wno-fatal
.PHONY: test-sio-auto-enable

test-sio-rts: $(HEADLESS_DIR)/sio-tx-disable/Vsio_tx_disable_tb
	@for mode in 0 1; do for rate in 1 4 7; do ./$(HEADLESS_DIR)/sio-tx-disable/Vsio_tx_disable_tb +CE_PERIOD=$$rate +MODEM=$$mode +RTS=1 || exit 1; done; done
.PHONY: test-sio-rts

test-sio-short-tx: $(HEADLESS_DIR)/sio-short-tx/Vsio_short_tx_tb
	@for rate in 1 4 7; do ./$(HEADLESS_DIR)/sio-short-tx/Vsio_short_tx_tb +CE_PERIOD=$$rate || exit 1; done
$(HEADLESS_DIR)/sio-short-tx/Vsio_short_tx_tb: tests/sio_short_tx_tb.sv ../rtl/x1_sio_async.sv
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module sio_short_tx_tb --Mdir $(HEADLESS_DIR)/sio-short-tx \
		-j 4 tests/sio_short_tx_tb.sv ../rtl/x1_sio_async.sv -Wno-fatal
.PHONY: test-sio-short-tx

test-sio-break: $(HEADLESS_DIR)/sio-break/Vsio_break_tb
	@for rate in 1 4 7; do ./$(HEADLESS_DIR)/sio-break/Vsio_break_tb +CE_PERIOD=$$rate || exit 1; done
$(HEADLESS_DIR)/sio-break/Vsio_break_tb: tests/sio_break_tb.sv ../rtl/x1_sio_async.sv
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module sio_break_tb --Mdir $(HEADLESS_DIR)/sio-break \
		-j 4 tests/sio_break_tb.sv ../rtl/x1_sio_async.sv
.PHONY: test-sio-break

test-sio-formats: $(HEADLESS_DIR)/sio-formats/Vsio_formats_tb
	@for rate in 1 4 7; do ./$(HEADLESS_DIR)/sio-formats/Vsio_formats_tb +CE_PERIOD=$$rate || exit 1; done
$(HEADLESS_DIR)/sio-formats/Vsio_formats_tb: tests/sio_formats_tb.sv ../rtl/x1_sio_async.sv
	mkdir -p $(dir $@)
	$(V) --binary --timing --assert --top-module sio_formats_tb --Mdir $(HEADLESS_DIR)/sio-formats \
		-j 4 tests/sio_formats_tb.sv ../rtl/x1_sio_async.sv -Wno-fatal
.PHONY: test-sio-formats

test-sio-irq: $(HEADLESS_DIR)/sio-irq/Vsio_irq_tb
	@for rate in 1 4 7; do ./$(HEADLESS_DIR)/sio-irq/Vsio_irq_tb +CE_PERIOD=$$rate || exit 1; done
$(HEADLESS_DIR)/sio-irq/Vsio_irq_tb: tests/sio_irq_tb.sv ../rtl/x1_sio_async.sv ../rtl/x1_sio_irq.sv
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module sio_irq_tb --Mdir $(HEADLESS_DIR)/sio-irq \
		-j 4 tests/sio_irq_tb.sv ../rtl/x1_sio_async.sv ../rtl/x1_sio_irq.sv -Wno-fatal
.PHONY: test-sio-irq

test-sio-irq-bridge: $(HEADLESS_DIR)/sio-irq-bridge/Vsio_irq_bridge_tb
	./$(HEADLESS_DIR)/sio-irq-bridge/Vsio_irq_bridge_tb
	@ulimit -c 0; if ./$(HEADLESS_DIR)/sio-irq-bridge/Vsio_irq_bridge_tb +BAD_SERVICE >$(HEADLESS_DIR)/sio-irq-bridge/bad-service.log 2>&1; then \
		echo 'ERROR: IEO-as-service negative control unexpectedly passed'; exit 1; \
	fi; rg -q 'second SIO RETI wrong owner|pending SIO stole DMA RETI' $(HEADLESS_DIR)/sio-irq-bridge/bad-service.log || \
		{ echo 'ERROR: wrong negative-control failure'; exit 1; }; \
	echo 'PASS: IEO-as-service negative control rejected'
$(HEADLESS_DIR)/sio-irq-bridge/Vsio_irq_bridge_tb: tests/sio_irq_bridge_tb.sv ../rtl/x1_sio_irq.sv ../rtl/x1_sio_async.sv ../rtl/x1_sio_irq_bridge.sv ../rtl/x1_irq_bridge.sv
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module sio_irq_bridge_tb --Mdir $(HEADLESS_DIR)/sio-irq-bridge \
		-j 4 $^ -Wno-fatal
.PHONY: test-sio-irq-bridge

test-sio-cpu-irq-reset: $(HEADLESS_DIR)/sio-cpu/Vsio_cpu_tb
	@for rate in 1 4 7; do for phase in 0 1 2 3; do \
		./$(HEADLESS_DIR)/sio-cpu/Vsio_cpu_tb +CE_PERIOD=$$rate +IRQ_RESET_PHASE=$$phase || exit 1; \
	done; done
.PHONY: test-sio-cpu-irq-reset

test-sio-cpu: $(HEADLESS_DIR)/sio-cpu/Vsio_cpu_tb
	@for rate in 1 4 7; do \
		./$(HEADLESS_DIR)/sio-cpu/Vsio_cpu_tb +CE_PERIOD=$$rate || exit 1; \
		./$(HEADLESS_DIR)/sio-cpu/Vsio_cpu_tb +CE_PERIOD=$$rate +first-status || exit 1; \
		./$(HEADLESS_DIR)/sio-cpu/Vsio_cpu_tb +CE_PERIOD=$$rate +flow || exit 1; \
	done
test-sio-decode: $(HEADLESS_DIR)/sio-decode/Vsio_decode_tb $(HEADLESS_DIR)/sio-cpu/Vsio_cpu_tb
	./$(HEADLESS_DIR)/sio-decode/Vsio_decode_tb
	@for rate in 1 4 7; do for profile in '' '+first-status' '+flow'; do ./$(HEADLESS_DIR)/sio-cpu/Vsio_cpu_tb +CE_PERIOD=$$rate +decode $$profile || exit 1; done; done
	@for fault in BYPASS_DAM BYPASS_ENABLE WIDE_DECODE; do if ./$(HEADLESS_DIR)/sio-cpu/Vsio_cpu_tb +CE_PERIOD=4 +decode +$$fault > $(HEADLESS_DIR)/sio-cpu/decode-negative-$$fault.log 2>&1; then echo "FAIL: $$fault decode negative unexpectedly passed"; exit 1; fi; if [ "$$fault" = WIDE_DECODE ]; then rg -q 'CPU programmed unsupported SIO behavior' $(HEADLESS_DIR)/sio-cpu/decode-negative-$$fault.log || exit 1; else rg -q 'SIO selected during excluded bus cycle' $(HEADLESS_DIR)/sio-cpu/decode-negative-$$fault.log || exit 1; fi; done
	@echo 'PASS: DAM/disabled/wide-port actual CPU negative controls'
$(HEADLESS_DIR)/sio-decode/Vsio_decode_tb: tests/sio_decode_tb.sv ../rtl/x1_sio_decode.sv
	mkdir -p $(@D)
	$(V) --binary --timing --assert --timescale 1ns/1ps --top-module sio_decode_tb --Mdir $(HEADLESS_DIR)/sio-decode \
		-j 4 tests/sio_decode_tb.sv ../rtl/x1_sio_decode.sv
.PHONY: test-sio-decode

$(HEADLESS_DIR)/sio-cpu/Vsio_cpu_tb: tests/sio_cpu_tb.sv ../rtl/x1_sio_decode.sv ../rtl/x1_sio_async.sv ../rtl/x1_sio_irq.sv ../rtl/x1_irq_bridge.sv ../rtl/cpu.v $(wildcard ../rtl/tv80/*.v)
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module sio_cpu_tb --Mdir $(HEADLESS_DIR)/sio-cpu \
		-j 4 tests/sio_cpu_tb.sv ../rtl/x1_sio_decode.sv ../rtl/x1_sio_async.sv ../rtl/x1_sio_irq.sv ../rtl/x1_irq_bridge.sv ../rtl/cpu.v \
		../rtl/tv80/tv80e.v ../rtl/tv80/tv80_core.v ../rtl/tv80/tv80_mcode.v ../rtl/tv80/tv80_alu.v ../rtl/tv80/tv80_reg.v \
		-Wno-fatal
.PHONY: test-sio-cpu

test-sio-first-status: $(HEADLESS_DIR)/sio-first-status/Vsio_first_status_tb
	@for rate in 1 4 7; do ./$(HEADLESS_DIR)/sio-first-status/Vsio_first_status_tb +CE_PERIOD=$$rate || exit 1; done
$(HEADLESS_DIR)/sio-first-status/Vsio_first_status_tb: tests/sio_first_status_tb.sv ../rtl/x1_sio_async.sv ../rtl/x1_sio_irq.sv
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module sio_first_status_tb --Mdir $(HEADLESS_DIR)/sio-first-status \
		-j 4 tests/sio_first_status_tb.sv ../rtl/x1_sio_async.sv ../rtl/x1_sio_irq.sv -Wno-fatal
.PHONY: test-sio-first-status

test-sio-flow: $(HEADLESS_DIR)/sio-flow/Vsio_flow_tb
	@for rate in 1 4 7; do ./$(HEADLESS_DIR)/sio-flow/Vsio_flow_tb +CE_PERIOD=$$rate || exit 1; done
$(HEADLESS_DIR)/sio-flow/Vsio_flow_tb: tests/sio_flow_tb.sv ../rtl/x1_sio_async.sv ../rtl/x1_sio_irq.sv
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module sio_flow_tb --Mdir $(HEADLESS_DIR)/sio-flow \
		-j 4 tests/sio_flow_tb.sv ../rtl/x1_sio_async.sv ../rtl/x1_sio_irq.sv -Wno-fatal
.PHONY: test-sio-flow

test-sio-dma: $(HEADLESS_DIR)/sio-dma/Vsio_dma_tb
	@for rate in 1 4 7; do ./$(HEADLESS_DIR)/sio-dma/Vsio_dma_tb +CE_PERIOD=$$rate || exit 1; done
$(HEADLESS_DIR)/sio-dma/Vsio_dma_tb: tests/sio_dma_tb.sv ../rtl/x1_dma.sv ../rtl/x1_sio_async.sv ../rtl/x1_sio_irq.sv Makefile
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module sio_dma_tb --Mdir $(HEADLESS_DIR)/sio-dma \
		-j 4 tests/sio_dma_tb.sv ../rtl/x1_dma.sv ../rtl/x1_sio_async.sv ../rtl/x1_sio_irq.sv
.PHONY: test-sio-dma

test-sio-dma-cpu: $(HEADLESS_DIR)/sio-dma-cpu/Vsio_dma_cpu_tb
	@for rate in 1 4 7; do for channel in 0 1; do \
		./$(HEADLESS_DIR)/sio-dma-cpu/Vsio_dma_cpu_tb +CE_PERIOD=$$rate +CHANNEL=$$channel || exit 1; \
		./$(HEADLESS_DIR)/sio-dma-cpu/Vsio_dma_cpu_tb +CE_PERIOD=$$rate +CHANNEL=$$channel +im2 || exit 1; \
		./$(HEADLESS_DIR)/sio-dma-cpu/Vsio_dma_cpu_tb +CE_PERIOD=$$rate +CHANNEL=$$channel +RESET_KIND=0 || exit 1; \
		./$(HEADLESS_DIR)/sio-dma-cpu/Vsio_dma_cpu_tb +CE_PERIOD=$$rate +CHANNEL=$$channel +RESET_KIND=1 || exit 1; \
	done; done
$(HEADLESS_DIR)/sio-dma-cpu/Vsio_dma_cpu_tb: tests/sio_dma_cpu_tb.sv ../rtl/x1_dma.sv ../rtl/x1_dma_reset.sv ../rtl/x1_sio_async.sv ../rtl/x1_sio_irq.sv ../rtl/x1_irq_bridge.sv ../rtl/cpu.v $(wildcard ../rtl/tv80/*.v) Makefile
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module sio_dma_cpu_tb --Mdir $(HEADLESS_DIR)/sio-dma-cpu \
		-j 4 tests/sio_dma_cpu_tb.sv ../rtl/x1_dma.sv ../rtl/x1_dma_reset.sv ../rtl/x1_sio_async.sv ../rtl/x1_sio_irq.sv ../rtl/x1_irq_bridge.sv ../rtl/cpu.v \
		../rtl/tv80/tv80e.v ../rtl/tv80/tv80_core.v ../rtl/tv80/tv80_mcode.v ../rtl/tv80/tv80_alu.v ../rtl/tv80/tv80_reg.v -Wno-fatal
.PHONY: test-sio-dma-cpu

# Fast X3 diagnostic continuations; not the delay-aware scheduling reference.
obj_dir_turbo_video_savable/Vtop: $(V_SRC) sim_headless.cpp frame_capture.h audio_capture.h d88_image.h Makefile $(MACHINE_MANIFEST)
	$(V) -cc --no-timing --savable --assert --trace-fst --exe --build -j 4 --Mdir obj_dir_turbo_video_savable --top-module top \
		$(TURBO_DSW_FLAGS) -GTURBO=1 -GTURBO_VIDEO_MASTER=1 -CFLAGS "-std=c++20 -DX1_TURBO_FOUNDATION -DX1_TURBO_VIDEO_MASTER -DX1_SAVABLE" \
		-MAKEFLAGS "OPT_FAST=-O3" $(V_SRC) sim_headless.cpp -Wno-fatal -o Vtop

obj_dir_turbo_video/Vtop: $(V_SRC) sim_headless.cpp frame_capture.h audio_capture.h d88_image.h Makefile $(MACHINE_MANIFEST)
	$(V) -cc --timing --assert --trace-fst --exe --build -j 4 --Mdir obj_dir_turbo_video --top-module top \
		$(TURBO_DSW_FLAGS) -GTURBO=1 -GTURBO_VIDEO_MASTER=1 -CFLAGS "-std=c++20 -DX1_TURBO_FOUNDATION -DX1_TURBO_VIDEO_MASTER" \
		-MAKEFLAGS "OPT_FAST=-O3" $(V_SRC) sim_headless.cpp -Wno-fatal -o Vtop

obj_dir_turbo_video_fast/Vtop: $(V_SRC) sim_headless.cpp frame_capture.h audio_capture.h d88_image.h Makefile $(MACHINE_MANIFEST)
	$(V) -cc --no-timing --assert --trace-fst --exe --build -j 4 --Mdir obj_dir_turbo_video_fast --top-module top \
		$(TURBO_DSW_FLAGS) -GTURBO=1 -GTURBO_VIDEO_MASTER=1 -CFLAGS "-std=c++20 -DX1_TURBO_FOUNDATION -DX1_TURBO_VIDEO_MASTER" \
		-MAKEFLAGS "OPT_FAST=-O3" $(V_SRC) sim_headless.cpp -Wno-fatal -o Vtop

.PHONY: turbo-video turbo-video-fast turbo-video-savable

test-turbo-video-snapshot: turbo-video-savable fast
	python3 tests/test_turbo_video_snapshot.py ./obj_dir_turbo_video_savable/Vtop ./obj_dir_fast/Vtop

.PHONY: test-turbo-video-snapshot

test-video-timing: $(HEADLESS_DIR)/video-timing/Vvideo_timing_tb
	./$(HEADLESS_DIR)/video-timing/Vvideo_timing_tb

$(HEADLESS_DIR)/video-timing/Vvideo_timing_tb: ../rtl/x1_video_timing.sv tests/video_timing_tb.sv
	$(V) --binary --timing --assert --top-module video_timing_tb --Mdir $(HEADLESS_DIR)/video-timing \
		-j 4 ../rtl/x1_video_timing.sv tests/video_timing_tb.sv -Wno-fatal

.PHONY: test-video-timing

test-video-status: $(HEADLESS_DIR)/video-status/Vvideo_status_tb
	@for half in 3 7 31; do ./$(HEADLESS_DIR)/video-status/Vvideo_status_tb +VIDEO_HALF=$$half || exit 1; done

$(HEADLESS_DIR)/video-status/Vvideo_status_tb: tests/video_status_tb.sv ../rtl/x1_video_status.sv
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module video_status_tb --Mdir $(HEADLESS_DIR)/video-status \
		-j 2 tests/video_status_tb.sv ../rtl/x1_video_status.sv -Wno-fatal
.PHONY: test-video-status

test-reset-release: $(HEADLESS_DIR)/reset-release/Vreset_release_tb
	@for half in 3 7 31; do ./$(HEADLESS_DIR)/reset-release/Vreset_release_tb +VIDEO_HALF=$$half || exit 1; done

$(HEADLESS_DIR)/reset-release/Vreset_release_tb: tests/reset_release_tb.sv ../rtl/x1_reset_release.sv
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module reset_release_tb --Mdir $(HEADLESS_DIR)/reset-release \
		-j 2 tests/reset_release_tb.sv ../rtl/x1_reset_release.sv -Wno-fatal
.PHONY: test-reset-release

test-dma-reset: $(HEADLESS_DIR)/dma-reset/Vdma_reset_tb
	./$(HEADLESS_DIR)/dma-reset/Vdma_reset_tb
$(HEADLESS_DIR)/dma-reset/Vdma_reset_tb: tests/dma_reset_tb.sv ../rtl/x1_dma_reset.sv
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module dma_reset_tb --Mdir $(HEADLESS_DIR)/dma-reset \
		-j 2 tests/dma_reset_tb.sv ../rtl/x1_dma_reset.sv -Wno-fatal
.PHONY: test-dma-reset

test-video-status-cpu: turbo-video
	python3 tests/test_video_status.py ./obj_dir_turbo_video/Vtop

.PHONY: test-video-status-cpu

test-text-raster: test-crtc-raster-boundary $(HEADLESS_DIR)/text-raster/Vtext_raster_tb $(HEADLESS_DIR)/turbo-video/Vturbo_video_tb
	./$(HEADLESS_DIR)/text-raster/Vtext_raster_tb
	./$(HEADLESS_DIR)/turbo-video/Vturbo_video_tb

$(HEADLESS_DIR)/text-raster/Vtext_raster_tb: tests/text_raster_tb.sv ../rtl/x1_text_raster.sv
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module text_raster_tb --Mdir $(HEADLESS_DIR)/text-raster \
		-j 2 tests/text_raster_tb.sv ../rtl/x1_text_raster.sv -Wno-fatal

.PHONY: test-text-raster

TEXT_RASTER_TIMEOUT ?= 1800
test-text-raster-cpu: turbo-video-fast turbo-video
	mkdir -p $(HEADLESS_DIR)
	@run_root=$$(mktemp -d $(HEADLESS_DIR)/text-raster-cpu.XXXXXX); \
	python3 tests/test_turbo_text_raster.py ./obj_dir_turbo_video_fast/Vtop --scan low --rows 20 --columns 80 --output $$run_root/low20 --timeout $(TEXT_RASTER_TIMEOUT) && \
	python3 tests/test_turbo_text_raster.py ./obj_dir_turbo_video_fast/Vtop --scan high --rows 12 --columns 80 --output $$run_root/high12 --timeout $(TEXT_RASTER_TIMEOUT) && \
	python3 tests/test_turbo_text_raster.py ./obj_dir_turbo_video/Vtop --scan high --rows 20 --columns 40 --output $$run_root/high20-delay --timeout $(TEXT_RASTER_TIMEOUT)

.PHONY: test-text-raster-cpu

# Expensive full documented row/width matrix. Each case retains one simulated
# second and the every-pixel/period oracle; this is not native BASIC acceptance.
test-text-raster-matrix: turbo-video-fast
	mkdir -p $(HEADLESS_DIR)
	@run_root=$$(mktemp -d $(HEADLESS_DIR)/text-raster-matrix.XXXXXX); \
	for scan in low high; do \
	  for rows in 10 12 20 25; do \
	    if [ "$$scan" = high ] && [ "$$rows" = 10 ]; then continue; fi; \
	    for columns in 40 80; do \
	      python3 tests/test_turbo_text_raster.py ./obj_dir_turbo_video_fast/Vtop \
	        --scan $$scan --rows $$rows --columns $$columns \
	        --output $$run_root/$$scan-$$rows-$$columns --timeout $(TEXT_RASTER_TIMEOUT) || exit 1; \
	    done; \
	  done; \
	done; \
	for columns in 40 80; do \
	  python3 tests/test_turbo_text_raster.py ./obj_dir_turbo_video_fast/Vtop \
	    --scan low --rows 20 --columns $$columns --exit-underline \
	    --output $$run_root/exit-$$columns --timeout $(TEXT_RASTER_TIMEOUT) || exit 1; \
	done

.PHONY: test-text-raster-matrix

test-crtc-raster-boundary: $(HEADLESS_DIR)/crtc-boundary/Vcrtc_raster_boundary_tb
	./$(HEADLESS_DIR)/crtc-boundary/Vcrtc_raster_boundary_tb

$(HEADLESS_DIR)/crtc-boundary/Vcrtc_raster_boundary_tb: tests/crtc_raster_boundary_tb.sv ../rtl/legacy/crtc/crtc6845s.v
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module crtc_raster_boundary_tb --Mdir $(HEADLESS_DIR)/crtc-boundary \
		-j 2 tests/crtc_raster_boundary_tb.sv ../rtl/legacy/crtc/crtc6845s.v -Wno-fatal

.PHONY: test-crtc-raster-boundary

test-font16: $(HEADLESS_DIR)/font16/Vfont16_tb
	./$(HEADLESS_DIR)/font16/Vfont16_tb

$(HEADLESS_DIR)/font16/Vfont16_tb: ../rtl/x1_font16.sv ../rtl/x1_video_ram.v tests/font16_tb.sv
	$(V) --binary --timing --assert --top-module font16_tb --Mdir $(HEADLESS_DIR)/font16 \
		-j 4 ../rtl/x1_font16.sv ../rtl/x1_video_ram.v tests/font16_tb.sv -Wno-fatal

.PHONY: test-font16

# Standalone CDC protocol diagnostic; not machine/framework integration or STA.
test-cdc-snapshot: $(HEADLESS_DIR)/cdc-snapshot/Vcdc_snapshot_tb
	./$(HEADLESS_DIR)/cdc-snapshot/Vcdc_snapshot_tb

$(HEADLESS_DIR)/cdc-snapshot/Vcdc_snapshot_tb: ../rtl/x1_cdc_snapshot.sv tests/cdc_snapshot_tb.sv
	$(V) --binary --timing --assert --top-module cdc_snapshot_tb --Mdir $(HEADLESS_DIR)/cdc-snapshot \
		-j 4 ../rtl/x1_cdc_snapshot.sv tests/cdc_snapshot_tb.sv

.PHONY: test-cdc-snapshot

# Asset-free collector failure-path test; not a machine/game acceptance test.
test-probe-timeout:
	python3 tests/test_probe_timeout.py

.PHONY: test-probe-timeout

test-hps-video-cdc: $(HEADLESS_DIR)/hps-video-cdc/Vhps_video_cdc_tb
	./$(HEADLESS_DIR)/hps-video-cdc/Vhps_video_cdc_tb

$(HEADLESS_DIR)/hps-video-cdc/Vhps_video_cdc_tb: ../sys/hps_io.sv ../rtl/x1_cdc_snapshot.sv tests/hps_video_cdc_tb.sv
	$(V) --binary --timing --assert --top-module hps_video_cdc_tb --Mdir $(HEADLESS_DIR)/hps-video-cdc \
		-j 4 ../sys/hps_io.sv ../rtl/x1_cdc_snapshot.sv tests/hps_video_cdc_tb.sv -Wno-fatal

.PHONY: test-hps-video-cdc

# Native-software probes without snapshots; --timing remains the diagnostic
# reference. Keep this separate from the base savable gameplay executable.
obj_dir_turbo_fast/Vtop: $(V_SRC) sim_headless.cpp frame_capture.h audio_capture.h d88_image.h Makefile $(MACHINE_MANIFEST)
	$(V) -cc --no-timing --assert --trace-fst --exe --build -j 4 --Mdir obj_dir_turbo_fast --top-module top \
		$(TURBO_DSW_FLAGS) -GTURBO=1 -CFLAGS "-std=c++20 -DX1_TURBO_FOUNDATION" -MAKEFLAGS "OPT_FAST=-O3" \
		$(V_SRC) sim_headless.cpp -Wno-fatal -o Vtop

obj_dir_turbo/Vtop: $(V_SRC) sim_headless.cpp frame_capture.h audio_capture.h d88_image.h Makefile $(MACHINE_MANIFEST)
	$(V) -cc --timing --assert --trace-fst --exe --build -j 4 --Mdir obj_dir_turbo --top-module top \
		$(TURBO_DSW_FLAGS) -GTURBO=1 -CFLAGS "-std=c++20 -DX1_TURBO_FOUNDATION" -MAKEFLAGS "OPT_FAST=-O3" \
		$(V_SRC) sim_headless.cpp -Wno-fatal -o Vtop

obj_dir_turbo_single/Vtop: $(V_SRC) sim_headless.cpp frame_capture.h audio_capture.h d88_image.h Makefile $(MACHINE_MANIFEST)
	$(V) -cc --timing --assert --trace-fst --exe --build -j 4 --Mdir obj_dir_turbo_single --top-module top \
		$(TURBO_DSW_FLAGS) -GTURBO=1 -GSINGLE_CLOCK=1 -GMASTER_HZ=28636364 -CFLAGS "-std=c++20 -DX1_SINGLE_CLOCK -DX1_TURBO_FOUNDATION" \
		-MAKEFLAGS "OPT_FAST=-O3" $(V_SRC) sim_headless.cpp -Wno-fatal -o Vtop

.PHONY: turbo turbo-single turbo-fast

test-turbo: turbo test-ctc test-gram-address test-video-timing test-video-status test-text-raster test-turbo-pcg-access test-dma test-dma-cpu $(HEADLESS_DIR)/turbo-video/Vturbo_video_tb
	python3 tests/test_turbo_banks.py ./obj_dir_turbo/Vtop
	python3 tests/test_turbo_ipl.py ./obj_dir_turbo/Vtop
	python3 tests/test_turbo_pcg.py ./obj_dir_turbo/Vtop
	python3 tests/test_ctc.py ./obj_dir_turbo/Vtop
	python3 tests/test_keyboard_irq.py ./obj_dir_turbo/Vtop
	python3 tests/test_keyboard_poll.py ./obj_dir_turbo/Vtop
	python3 tests/test_bus_trace.py ./obj_dir_turbo/Vtop
	python3 tests/test_drive_selection.py ./obj_dir_turbo/Vtop
	python3 tests/test_dual_disk.py ./obj_dir_turbo/Vtop
	./$(HEADLESS_DIR)/turbo-video/Vturbo_video_tb

$(HEADLESS_DIR)/turbo-video/Vturbo_video_tb: tests/turbo_video_tb.sv ../rtl/legacy/x1_vid.v ../rtl/legacy/crtc/crtc6845s.v ../rtl/x1_video_timing.sv ../rtl/x1_text_raster.sv
	$(V) --binary --timing --assert --top-module turbo_video_tb --Mdir $(HEADLESS_DIR)/turbo-video \
		-j 4 ../rtl/x1_video_timing.sv ../rtl/x1_text_raster.sv ../rtl/legacy/x1_vid.v ../rtl/legacy/crtc/crtc6845s.v tests/turbo_video_tb.sv -Wno-fatal

.PHONY: test-turbo

test-gram-address: $(HEADLESS_DIR)/gram-address/Vgram_address_tb
	./$(HEADLESS_DIR)/gram-address/Vgram_address_tb

$(HEADLESS_DIR)/gram-address/Vgram_address_tb: tests/gram_address_tb.sv ../rtl/x1_gram_address.sv
	$(V) --binary --timing --assert --top-module gram_address_tb --Mdir $(HEADLESS_DIR)/gram-address \
		-j 4 ../rtl/x1_gram_address.sv tests/gram_address_tb.sv -Wno-fatal

.PHONY: test-gram-address

# Full CPU-written address matrix. Uses the delay-aware Turbo model; clocks
# remain the old profile, so this is not native 24 kHz timing acceptance.
test-turbo-raster: turbo test-gram-address
	@for mode in 0 1 2 3; do for bank in 0 1; do \
		python3 tests/test_video_modes.py ./obj_dir_turbo/Vtop --kind graphics \
		--turbo-raster $$mode --turbo-bank $$bank $(VIDEO_TEST_FLAGS) || exit 1; \
		done; done

.PHONY: test-turbo-raster

SUB_IRQ_SRC = ../rtl/mr16core.v ../rtl/mr16_x1.v ../rtl/sub_rom.v ../rtl/sub_cpu.v ../rtl/dpram.sv ../rtl/x1_irq_bridge.sv tests/sub_irq_ack_tb.sv
SUB_IRQ_HZ = 32000000 28636364 28571428
SUB_IRQ_BINS = $(foreach hz,$(SUB_IRQ_HZ),$(HEADLESS_DIR)/subirq/$(hz)/Vsub_irq_ack_tb)

test-ctc: $(HEADLESS_DIR)/ctc/Vx1_ctc_tb $(HEADLESS_DIR)/irq/Vx1_irq_bridge_tb $(HEADLESS_DIR)/ctcirq/Vx1_ctc_irq_tb $(SUB_IRQ_BINS)
	./$(HEADLESS_DIR)/ctc/Vx1_ctc_tb
	./$(HEADLESS_DIR)/irq/Vx1_irq_bridge_tb
	./$(HEADLESS_DIR)/ctcirq/Vx1_ctc_irq_tb
	@for hz in $(SUB_IRQ_HZ); do ./$(HEADLESS_DIR)/subirq/$$hz/Vsub_irq_ack_tb || exit 1; done

$(HEADLESS_DIR)/subirq/%/Vsub_irq_ack_tb: $(SUB_IRQ_SRC)
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module sub_irq_ack_tb --Mdir $(HEADLESS_DIR)/subirq/$* \
		-GCLOCK_HZ=$* -j 4 $(SUB_IRQ_SRC) -Wno-fatal

$(HEADLESS_DIR)/ctc/Vx1_ctc_tb: ../rtl/x1_ctc.sv tests/x1_ctc_tb.sv
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module x1_ctc_tb --Mdir $(HEADLESS_DIR)/ctc \
		-j 4 ../rtl/x1_ctc.sv tests/x1_ctc_tb.sv -Wno-fatal

$(HEADLESS_DIR)/irq/Vx1_irq_bridge_tb: ../rtl/x1_irq_bridge.sv tests/x1_irq_bridge_tb.sv
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module x1_irq_bridge_tb --Mdir $(HEADLESS_DIR)/irq \
		-j 4 ../rtl/x1_irq_bridge.sv tests/x1_irq_bridge_tb.sv -Wno-fatal

$(HEADLESS_DIR)/ctcirq/Vx1_ctc_irq_tb: ../rtl/x1_ctc.sv ../rtl/x1_irq_bridge.sv tests/x1_ctc_irq_tb.sv
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module x1_ctc_irq_tb --Mdir $(HEADLESS_DIR)/ctcirq \
		-j 4 ../rtl/x1_ctc.sv ../rtl/x1_irq_bridge.sv tests/x1_ctc_irq_tb.sv -Wno-fatal

.PHONY: test-ctc

test-single: single test-clock-enables test-sub-timer test-fdc-abort test-fdc-sd-abort test-d88-scanner test-d88-crc test-cpu-busreq
	python3 tests/test_key_script.py ./obj_dir_single/Vtop $(VIDEO_TEST_FLAGS)
	python3 tests/test_video_modes.py ./obj_dir_single/Vtop $(VIDEO_TEST_FLAGS)
	python3 tests/test_video_modes.py ./obj_dir_single/Vtop --kind mixed --transition $(VIDEO_TEST_FLAGS)
	python3 tests/test_keyboard_poll.py ./obj_dir_single/Vtop $(VIDEO_TEST_FLAGS)
	python3 tests/test_warm_reset.py ./obj_dir_single/Vtop
	python3 tests/test_d88_bounds.py ./obj_dir_single/Vtop
	python3 tests/test_single_clock.py ./obj_dir_single/Vtop
	python3 tests/test_memory.py ./obj_dir_single/Vtop
	python3 tests/test_ctc_base.py ./obj_dir_single/Vtop
	python3 tests/test_subcpu.py ./obj_dir_single/Vtop
	python3 tests/test_graphics_bus.py ./obj_dir_single/Vtop
	python3 tests/test_keyboard_irq.py ./obj_dir_single/Vtop
	python3 tests/test_audio.py ./obj_dir_single/Vtop
	python3 tests/test_psg_modes.py ./obj_dir_single/Vtop
	python3 tests/test_system_ports.py ./obj_dir_single/Vtop
	python3 tests/test_pcg.py ./obj_dir_single/Vtop 28636364
	python3 tests/test_disk.py ./obj_dir_single/Vtop
	python3 tests/test_dual_disk.py ./obj_dir_single/Vtop

boot-game-single: single-fast
	./obj_dir_single_fast/Vtop --cycles 416000000 --rom ../bios/ipl_x1.hex --disk $(GAME_DISK) \
		--keys tests/cross_start.keys --save-state obj_dir_single_fast/cross-start.state \
		--frame obj_dir_single_fast/cross-start.ppm --dump obj_dir_single_fast/cross-start --progress

test-game-single: single-fast
	python3 tests/test_gameplay.py ./obj_dir_single_fast/Vtop obj_dir_single_fast/cross-start.state $(GAME_DISK)

test-game-reset-single: single-fast
	python3 tests/test_game_reset.py ./obj_dir_single_fast/Vtop obj_dir_single_fast/cross-start.state $(GAME_DISK)

test-clock-enables: obj_dir_single/enable/Vclock_enables_tb obj_dir_single/crtc/Vcrtc_enable_tb
	./obj_dir_single/enable/Vclock_enables_tb
	./obj_dir_single/crtc/Vcrtc_enable_tb

test-sub-timer: obj_dir_single/subtimer/Vsub_timer_tb obj_dir_single/subtimer_board/Vsub_timer_tb obj_dir_single/subtimer_base/Vsub_timer_tb
	./obj_dir_single/subtimer/Vsub_timer_tb
	./obj_dir_single/subtimer_board/Vsub_timer_tb
	./obj_dir_single/subtimer_base/Vsub_timer_tb

obj_dir_single/subtimer/Vsub_timer_tb: tests/sub_timer_tb.sv ../rtl/mr16_x1.v ../rtl/mr16core.v
	$(V) --binary --timing --assert --top-module sub_timer_tb --Mdir obj_dir_single/subtimer \
		-j 4 ../rtl/mr16core.v ../rtl/mr16_x1.v tests/sub_timer_tb.sv -Wno-fatal

obj_dir_single/subtimer_board/Vsub_timer_tb: tests/sub_timer_tb.sv ../rtl/mr16_x1.v ../rtl/mr16core.v
	$(V) --binary --timing --assert --top-module sub_timer_tb --Mdir obj_dir_single/subtimer_board \
		-GCLOCK_HZ=28571428 -j 4 ../rtl/mr16core.v ../rtl/mr16_x1.v tests/sub_timer_tb.sv -Wno-fatal

obj_dir_single/subtimer_base/Vsub_timer_tb: tests/sub_timer_tb.sv ../rtl/mr16_x1.v ../rtl/mr16core.v
	$(V) --binary --timing --assert --top-module sub_timer_tb --Mdir obj_dir_single/subtimer_base \
		-GCLOCK_HZ=32000000 -j 4 ../rtl/mr16core.v ../rtl/mr16_x1.v tests/sub_timer_tb.sv -Wno-fatal

obj_dir_single/enable/Vclock_enables_tb: tests/clock_enables_tb.sv ../rtl/x1_clock_enables.v
	$(V) --binary --timing --assert --top-module clock_enables_tb --Mdir obj_dir_single/enable \
		-j 4 ../rtl/x1_clock_enables.v tests/clock_enables_tb.sv -Wno-fatal

obj_dir_single/crtc/Vcrtc_enable_tb: tests/crtc_enable_tb.sv ../rtl/legacy/crtc/crtc6845s.v
	$(V) --binary --timing --assert --top-module crtc_enable_tb --Mdir obj_dir_single/crtc \
		-j 4 ../rtl/legacy/crtc/crtc6845s.v tests/crtc_enable_tb.sv -Wno-fatal

obj_dir_single/Vtop: $(V_SRC) sim_headless.cpp frame_capture.h audio_capture.h d88_image.h Makefile $(MACHINE_MANIFEST)
	$(V) -cc --timing --assert --trace-fst --exe --build -j 4 --Mdir obj_dir_single --top-module top \
		-GSINGLE_CLOCK=1 -GMASTER_HZ=28636364 -CFLAGS "-std=c++20 -DX1_SINGLE_CLOCK" \
		-MAKEFLAGS "OPT_FAST=-O3" $(V_SRC) sim_headless.cpp -Wno-fatal -o Vtop

obj_dir_single_fast/Vtop: $(V_SRC) sim_headless.cpp frame_capture.h audio_capture.h d88_image.h sdl_frontend.h Makefile $(MACHINE_MANIFEST)
	$(V) -cc --no-timing --savable --assert --trace-fst --exe --build -j 4 --Mdir obj_dir_single_fast --top-module top \
		-GSINGLE_CLOCK=1 -GMASTER_HZ=28636364 -CFLAGS "-std=c++20 -DX1_SINGLE_CLOCK -DX1_SDL -DX1_SAVABLE $(shell sdl2-config --cflags)" \
		-MAKEFLAGS "OPT_FAST=-O3" -LDFLAGS "$(shell sdl2-config --libs)" $(V_SRC) sim_headless.cpp -Wno-fatal -o Vtop

GAME_DISK ?= ../references/software/private-downloads/cross-chase/Xchase_x1.d88
GAME_STATE ?= obj_dir_fast/cross-start.state
PLAY_CYCLES ?= 32000000000

# Local, licensed assets are not bundled. Regenerate after changing RTL.
boot-game: fast
	./obj_dir_fast/Vtop --cycles 416000000 --rom ../bios/ipl_x1.hex --disk $(GAME_DISK) \
		--keys tests/cross_start.keys --save-state $(GAME_STATE) \
		--frame obj_dir_fast/cross-start.ppm --dump obj_dir_fast/cross-start --progress

test-game: fast
	python3 tests/test_gameplay.py ./obj_dir_fast/Vtop $(GAME_STATE) $(GAME_DISK)

test-game-reset: fast
	python3 tests/test_game_reset.py ./obj_dir_fast/Vtop $(GAME_STATE) $(GAME_DISK)

play: fast
	./obj_dir_fast/Vtop --interactive --cycles $(PLAY_CYCLES) \
		--restore-state $(GAME_STATE) --disk $(GAME_DISK)

obj_dir_fast/Vtop: $(V_SRC) sim_headless.cpp frame_capture.h audio_capture.h d88_image.h sdl_frontend.h Makefile $(MACHINE_MANIFEST)
	$(V) -cc --no-timing --savable --assert --trace-fst --exe --build -j 4 --Mdir obj_dir_fast --top-module top \
		-CFLAGS "-std=c++20 -DX1_SDL -DX1_SAVABLE $(shell sdl2-config --cflags)" -MAKEFLAGS "OPT_FAST=-O3" \
		-LDFLAGS "$(shell sdl2-config --libs)" $(V_SRC) sim_headless.cpp -Wno-fatal -o Vtop

obj_dir_interactive/Vtop: $(V_SRC) sim_headless.cpp frame_capture.h audio_capture.h d88_image.h sdl_frontend.h Makefile $(MACHINE_MANIFEST)
	$(V) -cc --timing --assert --trace-fst --exe --build -j 4 --Mdir obj_dir_interactive --top-module top \
		-CFLAGS "-O2 -std=c++20 -DX1_SDL $(shell sdl2-config --cflags)" \
		-LDFLAGS "$(shell sdl2-config --libs)" $(V_SRC) sim_headless.cpp -Wno-fatal -o Vtop

$(HEADLESS_EXE): $(V_SRC) sim_headless.cpp frame_capture.h audio_capture.h d88_image.h Makefile $(MACHINE_MANIFEST)
	$(V) -cc --timing --assert --trace-fst --exe --build -j 4 --Mdir $(HEADLESS_DIR) --top-module top \
		-CFLAGS "-std=c++20" -MAKEFLAGS "OPT_FAST=-O3" $(V_SRC) sim_headless.cpp \
		-Wno-fatal -o Vtop

run: headless
	./$(HEADLESS_EXE) $(CYCLES)

test: headless test-rgb12 test-sub-timer test-fdc-abort test-fdc-sd-abort test-d88-scanner test-d88-crc test-d88-metadata test-cpu-busreq
	python3 tests/test_key_script.py ./$(HEADLESS_EXE) $(VIDEO_TEST_FLAGS)
	python3 tests/test_video_modes.py ./$(HEADLESS_EXE) $(VIDEO_TEST_FLAGS)
	python3 tests/test_video_modes.py ./$(HEADLESS_EXE) --kind mixed --transition $(VIDEO_TEST_FLAGS)
	$(MAKE) test-peripherals

# Resume the independent peripheral checks after a long video matrix, using
# the same HEADLESS_EXE. Keep test's original sequential execution order.
test-peripherals: headless
	python3 tests/test_keyboard_poll.py ./$(HEADLESS_EXE) $(VIDEO_TEST_FLAGS)
	python3 tests/test_warm_reset.py ./$(HEADLESS_EXE)
	python3 tests/test_d88_bounds.py ./$(HEADLESS_EXE)
	python3 tests/test_timing.py ./$(HEADLESS_EXE)
	python3 tests/test_memory.py ./$(HEADLESS_EXE)
	python3 tests/test_ctc_base.py ./$(HEADLESS_EXE)
	python3 tests/test_bus_trace.py ./$(HEADLESS_EXE)
	python3 tests/test_drive_selection.py ./$(HEADLESS_EXE)
	python3 tests/test_dual_disk.py ./$(HEADLESS_EXE)
	python3 tests/test_subcpu.py ./$(HEADLESS_EXE)
	python3 tests/test_graphics_bus.py ./$(HEADLESS_EXE)
	python3 tests/test_keyboard_irq.py ./$(HEADLESS_EXE)
	python3 tests/test_audio.py ./$(HEADLESS_EXE)
	python3 tests/test_psg_modes.py ./$(HEADLESS_EXE)
	python3 tests/test_system_ports.py ./$(HEADLESS_EXE)
	python3 tests/test_pcg.py ./$(HEADLESS_EXE)
	python3 tests/test_disk.py ./$(HEADLESS_EXE)
	$(MAKE) test-loader
	$(MAKE) test-joystick
	$(MAKE) test-pcg-access
	$(MAKE) test-disk-control

test-fast: fast test-sub-timer test-fdc-abort test-fdc-sd-abort test-d88-scanner test-d88-crc test-d88-metadata test-cpu-busreq
	python3 tests/test_key_script.py ./obj_dir_fast/Vtop $(VIDEO_TEST_FLAGS)
	python3 tests/test_video_modes.py ./obj_dir_fast/Vtop $(VIDEO_TEST_FLAGS)
	python3 tests/test_video_modes.py ./obj_dir_fast/Vtop --kind mixed --transition $(VIDEO_TEST_FLAGS)
	python3 tests/test_keyboard_poll.py ./obj_dir_fast/Vtop $(VIDEO_TEST_FLAGS)
	python3 tests/test_warm_reset.py ./obj_dir_fast/Vtop
	python3 tests/test_d88_bounds.py ./obj_dir_fast/Vtop
	python3 tests/test_memory.py ./obj_dir_fast/Vtop
	python3 tests/test_ctc_base.py ./obj_dir_fast/Vtop
	python3 tests/test_subcpu.py ./obj_dir_fast/Vtop
	python3 tests/test_graphics_bus.py ./obj_dir_fast/Vtop
	python3 tests/test_keyboard_irq.py ./obj_dir_fast/Vtop
	python3 tests/test_audio.py ./obj_dir_fast/Vtop
	python3 tests/test_psg_modes.py ./obj_dir_fast/Vtop
	python3 tests/test_system_ports.py ./obj_dir_fast/Vtop
	python3 tests/test_pcg.py ./obj_dir_fast/Vtop
	python3 tests/test_disk.py ./obj_dir_fast/Vtop
	python3 tests/test_dual_disk.py ./obj_dir_fast/Vtop
	python3 tests/test_snapshot.py ./obj_dir_fast/Vtop
	$(MAKE) test-sdl
	$(MAKE) test-joystick
	$(MAKE) test-pcg-access
	$(MAKE) test-disk-control

test-disk-control: $(HEADLESS_DIR)/disk/Vdisk_control_tb $(HEADLESS_DIR)/index/Vfdc_index_tb $(HEADLESS_DIR)/media/Vdisk_media_tb $(HEADLESS_DIR)/dual-fdc/Vdual_fdc_tb
	./$(HEADLESS_DIR)/media/Vdisk_media_tb
	./$(HEADLESS_DIR)/dual-fdc/Vdual_fdc_tb
	$(MAKE) test-write-eject
	./$(HEADLESS_DIR)/disk/Vdisk_control_tb
	./$(HEADLESS_DIR)/index/Vfdc_index_tb

test-fdc-abort: $(HEADLESS_DIR)/abort/Vfdc_abort_tb
	./$(HEADLESS_DIR)/abort/Vfdc_abort_tb

$(HEADLESS_DIR)/abort/Vfdc_abort_tb: tests/fdc_abort_tb.sv ../rtl/vendor/wd1793.sv ../rtl/vendor/x1_fdc_index_ram.v
	$(V) --binary --timing --assert --top-module fdc_abort_tb --Mdir $(HEADLESS_DIR)/abort \
		-j 4 ../rtl/vendor/wd1793.sv ../rtl/vendor/x1_fdc_index_ram.v tests/fdc_abort_tb.sv -Wno-fatal

.PHONY: test-fdc-abort

test-fdc-sd-abort: $(HEADLESS_DIR)/sd-abort/Vfdc_sd_abort_tb
	./$(HEADLESS_DIR)/sd-abort/Vfdc_sd_abort_tb

$(HEADLESS_DIR)/sd-abort/Vfdc_sd_abort_tb: tests/fdc_sd_abort_tb.sv ../rtl/vendor/wd1793.sv ../rtl/vendor/x1_fdc_index_ram.v
	$(V) --binary --timing --assert --top-module fdc_sd_abort_tb --Mdir $(HEADLESS_DIR)/sd-abort \
		-j 4 ../rtl/vendor/wd1793.sv ../rtl/vendor/x1_fdc_index_ram.v tests/fdc_sd_abort_tb.sv -Wno-fatal

.PHONY: test-fdc-sd-abort

test-d88-scanner: $(HEADLESS_DIR)/d88/Vd88_scanner_tb
	./$(HEADLESS_DIR)/d88/Vd88_scanner_tb

$(HEADLESS_DIR)/d88/Vd88_scanner_tb: tests/d88_scanner_tb.sv ../rtl/vendor/wd1793.sv ../rtl/vendor/x1_fdc_index_ram.v
	$(V) --binary --timing --assert --top-module d88_scanner_tb --Mdir $(HEADLESS_DIR)/d88 \
		-j 4 ../rtl/vendor/wd1793.sv ../rtl/vendor/x1_fdc_index_ram.v tests/d88_scanner_tb.sv -Wno-fatal

.PHONY: test-d88-scanner

test-d88-crc: $(HEADLESS_DIR)/d88-crc/Vd88_crc_tb
	./$(HEADLESS_DIR)/d88-crc/Vd88_crc_tb +divider=8
	./$(HEADLESS_DIR)/d88-crc/Vd88_crc_tb +divider=1

$(HEADLESS_DIR)/d88-crc/Vd88_crc_tb: tests/d88_crc_tb.sv ../rtl/vendor/wd1793.sv ../rtl/vendor/x1_fdc_index_ram.v
	$(V) --binary --timing --assert --top-module d88_crc_tb --Mdir $(HEADLESS_DIR)/d88-crc \
		-j 4 ../rtl/vendor/wd1793.sv ../rtl/vendor/x1_fdc_index_ram.v tests/d88_crc_tb.sv -Wno-fatal

.PHONY: test-d88-crc

test-cpu-busreq: $(HEADLESS_DIR)/cpu-busreq/Vcpu_busreq_tb
	./$(HEADLESS_DIR)/cpu-busreq/Vcpu_busreq_tb

$(HEADLESS_DIR)/cpu-busreq/Vcpu_busreq_tb: tests/cpu_busreq_tb.sv ../rtl/cpu.v $(wildcard ../rtl/tv80/*.v)
	$(V) --binary --timing --assert --top-module cpu_busreq_tb --Mdir $(HEADLESS_DIR)/cpu-busreq \
		-j 4 ../rtl/cpu.v ../rtl/tv80/tv80e.v ../rtl/tv80/tv80_core.v \
		../rtl/tv80/tv80_mcode.v ../rtl/tv80/tv80_alu.v ../rtl/tv80/tv80_reg.v tests/cpu_busreq_tb.sv -Wno-fatal

.PHONY: test-cpu-busreq

test-dma: $(HEADLESS_DIR)/dma/Vdma_tb
	./$(HEADLESS_DIR)/dma/Vdma_tb

test-dma-compare: $(HEADLESS_DIR)/dma-compare/Vdma_compare_tb
	@for rate in 1 4; do ./$(HEADLESS_DIR)/dma-compare/Vdma_compare_tb +CE_PERIOD=$$rate || exit 1; done
$(HEADLESS_DIR)/dma-compare/Vdma_compare_tb: tests/dma_compare_tb.sv ../rtl/x1_dma.sv
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module dma_compare_tb --Mdir $(HEADLESS_DIR)/dma-compare \
		-j 4 tests/dma_compare_tb.sv ../rtl/x1_dma.sv
.PHONY: test-dma-compare

test-dma-search: $(HEADLESS_DIR)/dma-search/Vdma_search_tb
	@for rate in 1 4; do ./$(HEADLESS_DIR)/dma-search/Vdma_search_tb +CE_PERIOD=$$rate || exit 1; done
$(HEADLESS_DIR)/dma-search/Vdma_search_tb: tests/dma_search_tb.sv ../rtl/x1_dma.sv
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module dma_search_tb --Mdir $(HEADLESS_DIR)/dma-search \
		-j 4 tests/dma_search_tb.sv ../rtl/x1_dma.sv
.PHONY: test-dma-search

test-dma-service: $(HEADLESS_DIR)/dma-service/Vdma_service_tb
	./$(HEADLESS_DIR)/dma-service/Vdma_service_tb
$(HEADLESS_DIR)/dma-service/Vdma_service_tb: tests/dma_service_tb.sv ../rtl/x1_dma_service.sv ../rtl/x1_dma_vector.sv
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module dma_service_tb --Mdir $(HEADLESS_DIR)/dma-service \
		-j 4 tests/dma_service_tb.sv ../rtl/x1_dma_service.sv ../rtl/x1_dma_vector.sv
.PHONY: test-dma-service

test-dma-service-cpu: $(HEADLESS_DIR)/dma-service-cpu/Vdma_service_cpu_tb
	@for rate in 1 4 7; do for profile in 0 1 2 3; do \
		./$(HEADLESS_DIR)/dma-service-cpu/Vdma_service_cpu_tb +CE_PERIOD=$$rate +PROFILE=$$profile || exit 1; \
	done; done
$(HEADLESS_DIR)/dma-service-cpu/Vdma_service_cpu_tb: tests/dma_service_cpu_tb.sv ../rtl/x1_dma_service.sv ../rtl/x1_dma_vector.sv ../rtl/x1_dma.sv ../rtl/cpu.v $(wildcard ../rtl/tv80/*.v)
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module dma_service_cpu_tb --Mdir $(HEADLESS_DIR)/dma-service-cpu \
		-j 4 tests/dma_service_cpu_tb.sv ../rtl/x1_dma_service.sv ../rtl/x1_dma_vector.sv ../rtl/x1_dma.sv \
		../rtl/cpu.v ../rtl/tv80/tv80e.v ../rtl/tv80/tv80_core.v ../rtl/tv80/tv80_mcode.v \
		../rtl/tv80/tv80_alu.v ../rtl/tv80/tv80_reg.v -Wno-fatal
.PHONY: test-dma-service-cpu

test-dma-native-irq-cpu: $(HEADLESS_DIR)/dma-native-irq-cpu/Vdma_service_cpu_tb
	@for rate in 1 4 7; do for profile in 0 1 2 3; do \
		./$(HEADLESS_DIR)/dma-native-irq-cpu/Vdma_service_cpu_tb +CE_PERIOD=$$rate +PROFILE=$$profile || exit 1; \
	done; done
$(HEADLESS_DIR)/dma-native-irq-cpu/Vdma_service_cpu_tb: tests/dma_service_cpu_tb.sv ../rtl/x1_dma_service.sv ../rtl/x1_dma_vector.sv ../rtl/x1_dma.sv ../rtl/cpu.v $(wildcard ../rtl/tv80/*.v)
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module dma_service_cpu_tb -GNATIVE_IRQ=1 --Mdir $(HEADLESS_DIR)/dma-native-irq-cpu \
		-j 4 tests/dma_service_cpu_tb.sv ../rtl/x1_dma_service.sv ../rtl/x1_dma_vector.sv ../rtl/x1_dma.sv \
		../rtl/cpu.v ../rtl/tv80/tv80e.v ../rtl/tv80/tv80_core.v ../rtl/tv80/tv80_mcode.v \
		../rtl/tv80/tv80_alu.v ../rtl/tv80/tv80_reg.v -Wno-fatal
.PHONY: test-dma-native-irq-cpu

test-dma-native-irq: $(HEADLESS_DIR)/dma-native-irq/Vdma_native_irq_tb
	@for rate in 1 4 7; do ./$(HEADLESS_DIR)/dma-native-irq/Vdma_native_irq_tb +CE_PERIOD=$$rate || exit 1; done
$(HEADLESS_DIR)/dma-native-irq/Vdma_native_irq_tb: tests/dma_native_irq_tb.sv ../rtl/x1_dma.sv ../rtl/x1_dma_service.sv ../rtl/x1_dma_vector.sv
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module dma_native_irq_tb --Mdir $(HEADLESS_DIR)/dma-native-irq \
		-j 4 tests/dma_native_irq_tb.sv ../rtl/x1_dma.sv ../rtl/x1_dma_service.sv ../rtl/x1_dma_vector.sv
.PHONY: test-dma-native-irq

test-dma-ready-irq: $(HEADLESS_DIR)/dma-ready-irq/Vdma_ready_irq_tb
	@for rate in 1 4 7; do ./$(HEADLESS_DIR)/dma-ready-irq/Vdma_ready_irq_tb +CE_PERIOD=$$rate || exit 1; done
$(HEADLESS_DIR)/dma-ready-irq/Vdma_ready_irq_tb: tests/dma_ready_irq_tb.sv ../rtl/x1_dma.sv ../rtl/x1_dma_service.sv ../rtl/x1_dma_vector.sv
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module dma_ready_irq_tb --Mdir $(HEADLESS_DIR)/dma-ready-irq \
		-j 4 tests/dma_ready_irq_tb.sv ../rtl/x1_dma.sv ../rtl/x1_dma_service.sv ../rtl/x1_dma_vector.sv
.PHONY: test-dma-ready-irq

test-dma-restart-irq: $(HEADLESS_DIR)/dma-restart-irq/Vdma_restart_irq_tb
	@for rate in 1 4 7; do ./$(HEADLESS_DIR)/dma-restart-irq/Vdma_restart_irq_tb +CE_PERIOD=$$rate || exit 1; done
$(HEADLESS_DIR)/dma-restart-irq/Vdma_restart_irq_tb: tests/dma_restart_irq_tb.sv ../rtl/x1_dma.sv ../rtl/x1_dma_service.sv ../rtl/x1_dma_vector.sv
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module dma_restart_irq_tb --Mdir $(HEADLESS_DIR)/dma-restart-irq \
		-j 4 tests/dma_restart_irq_tb.sv ../rtl/x1_dma.sv ../rtl/x1_dma_service.sv ../rtl/x1_dma_vector.sv
.PHONY: test-dma-restart-irq

test-dma-restart-irq-cpu: $(HEADLESS_DIR)/dma-restart-irq-cpu/Vdma_service_cpu_tb
	@for rate in 1 4 7; do ./$(HEADLESS_DIR)/dma-restart-irq-cpu/Vdma_service_cpu_tb +CE_PERIOD=$$rate +PROFILE=0 || exit 1; done
	@for rate in 1 4 7; do for direction in 0 1; do for mode in 0 1 2; do \
		./$(HEADLESS_DIR)/dma-restart-irq-cpu/Vdma_service_cpu_tb +CE_PERIOD=$$rate +PROFILE=0 +BUFFER_UPDATE=1 +REVERSE=$$direction +RESTART_MODE=$$mode || exit 1; \
	done; done; done
$(HEADLESS_DIR)/dma-restart-irq-cpu/Vdma_service_cpu_tb: tests/dma_service_cpu_tb.sv ../rtl/x1_dma_service.sv ../rtl/x1_dma_vector.sv ../rtl/x1_dma.sv ../rtl/cpu.v $(wildcard ../rtl/tv80/*.v) Makefile
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module dma_service_cpu_tb -GNATIVE_IRQ=1 -GNATIVE_RESTART=1 --Mdir $(HEADLESS_DIR)/dma-restart-irq-cpu \
		-j 4 tests/dma_service_cpu_tb.sv ../rtl/x1_dma_service.sv ../rtl/x1_dma_vector.sv ../rtl/x1_dma.sv \
		../rtl/cpu.v ../rtl/tv80/tv80e.v ../rtl/tv80/tv80_core.v ../rtl/tv80/tv80_mcode.v \
		../rtl/tv80/tv80_alu.v ../rtl/tv80/tv80_reg.v -Wno-fatal
.PHONY: test-dma-restart-irq-cpu

test-dma-ready-irq-cpu: $(HEADLESS_DIR)/dma-ready-irq-cpu/Vdma_service_cpu_tb
	@for rate in 1 4 7; do ./$(HEADLESS_DIR)/dma-ready-irq-cpu/Vdma_service_cpu_tb +CE_PERIOD=$$rate +PROFILE=0 || exit 1; done
$(HEADLESS_DIR)/dma-ready-irq-cpu/Vdma_service_cpu_tb: tests/dma_service_cpu_tb.sv ../rtl/x1_dma_service.sv ../rtl/x1_dma_vector.sv ../rtl/x1_dma.sv ../rtl/cpu.v $(wildcard ../rtl/tv80/*.v) Makefile
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module dma_service_cpu_tb -GNATIVE_IRQ=1 -GNATIVE_READY=1 --Mdir $(HEADLESS_DIR)/dma-ready-irq-cpu \
		-j 4 tests/dma_service_cpu_tb.sv ../rtl/x1_dma_service.sv ../rtl/x1_dma_vector.sv ../rtl/x1_dma.sv \
		../rtl/cpu.v ../rtl/tv80/tv80e.v ../rtl/tv80/tv80_core.v ../rtl/tv80/tv80_mcode.v \
		../rtl/tv80/tv80_alu.v ../rtl/tv80/tv80_reg.v -Wno-fatal
.PHONY: test-dma-ready-irq-cpu

test-dma-irq-bridge: $(HEADLESS_DIR)/dma-irq-bridge/Vdma_irq_bridge_tb
	@for rate in 1 4 7; do ./$(HEADLESS_DIR)/dma-irq-bridge/Vdma_irq_bridge_tb +CE_PERIOD=$$rate || exit 1; done
$(HEADLESS_DIR)/dma-irq-bridge/Vdma_irq_bridge_tb: tests/dma_irq_bridge_tb.sv ../rtl/x1_dma.sv ../rtl/x1_dma_service.sv ../rtl/x1_dma_vector.sv ../rtl/x1_ctc.sv ../rtl/x1_irq_bridge.sv ../rtl/x1_dma_irq_bridge.sv ../rtl/x1_sio_async.sv ../rtl/x1_sio_irq.sv ../rtl/x1_sio_irq_bridge.sv
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module dma_irq_bridge_tb --Mdir $(HEADLESS_DIR)/dma-irq-bridge \
		-j 4 tests/dma_irq_bridge_tb.sv ../rtl/x1_dma.sv ../rtl/x1_dma_service.sv ../rtl/x1_dma_vector.sv \
		../rtl/x1_ctc.sv ../rtl/x1_irq_bridge.sv ../rtl/x1_dma_irq_bridge.sv
.PHONY: test-dma-irq-bridge

test-sio-device-chain: $(HEADLESS_DIR)/sio-device-chain/Vdma_irq_bridge_tb
	@for rate in 1 4 7; do ./$(HEADLESS_DIR)/sio-device-chain/Vdma_irq_bridge_tb +CE_PERIOD=$$rate || exit 1; done
$(HEADLESS_DIR)/sio-device-chain/Vdma_irq_bridge_tb: tests/dma_irq_bridge_tb.sv ../rtl/x1_dma.sv ../rtl/x1_dma_service.sv ../rtl/x1_dma_vector.sv ../rtl/x1_ctc.sv ../rtl/x1_irq_bridge.sv ../rtl/x1_dma_irq_bridge.sv ../rtl/x1_sio_async.sv ../rtl/x1_sio_irq.sv ../rtl/x1_sio_irq_bridge.sv
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module dma_irq_bridge_tb -GSIO_CHAIN=1 --Mdir $(HEADLESS_DIR)/sio-device-chain \
		-j 4 $^ -Wno-fatal
.PHONY: test-sio-device-chain

test-sio-chain-cpu: $(HEADLESS_DIR)/sio-chain-cpu/Vsio_chain_cpu_tb
	@for rate in 1 4 7; do \
		./$(HEADLESS_DIR)/sio-chain-cpu/Vsio_chain_cpu_tb +CE_PERIOD=$$rate || exit 1; \
		./$(HEADLESS_DIR)/sio-chain-cpu/Vsio_chain_cpu_tb +CE_PERIOD=$$rate +RESET_NESTED || exit 1; \
		ulimit -c 0; if ./$(HEADLESS_DIR)/sio-chain-cpu/Vsio_chain_cpu_tb +CE_PERIOD=$$rate +BAD_IUS >$(HEADLESS_DIR)/sio-chain-cpu/bad-ius-$$rate.log 2>&1; then \
			echo 'ERROR: CPU wrong-owner control unexpectedly passed'; exit 1; \
		fi; rg -q 'CPU SIO RETI owner' $(HEADLESS_DIR)/sio-chain-cpu/bad-ius-$$rate.log || \
			{ echo 'ERROR: wrong CPU negative-control failure'; exit 1; }; \
		echo "PASS actual CPU wrong-owner control CE=$$rate rejected"; \
	done
$(HEADLESS_DIR)/sio-chain-cpu/Vsio_chain_cpu_tb: tests/sio_chain_cpu_tb.sv ../rtl/x1_sio_decode.sv ../rtl/x1_sio_async.sv ../rtl/x1_sio_irq.sv ../rtl/x1_sio_irq_bridge.sv ../rtl/x1_dma.sv ../rtl/x1_dma_service.sv ../rtl/x1_dma_vector.sv ../rtl/x1_ctc.sv ../rtl/x1_irq_bridge.sv ../rtl/cpu.v $(wildcard ../rtl/tv80/*.v)
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module sio_chain_cpu_tb --Mdir $(HEADLESS_DIR)/sio-chain-cpu \
		-j 4 tests/sio_chain_cpu_tb.sv ../rtl/x1_sio_decode.sv ../rtl/x1_sio_async.sv ../rtl/x1_sio_irq.sv \
		../rtl/x1_sio_irq_bridge.sv ../rtl/x1_dma.sv ../rtl/x1_dma_service.sv ../rtl/x1_dma_vector.sv \
		../rtl/x1_ctc.sv ../rtl/x1_irq_bridge.sv ../rtl/cpu.v ../rtl/tv80/tv80e.v ../rtl/tv80/tv80_core.v \
		../rtl/tv80/tv80_mcode.v ../rtl/tv80/tv80_alu.v ../rtl/tv80/tv80_reg.v -Wno-fatal
.PHONY: test-sio-chain-cpu

DMA_TEST_CFLAGS ?= -O1
$(HEADLESS_DIR)/dma/Vdma_tb: tests/dma_tb.sv ../rtl/x1_dma.sv Makefile
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module dma_tb --Mdir $(HEADLESS_DIR)/dma \
		-j 2 -CFLAGS "$(DMA_TEST_CFLAGS)" tests/dma_tb.sv ../rtl/x1_dma.sv

.PHONY: test-dma

# Actual CPU wrapper and original program; DMA is not yet a machine device.
test-dma-cpu: $(HEADLESS_DIR)/dma-cpu/Vdma_cpu_tb
	./$(HEADLESS_DIR)/dma-cpu/Vdma_cpu_tb
	./$(HEADLESS_DIR)/dma-cpu/Vdma_cpu_tb +direct-register-read

$(HEADLESS_DIR)/dma-cpu/Vdma_cpu_tb: tests/dma_cpu_tb.sv ../rtl/x1_dma.sv ../rtl/cpu.v $(wildcard ../rtl/tv80/*.v)
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module dma_cpu_tb --Mdir $(HEADLESS_DIR)/dma-cpu \
		-j 2 tests/dma_cpu_tb.sv ../rtl/x1_dma.sv ../rtl/cpu.v \
		../rtl/tv80/tv80e.v ../rtl/tv80/tv80_core.v ../rtl/tv80/tv80_mcode.v \
		../rtl/tv80/tv80_alu.v ../rtl/tv80/tv80_reg.v -Wno-fatal

test-d88-metadata: $(HEADLESS_DIR)/d88-metadata/Vd88_metadata_tb
	./$(HEADLESS_DIR)/d88-metadata/Vd88_metadata_tb +divider=1
	./$(HEADLESS_DIR)/d88-metadata/Vd88_metadata_tb +divider=8

$(HEADLESS_DIR)/d88-metadata/Vd88_metadata_tb: tests/d88_metadata_tb.sv ../rtl/vendor/wd1793.sv ../rtl/vendor/x1_fdc_index_ram.v
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module d88_metadata_tb --Mdir $(HEADLESS_DIR)/d88-metadata \
		-j 2 tests/d88_metadata_tb.sv ../rtl/vendor/wd1793.sv ../rtl/vendor/x1_fdc_index_ram.v -Wno-fatal

.PHONY: test-dma-cpu test-d88-metadata

test-requalify-scheduling:
	python3 tests/test_requalify_scheduling.py
	python3 tests/test_native_continuation.py

.PHONY: test-requalify-scheduling

test-keyboard-receiver:
	python3 tests/test_keyboard_receiver.py

.PHONY: test-keyboard-receiver

$(HEADLESS_DIR)/disk/Vdisk_control_tb: tests/disk_control_tb.sv ../rtl/x1_disk_control.v
	$(V) --binary --timing --assert --top-module disk_control_tb --Mdir $(HEADLESS_DIR)/disk \
		-j 4 ../rtl/x1_disk_control.v tests/disk_control_tb.sv -Wno-fatal

$(HEADLESS_DIR)/index/Vfdc_index_tb: tests/fdc_index_tb.sv ../rtl/vendor/wd1793.sv ../rtl/vendor/x1_fdc_index_ram.v
	$(V) --binary --timing --assert --top-module fdc_index_tb --Mdir $(HEADLESS_DIR)/index \
		-j 4 ../rtl/vendor/wd1793.sv ../rtl/vendor/x1_fdc_index_ram.v tests/fdc_index_tb.sv -Wno-fatal

test-pcg-access: $(HEADLESS_DIR)/pcg/Vpcg_access_tb
	./$(HEADLESS_DIR)/pcg/Vpcg_access_tb
	./$(HEADLESS_DIR)/pcg/Vpcg_access_tb +VIDEO_HALF=3
	./$(HEADLESS_DIR)/pcg/Vpcg_access_tb +VIDEO_HALF=17

test-turbo-pcg-access: test-font16 test-pcg-access $(HEADLESS_DIR)/pcg-selector/Vpcg_selector_tb $(HEADLESS_DIR)/turbo-pcg/Vturbo_pcg_access_tb
	./$(HEADLESS_DIR)/pcg-selector/Vpcg_selector_tb
	@for half in 3 7 31; do for width in 1 3; do \
		./$(HEADLESS_DIR)/turbo-pcg/Vturbo_pcg_access_tb +VIDEO_HALF=$$half +WINDOW_WIDTH=$$width || exit 1; \
	done; done

$(HEADLESS_DIR)/pcg-selector/Vpcg_selector_tb: tests/pcg_selector_tb.sv ../rtl/x1_pcg_selector.sv
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module pcg_selector_tb --Mdir $(HEADLESS_DIR)/pcg-selector \
		-j 2 tests/pcg_selector_tb.sv ../rtl/x1_pcg_selector.sv -Wno-fatal

$(HEADLESS_DIR)/turbo-pcg/Vturbo_pcg_access_tb: tests/turbo_pcg_access_tb.sv ../rtl/x1_pcg_access.v ../rtl/x1_video_ram.v ../rtl/x1_font16.sv ../rtl/x1_reset_release.sv
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module turbo_pcg_access_tb --Mdir $(HEADLESS_DIR)/turbo-pcg \
		-j 2 tests/turbo_pcg_access_tb.sv ../rtl/x1_pcg_access.v ../rtl/x1_video_ram.v ../rtl/x1_font16.sv ../rtl/x1_reset_release.sv -Wno-fatal

test-turbo-pcg-cpu: turbo turbo-video
	python3 tests/test_turbo_pcg.py ./obj_dir_turbo/Vtop
	python3 tests/test_turbo_pcg.py ./obj_dir_turbo_video/Vtop

.PHONY: test-turbo-pcg-access test-turbo-pcg-cpu

$(HEADLESS_DIR)/pcg/Vpcg_access_tb: tests/pcg_access_tb.sv ../rtl/x1_pcg_access.v ../rtl/x1_video_ram.v
	$(V) --binary --timing --assert --top-module pcg_access_tb --Mdir $(HEADLESS_DIR)/pcg \
		-j 4 ../rtl/x1_pcg_access.v ../rtl/x1_video_ram.v tests/pcg_access_tb.sv -Wno-fatal

test-rgb12: $(HEADLESS_DIR)/rgb12/frame_rgb12_tb
	./$(HEADLESS_DIR)/rgb12/frame_rgb12_tb $(HEADLESS_DIR)/rgb12/all-colors.ppm

$(HEADLESS_DIR)/rgb12/frame_rgb12_tb: tests/frame_rgb12_tb.cpp frame_capture.h
	mkdir -p $(@D)
	$(CXX) -std=c++20 -Wall -Wextra -Werror tests/frame_rgb12_tb.cpp -o $@
.PHONY: test-rgb12

test-rgb12-wrapper: $(HEADLESS_DIR)/rgb12-wrapper/Vrgb12_wrapper_tb
	./$(HEADLESS_DIR)/rgb12-wrapper/Vrgb12_wrapper_tb

$(HEADLESS_DIR)/rgb12-wrapper/Vrgb12_wrapper_tb: tests/rgb12_wrapper_tb.sv ../sharpx1.sv ../sys/hps_io.sv tests/board_pll_lint.v ../rtl/x1_joystick_map.v $(MACHINE_SRC) Makefile
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module rgb12_wrapper_tb --Mdir $(HEADLESS_DIR)/rgb12-wrapper -j 4 -Itests \
		../sharpx1.sv ../sys/hps_io.sv tests/board_pll_lint.v ../rtl/x1_joystick_map.v \
		$(MACHINE_SRC) tests/rgb12_wrapper_tb.sv -Wno-fatal
.PHONY: test-rgb12-wrapper

test-joystick: $(HEADLESS_DIR)/joystick/Vjoystick_tb
	./$(HEADLESS_DIR)/joystick/Vjoystick_tb

$(HEADLESS_DIR)/joystick/Vjoystick_tb: tests/joystick_tb.sv ../rtl/x1_joystick_map.v
	$(V) --binary --timing --assert --top-module joystick_tb --Mdir $(HEADLESS_DIR)/joystick \
		-j 4 ../rtl/x1_joystick_map.v tests/joystick_tb.sv -Wno-fatal

test-sdl: obj_dir_fast/sdl_tb
	SDL_VIDEODRIVER=dummy ./obj_dir_fast/sdl_tb

obj_dir_fast/sdl_tb: tests/sdl_tb.cpp sdl_frontend.h
	mkdir -p obj_dir_fast
	$(CXX) -std=c++20 $(shell sdl2-config --cflags) tests/sdl_tb.cpp $(shell sdl2-config --libs) -o $@

test-loader: $(HEADLESS_DIR)/loader/Vloader_tb
	./$(HEADLESS_DIR)/loader/Vloader_tb

$(HEADLESS_DIR)/loader/Vloader_tb: tests/loader_tb.sv $(MACHINE_SRC) $(MACHINE_MANIFEST)
	$(V) --binary --timing --assert --top-module loader_tb --Mdir $(HEADLESS_DIR)/loader \
		-j 4 $(MACHINE_SRC) tests/loader_tb.sv -Wno-fatal

lint:
	$(V) --lint-only --timing --assert --top-module top $(V_SRC) -Wno-fatal

$(HEADLESS_DIR)/media/Vdisk_media_tb: ../rtl/x1_disk_media.sv tests/disk_media_tb.sv
	$(V) --binary --timing --assert --top-module disk_media_tb --Mdir $(HEADLESS_DIR)/media \
		-j 4 ../rtl/x1_disk_media.sv tests/disk_media_tb.sv -Wno-fatal

$(HEADLESS_DIR)/dual-fdc/Vdual_fdc_tb: ../rtl/x1_disk_media.sv ../rtl/vendor/wd1793.sv ../rtl/vendor/x1_fdc_index_ram.v tests/dual_fdc_tb.sv
	$(V) --binary --timing --assert --top-module dual_fdc_tb --Mdir $(HEADLESS_DIR)/dual-fdc \
		-j 4 ../rtl/x1_disk_media.sv ../rtl/vendor/wd1793.sv ../rtl/vendor/x1_fdc_index_ram.v tests/dual_fdc_tb.sv -Wno-fatal

test-write-eject: $(HEADLESS_DIR)/write-eject-before/Vdual_fdc_tb $(HEADLESS_DIR)/write-eject-during/Vdual_fdc_tb
	./$(HEADLESS_DIR)/write-eject-before/Vdual_fdc_tb
	./$(HEADLESS_DIR)/write-eject-during/Vdual_fdc_tb

$(HEADLESS_DIR)/write-eject-before/Vdual_fdc_tb: ../rtl/x1_disk_media.sv ../rtl/vendor/wd1793.sv ../rtl/vendor/x1_fdc_index_ram.v tests/dual_fdc_tb.sv
	$(V) --binary --timing --assert --top-module dual_fdc_tb -GEJECT_WRITE=1 --Mdir $(HEADLESS_DIR)/write-eject-before \
		-j 4 ../rtl/x1_disk_media.sv ../rtl/vendor/wd1793.sv ../rtl/vendor/x1_fdc_index_ram.v tests/dual_fdc_tb.sv -Wno-fatal

$(HEADLESS_DIR)/write-eject-during/Vdual_fdc_tb: ../rtl/x1_disk_media.sv ../rtl/vendor/wd1793.sv ../rtl/vendor/x1_fdc_index_ram.v tests/dual_fdc_tb.sv
	$(V) --binary --timing --assert --top-module dual_fdc_tb -GEJECT_WRITE=2 --Mdir $(HEADLESS_DIR)/write-eject-during \
		-j 4 ../rtl/x1_disk_media.sv ../rtl/vendor/wd1793.sv ../rtl/vendor/x1_fdc_index_ram.v tests/dual_fdc_tb.sv -Wno-fatal

.PHONY: test-write-eject

lint-wrapper:
	$(V) --lint-only --timing --top-module emu -Itests ../sharpx1.sv ../sys/hps_io.sv \
		tests/board_pll_lint.v ../rtl/x1_joystick_map.v $(MACHINE_SRC) -Wno-fatal

lint-wrapper-turbo-video:
	$(V) --lint-only --timing --top-module emu -DX1_TURBO_FOUNDATION -DX1_TURBO_VIDEO_MASTER -Itests \
		../sharpx1.sv ../sys/hps_io.sv tests/board_pll_lint.v ../rtl/x1_joystick_map.v \
		$(MACHINE_SRC) -Wno-fatal

.PHONY: lint-wrapper-turbo-video

lint-wrapper-turbo-dma:
	$(V) --lint-only --timing --top-module emu -DX1_TURBO_FOUNDATION -DX1_SINGLE_CLOCK -DX1_TURBO_DMA_RESTART -Itests \
		../sharpx1.sv ../sys/hps_io.sv tests/board_pll_lint.v ../rtl/x1_joystick_map.v \
		$(MACHINE_SRC) -Wno-fatal
.PHONY: lint-wrapper-turbo-dma

clean:
	# obj_dir is a tracked legacy GUI build artifact; preserve it.
	rm -rf obj_dir_headless

.PHONY: all headless interactive fast boot-game test-game play run test test-peripherals test-fast test-sdl test-loader test-joystick test-pcg-access test-disk-control lint lint-wrapper clean
.PHONY: single single-fast test-single test-clock-enables boot-game-single test-game-single
.PHONY: test-sub-timer
.PHONY: test-game-reset test-game-reset-single
