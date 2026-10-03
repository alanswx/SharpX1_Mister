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

play: fast
	./obj_dir_fast/Vtop --interactive --cycles $(PLAY_CYCLES) \
		--restore-state $(GAME_STATE) --disk $(GAME_DISK)

obj_dir_fast/Vtop: $(V_SRC) sim_headless.cpp frame_capture.h audio_capture.h sdl_frontend.h Makefile $(MACHINE_MANIFEST)
	$(V) -cc --no-timing --savable --assert --trace-fst --exe --build -j 4 --Mdir obj_dir_fast --top-module top \
		-CFLAGS "-std=c++20 -DX1_SDL -DX1_SAVABLE $(shell sdl2-config --cflags)" -MAKEFLAGS "OPT_FAST=-O3" \
		-LDFLAGS "$(shell sdl2-config --libs)" $(V_SRC) sim_headless.cpp -Wno-fatal -o Vtop

obj_dir_interactive/Vtop: $(V_SRC) sim_headless.cpp frame_capture.h audio_capture.h sdl_frontend.h Makefile $(MACHINE_MANIFEST)
	$(V) -cc --timing --assert --trace-fst --exe --build -j 4 --Mdir obj_dir_interactive --top-module top \
		-CFLAGS "-O2 -std=c++20 -DX1_SDL $(shell sdl2-config --cflags)" \
		-LDFLAGS "$(shell sdl2-config --libs)" $(V_SRC) sim_headless.cpp -Wno-fatal -o Vtop

$(HEADLESS_EXE): $(V_SRC) sim_headless.cpp frame_capture.h audio_capture.h Makefile $(MACHINE_MANIFEST)
	$(V) -cc --timing --assert --trace-fst --exe --build -j 4 --Mdir $(HEADLESS_DIR) --top-module top \
		-CFLAGS "-std=c++20" -MAKEFLAGS "OPT_FAST=-O3" $(V_SRC) sim_headless.cpp \
		-Wno-fatal -o Vtop

run: headless
	./$(HEADLESS_EXE) $(CYCLES)

test: headless
	python3 tests/test_timing.py ./$(HEADLESS_EXE)
	python3 tests/test_memory.py ./$(HEADLESS_EXE)
	python3 tests/test_subcpu.py ./$(HEADLESS_EXE)
	python3 tests/test_graphics_bus.py ./$(HEADLESS_EXE)
	python3 tests/test_keyboard_irq.py ./$(HEADLESS_EXE)
	python3 tests/test_audio.py ./$(HEADLESS_EXE)
	python3 tests/test_psg_modes.py ./$(HEADLESS_EXE)
	python3 tests/test_system_ports.py ./$(HEADLESS_EXE)
	python3 tests/test_pcg.py ./$(HEADLESS_EXE)
	$(MAKE) test-loader
	$(MAKE) test-joystick
	$(MAKE) test-pcg-access

test-fast: fast
	python3 tests/test_memory.py ./obj_dir_fast/Vtop
	python3 tests/test_subcpu.py ./obj_dir_fast/Vtop
	python3 tests/test_graphics_bus.py ./obj_dir_fast/Vtop
	python3 tests/test_keyboard_irq.py ./obj_dir_fast/Vtop
	python3 tests/test_audio.py ./obj_dir_fast/Vtop
	python3 tests/test_psg_modes.py ./obj_dir_fast/Vtop
	python3 tests/test_system_ports.py ./obj_dir_fast/Vtop
	python3 tests/test_pcg.py ./obj_dir_fast/Vtop
	python3 tests/test_snapshot.py ./obj_dir_fast/Vtop
	$(MAKE) test-sdl
	$(MAKE) test-joystick
	$(MAKE) test-pcg-access

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

.PHONY: all headless interactive fast boot-game test-game play run test test-fast test-sdl test-loader test-joystick test-pcg-access lint lint-wrapper clean
