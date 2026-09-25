//------------------------------------------------------------------------
// random_seq.sv
// Constrained-random read/write traffic spread across all banks.
//------------------------------------------------------------------------
class random_seq extends uvm_sequence #(ddr4_transaction);

  `uvm_object_utils(random_seq)

  rand int unsigned num_txns;
  constraint c_num_txns { num_txns inside {[20:200]}; }

  function new(string name = "random_seq");
    super.new(name);
    num_txns = 50;
  endfunction

  task body();
    ddr4_transaction tr;
    repeat (num_txns) begin
      tr = ddr4_transaction::type_id::create("tr");
      start_item(tr);
      if (!tr.randomize())
        `uvm_error("RANDOM_SEQ", "randomize() failed")
      finish_item(tr);
    end
  endtask

endclass : random_seq
