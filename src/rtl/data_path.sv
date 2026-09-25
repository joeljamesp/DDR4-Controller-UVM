//------------------------------------------------------------------------
// data_path.sv
// Write-data buffering and read-data return path with BL8 (burst
// length 8) support. Owns the behavioral backing memory, addressed as
// {bank, row, col}, with the column incrementing (wrapping within the
// row) for each of the burst's beats. Streams DATA_WIDTH-wide beats at
// two beats per controller clock, matching a DDR4 double-data-rate
// burst of 8 taking BURST_BEATS clocks.
//------------------------------------------------------------------------
import ddr4_pkg::*;

module data_path (
  input  logic clk,
  input  logic rst_n,

  // Burst control from command_generator
  input  logic   access_start,     // pulse: begin a new burst
  input  logic   access_is_write,
  input  bank_t  access_bank,
  input  row_t   access_row,
  input  col_t   access_col,
  output logic   burst_done,       // pulse: burst complete

  // Front-end write data stream (only consumed during a write burst)
  input  logic                    wdata_valid,
  input  logic [DATA_WIDTH-1:0]   wdata,
  output logic                    wdata_ready,

  // Front-end read data stream (produced during a read burst)
  output logic                    resp_valid,
  output logic [DATA_WIDTH-1:0]   resp_data,
  output logic                    resp_last
);

  localparam int BEAT_CNT_W = $clog2(BURST_BEATS + 1);

  // Behavioral backing store: one entry per {bank,row,col}.
  logic [DATA_WIDTH-1:0] mem [0:(1 << (BANK_BITS+ROW_BITS+COL_BITS))-1];

  typedef enum logic [1:0] {DP_IDLE, DP_WRITE, DP_READ} dp_state_e;
  dp_state_e dp_state, dp_state_n;

  logic [BEAT_CNT_W-1:0] beat_cnt;
  bank_t                 lat_bank;
  row_t                  lat_row;
  col_t                  lat_col;

  function automatic int unsigned flat_addr(bank_t b, row_t r, col_t c);
    return {b, r, c};
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) dp_state <= DP_IDLE;
    else        dp_state <= dp_state_n;
  end

  always_comb begin
    dp_state_n = dp_state;
    unique case (dp_state)
      DP_IDLE: if (access_start) dp_state_n = access_is_write ? DP_WRITE : DP_READ;
      DP_WRITE: if (beat_cnt == BEAT_CNT_W'(BURST_BEATS-1) && wdata_valid) dp_state_n = DP_IDLE;
      DP_READ:  if (beat_cnt == BEAT_CNT_W'(BURST_BEATS-1)) dp_state_n = DP_IDLE;
      default:  dp_state_n = DP_IDLE;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      beat_cnt <= '0;
      lat_bank <= '0;
      lat_row  <= '0;
      lat_col  <= '0;
    end else begin
      if (access_start) begin
        beat_cnt <= '0;
        lat_bank <= access_bank;
        lat_row  <= access_row;
        lat_col  <= access_col;
      end else if (dp_state == DP_WRITE && wdata_valid) begin
        beat_cnt <= beat_cnt + 1'b1;
      end else if (dp_state == DP_READ) begin
        beat_cnt <= beat_cnt + 1'b1;
      end
    end
  end

  // Write: consume one beat per cycle into mem[bank][row][col+beat]
  always_ff @(posedge clk) begin
    if (dp_state == DP_WRITE && wdata_valid) begin
      mem[flat_addr(lat_bank, lat_row, lat_col + col_t'(beat_cnt))] <= wdata;
    end
  end

  assign wdata_ready = (dp_state == DP_WRITE);
  assign burst_done  = (dp_state == DP_WRITE && wdata_valid && beat_cnt == BEAT_CNT_W'(BURST_BEATS-1)) ||
                        (dp_state == DP_READ  && beat_cnt == BEAT_CNT_W'(BURST_BEATS-1));

  assign resp_valid = (dp_state == DP_READ);
  assign resp_data  = mem[flat_addr(lat_bank, lat_row, lat_col + col_t'(beat_cnt))];
  assign resp_last  = (dp_state == DP_READ) && (beat_cnt == BEAT_CNT_W'(BURST_BEATS-1));

endmodule : data_path
