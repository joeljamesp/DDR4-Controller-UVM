//------------------------------------------------------------------------
// traffic_test.sv
// Baseline sanity test: constrained-random traffic across all banks.
//------------------------------------------------------------------------
class traffic_test extends base_test;

  `uvm_component_utils(traffic_test)

  function new(string name = "traffic_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    random_seq seq = random_seq::type_id::create("seq");

    phase.raise_objection(this);
    seq.num_txns = 100;
    seq.start(env.agent.sequencer);
    phase.drop_objection(this);
  endtask

endclass : traffic_test
