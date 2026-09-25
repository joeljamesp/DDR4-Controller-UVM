//------------------------------------------------------------------------
// command_generator.sv
// Translates a single front-end read/write request into the DDR4
// command sequence (ACT -> RD/WR -> PRE) required to service it,
// tracking per-bank open-row state (open-page policy) so that a
// request hitting an already-open row skips the ACT, and a request
// to a different row in an open bank issues PRE before ACT.
//
// Also arbitrates periodic refresh: when refresh_req is asserted, any
// open banks are precharged (JEDEC PREA-style, single precharge-all)
// before a REFRESH pulse is issued and tRFC is honored.
//
// Timing (tRCD/tRAS/tRP/tRFC) is enforced with simple cycle counters
// defined in ddr4_pkg -- simplified constants, not JEDEC SPD values.
//------------------------------------------------------------------------
import ddr4_pkg::*;

module command_generator (
  input  logic clk,
  input  logic rst_n,

  // Front-end request (one in flight at a time)
  input  logic   req_valid,
  output logic   req_ready,
  input  logic   req_rw,      // 0 = read, 1 = write
  input  bank_t  req_bank,
  input  row_t   req_row,
  input  col_t   req_col,

  // Refresh arbitration
  input  logic   refresh_req,
  output logic   refresh_ack,

  // Internal DDR4 command bus (exposed for monitoring/coverage)
  output logic       ddr_cmd_valid,
  output ddr4_cmd_e  ddr_cmd_type,
  output bank_t      ddr_cmd_bank,
  output row_t       ddr_cmd_row,
  output col_t       ddr_cmd_col,
  output logic       ddr_refresh_pulse,

  // Data path handshake
  output logic   access_start,     // pulse: RD/WR command issued this cycle
  output logic   access_is_write,
  output bank_t  access_bank,
  output row_t   access_row,
  output col_t   access_col,
  input  logic   burst_done,       // pulse from data_path: burst complete

  output logic   cmd_done,         // pulse: request's command sequence complete
  output logic   busy
);

  typedef enum logic [3:0] {
    S_IDLE,
    S_CHECK,
    S_PRECHARGE_ISSUE,
    S_PRECHARGE_WAIT,
    S_ACTIVATE_ISSUE,
    S_ACTIVATE_WAIT,
    S_ACCESS_ISSUE,
    S_ACCESS_WAIT,
    S_REF_PRECHARGE_ISSUE,
    S_REF_PRECHARGE_WAIT,
    S_REF_ISSUE,
    S_REF_WAIT
  } state_e;

  state_e state, state_n;

  // Per-bank open-page tracking
  logic [NUM_BANKS-1:0]        bank_open;
  row_t                        open_row [NUM_BANKS];
  logic [$clog2(T_RAS+2)-1:0]  active_timer [NUM_BANKS];

  // Latched request
  logic  lat_rw;
  bank_t lat_bank;
  row_t  lat_row;
  col_t  lat_col;

  logic [$clog2(T_RCD+1)-1:0] rcd_cnt;
  logic [$clog2(T_RP+1)-1:0]  rp_cnt;
  logic [$clog2(T_RFC+1)-1:0] rfc_cnt;

  wire row_hit  = bank_open[lat_bank] && (open_row[lat_bank] == lat_row);
  wire row_miss = bank_open[lat_bank] && (open_row[lat_bank] != lat_row);
  wire ras_met  = active_timer[lat_bank] >= T_RAS[$bits(active_timer[0])-1:0];
  wire any_open = |bank_open;

  assign busy      = (state != S_IDLE);
  assign req_ready = (state == S_IDLE) && !refresh_req;

  // ---------------------------------------------------------------
  // Background per-bank active timers (run regardless of FSM state)
  // ---------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      bank_open <= '0;
      for (int i = 0; i < NUM_BANKS; i++) begin
        open_row[i]     <= '0;
        active_timer[i] <= '0;
      end
    end else begin
      for (int i = 0; i < NUM_BANKS; i++) begin
        if (bank_open[i] && !(&active_timer[i]))
          active_timer[i] <= active_timer[i] + 1'b1;
      end

      // Precharge-all on refresh completion of the precharge phase
      if (state == S_REF_PRECHARGE_ISSUE && any_open) begin
        bank_open <= '0;
      end

      // Same-bank precharge (row conflict)
      if (state == S_PRECHARGE_ISSUE) begin
        bank_open[lat_bank] <= 1'b0;
      end

      // Activate opens the bank
      if (state == S_ACTIVATE_ISSUE) begin
        bank_open[lat_bank]    <= 1'b1;
        open_row[lat_bank]     <= lat_row;
        active_timer[lat_bank] <= '0;
      end
    end
  end

  // ---------------------------------------------------------------
  // Request latch
  // ---------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      lat_rw   <= 1'b0;
      lat_bank <= '0;
      lat_row  <= '0;
      lat_col  <= '0;
    end else if (state == S_IDLE && req_valid && req_ready) begin
      lat_rw   <= req_rw;
      lat_bank <= req_bank;
      lat_row  <= req_row;
      lat_col  <= req_col;
    end
  end

  // ---------------------------------------------------------------
  // Timing counters
  // ---------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rcd_cnt <= '0;
      rp_cnt  <= '0;
      rfc_cnt <= '0;
    end else begin
      rcd_cnt <= (state == S_ACTIVATE_ISSUE) ? '0 :
                 (state == S_ACTIVATE_WAIT)  ? rcd_cnt + 1'b1 : rcd_cnt;
      rp_cnt  <= (state == S_PRECHARGE_ISSUE || state == S_REF_PRECHARGE_ISSUE) ? '0 :
                 (state == S_PRECHARGE_WAIT  || state == S_REF_PRECHARGE_WAIT)  ? rp_cnt + 1'b1 : rp_cnt;
      rfc_cnt <= (state == S_REF_ISSUE) ? '0 :
                 (state == S_REF_WAIT)  ? rfc_cnt + 1'b1 : rfc_cnt;
    end
  end

  // ---------------------------------------------------------------
  // Main FSM
  // ---------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= S_IDLE;
    else        state <= state_n;
  end

  always_comb begin
    state_n = state;
    unique case (state)
      S_IDLE: begin
        if (refresh_req)
          state_n = S_REF_PRECHARGE_ISSUE;
        else if (req_valid)
          state_n = S_CHECK;
      end

      S_CHECK: begin
        if (row_hit)
          state_n = S_ACCESS_ISSUE;
        else if (row_miss)
          state_n = ras_met ? S_PRECHARGE_ISSUE : S_CHECK; // stall until tRAS met
        else
          state_n = S_ACTIVATE_ISSUE;
      end

      S_PRECHARGE_ISSUE: state_n = S_PRECHARGE_WAIT;
      S_PRECHARGE_WAIT:  state_n = (rp_cnt >= T_RP[$bits(rp_cnt)-1:0] - 1'b1) ? S_ACTIVATE_ISSUE : S_PRECHARGE_WAIT;

      S_ACTIVATE_ISSUE: state_n = S_ACTIVATE_WAIT;
      S_ACTIVATE_WAIT:  state_n = (rcd_cnt >= T_RCD[$bits(rcd_cnt)-1:0] - 1'b1) ? S_ACCESS_ISSUE : S_ACTIVATE_WAIT;

      S_ACCESS_ISSUE: state_n = S_ACCESS_WAIT;
      S_ACCESS_WAIT:  state_n = burst_done ? S_IDLE : S_ACCESS_WAIT;

      S_REF_PRECHARGE_ISSUE: state_n = any_open ? S_REF_PRECHARGE_WAIT : S_REF_ISSUE;
      S_REF_PRECHARGE_WAIT:  state_n = (rp_cnt >= T_RP[$bits(rp_cnt)-1:0] - 1'b1) ? S_REF_ISSUE : S_REF_PRECHARGE_WAIT;

      S_REF_ISSUE: state_n = S_REF_WAIT;
      S_REF_WAIT:  state_n = (rfc_cnt >= T_RFC[$bits(rfc_cnt)-1:0] - 1'b1) ? S_IDLE : S_REF_WAIT;

      default: state_n = S_IDLE;
    endcase
  end

  // ---------------------------------------------------------------
  // Output command bus (combinational, one-hot per issuing state)
  // ---------------------------------------------------------------
  always_comb begin
    ddr_cmd_valid     = 1'b0;
    ddr_cmd_type      = CMD_ACT;
    ddr_cmd_bank      = lat_bank;
    ddr_cmd_row       = lat_row;
    ddr_cmd_col       = lat_col;
    ddr_refresh_pulse = 1'b0;
    access_start      = 1'b0;
    access_is_write   = lat_rw;
    access_bank       = lat_bank;
    access_row        = lat_row;
    access_col        = lat_col;
    cmd_done          = 1'b0;
    refresh_ack       = 1'b0;

    case (state)
      S_PRECHARGE_ISSUE: begin
        ddr_cmd_valid = 1'b1;
        ddr_cmd_type  = CMD_PRE;
      end
      S_ACTIVATE_ISSUE: begin
        ddr_cmd_valid = 1'b1;
        ddr_cmd_type  = CMD_ACT;
      end
      S_ACCESS_ISSUE: begin
        ddr_cmd_valid   = 1'b1;
        ddr_cmd_type    = lat_rw ? CMD_WR : CMD_RD;
        access_start    = 1'b1;
      end
      S_ACCESS_WAIT: begin
        if (burst_done) cmd_done = 1'b1;
      end
      S_REF_PRECHARGE_ISSUE: begin
        if (any_open) begin
          ddr_cmd_valid = 1'b1;
          ddr_cmd_type  = CMD_PRE;
        end
      end
      S_REF_ISSUE: begin
        ddr_refresh_pulse = 1'b1;
      end
      S_REF_WAIT: begin
        if (state_n == S_IDLE) refresh_ack = 1'b1;
      end
      default: ;
    endcase
  end

endmodule : command_generator
