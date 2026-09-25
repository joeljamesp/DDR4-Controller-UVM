//------------------------------------------------------------------------
// corner_case_seq.sv
// Same-bank consecutive access to alternating rows, forcing a PRE+ACT
// row-conflict sequence on every pair of transactions. Run for enough
// transactions that the free-running refresh counter in
// ddr4_controller fires mid-stream, exercising refresh/access
// interleaving as a side effect of the traffic volume rather than an
// explicit hook (the DUT has no separate refresh command port).
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
    if (!this.randomize())
      `uvm_error("CORNER_SEQ", "sequence randomize() failed")

    repeat (num_pairs) begin
      tr = ddr4_transaction::type_id::create("tr");
      start_item(tr);
      if (!tr.randomize() with {
            addr == ddr4_transaction::pack_addr(bank, row_a, tr.col);
          })
        `uvm_error("CORNER_SEQ", "transaction randomize() failed")
      finish_item(tr);

      tr = ddr4_transaction::type_id::create("tr");
      start_item(tr);
      if (!tr.randomize() with {
            addr == ddr4_transaction::pack_addr(bank, row_b, tr.col);
          })
        `uvm_error("CORNER_SEQ", "transaction randomize() failed")
      finish_item(tr);
    end
  endtask

endclass : corner_case_seq
