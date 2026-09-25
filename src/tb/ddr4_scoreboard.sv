//------------------------------------------------------------------------
// ddr4_scoreboard.sv
// Reference-model check: maintains a shadow memory keyed the same way
// data_path addresses its backing store ({bank,row,col+beat}) and
// verifies every read burst returns exactly what was last written to
// each of those locations. Locations that were never written are
// reported but not scored as mismatches (their content is whatever the
// DUT's memory array happened to reset/elaborate to).
//------------------------------------------------------------------------
class ddr4_scoreboard extends uvm_component;

  `uvm_component_utils(ddr4_scoreboard)

  uvm_analysis_imp #(ddr4_transaction, ddr4_scoreboard) item_export;

  ddr4_config cfg;

  bit [ddr4_pkg::DATA_WIDTH-1:0] shadow_mem [int unsigned];
  bit                            shadow_valid [int unsigned];

  int unsigned num_writes;
  int unsigned num_reads;
  int unsigned num_compares;
  int unsigned num_mismatches;
  int unsigned num_unwritten_reads;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    item_export = new("item_export", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(ddr4_config)::get(this, "", "cfg", cfg))
      `uvm_fatal("SCB", "ddr4_config not found in uvm_config_db")
  endfunction

  function int unsigned flat_key(ddr4_pkg::bank_t b, ddr4_pkg::row_t r, ddr4_pkg::col_t c);
    return {b, r, c};
  endfunction

  function void write(ddr4_transaction tr);
    if (!cfg.scoreboard_enable) return;

    if (tr.rw) begin
      num_writes++;
      for (int i = 0; i < ddr4_pkg::BURST_BEATS; i++) begin
        ddr4_pkg::col_t beat_col = tr.col + ddr4_pkg::col_t'(i);
        int unsigned key = flat_key(tr.bank, tr.row, beat_col);
        shadow_mem[key]   = tr.wdata[i];
        shadow_valid[key] = 1'b1;
      end
    end else begin
      num_reads++;
      for (int i = 0; i < ddr4_pkg::BURST_BEATS; i++) begin
        ddr4_pkg::col_t beat_col = tr.col + ddr4_pkg::col_t'(i);
        int unsigned key = flat_key(tr.bank, tr.row, beat_col);

        if (!shadow_valid.exists(key) || !shadow_valid[key]) begin
          num_unwritten_reads++;
          `uvm_info("SCB", $sformatf(
            "read of never-written location bank=%0d row=%0d col=%0d beat=%0d (data=0x%0h) - not scored",
            tr.bank, tr.row, beat_col, i, tr.rdata[i]), UVM_HIGH)
          continue;
        end

        num_compares++;
        if (tr.rdata[i] !== shadow_mem[key]) begin
          num_mismatches++;
          `uvm_error("SCB", $sformatf(
            "DATA MISMATCH bank=%0d row=%0d col=%0d beat=%0d: expected=0x%0h actual=0x%0h",
            tr.bank, tr.row, beat_col, i, shadow_mem[key], tr.rdata[i]))
        end
      end
    end
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SCB", $sformatf(
      "SCOREBOARD SUMMARY: writes=%0d reads=%0d compares=%0d mismatches=%0d unwritten_reads=%0d",
      num_writes, num_reads, num_compares, num_mismatches, num_unwritten_reads), UVM_LOW)
  endfunction

endclass : ddr4_scoreboard
