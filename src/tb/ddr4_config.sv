//------------------------------------------------------------------------
// ddr4_config.sv
// Environment configuration object: agent activity, coverage/scoreboard
// enables, and the virtual interface handle placed here by the top-level
// test/env and fetched by every TB component via uvm_config_db.
//------------------------------------------------------------------------
class ddr4_config extends uvm_object;

  `uvm_object_utils(ddr4_config)

  uvm_active_passive_enum is_active     = UVM_ACTIVE;
  bit                     coverage_enable   = 1;
  bit                     scoreboard_enable = 1;

  virtual ddr4_if vif;

  function new(string name = "ddr4_config");
    super.new(name);
  endfunction

endclass : ddr4_config
