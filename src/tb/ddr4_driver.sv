//------------------------------------------------------------------------
// ddr4_driver.sv
// Drives ddr4_transaction items onto the front-end request/data-stream
// signals of ddr4_if. No clocking block is used, but every signal change
// is made with a NONBLOCKING assignment synchronized to a specific
// posedge -- required here, not optional: the monitor and this driver
// both react to the same @(posedge vif.clk) event, and a blocking
// assignment to req_valid raced against the monitor's same-edge read of
// it (order between two processes triggered by the same event is
// simulator-defined). Nonblocking assignment defers the update to the
// NBA region, so every Active-region read at that edge -- the monitor's
// check, and the DUT's own request-latch logic -- deterministically
// sees the value as driven for that cycle, per IEEE 1800 scheduling
// semantics. (First-run testing surfaced this as a real bug: on the
// simulator used, the monitor consistently lost the race and reported
// zero transactions; see VERIFICATION_PLAN.md.)
//------------------------------------------------------------------------
class ddr4_driver extends uvm_driver #(ddr4_transaction);

  `uvm_component_utils(ddr4_driver)

  virtual ddr4_if vif;
  ddr4_config     cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(ddr4_config)::get(this, "", "cfg", cfg))
      `uvm_fatal("DRV", "ddr4_config not found in uvm_config_db")
    vif = cfg.vif;
  endfunction

  task run_phase(uvm_phase phase);
    reset_signals();
    wait (vif.rst_n === 1'b1);

    forever begin
      seq_item_port.get_next_item(req);
      drive_transaction(req);
      seq_item_port.item_done();
    end
  endtask

  task reset_signals();
    vif.req_valid   <= 1'b0;
    vif.req_rw      <= 1'b0;
    vif.req_addr    <= '0;
    vif.wdata_valid <= 1'b0;
    vif.wdata       <= '0;
  endtask

  task drive_transaction(ddr4_transaction tr);
    // Issue the front-end request, synchronized to this edge.
    @(posedge vif.clk);
    vif.req_valid <= 1'b1;
    vif.req_rw    <= tr.rw;
    vif.req_addr  <= tr.addr;

    // Hold req_valid asserted (it keeps its NBA-driven value across
    // cycles until reassigned) until the DUT samples it with req_ready
    // high on some subsequent edge.
    @(posedge vif.clk);
    while (!vif.req_ready) @(posedge vif.clk);
    vif.req_valid <= 1'b0;

    if (tr.rw) begin
      // Write burst: wait for the data path to open its write window,
      // then stream BURST_BEATS words, one per edge.
      while (!vif.wdata_ready) @(posedge vif.clk);
      for (int i = 0; i < ddr4_pkg::BURST_BEATS; i++) begin
        vif.wdata_valid <= 1'b1;
        vif.wdata       <= tr.wdata[i];
        @(posedge vif.clk);
      end
      vif.wdata_valid <= 1'b0;
      vif.wdata       <= '0;
    end else begin
      // Read burst: capture BURST_BEATS returned beats.
      for (int i = 0; i < ddr4_pkg::BURST_BEATS; i++) begin
        while (!vif.resp_valid) @(posedge vif.clk);
        tr.rdata[i] = vif.resp_data;
        @(posedge vif.clk);
      end
    end
  endtask

endclass : ddr4_driver
