//------------------------------------------------------------------------
// corner_case_seq.sv
// Same-bank consecutive access to alternating rows, forcing a PRE+ACT
// row-conflict sequence on every pair of transactions. Run for enough
// transactions that the free-running refresh counter in
// ddr4_controller fires mid-stream, exercising refresh/access
// interleaving as a side effect of the traffic volume rather than an
// explicit hook (the DUT has no separate refresh command port).
//
// As in burst_seq, the target address is computed as a plain concrete
// value before tr.randomize() rather than via a function call inside
// the `with` constraint -- xsim's constraint solver can't evaluate a
// function call with a still-unresolved argument (tr.col) inside an
// active constraint (see burst_seq.sv for the full explanation; this
// was hit and fixed during first-run testing, not a hypothetical).
//------------------------------------------------------------------------
class corner_case_seq extends uvm_sequence #(ddr4_transaction);

  `uvm_object_utils(corner_case_seq)

  rand int unsigned    num_pairs;
  rand ddr4_pkg::bank_t bank;
  ddr4_pkg::row_t       row_a;
  ddr4_pkg::row_t       row_b;

  constraint c_num_pairs { num_pairs inside {[20:80]}; }

  function new(string name = "corner_case_seq");
    super.new(name);
    num_pairs = 40;
    row_a     = ddr4_pkg::row_t'(0);
    row_b     = ddr4_pkg::row_t'(1);
  endfunction

  task body();
    ddr4_transaction tr;
    ddr4_pkg::col_t  rand_col;
    ddr4_pkg::addr_t addr_a, addr_b;

    if (!this.randomize())
      `uvm_error("CORNER_SEQ", "sequence randomize() failed")

    repeat (num_pairs) begin
      rand_col = ddr4_pkg::col_t'($urandom_range((1 << ddr4_pkg::COL_BITS) - 1, 0));
      addr_a   = ddr4_transaction::pack_addr(bank, row_a, rand_col);
      addr_b   = ddr4_transaction::pack_addr(bank, row_b, rand_col);

      tr = ddr4_transaction::type_id::create("tr");
      start_item(tr);
      if (!tr.randomize() with { addr == addr_a; })
        `uvm_error("CORNER_SEQ", "transaction randomize() failed")
      finish_item(tr);

      tr = ddr4_transaction::type_id::create("tr");
      start_item(tr);
      if (!tr.randomize() with { addr == addr_b; })
        `uvm_error("CORNER_SEQ", "transaction randomize() failed")
      finish_item(tr);
    end
  endtask

endclass : corner_case_seq
