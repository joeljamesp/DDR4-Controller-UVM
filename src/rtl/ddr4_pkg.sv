//------------------------------------------------------------------------
// ddr4_pkg.sv
// Shared parameters, encodings and typedefs for the simplified DDR4
// memory controller RTL. Timing constants are illustrative simplified
// cycle counts, not JEDEC SPD values.
//------------------------------------------------------------------------
package ddr4_pkg;

  // ---------------------------------------------------------------
  // Geometry
  // ---------------------------------------------------------------
  parameter int NUM_BANKS   = 8;
  parameter int BANK_BITS   = $clog2(NUM_BANKS); // 3
  // NOTE: ROW_BITS/COL_BITS are deliberately much smaller than a real
  // DDR4 device (which would need a multi-GB behavioral memory array
  // to back every row). This keeps the backing store in data_path a
  // few hundred KB while still exercising the full ACT/RD/WR/PRE
  // command sequencing, row-hit/row-miss logic and bank arbitration.
  parameter int ROW_BITS    = 8;
  parameter int COL_BITS    = 4;   // 16 columns/row, burst of 8 fits twice
  parameter int ADDR_WIDTH  = BANK_BITS + ROW_BITS + COL_BITS; // 15
  parameter int DATA_WIDTH  = 64;
  parameter int BURST_LEN   = 8;                 // BL8
  parameter int BURST_BEATS = BURST_LEN / 2;     // DDR: 2 beats/clk -> 4 clks

  // ---------------------------------------------------------------
  // Simplified timing parameters (in controller clock cycles)
  // ---------------------------------------------------------------
  parameter int T_RCD  = 4;   // ACT -> RD/WR
  parameter int T_RAS  = 8;   // min row-active time before PRE allowed
  parameter int T_RP   = 3;   // PRE -> ACT (same bank)
  parameter int T_RFC  = 6;   // refresh recovery time
  parameter int T_REFI = 64;  // cycles between refresh requests

  // ---------------------------------------------------------------
  // Command encoding on the internal DDR4 command bus (exposed for
  // verification/coverage purposes as ddr_cmd_type on ddr4_if).
  // ---------------------------------------------------------------
  typedef enum logic [1:0] {
    CMD_ACT = 2'b00,
    CMD_RD  = 2'b01,
    CMD_WR  = 2'b10,
    CMD_PRE = 2'b11
  } ddr4_cmd_e;

  // Per-bank state machine (also exposed for whitebox coverage/debug)
  typedef enum logic [2:0] {
    BANK_IDLE,
    BANK_ACTIVATING,
    BANK_ACTIVE,
    BANK_ACCESSING,
    BANK_PRECHARGING
  } bank_state_e;

  typedef logic [BANK_BITS-1:0] bank_t;
  typedef logic [ROW_BITS-1:0]  row_t;
  typedef logic [COL_BITS-1:0]  col_t;
  typedef logic [ADDR_WIDTH-1:0] addr_t;

endpackage : ddr4_pkg
