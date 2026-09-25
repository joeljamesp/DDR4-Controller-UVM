//------------------------------------------------------------------------
// ddr4_env.sv
// Top-level verification environment: agent, scoreboard, coverage
// collector, wired together via the monitor's analysis ports.
//------------------------------------------------------------------------
class ddr4_env extends uvm_env;

  `uvm_component_utils(ddr4_env)

  ddr4_config     cfg;
  ddr4_agent      agent;
  ddr4_scoreboard scoreboard;
  ddr4_coverage   coverage;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(ddr4_config)::get(this, "", "cfg", cfg)) begin
      cfg = ddr4_config::type_id::create("cfg");
      `uvm_warning("ENV", "ddr4_config not found in uvm_config_db, creating default")
    end
    uvm_config_db#(ddr4_config)::set(this, "*", "cfg", cfg);

    agent = ddr4_agent::type_id::create("agent", this);

    if (cfg.scoreboard_enable)
      scoreboard = ddr4_scoreboard::type_id::create("scoreboard", this);

    if (cfg.coverage_enable)
      coverage = ddr4_coverage::type_id::create("coverage", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    if (cfg.scoreboard_enable)
      agent.monitor.txn_ap.connect(scoreboard.item_export);

    if (cfg.coverage_enable) begin
      agent.monitor.txn_ap.connect(coverage.txn_export);
      agent.monitor.cmd_ap.connect(coverage.cmd_export);
    end
  endfunction

endclass : ddr4_env
