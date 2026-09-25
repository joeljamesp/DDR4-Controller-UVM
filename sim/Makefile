# ------------------------------------------------------------------------
# DDR4 Controller UVM Verification - simulator-agnostic Makefile
#
# Supported simulators (pick whichever is installed / licensed):
#   make xsim    TEST=traffic_test    (Xilinx Vivado xsim, UVM 1.2 bundled)
#   make questa  TEST=traffic_test    (Siemens Questa)
#   make vcs     TEST=traffic_test    (Synopsys VCS)
#   make clean
#
# TEST selects the UVM_TESTNAME: traffic_test | stress_test | coverage_test
# ------------------------------------------------------------------------

TEST       ?= traffic_test
RESULTS    := results
RTL_FLIST  := rtl_filelist.f
TB_FLIST   := tb_filelist.f
INCDIRS    := -i ../src/rtl -i ../src/tb

# Requires Vivado's settings64.(sh|bat) to have been sourced so
# XILINX_VIVADO points at the install (needed to locate the bundled
# uvm_macros.svh include directory below).
UVM_INC    := $(XILINX_VIVADO)/data/xsim/system_verilog/uvm_include

.PHONY: all xsim questa vcs clean help

all: help

help:
	@echo "Targets: xsim | questa | vcs | clean   (TEST=traffic_test|stress_test|coverage_test)"

$(RESULTS):
	mkdir -p $(RESULTS)

# ------------------------------------------------------------------------
# Xilinx Vivado xsim (bundles UVM 1.2 since Vivado 2020.1)
#
# NOTE: this xsim build's CLI parser (at least on Windows, v2026.1)
# rejects any --testplusarg value containing '=' (e.g. UVM_TESTNAME=foo),
# regardless of quoting/escaping -- a parser bug, not a usage error (we
# verified with `--testplusarg A=B` alone: it always fails the same way).
# TEST is therefore passed as a compile-time define instead; see the
# `ifdef UVM_TESTNAME_DEFAULT` fallback in tb_top.sv. A real +UVM_TESTNAME
# plusarg still takes priority when the target simulator's CLI can accept
# one (Questa/VCS below, or a non-Windows xsim without this bug).
# ------------------------------------------------------------------------
xsim: $(RESULTS)
	xvlog -sv $(INCDIRS) -f $(RTL_FLIST)
	xvlog -sv -L uvm $(INCDIRS) -i "$(UVM_INC)" -d 'UVM_TESTNAME_DEFAULT="$(TEST)"' -f $(TB_FLIST)
	xelab -debug typical tb_top -s ddr4_sim -L uvm
	cd $(RESULTS) && xsim ../ddr4_sim -runall -log ddr4_sim_$(TEST).log

# ------------------------------------------------------------------------
# Siemens Questa/ModelSim
# ------------------------------------------------------------------------
questa: $(RESULTS)
	vlib work
	vlog -sv +incdir+../src/rtl +incdir+../src/tb -f $(RTL_FLIST)
	vlog -sv +incdir+../src/rtl +incdir+../src/tb -f $(TB_FLIST)
	vsim -c tb_top +UVM_TESTNAME=$(TEST) -do "run -all; quit" \
		-l $(RESULTS)/ddr4_sim_$(TEST).log

# ------------------------------------------------------------------------
# Synopsys VCS
# ------------------------------------------------------------------------
vcs: $(RESULTS)
	vcs -full64 -sverilog -ntb_opts uvm-1.2 \
		+incdir+../src/rtl +incdir+../src/tb \
		-f $(RTL_FLIST) -f $(TB_FLIST) -o $(RESULTS)/simv
	cd $(RESULTS) && ./simv +UVM_TESTNAME=$(TEST) -l ddr4_sim_$(TEST).log

clean:
	rm -rf work xsim.dir *.jou *.log *.pb *.wdb ddr4_sim* $(RESULTS)/* \
		csrc simv* .vcs_lib_lock ucli.key transcript vsim.wlf
