//------------------------------------------------------------------------
// address_translator.sv
// Maps a flat host address into {bank, row, column} fields.
// Layout (LSB -> MSB): [COL_BITS-1:0] column | [BANK_BITS-1:0] bank |
//                       [ROW_BITS-1:0] row
// This bank-interleave placement (bank bits below row bits) spreads
// sequentially incrementing addresses across banks, which is what lets
// the "different-bank back-to-back" stimulus patterns actually land on
// different banks without special-casing the address generator.
//------------------------------------------------------------------------
import ddr4_pkg::*;

module address_translator (
  input  addr_t addr,
  output bank_t bank,
  output row_t  row,
  output col_t  col
);

  localparam int COL_LSB  = 0;
  localparam int BANK_LSB = COL_BITS;
  localparam int ROW_LSB  = COL_BITS + BANK_BITS;

  assign col  = addr[COL_LSB  +: COL_BITS];
  assign bank = addr[BANK_LSB +: BANK_BITS];
  assign row  = addr[ROW_LSB  +: ROW_BITS];

endmodule : address_translator
