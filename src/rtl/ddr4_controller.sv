//------------------------------------------------------------------------
// ddr4_controller.sv
// Top-level simplified DDR4 memory controller: address translation,
// command decode / bank state machine (via command_generator), data
// path (via data_path), and a free-running refresh counter.
//------------------------------------------------------------------------
import ddr4_pkg::*;

module ddr4_controller (
  ddr4_if.dut bus
);

  wire clk   = bus.clk;
  wire rst_n = bus.rst_n;

  // ---------------------------------------------------------------
  // Address translation
  // ---------------------------------------------------------------
  bank_t req_bank;
  row_t  req_row;
  col_t  req_col;

  address_translator u_addr_xlate (
    .addr (bus.req_addr),
    .bank (req_bank),
    .row  (req_row),
    .col  (req_col)
  );

  // ---------------------------------------------------------------
  // Refresh counter (simple free-running interval counter)
  // ---------------------------------------------------------------
  localparam int REFI_W = $clog2(T_REFI + 1);
  logic [REFI_W-1:0] refi_cnt;
  logic              refresh_req, refresh_ack;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      refi_cnt    <= '0;
      refresh_req <= 1'b0;
    end else if (refresh_ack) begin
      refi_cnt    <= '0;
      refresh_req <= 1'b0;
    end else if (!refresh_req && (refi_cnt >= REFI_W'(T_REFI - 1))) begin
      refresh_req <= 1'b1;
    end else if (!refresh_req) begin
      refi_cnt <= refi_cnt + 1'b1;
    end
  end

  // ---------------------------------------------------------------
  // Command generation / bank state machine
  // ---------------------------------------------------------------
  logic  access_start, access_is_write;
  bank_t access_bank;
  row_t  access_row;
  col_t  access_col;
  logic  burst_done, cmd_done, busy;

  command_generator u_cmd_gen (
    .clk               (clk),
    .rst_n             (rst_n),

    .req_valid         (bus.req_valid),
    .req_ready         (bus.req_ready),
    .req_rw            (bus.req_rw),
    .req_bank          (req_bank),
    .req_row           (req_row),
    .req_col           (req_col),

    .refresh_req       (refresh_req),
    .refresh_ack       (refresh_ack),

    .ddr_cmd_valid     (bus.ddr_cmd_valid),
    .ddr_cmd_type      (bus.ddr_cmd_type),
    .ddr_cmd_bank      (bus.ddr_cmd_bank),
    .ddr_cmd_row       (bus.ddr_cmd_row),
    .ddr_cmd_col       (bus.ddr_cmd_col),
    .ddr_refresh_pulse (bus.ddr_refresh_pulse),

    .access_start      (access_start),
    .access_is_write   (access_is_write),
    .access_bank       (access_bank),
    .access_row        (access_row),
    .access_col        (access_col),
    .burst_done        (burst_done),

    .cmd_done          (cmd_done),
    .busy              (busy)
  );

  // ---------------------------------------------------------------
  // Data path
  // ---------------------------------------------------------------
  data_path u_data_path (
    .clk             (clk),
    .rst_n           (rst_n),

    .access_start    (access_start),
    .access_is_write (access_is_write),
    .access_bank     (access_bank),
    .access_row      (access_row),
    .access_col      (access_col),
    .burst_done      (burst_done),

    .wdata_valid     (bus.wdata_valid),
    .wdata           (bus.wdata),
    .wdata_ready     (bus.wdata_ready),

    .resp_valid      (bus.resp_valid),
    .resp_data       (bus.resp_data),
    .resp_last       (bus.resp_last)
  );

endmodule : ddr4_controller
