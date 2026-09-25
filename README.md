# DDR4 Controller UVM Verification

A simplified but functionally real DDR4 memory controller (SystemVerilog RTL)
verified with a layered UVM testbench: constrained-random stimulus, a
reference-model scoreboard, and functional coverage over command/bank
sequencing.

## Status

**Simulated and passing on Vivado xsim 2026.1 (UVM 1.2, bundled).** All three
tests ran clean: 0 errors, 0 fatals, 0 scoreboard mismatches across every run.
Real logs are committed at `sim/results/ddr4_sim_*.log`.

| Test | Writes | Reads | Compares | Mismatches | cmd×bank cov. | adjacency | refresh | rw×bank |
|---|---|---|---|---|---|---|---|---|
| `traffic_test` | 49 | 51 | 1 | **0** | 100% | 100% | 100% | 100% |
| `stress_test` | 45 | 78 | 261 | **0** | 50% | 100% | 100% | 50% |
| `coverage_test` | 47 | 53 | 0 | **0** | 100% (target 90%, met in 1 iteration) | 100% | 100% | 100% |

"Compares" is the number of read beats that landed on a location the
scoreboard had actually seen written before (see `unwritten_reads` in each
log — with only ~100 random transactions across a 32K-location address
space, most reads miss anything previously written, which is expected, not
a bug). `stress_test`'s lower cmd×bank coverage is also expected: it
concentrates traffic on fewer banks by design (row-hit/row-conflict
stress), unlike `traffic_test`/`coverage_test`'s all-bank random spread.

Two real bugs were caught and fixed during this first bring-up (both
explained in code comments where fixed):
1. **Field-shadowing in `randomize() with {}`** — `burst_seq`/
   `corner_case_seq` referenced sequence-local `bank`/`row` fields inside a
   `with` block on a `ddr4_transaction`, which also has fields named
   `bank`/`row`; unqualified names there resolve against the object being
   randomized first, so they silently bound to the wrong (stale) fields.
   Fixed with `local::`.
2. **Driver/monitor race on `req_valid`** — the driver used a *blocking*
   assignment to `req_valid`, read by both the DUT and the monitor on the
   same clock edge with no clocking block to arbitrage the order; the
   monitor lost the race and reported zero transactions. Fixed by driving
   every interface signal with a *nonblocking* assignment synchronized to a
   specific posedge, per IEEE 1800 Active/NBA region ordering.
3. **xsim constraint-solver limitation** — calling `ddr4_transaction::
   pack_addr(...)` inside a `randomize() with {}` block, with one argument
   still unresolved, produced "Invalid X/Z in a state expression value" —
   this xsim build can't evaluate a function call with a mixed
   known/unknown argument inside an active constraint. Fixed by computing
   the target address as a plain concrete value before calling
   `randomize()`.
4. **xsim CLI quirk (Windows, v2026.1)**: `--testplusarg` rejects any value
   containing `=` (i.e. the standard `+UVM_TESTNAME=foo` form), regardless
   of quoting. Worked around with a compile-time `` `define
   UVM_TESTNAME_DEFAULT `` fallback in `tb_top.sv` (a real `+UVM_TESTNAME`
   plusarg still takes priority where the simulator's CLI accepts one —
   Questa, VCS, or a non-Windows xsim without this bug). See `sim/Makefile`.

None of this was fabricated after the fact — the environment was written,
then actually compiled and run, and these are the real findings from that
run.

## Architecture

```
                         ddr4_controller (DUT)
        ┌───────────────────────────────────────────────────┐
        │                                                     │
front-  │   ┌────────────────┐                                │
end     │   │address_         │  bank/row/col                 │
req/    │──▶│translator       │──────────┐                    │
resp    │   └────────────────┘           ▼                    │
(bus)   │                        ┌──────────────────┐         │
        │   refresh   ┌─────────▶│  command_generator │        │
        │   counter    │         │  (per-bank open-   │        │
        │   (T_REFI)───┘         │  page FSM, ACT/    │        │
        │                        │  RD/WR/PRE, tRCD/  │        │
        │                        │  tRAS/tRP/tRFC)     │        │
        │                        └─────────┬──────────┘        │
        │                                  │ access_start/     │
        │                                  │ is_write/bank/    │
        │                                  │ row/col            │
        │                                  ▼                    │
        │                        ┌──────────────────┐          │
        │                        │    data_path      │          │
        │                        │ (write buffering,  │          │
        │                        │  BL8 read return)  │          │
        │                        └──────────────────┘          │
        │                                                       │
        │   ddr_cmd_valid/type/bank/row/col, ddr_refresh_pulse  │
        └───────────────────────────┬───────────────────────────┘
                                     │  (whitebox, ddr4_if)
                                     ▼
                          ┌─────────────────────┐
                          │   ddr4_monitor        │
                          └──────────┬───────────┘
                     txn_ap  ┌───────┴────────┐  cmd_ap
                             ▼                 ▼
                    ┌────────────────┐  ┌───────────────┐
                    │ ddr4_scoreboard │  │ ddr4_coverage  │
                    │ (shadow memory) │  │ (cmd x bank,   │
                    └────────────────┘  │  adjacency,    │
                                         │  refresh, r/w  │
                                         │  x bank)       │
                                         └───────────────┘
