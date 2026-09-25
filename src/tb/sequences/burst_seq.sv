//------------------------------------------------------------------------
// burst_seq.sv
// Back-to-back burst transactions all targeting the same open bank/row,
// so every access after the first is a row hit (no ACT/PRE), stressing
// the pipelined read/write burst timing path.
//------------------------------------------------------------------------
class burst_seq extends uvm_sequence #(ddr4_transaction);

  `uvm_object_utils(burst_seq)

  rand int unsigned  num_txns;
  rand ddr4_pkg::bank_t bank;
  rand ddr4_pkg::row_t  row;

  constraint c_num_txns { num_txns inside {[16:64]}; }

  function new(string name = "burst_seq");
    super.new(name);
    num_txns = 32;
  endfunction

  task body();
    ddr4_transaction tr;
    if (!this.randomize())
      `uvm_error("BURST_SEQ", "sequence randomize() failed")

    repeat (num_txns) begin
      tr = ddr4_transaction::type_id::create("tr");
      start_item(tr);
      if (!tr.randomize() with {
            addr == ddr4_transaction::pack_addr(bank, row, tr.col);
          })
        `uvm_error("BURST_SEQ", "transaction randomize() failed")
      finish_item(tr);
    end
  endtask

endclass : burst_seq
