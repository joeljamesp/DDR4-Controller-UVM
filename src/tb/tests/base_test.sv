//------------------------------------------------------------------------
// base_test.sv
// Builds the environment from a virtual interface handed down through
// uvm_config_db by the top-level testbench module (tb_top.sv).
//------------------------------------------------------------------------
class base_test extends uvm_test;

  `uvm_component_utils(base_test)

  ddr4_env    env;
  ddr4_config cfg;

  function new(string name = "base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    cfg = ddr4_config::type_id::create("cfg");

    if (!uvm_config_db#(virtual ddr4_if)::get(this, "", "vif", cfg.vif))
      `uvm_fatal("TEST", "virtual ddr4_if not found in uvm_config_db (set by tb_top.sv)")

    uvm_config_db#(ddr4_config)::set(this, "*", "cfg", cfg);

    env = ddr4_env::type_id::create("env", this);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction

endclass : base_test
