# Headless shared-machine simulation. Historical GUI artifacts remain untouched.
V ?= verilator
MACHINE_MANIFEST = ../rtl/machine.qip
MACHINE_SRC = $(addprefix ../,$(shell awk '/^set_global_assignment -name (SYSTEMVERILOG_FILE|VERILOG_FILE) / { print $$4 }' $(MACHINE_MANIFEST)))
V_SRC = sim.v $(MACHINE_SRC)
HEADLESS_DIR = obj_dir_headless
HEADLESS_EXE = $(HEADLESS_DIR)/Vtop
VIDEO_TEST_FLAGS ?=

all: headless
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
turbo-single: obj_dir_turbo_single/Vtop
turbo-fast: obj_dir_turbo_fast/Vtop
turbo-video: obj_dir_turbo_video/Vtop
turbo-video-fast: obj_dir_turbo_video_fast/Vtop
turbo-video-savable: obj_dir_turbo_video_savable/Vtop

# Fast X3 diagnostic continuations; not the delay-aware scheduling reference.
obj_dir_turbo_video_savable/Vtop: $(V_SRC) sim_headless.cpp frame_capture.h audio_capture.h d88_image.h Makefile $(MACHINE_MANIFEST)
	$(V) -cc --no-timing --savable --assert --trace-fst --exe --build -j 4 --Mdir obj_dir_turbo_video_savable --top-module top \
		-GTURBO=1 -GTURBO_VIDEO_MASTER=1 -CFLAGS "-std=c++20 -DX1_TURBO_FOUNDATION -DX1_TURBO_VIDEO_MASTER -DX1_SAVABLE" \
		-MAKEFLAGS "OPT_FAST=-O3" $(V_SRC) sim_headless.cpp -Wno-fatal -o Vtop

obj_dir_turbo_video/Vtop: $(V_SRC) sim_headless.cpp frame_capture.h audio_capture.h d88_image.h Makefile $(MACHINE_MANIFEST)
	$(V) -cc --timing --assert --trace-fst --exe --build -j 4 --Mdir obj_dir_turbo_video --top-module top \
		-GTURBO=1 -GTURBO_VIDEO_MASTER=1 -CFLAGS "-std=c++20 -DX1_TURBO_FOUNDATION -DX1_TURBO_VIDEO_MASTER" \
		-MAKEFLAGS "OPT_FAST=-O3" $(V_SRC) sim_headless.cpp -Wno-fatal -o Vtop

obj_dir_turbo_video_fast/Vtop: $(V_SRC) sim_headless.cpp frame_capture.h audio_capture.h d88_image.h Makefile $(MACHINE_MANIFEST)
	$(V) -cc --no-timing --assert --trace-fst --exe --build -j 4 --Mdir obj_dir_turbo_video_fast --top-module top \
		-GTURBO=1 -GTURBO_VIDEO_MASTER=1 -CFLAGS "-std=c++20 -DX1_TURBO_FOUNDATION -DX1_TURBO_VIDEO_MASTER" \
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
		-GTURBO=1 -CFLAGS "-std=c++20 -DX1_TURBO_FOUNDATION" -MAKEFLAGS "OPT_FAST=-O3" \
		$(V_SRC) sim_headless.cpp -Wno-fatal -o Vtop

obj_dir_turbo/Vtop: $(V_SRC) sim_headless.cpp frame_capture.h audio_capture.h d88_image.h Makefile $(MACHINE_MANIFEST)
	$(V) -cc --timing --assert --trace-fst --exe --build -j 4 --Mdir obj_dir_turbo --top-module top \
		-GTURBO=1 -CFLAGS "-std=c++20 -DX1_TURBO_FOUNDATION" -MAKEFLAGS "OPT_FAST=-O3" \
		$(V_SRC) sim_headless.cpp -Wno-fatal -o Vtop

obj_dir_turbo_single/Vtop: $(V_SRC) sim_headless.cpp frame_capture.h audio_capture.h d88_image.h Makefile $(MACHINE_MANIFEST)
	$(V) -cc --timing --assert --trace-fst --exe --build -j 4 --Mdir obj_dir_turbo_single --top-module top \
		-GTURBO=1 -GSINGLE_CLOCK=1 -GMASTER_HZ=28636364 -CFLAGS "-std=c++20 -DX1_SINGLE_CLOCK -DX1_TURBO_FOUNDATION" \
		-MAKEFLAGS "OPT_FAST=-O3" $(V_SRC) sim_headless.cpp -Wno-fatal -o Vtop

.PHONY: turbo turbo-single turbo-fast

test-turbo: turbo test-ctc test-gram-address test-video-timing test-turbo-pcg-access test-dma test-dma-cpu $(HEADLESS_DIR)/turbo-video/Vturbo_video_tb
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

