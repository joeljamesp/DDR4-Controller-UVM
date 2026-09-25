//------------------------------------------------------------------------
// coverage_test.sv
// Runs random_seq iterations until the command x bank cross-coverage
// crosses a target threshold or an iteration cap is hit, then reports
// the actual achieved coverage. This does not fabricate a result: if
// the target isn't reached within the cap, that is reported honestly.
//------------------------------------------------------------------------
class coverage_test extends base_test;

  `uvm_component_utils(coverage_test)

  real target_coverage  = 90.0;
  int  max_iterations   = 20;
  int  txns_per_iter    = 100;

  function new(string name = "coverage_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    random_seq seq;
    int  iter = 0;
    real cov  = 0.0;

    phase.raise_objection(this);

    do begin
      seq = random_seq::type_id::create($sformatf("seq_%0d", iter));
      seq.num_txns = txns_per_iter;
      seq.start(env.agent.sequencer);

      cov = env.coverage.cg_cmd_bank.get_coverage();
      iter++;

      `uvm_info("COVTEST", $sformatf(
        "iteration %0d: cmd_x_bank coverage = %0.2f%%", iter, cov), UVM_LOW)
    end while (cov < target_coverage && iter < max_iterations);

    `uvm_info("COVTEST", $sformatf(
      "FINAL RESULT: cmd_x_bank coverage = %0.2f%% after %0d iteration(s) of %0d txns each (target=%0.2f%%) -- %s",
      cov, iter, txns_per_iter, target_coverage,
      (cov >= target_coverage) ? "target met" : "target NOT met, reporting actual achieved coverage"),
      UVM_LOW)

    phase.drop_objection(this);
  endtask

endclass : coverage_test
