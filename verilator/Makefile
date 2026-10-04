# Headless shared-machine simulation. Historical GUI artifacts remain untouched.
V ?= verilator
MACHINE_MANIFEST = ../rtl/machine.qip
MACHINE_SRC = $(addprefix ../,$(shell awk '/^set_global_assignment -name (SYSTEMVERILOG_FILE|VERILOG_FILE) / { print $$4 }' $(MACHINE_MANIFEST)))
V_SRC = sim.v $(MACHINE_SRC)
HEADLESS_DIR = obj_dir_headless
HEADLESS_EXE = $(HEADLESS_DIR)/Vtop

all: headless
headless: $(HEADLESS_EXE)

interactive: obj_dir_interactive/Vtop

# Clocked, synthesis-style execution: inherited intra-assignment delays are
# ignored. Keep the headless --timing build as the scheduling reference.
fast: obj_dir_fast/Vtop

# Experimental shared-clock model; baseline builds and board default stay intact.
single: obj_dir_single/Vtop
single-fast: obj_dir_single_fast/Vtop

test-single: single test-clock-enables test-sub-timer test-fdc-abort test-fdc-sd-abort
	python3 tests/test_warm_reset.py ./obj_dir_single/Vtop
	python3 tests/test_d88_bounds.py ./obj_dir_single/Vtop
	python3 tests/test_single_clock.py ./obj_dir_single/Vtop
	python3 tests/test_memory.py ./obj_dir_single/Vtop
	python3 tests/test_subcpu.py ./obj_dir_single/Vtop
	python3 tests/test_graphics_bus.py ./obj_dir_single/Vtop
	python3 tests/test_keyboard_irq.py ./obj_dir_single/Vtop
	python3 tests/test_audio.py ./obj_dir_single/Vtop
	python3 tests/test_psg_modes.py ./obj_dir_single/Vtop
	python3 tests/test_system_ports.py ./obj_dir_single/Vtop
	python3 tests/test_pcg.py ./obj_dir_single/Vtop 28636364
	python3 tests/test_disk.py ./obj_dir_single/Vtop

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

test: headless test-sub-timer test-fdc-abort test-fdc-sd-abort
	python3 tests/test_warm_reset.py ./$(HEADLESS_EXE)
	python3 tests/test_d88_bounds.py ./$(HEADLESS_EXE)
	python3 tests/test_timing.py ./$(HEADLESS_EXE)
	python3 tests/test_memory.py ./$(HEADLESS_EXE)
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

test-fast: fast test-sub-timer test-fdc-abort test-fdc-sd-abort
	python3 tests/test_warm_reset.py ./obj_dir_fast/Vtop
	python3 tests/test_d88_bounds.py ./obj_dir_fast/Vtop
	python3 tests/test_memory.py ./obj_dir_fast/Vtop
	python3 tests/test_subcpu.py ./obj_dir_fast/Vtop
	python3 tests/test_graphics_bus.py ./obj_dir_fast/Vtop
	python3 tests/test_keyboard_irq.py ./obj_dir_fast/Vtop
	python3 tests/test_audio.py ./obj_dir_fast/Vtop
	python3 tests/test_psg_modes.py ./obj_dir_fast/Vtop
	python3 tests/test_system_ports.py ./obj_dir_fast/Vtop
	python3 tests/test_pcg.py ./obj_dir_fast/Vtop
	python3 tests/test_disk.py ./obj_dir_fast/Vtop
	python3 tests/test_snapshot.py ./obj_dir_fast/Vtop
	$(MAKE) test-sdl
	$(MAKE) test-joystick
	$(MAKE) test-pcg-access
	$(MAKE) test-disk-control

test-disk-control: $(HEADLESS_DIR)/disk/Vdisk_control_tb $(HEADLESS_DIR)/index/Vfdc_index_tb
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

lint-wrapper:
	$(V) --lint-only --timing --top-module emu -Itests ../sharpx1.sv ../sys/hps_io.sv \
		tests/board_pll_lint.v ../rtl/x1_joystick_map.v $(MACHINE_SRC) -Wno-fatal

clean:
	# obj_dir is a tracked legacy GUI build artifact; preserve it.
	rm -rf obj_dir_headless

.PHONY: all headless interactive fast boot-game test-game play run test test-fast test-sdl test-loader test-joystick test-pcg-access test-disk-control lint lint-wrapper clean
.PHONY: single single-fast test-single test-clock-enables boot-game-single test-game-single
.PHONY: test-sub-timer
.PHONY: test-game-reset test-game-reset-single
