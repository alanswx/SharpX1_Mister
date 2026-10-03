VERILATOR ?= verilator
GHDL ?= ghdl

.PHONY: all lint lint-verilog lint-vhdl
all: lint
lint: lint-verilog lint-vhdl

# Candidate hierarchies are separate: some reuse names such as dpram.
# These checks establish syntax/dependency completeness, not X1 compatibility.
lint-verilog:
	$(VERILATOR) --lint-only -Wno-fatal --top-module jt49_bus jt49/hdl/*.v
	$(VERILATOR) --lint-only -Wno-fatal --top-module jt51 jt51/hdl/*.v
	$(VERILATOR) --lint-only -Wno-fatal --top-module i8255 amstrad/i8255.v
	$(VERILATOR) --lint-only -Wno-fatal --top-module UM6845R amstrad/UM6845R.v
	$(VERILATOR) --lint-only -Wno-fatal --top-module wd1793 fm7/wd1793.sv fm7/wd1793_dpram.v
	$(VERILATOR) --lint-only -Wno-fatal --top-module wd1793 -GRWMODE=1 fm7/wd1793.sv fm7/wd1793_dpram.v

T48_FILES = t48_pack-p.vhd t48_tb_pack-p.vhd alu_pack-p.vhd cond_branch_pack-p.vhd decoder_pack-p.vhd dmem_ctrl_pack-p.vhd pmem_ctrl_pack-p.vhd t48_comp_pack-p.vhd t48_core_comp_pack-p.vhd alu.vhd alu-c.vhd bus_mux.vhd bus_mux-c.vhd clock_ctrl.vhd clock_ctrl-c.vhd cond_branch.vhd cond_branch-c.vhd db_bus.vhd db_bus-c.vhd int.vhd int-c.vhd timer.vhd timer-c.vhd decoder.vhd decoder-c.vhd dmem_ctrl.vhd dmem_ctrl-c.vhd p1.vhd p1-c.vhd p2.vhd p2-c.vhd pmem_ctrl.vhd pmem_ctrl-c.vhd psw.vhd psw-c.vhd t48_core.vhd t48_core-c.vhd

lint-vhdl:
	mkdir -p build/zxnext build/sharpmz build/t48
	$(GHDL) -a --std=08 -fsynopsys --workdir=build/zxnext zxnext/ctc_chan.vhd zxnext/ctc.vhd zxnext/dma.vhd
	$(GHDL) -a --std=08 -fsynopsys --workdir=build/sharpmz sharpmz/i8255.vhd
	$(GHDL) -a --std=08 -fsynopsys --workdir=build/t48 $(addprefix t48/,$(T48_FILES))
