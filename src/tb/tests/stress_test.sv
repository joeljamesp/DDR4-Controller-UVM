//------------------------------------------------------------------------
// stress_test.sv
// Back-to-back bursts plus same-bank row-conflict corner cases, run at
// higher transaction counts than traffic_test.
//------------------------------------------------------------------------
class stress_test extends base_test;

  `uvm_component_utils(stress_test)

  function new(string name = "stress_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    burst_seq        bseq = burst_seq::type_id::create("bseq");
    corner_case_seq  cseq = corner_case_seq::type_id::create("cseq");

    phase.raise_objection(this);

    bseq.num_txns = 64;
    bseq.start(env.agent.sequencer);

    cseq.num_pairs = 80;
    cseq.start(env.agent.sequencer);

    phase.drop_objection(this);
  endtask

endclass : stress_test
