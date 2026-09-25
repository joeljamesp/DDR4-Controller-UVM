//------------------------------------------------------------------------
// burst_seq.sv
// Back-to-back burst transactions all targeting the same open bank/row,
// so every access after the first is a row hit (no ACT/PRE), stressing
// the pipelined read/write burst timing path.
//
// The target address is computed as a plain concrete value BEFORE
// calling tr.randomize(), rather than inline inside a `with` constraint
// (e.g. `addr == pack_addr(bank, row, tr.col)`). The latter asks the
// solver to evaluate a function call where one argument (tr.col) is
// still unresolved -- xsim's constraint solver can't handle that
// ("Invalid X/Z in a state expression value"), a real tool limitation
// hit during first-run testing, not a hypothetical. Computing the
// column ourselves and constraining against a fully concrete address
// sidesteps it entirely.
//------------------------------------------------------------------------
class burst_seq extends uvm_sequence #(ddr4_transaction);

  `uvm_object_utils(burst_seq)

  rand int unsigned    num_txns;
  rand ddr4_pkg::bank_t bank;
  rand ddr4_pkg::row_t  row;

  constraint c_num_txns { num_txns inside {[16:64]}; }

  function new(string name = "burst_seq");
    super.new(name);
    num_txns = 32;
  endfunction

  task body();
    ddr4_transaction tr;
    ddr4_pkg::col_t   rand_col;
    ddr4_pkg::addr_t  target_addr;

    if (!this.randomize())
      `uvm_error("BURST_SEQ", "sequence randomize() failed")

    repeat (num_txns) begin
      rand_col    = ddr4_pkg::col_t'($urandom_range((1 << ddr4_pkg::COL_BITS) - 1, 0));
      target_addr = ddr4_transaction::pack_addr(bank, row, rand_col);

      tr = ddr4_transaction::type_id::create("tr");
      start_item(tr);
      if (!tr.randomize() with { addr == target_addr; })
        `uvm_error("BURST_SEQ", "transaction randomize() failed")
      finish_item(tr);
    end
  endtask

endclass : burst_seq
