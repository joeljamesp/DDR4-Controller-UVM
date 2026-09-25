//------------------------------------------------------------------------
// ddr4_test_pkg.sv
// UVM package: pulls in every TB class in dependency order. Named
// ddr4_test_pkg (not ddr4_pkg) to avoid colliding with the RTL
// parameter/typedef package of the same shortened name.
//------------------------------------------------------------------------
`include "uvm_macros.svh"

package ddr4_test_pkg;

  import uvm_pkg::*;
  import ddr4_pkg::*;

  `include "ddr4_transaction.sv"
  `include "ddr4_config.sv"
  `include "ddr4_sequencer.sv"
  `include "ddr4_driver.sv"
  `include "ddr4_monitor.sv"
  `include "ddr4_scoreboard.sv"
  `include "ddr4_coverage.sv"
  `include "ddr4_agent.sv"
  `include "ddr4_env.sv"

  `include "sequences/random_seq.sv"
  `include "sequences/burst_seq.sv"
  `include "sequences/corner_case_seq.sv"

  `include "tests/base_test.sv"
  `include "tests/traffic_test.sv"
  `include "tests/stress_test.sv"
  `include "tests/coverage_test.sv"

endpackage : ddr4_test_pkg
