//------------------------------------------------------------------------
// ddr4_agent.sv
// Standard UVM agent: sequencer + driver built only when active,
// monitor always built.
//------------------------------------------------------------------------
class ddr4_agent extends uvm_agent;

  `uvm_component_utils(ddr4_agent)

  ddr4_config    cfg;
  ddr4_sequencer sequencer;
  ddr4_driver    driver;
  ddr4_monitor   monitor;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(ddr4_config)::get(this, "", "cfg", cfg))
      `uvm_fatal("AGT", "ddr4_config not found in uvm_config_db")

    is_active = cfg.is_active;

    monitor = ddr4_monitor::type_id::create("monitor", this);

    if (is_active == UVM_ACTIVE) begin
      sequencer = ddr4_sequencer::type_id::create("sequencer", this);
      driver    = ddr4_driver::type_id::create("driver", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (is_active == UVM_ACTIVE)
      driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction

endclass : ddr4_agent
