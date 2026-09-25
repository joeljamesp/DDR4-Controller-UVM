//------------------------------------------------------------------------
// ddr4_monitor.sv
// Passively reconstructs completed front-end transactions (published to
// the scoreboard) and snoops the internal DDR4 command bus for every
// ACT/RD/WR/PRE/REFRESH pulse (published to the coverage collector).
//------------------------------------------------------------------------
class ddr4_monitor extends uvm_monitor;

  `uvm_component_utils(ddr4_monitor)

  virtual ddr4_if vif;
  ddr4_config     cfg;

  uvm_analysis_port #(ddr4_transaction) txn_ap;
  uvm_analysis_port #(ddr4_cmd_item)    cmd_ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    txn_ap = new("txn_ap", this);
    cmd_ap = new("cmd_ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(ddr4_config)::get(this, "", "cfg", cfg))
      `uvm_fatal("MON", "ddr4_config not found in uvm_config_db")
    vif = cfg.vif;
  endfunction

  task run_phase(uvm_phase phase);
    fork
      collect_txn();
      collect_cmd();
    join
  endtask

  task collect_txn();
    ddr4_transaction tr;
    forever begin
      @(posedge vif.clk);
      if (vif.rst_n && vif.req_valid && vif.req_ready) begin
        tr = ddr4_transaction::type_id::create("tr");
        tr.rw   = vif.req_rw;
        tr.addr = vif.req_addr;
        tr.decode_addr();

        if (tr.rw) begin
          for (int i = 0; i < ddr4_pkg::BURST_BEATS; i++) begin
            do @(posedge vif.clk); while (!vif.wdata_valid);
            tr.wdata[i] = vif.wdata;
          end
        end else begin
          for (int i = 0; i < ddr4_pkg::BURST_BEATS; i++) begin
            do @(posedge vif.clk); while (!vif.resp_valid);
            tr.rdata[i] = vif.resp_data;
          end
        end

        `uvm_info("MON", $sformatf("captured %s", tr.convert2string()), UVM_HIGH)
        txn_ap.write(tr);
      end
    end
  endtask

  task collect_cmd();
    ddr4_cmd_item ci;
    forever begin
      @(posedge vif.clk);
      if (!vif.rst_n) continue;

      if (vif.ddr_cmd_valid) begin
        ci            = ddr4_cmd_item::type_id::create("ci");
        ci.cmd_type   = vif.ddr_cmd_type;
        ci.bank       = vif.ddr_cmd_bank;
        ci.row        = vif.ddr_cmd_row;
        ci.col        = vif.ddr_cmd_col;
        ci.is_refresh = 1'b0;
        cmd_ap.write(ci);
      end

      if (vif.ddr_refresh_pulse) begin
        ci            = ddr4_cmd_item::type_id::create("ci_ref");
        ci.is_refresh = 1'b1;
        cmd_ap.write(ci);
      end
    end
  endtask

endclass : ddr4_monitor
