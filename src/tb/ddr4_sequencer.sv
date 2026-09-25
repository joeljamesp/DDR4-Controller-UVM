//------------------------------------------------------------------------
// ddr4_sequencer.sv
//------------------------------------------------------------------------
class ddr4_sequencer extends uvm_sequencer #(ddr4_transaction);

  `uvm_component_utils(ddr4_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

endclass : ddr4_sequencer
