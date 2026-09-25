# Verification Plan — DDR4 Controller UVM Environment

## Objective

Verify the simplified DDR4 memory controller (`src/rtl/`) correctly sequences
DDR4 commands (ACT/RD/WR/PRE + refresh) for front-end read/write requests,
and returns correct read data for everything previously written, across
random and directed corner-case traffic.

## DUT functions under test

1. Address translation into `{bank, row, col}`
2. Per-bank open-page policy: row hit (skip ACT), row miss (ACT only),
   row conflict (PRE → ACT)
3. Simplified timing enforcement: tRCD, tRAS, tRP, tRFC (cycle-count
   constants, not JEDEC SPD values — see `ddr4_pkg.sv`)
4. BL8 burst write/read data path correctness
5. Free-running refresh arbitration: precharge-all → REFRESH → tRFC,
   interleaved with normal traffic
6. Multi-bank concurrency *patterns*: back-to-back accesses landing on
   different banks vs. the same bank (the RTL processes one front-end
   request to completion at a time — it does not pipeline overlapping
   commands across banks in hardware. What's verified is that the
   *sequencing and bank bookkeeping* stay correct as stimulus alternates
   banks, not true concurrent multi-bank execution.)

## What is verified

| Item | Mechanism |
|---|---|
| Read-after-write data integrity | `ddr4_scoreboard` shadow-memory comparison, keyed identically to `data_path`'s backing store addressing |
| Command legality/sequencing (no RD/WR issued to an unopened/wrong row) | Implicit in RTL FSM structure (`command_generator`); coverage confirms all four command types are exercised per bank |
| Row-conflict handling (PRE before re-ACT) | `corner_case_seq` — alternating-row same-bank traffic forces this path every pair of transactions |
| Row-hit fast path (no ACT overhead) | `burst_seq` — repeated access to one open bank/row |
| Refresh interleaving with traffic | `corner_case_seq` runs long enough that the free-running `T_REFI` counter fires mid-stream; no explicit hook needed since the DUT has no separate refresh command port |
| Command × bank coverage closure | `ddr4_coverage` cross-coverage, driven to a target threshold by `coverage_test` |

## What is *not* modeled (explicitly out of scope)

- Real DDR4 PHY-level signaling (DQ/DQS/ODT/CKE/CS_n/RAS_n/CAS_n/WE_n pins) —
  the DUT models the controller's internal command/data pipeline, exposing
  an internal whitebox command bus for verification, not the physical DDR4
  pin interface.
- Full JEDEC timing table (tFAW, tWTR, tCCD, tZQCS, ZQ calibration, training,
  MRS/mode-register setup, etc.) — only tRCD/tRAS/tRP/tRFC are modeled, as
  simplified cycle constants.
- True hardware pipelining/overlap of commands to independent banks within
  a single request's service time (see note in item 6 above).
- ECC/CRC, DBI, or any RAS features.

## Coverage model (`ddr4_coverage.sv`)

- **`cg_cmd_bank`**: command type (ACT/RD/WR/PRE) × bank (0–7) cross
- **`cg_adjacency`**: back-to-back RD/WR landing on the same bank vs. a
  different bank as the immediately preceding RD/WR
- **`cg_refresh`**: at least one refresh pulse observed
- **`cg_txn_burst`**: completed-transaction direction (read/write) × bank

## Test list

| Test | Sequence(s) | Purpose |
|---|---|---|
| `traffic_test` | `random_seq` (100 txns) | Baseline sanity: random traffic across all banks completes and checks clean |
| `stress_test` | `burst_seq` (64) + `corner_case_seq` (80 pairs) | Higher-volume row-hit and row-conflict stress |
| `coverage_test` | `random_seq`, looped | Drives `cg_cmd_bank` toward a 90% target or an iteration cap, reporting whatever is actually achieved |

## Coverage goal

Target: 90% on `cg_cmd_bank` (command × bank cross). **Measured on Vivado
xsim 2026.1**: `coverage_test` reached 100% in a single 100-transaction
iteration (target met). `traffic_test` also reached 100% on all four
covergroups; `stress_test` reached 50% on `cg_cmd_bank`/`cg_txn_burst`
because it deliberately concentrates traffic on fewer banks (row-hit/
row-conflict stress) rather than spreading across all eight. Full logs:
`sim/results/ddr4_sim_{traffic,stress,coverage}_test.log`.

Scoreboard results across all three runs: 0 mismatches, 0 UVM errors/fatals.
`stress_test`'s address locality (repeated same-bank/row access) gave it by
far the most actual read-after-write compares (261, vs. 1 and 0 for the
other two) — with ~100 fully random addresses spread across a 32K-location
space, most single-shot random reads land on a location never written in
that run, which `unwritten_reads` in the scoreboard summary accounts for
honestly rather than silently passing or hiding.

## Known simplifications (by design, not oversight)

- Backing memory geometry (`ROW_BITS=8`, `COL_BITS=4`) is far smaller than a
  real DDR4 device so the simulation memory array stays a few hundred KB.
- Controller processes one front-end request to completion before accepting
  the next (no request-level pipelining).
- Driver/monitor use plain procedural interface access rather than a
  clocking block. This is not merely a style choice with no consequence:
  first-run testing hit a real race from it (driver's `req_valid` write and
  the monitor's same-edge read, order undefined without a clocking block —
  see README status section), fixed by driving every signal with a
  nonblocking assignment synchronized to a specific posedge. That fix is
  correct per IEEE 1800 scheduling semantics, but a clocking block remains
  the more idiomatic, harder-to-misuse choice for a production environment.
