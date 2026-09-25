//------------------------------------------------------------------------
// tb_top.sv
// Testbench top: clock/reset generation, DUT + interface instantiation,
// virtual interface hand-off into uvm_config_db, and run_test().
//------------------------------------------------------------------------
`include "uvm_macros.svh"

module tb_top;

  import uvm_pkg::*;
  import ddr4_test_pkg::*;

  logic clk;
  logic rst_n;

  initial clk = 1'b0;
  always #5 clk = ~clk; // 100 MHz controller clock

  initial begin
    rst_n = 1'b0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
  end

  ddr4_if bus (.clk(clk), .rst_n(rst_n));

  ddr4_controller dut (.bus(bus));

  initial begin
    uvm_config_db#(virtual ddr4_if)::set(null, "*", "vif", bus);
    // A +UVM_TESTNAME plusarg (standard on Questa/VCS/most xsim builds)
    // always takes priority over this default; UVM_TESTNAME_DEFAULT is a
    // compile-time fallback for simulator CLIs where passing a plusarg
    // containing '=' is broken (see sim/Makefile xsim target).
`ifdef UVM_TESTNAME_DEFAULT
    run_test(`UVM_TESTNAME_DEFAULT);
`else
    run_test();
`endif
  end

  // Waveform dump (only meaningful under a simulator that actually runs)
  initial begin
    $dumpfile("results/ddr4_tb.vcd");
    $dumpvars(0, tb_top);
  end

endmodule : tb_top
