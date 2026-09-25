//------------------------------------------------------------------------
// ddr4_driver.sv
// Drives ddr4_transaction items onto the front-end request/data-stream
// signals of ddr4_if. No clocking block is used (plain synchronous
// procedural drive) to keep the example approachable; a production
// environment would move this onto a clocking block for setup/hold
// safety on the target simulator.
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
    vif.req_valid   = 1'b0;
    vif.req_rw      = 1'b0;
    vif.req_addr    = '0;
    vif.wdata_valid = 1'b0;
    vif.wdata       = '0;
  endtask

  task drive_transaction(ddr4_transaction tr);
    // Issue the front-end request and wait for acceptance.
    vif.req_valid = 1'b1;
    vif.req_rw    = tr.rw;
    vif.req_addr  = tr.addr;
    do @(posedge vif.clk); while (!vif.req_ready);
    vif.req_valid = 1'b0;

    if (tr.rw) begin
      // Write burst: wait for the data path to open its write window,
      // then stream BURST_BEATS words.
      do @(posedge vif.clk); while (!vif.wdata_ready);
      for (int i = 0; i < ddr4_pkg::BURST_BEATS; i++) begin
        vif.wdata_valid = 1'b1;
        vif.wdata       = tr.wdata[i];
        @(posedge vif.clk);
      end
      vif.wdata_valid = 1'b0;
      vif.wdata       = '0;
    end else begin
      // Read burst: capture BURST_BEATS returned beats.
      for (int i = 0; i < ddr4_pkg::BURST_BEATS; i++) begin
        do @(posedge vif.clk); while (!vif.resp_valid);
        tr.rdata[i] = vif.resp_data;
      end
    end
  endtask

endclass : ddr4_driver