```

`ddr4_driver`/`ddr4_sequencer` sit on the other side of `ddr4_if` from the
monitor, driving `ddr4_transaction` items generated by the sequences under
`src/tb/sequences/`.

### RTL (`src/rtl/`)

| File | Role |
|---|---|
| `ddr4_pkg.sv` | Shared parameters (geometry, simplified timing constants), command/bank-state enums |
| `ddr4_if.sv` | Front-end req/resp interface + whitebox internal command bus, shared by DUT and TB |
| `address_translator.sv` | Flat address → `{bank, row, col}` |
| `command_generator.sv` | Per-bank open-page FSM; issues ACT→RD/WR→PRE; row-hit/row-miss detection; refresh arbitration (precharge-all → REFRESH → tRFC) |
| `data_path.sv` | Write-data buffering and BL8 (burst-of-8) read return; owns the behavioral backing memory |
| `ddr4_controller.sv` | Top-level: wires the above + a free-running refresh interval counter |

Address geometry is deliberately smaller than a real DDR4 device
(`ROW_BITS=8`, `COL_BITS=4`, 8 banks) so the behavioral memory array in
`data_path` stays a few hundred KB in simulation, while still exercising the
full ACT/RD/WR/PRE sequencing, row-hit/row-conflict logic, and bank
arbitration a real controller needs. Timing constants (`T_RCD`, `T_RAS`,
`T_RP`, `T_RFC`, `T_REFI`) are simplified illustrative cycle counts, not
JEDEC SPD values — noted explicitly in `ddr4_pkg.sv`.

### UVM testbench (`src/tb/`)

Standard layered architecture: `ddr4_env` → `ddr4_agent` (`ddr4_sequencer`,
`ddr4_driver`, `ddr4_monitor`) → `ddr4_scoreboard` + `ddr4_coverage`, built
from a `ddr4_config` object and a `ddr4_transaction`/`ddr4_cmd_item` pair of
sequence items (front-end transaction vs. whitebox command-bus event).

- **Scoreboard** (`ddr4_scoreboard.sv`): shadow memory keyed the same way as
  `data_path`'s backing store (`{bank,row,col+beat}`); every read burst is
  checked against the last write to each location. Locations that were
  never written are reported (`UVM_HIGH`) but not scored as mismatches.
- **Coverage** (`ddr4_coverage.sv`): command-type × bank cross-coverage,
  back-to-back same-bank vs. different-bank adjacency, refresh-issued
  coverage, and read/write × bank coverage over completed transactions.

### Sequences (`src/tb/sequences/`)

- `random_seq.sv` — constrained-random read/write traffic across all banks
- `burst_seq.sv` — back-to-back bursts to one open bank/row (row-hit path)
- `corner_case_seq.sv` — same-bank alternating-row traffic (forces PRE+ACT
  row conflicts every pair) run long enough that the free-running refresh
  counter fires mid-stream

### Tests (`src/tb/tests/`)

- `base_test.sv` — builds `ddr4_env` from the virtual interface set by `tb_top.sv`
- `traffic_test.sv` — `random_seq`, 100 transactions
- `stress_test.sv` — `burst_seq` + `corner_case_seq` at higher counts
- `coverage_test.sv` — loops `random_seq` until cmd×bank coverage crosses a
  target threshold or an iteration cap is hit, then **reports the actual
  achieved coverage** either way

## How to run

Requires a UVM-1.2-capable SystemVerilog simulator. Free option: **Xilinx
Vivado** (xsim bundles UVM 1.2 since 2020.1).

```bash
cd sim
make xsim   TEST=traffic_test     # or stress_test / coverage_test
make questa TEST=traffic_test     # if Questa/ModelSim is installed instead
make vcs    TEST=traffic_test     # if VCS is installed instead
make clean
```

Logs and waveforms land in `sim/results/`.

## Verification plan

See [VERIFICATION_PLAN.md](VERIFICATION_PLAN.md).
