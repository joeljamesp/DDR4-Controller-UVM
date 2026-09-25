//------------------------------------------------------------------------
// ddr4_transaction.sv
// Front-end read/write transaction driven onto ddr4_if by ddr4_driver
// and reconstructed by ddr4_monitor. wdata/rdata are sized to
// BURST_BEATS (controller-clock beats), not BURST_LEN (DDR UI beats) --
// each 64-bit controller-clock word carries two DDR4 UI beats, matching
// data_path's per-cycle burst transfer.
//------------------------------------------------------------------------
class ddr4_transaction extends uvm_sequence_item;

  rand bit                                    rw;   // 0 = read, 1 = write
  rand ddr4_pkg::addr_t                       addr;
  rand bit [ddr4_pkg::DATA_WIDTH-1:0]         wdata [ddr4_pkg::BURST_BEATS];
  bit      [ddr4_pkg::DATA_WIDTH-1:0]         rdata [ddr4_pkg::BURST_BEATS];

  // Decoded address fields, filled in post_randomize / by the monitor.
  ddr4_pkg::bank_t bank;
  ddr4_pkg::row_t  row;
  ddr4_pkg::col_t  col;

  `uvm_object_utils_begin(ddr4_transaction)
    `uvm_field_int(rw,   UVM_ALL_ON)
    `uvm_field_int(addr, UVM_ALL_ON)
    `uvm_field_sarray_int(wdata, UVM_ALL_ON)
    `uvm_field_sarray_int(rdata, UVM_ALL_ON)
    `uvm_field_int(bank, UVM_ALL_ON | UVM_NOCOMPARE)
    `uvm_field_int(row,  UVM_ALL_ON | UVM_NOCOMPARE)
    `uvm_field_int(col,  UVM_ALL_ON | UVM_NOCOMPARE)
  `uvm_object_utils_end

  function new(string name = "ddr4_transaction");
    super.new(name);
  endfunction

  function void post_randomize();
    decode_addr();
  endfunction

  function void decode_addr();
    col  = addr[0                                       +: ddr4_pkg::COL_BITS];
    bank = addr[ddr4_pkg::COL_BITS                       +: ddr4_pkg::BANK_BITS];
    row  = addr[ddr4_pkg::COL_BITS + ddr4_pkg::BANK_BITS +: ddr4_pkg::ROW_BITS];
  endfunction

  // Packs {bank,row,col} back into a flat address using the same field
  // layout as address_translator, so directed sequences can target a
  // specific bank/row without depending on random constraints.
  static function ddr4_pkg::addr_t pack_addr(ddr4_pkg::bank_t b, ddr4_pkg::row_t r, ddr4_pkg::col_t c);
    return {r, b, c};
  endfunction

  function string convert2string();
    return $sformatf("%s addr=0x%0h (bank=%0d row=%0d col=%0d)",
                      rw ? "WR" : "RD", addr, bank, row, col);
  endfunction

endclass : ddr4_transaction

//------------------------------------------------------------------------
// ddr4_cmd_item
// Whitebox observation of one pulse on the internal DDR4 command bus
// (ACT/RD/WR/PRE or a REFRESH pulse), used only for coverage.
//------------------------------------------------------------------------
class ddr4_cmd_item extends uvm_object;

  ddr4_pkg::ddr4_cmd_e cmd_type;
  ddr4_pkg::bank_t      bank;
  ddr4_pkg::row_t       row;
  ddr4_pkg::col_t       col;
  bit                   is_refresh;

  `uvm_object_utils_begin(ddr4_cmd_item)
    `uvm_field_enum(ddr4_pkg::ddr4_cmd_e, cmd_type, UVM_ALL_ON)
    `uvm_field_int(bank, UVM_ALL_ON)
    `uvm_field_int(is_refresh, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "ddr4_cmd_item");
    super.new(name);
  endfunction

endclass : ddr4_cmd_item
