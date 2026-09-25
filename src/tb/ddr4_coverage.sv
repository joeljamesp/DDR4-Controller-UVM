//------------------------------------------------------------------------
// ddr4_coverage.sv
// Functional coverage: command-type x bank cross coverage, back-to-back
// same-bank vs. different-bank access pattern coverage, refresh
// interleave coverage (all sampled from the whitebox command bus via
// ddr4_cmd_item), and read/write-per-bank burst coverage (sampled from
// completed front-end transactions via ddr4_transaction).
//------------------------------------------------------------------------

`uvm_analysis_imp_decl(_cmd)
`uvm_analysis_imp_decl(_txn)

class ddr4_coverage extends uvm_component;

  `uvm_component_utils(ddr4_coverage)

  uvm_analysis_imp_cmd #(ddr4_cmd_item,    ddr4_coverage) cmd_export;
  uvm_analysis_imp_txn #(ddr4_transaction, ddr4_coverage) txn_export;

  ddr4_config cfg;

  ddr4_pkg::ddr4_cmd_e cur_cmd;
  ddr4_pkg::bank_t      cur_bank;
  bit                   is_refresh;

  // Back-to-back adjacency tracking (RD/WR commands only)
  bit                   have_prev_bank;
  ddr4_pkg::bank_t      prev_access_bank;
  bit                   adjacency_same_bank;

  ddr4_transaction cur_txn;

  covergroup cg_cmd_bank;
    option.per_instance = 1;
    cp_cmd : coverpoint cur_cmd {
      bins act = {ddr4_pkg::CMD_ACT};
      bins rd  = {ddr4_pkg::CMD_RD};
      bins wr  = {ddr4_pkg::CMD_WR};
      bins pre = {ddr4_pkg::CMD_PRE};
    }
    cp_bank : coverpoint cur_bank {
      bins bank[ddr4_pkg::NUM_BANKS] = {[0:ddr4_pkg::NUM_BANKS-1]};
    }
    cx_cmd_bank : cross cp_cmd, cp_bank;
  endgroup

  covergroup cg_refresh;
    option.per_instance = 1;
    cp_refresh : coverpoint is_refresh {
      bins refresh_issued = {1};
    }
  endgroup

  covergroup cg_adjacency;
    option.per_instance = 1;
    cp_adjacency : coverpoint adjacency_same_bank {
      bins same_bank = {1};
      bins diff_bank = {0};
    }
  endgroup

  covergroup cg_txn_burst;
    option.per_instance = 1;
    cp_rw : coverpoint cur_txn.rw {
      bins read  = {0};
      bins write = {1};
    }
    cp_bank : coverpoint cur_txn.bank {
      bins bank[ddr4_pkg::NUM_BANKS] = {[0:ddr4_pkg::NUM_BANKS-1]};
    }
    cx_rw_bank : cross cp_rw, cp_bank;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cmd_export = new("cmd_export", this);
    txn_export = new("txn_export", this);
    cg_cmd_bank = new();
    cg_refresh  = new();
    cg_adjacency = new();
    cg_txn_burst = new();
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(ddr4_config)::get(this, "", "cfg", cfg))
      `uvm_fatal("COV", "ddr4_config not found in uvm_config_db")
  endfunction

  // Whitebox command bus events
  function void write_cmd(ddr4_cmd_item item);
    if (!cfg.coverage_enable) return;

    if (item.is_refresh) begin
      is_refresh = 1'b1;
      cg_refresh.sample();
      return;
    end

    cur_cmd  = item.cmd_type;
    cur_bank = item.bank;
    cg_cmd_bank.sample();

    if (item.cmd_type == ddr4_pkg::CMD_RD || item.cmd_type == ddr4_pkg::CMD_WR) begin
      if (have_prev_bank) begin
        adjacency_same_bank = (item.bank == prev_access_bank);
        cg_adjacency.sample();
      end
      prev_access_bank = item.bank;
      have_prev_bank    = 1'b1;
    end
  endfunction

  // Completed front-end transactions
  function void write_txn(ddr4_transaction tr);
    if (!cfg.coverage_enable) return;
    cur_txn = tr;
    cg_txn_burst.sample();
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("COV", $sformatf(
      "COVERAGE SUMMARY: cmd_x_bank=%0.2f%% adjacency=%0.2f%% refresh=%0.2f%% txn_rw_x_bank=%0.2f%%",
      cg_cmd_bank.get_coverage(), cg_adjacency.get_coverage(),
      cg_refresh.get_coverage(), cg_txn_burst.get_coverage()), UVM_LOW)
  endfunction

endclass : ddr4_coverage
