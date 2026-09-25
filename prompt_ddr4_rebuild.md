# DDR4 Controller UVM Verification — Rebuild Prompt

**Author:** Joel James P (joeljamesp)
**Email:** joeljamesnow@gmail.com
**GitHub target:** https://github.com/joeljamesp/DDR4-Controller-UVM (repo does not exist yet — create it)

---

## Context for Claude Code

The original working copy of this project lived on my old laptop's WSL install and was
accidentally deleted when I switched machines. It is **not recoverable** — build it fresh.
This is a from-scratch rebuild, not a recovery task.

My resume and profile README already describe this project as:

> Designed a layered UVM testbench (driver, monitor, scoreboard, sequencer) to generate
> transaction-based stimulus for a DDR4 memory controller's command and data pipelines.
> Implemented functional coverage models (covergroups, cross-coverage) targeting state
> machine transitions, multi-bank concurrent access patterns, and pipelined read/write
> response timing.

Build the real project so that description is true, then push it to GitHub today.

## Goal

A simplified but functionally real DDR4 memory controller (SystemVerilog RTL) verified
with a proper UVM testbench. Doesn't need to model every JEDEC DDR4 timing parameter —
needs to be a credible, working verification environment that demonstrates real UVM
methodology: layered testbench architecture, functional coverage, and constrained-random
stimulus.

## Scope

### 1. RTL (DUT) — `src/rtl/`
- `ddr4_controller.sv` — top-level controller: command decode, bank state machine
  (idle/activate/read/write/precharge), simple refresh counter
- `command_generator.sv` — translates read/write requests into DDR4 command sequences
  (ACT → RD/WR → PRE) with timing parameter checks (tRCD, tRP, tRAS — simplified constants
  are fine, don't need full SPD table)
- `address_translator.sv` — maps a flat address into {bank, row, column}
- `data_path.sv` — write data buffering, read data return path with burst support (BL8)

Keep it synthesizable-style SystemVerilog even though the goal here is verification, not
synthesis — that's what makes the DUT credible.

### 2. UVM Testbench — `src/tb/`
Standard layered UVM architecture:
- `ddr4_env.sv` — environment, instantiates agent(s), scoreboard, coverage collector
- `ddr4_config.sv` — configuration object (agent active/passive, coverage enable, etc.)
- `ddr4_sequencer.sv`, `ddr4_driver.sv`, `ddr4_monitor.sv` — standard UVM agent components
- `ddr4_scoreboard.sv` — checks read data returned matches what was written (a simple
  reference model / memory shadow array is enough)
- `ddr4_coverage.sv` — covergroups on: command type, bank ID, cross-coverage of
  (bank × command), back-to-back same-bank vs. different-bank accesses, burst boundaries
- Transaction item: `ddr4_transaction.sv` — address, r/w, burst length, data

### 3. Sequences — `src/tb/sequences/`
- `random_seq.sv` — constrained-random read/write traffic across all banks
- `burst_seq.sv` — back-to-back burst transactions
- `corner_case_seq.sv` — same-bank consecutive access (tests bank conflict / row miss
  handling), back-to-back refresh + access interleaving

### 4. Tests — `src/tb/tests/`
- `base_test.sv` — base test class, builds environment
- `traffic_test.sv` — runs random_seq
- `stress_test.sv` — runs burst_seq + corner_case_seq under high transaction count
- `coverage_test.sv` — runs until functional coverage crosses a target threshold (report
  actual achieved coverage honestly — don't fabricate a number, run the simulation and
  report what it actually hits)

### 5. Simulation setup — `sim/`
- Use whatever simulator is actually available on this machine — check for ModelSim/
  Questa, or fall back to **Icarus Verilog + a lightweight UVM-lite substitute** if no UVM-
  capable simulator is installed. If neither is available, structure the code correctly
  per UVM conventions and clearly document in the README that it's written for
  Questa/VCS/Xcelium execution, with instructions for someone who has a license to run it.
  Do not fake simulation output — if it can't actually run here, say so.
- `Makefile` — build/run targets
- `results/` — waveform dumps, log output, coverage reports (only real ones if simulation runs)

### 6. Documentation
- `README.md` — architecture overview, block diagram (ASCII is fine), verification plan
  summary, how to run, actual achieved results (only if simulation ran — otherwise state
  the environment is complete and simulator-ready)
- `VERIFICATION_PLAN.md` — what's verified, coverage goals, test list

## GitHub Setup

```bash
git init
git add .
git commit -m "Initial UVM verification environment for DDR4 memory controller"
git branch -M main
git remote add origin https://github.com/joeljamesp/DDR4-Controller-UVM.git
git push -u origin main
```

Repo should be **private** unless I say otherwise. Use `.gitignore` to exclude simulator
build artifacts (`*.vcd`, `work/`, `transcript`, `*.wlf`, `csrc/`, `simv*`, `*.log` except
committed final reports).

## Important constraints
- Do not fabricate coverage percentages, timing numbers, or "results achieved" — if you
  can't actually run the simulation in this environment, the README should honestly say
  the environment is verification-ready and simulator-agnostic, not claim results that
  weren't produced.
- Match commit author to: `git config user.email "joeljamesnow@gmail.com"` and
  `git config user.name "Joel James P"`.
- One-shot this today — I need it pushed and live.
