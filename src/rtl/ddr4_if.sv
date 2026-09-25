//------------------------------------------------------------------------
// ddr4_if.sv
// Front-end request/response interface between the UVM testbench and
// the DDR4 controller, plus the internal DDR4 command bus exposed as
// whitebox signals for the monitor (bank/command coverage would be
// unobservable from the front-end request/response alone, since a
// single front-end transaction can fan out into PRE+ACT+RD/WR).
//------------------------------------------------------------------------
interface ddr4_if (input logic clk, input logic rst_n);
  import ddr4_pkg::*;

  // Front-end request
  logic                  req_valid;
  logic                  req_ready;
  logic                  req_rw;        // 0 = read, 1 = write
  addr_t                 req_addr;

  // Front-end write data stream
  logic                  wdata_valid;
  logic [DATA_WIDTH-1:0] wdata;
  logic                  wdata_ready;

  // Front-end read data stream
  logic                  resp_valid;
  logic [DATA_WIDTH-1:0] resp_data;
  logic                  resp_last;

  // Internal DDR4 command bus (whitebox, for monitor/coverage only)
  logic                  ddr_cmd_valid;
  ddr4_cmd_e             ddr_cmd_type;
  bank_t                 ddr_cmd_bank;
  row_t                  ddr_cmd_row;
  col_t                  ddr_cmd_col;
  logic                  ddr_refresh_pulse;

  modport dut (
    input  clk, rst_n,
    input  req_valid, req_rw, req_addr,
    output req_ready,
    input  wdata_valid, wdata,
    output wdata_ready,
    output resp_valid, resp_data, resp_last,
    output ddr_cmd_valid, ddr_cmd_type, ddr_cmd_bank, ddr_cmd_row, ddr_cmd_col,
    output ddr_refresh_pulse
  );

  modport driver (
    input  clk, rst_n,
    output req_valid, req_rw, req_addr,
    input  req_ready,
    output wdata_valid, wdata,
    input  wdata_ready,
    input  resp_valid, resp_data, resp_last
  );

  modport monitor (
    input clk, rst_n,
    input req_valid, req_ready, req_rw, req_addr,
    input wdata_valid, wdata, wdata_ready,
    input resp_valid, resp_data, resp_last,
    input ddr_cmd_valid, ddr_cmd_type, ddr_cmd_bank, ddr_cmd_row, ddr_cmd_col,
    input ddr_refresh_pulse
  );

endinterface : ddr4_if