$(HEADLESS_DIR)/turbo-video/Vturbo_video_tb: tests/turbo_video_tb.sv ../rtl/legacy/x1_vid.v ../rtl/legacy/crtc/crtc6845s.v ../rtl/x1_video_timing.sv
	$(V) --binary --timing --assert --top-module turbo_video_tb --Mdir $(HEADLESS_DIR)/turbo-video \
		-j 4 ../rtl/x1_video_timing.sv ../rtl/legacy/x1_vid.v ../rtl/legacy/crtc/crtc6845s.v tests/turbo_video_tb.sv -Wno-fatal

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
	$(V) --binary --timing --assert --top-module x1_ctc_tb --Mdir $(HEADLESS_DIR)/ctc \
		-j 4 ../rtl/x1_ctc.sv tests/x1_ctc_tb.sv -Wno-fatal

$(HEADLESS_DIR)/irq/Vx1_irq_bridge_tb: ../rtl/x1_irq_bridge.sv tests/x1_irq_bridge_tb.sv
	$(V) --binary --timing --assert --top-module x1_irq_bridge_tb --Mdir $(HEADLESS_DIR)/irq \
		-j 4 ../rtl/x1_irq_bridge.sv tests/x1_irq_bridge_tb.sv -Wno-fatal

$(HEADLESS_DIR)/ctcirq/Vx1_ctc_irq_tb: ../rtl/x1_ctc.sv ../rtl/x1_irq_bridge.sv tests/x1_ctc_irq_tb.sv
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

test: headless test-sub-timer test-fdc-abort test-fdc-sd-abort test-d88-scanner test-d88-crc test-d88-metadata test-cpu-busreq
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

$(HEADLESS_DIR)/dma/Vdma_tb: tests/dma_tb.sv ../rtl/x1_dma.sv
	$(V) --binary --timing --assert --top-module dma_tb --Mdir $(HEADLESS_DIR)/dma \
		-j 2 -CFLAGS -O1 tests/dma_tb.sv ../rtl/x1_dma.sv

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

$(HEADLESS_DIR)/turbo-pcg/Vturbo_pcg_access_tb: tests/turbo_pcg_access_tb.sv ../rtl/x1_pcg_access.v ../rtl/x1_video_ram.v ../rtl/x1_font16.sv
	mkdir -p $(@D)
	$(V) --binary --timing --assert --top-module turbo_pcg_access_tb --Mdir $(HEADLESS_DIR)/turbo-pcg \
		-j 2 tests/turbo_pcg_access_tb.sv ../rtl/x1_pcg_access.v ../rtl/x1_video_ram.v ../rtl/x1_font16.sv -Wno-fatal

test-turbo-pcg-cpu: turbo turbo-video
	python3 tests/test_turbo_pcg.py ./obj_dir_turbo/Vtop
	python3 tests/test_turbo_pcg.py ./obj_dir_turbo_video/Vtop

.PHONY: test-turbo-pcg-access test-turbo-pcg-cpu

$(HEADLESS_DIR)/pcg/Vpcg_access_tb: tests/pcg_access_tb.sv ../rtl/x1_pcg_access.v ../rtl/x1_video_ram.v
	$(V) --binary --timing --assert --top-module pcg_access_tb --Mdir $(HEADLESS_DIR)/pcg \
		-j 4 ../rtl/x1_pcg_access.v ../rtl/x1_video_ram.v tests/pcg_access_tb.sv -Wno-fatal

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
		tests/board_pll_lint.v ../rtl/x1_joystick_map.v ../rtl/x1_cdc_snapshot.sv $(MACHINE_SRC) -Wno-fatal

lint-wrapper-turbo-video:
	$(V) --lint-only --timing --top-module emu -DX1_TURBO_FOUNDATION -DX1_TURBO_VIDEO_MASTER -Itests \
		../sharpx1.sv ../sys/hps_io.sv tests/board_pll_lint.v ../rtl/x1_joystick_map.v \
		../rtl/x1_cdc_snapshot.sv $(MACHINE_SRC) -Wno-fatal

.PHONY: lint-wrapper-turbo-video

clean:
	# obj_dir is a tracked legacy GUI build artifact; preserve it.
	rm -rf obj_dir_headless

.PHONY: all headless interactive fast boot-game test-game play run test test-peripherals test-fast test-sdl test-loader test-joystick test-pcg-access test-disk-control lint lint-wrapper clean
.PHONY: single single-fast test-single test-clock-enables boot-game-single test-game-single
.PHONY: test-sub-timer
.PHONY: test-game-reset test-game-reset-single
