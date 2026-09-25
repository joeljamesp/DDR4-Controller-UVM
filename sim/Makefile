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

.PHONY: all xsim questa vcs clean help

all: help

help:
	@echo "Targets: xsim | questa | vcs | clean   (TEST=traffic_test|stress_test|coverage_test)"

$(RESULTS):
	mkdir -p $(RESULTS)

# ------------------------------------------------------------------------
# Xilinx Vivado xsim (bundles UVM 1.2 since Vivado 2020.1)
# ------------------------------------------------------------------------
xsim: $(RESULTS)
	xvlog -sv $(INCDIRS) -f $(RTL_FLIST)
	xvlog -sv $(INCDIRS) -f $(TB_FLIST)
	xelab -debug typical tb_top -s ddr4_sim -L uvm
	cd $(RESULTS) && xsim ../ddr4_sim -runall -testplusarg "UVM_TESTNAME=$(TEST)" \
		-log ddr4_sim_$(TEST).log

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
