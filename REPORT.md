# Lab 2 — Report

Fill every `____`. Numbers without a corner and a clock period next to them do
not count. Every number in here must be reproducible from a report the flow
writes — name the file, and the git tag it came from, when you are asked to.

| | |
|---|---|
| Group number | ____ |
| Members | ____, ____, ____ |
| Accelerator (top module) | ____ |
| Lab 1 repository / tag | ____ / `lab1-delivery` |
| Lab 2 repository / release tag | ____ / `lab2-delivery` |
| Date | ____ |

---

## 1. The baseline, reproduced

Your Lab 1 design, imported into this repository (SETUP.md) and run through
the flow again **here**, before any change. Commit tagged `lab2-baseline`.

| | Lab 1 report | reproduced here | corner | from |
|---|---|---|---|---|
| Implemented clock period | ____ ns | ____ ns | — | — |
| Worst slack at that period | ____ ns | ____ ns | slow_1p08V_125C | `qor.rpt` |
| f_max | ____ MHz | ____ MHz | slow_1p08V_125C | 1 / (period − WNS), `qor.rpt` |
| Area, post-synthesis | ____ µm² | ____ µm² | slow_1p08V_125C | `area.rpt` |
| Area, post-layout | ____ µm² | ____ µm² | — | `08_export.area.rpt` |
| Cells / flip-flops, post-synthesis | ____ / ____ | ____ / ____ | — | `qor.rpt` |
| Power, post-layout | ____ mW | ____ mW | typ_1p20V_25C | `<accel>_pnr_power.rpt` |
| Cycles per item | ____ | ____ | — | simulation |
| Energy per item | ____ pJ | ____ pJ | typ_1p20V_25C | computed |

Testbench on the reproduced baseline: `make sim` ____, `make questa` ____,
`make power-sim` ____, `make power-postlayout` ____.

If any number differs from Lab 1, say which and why (a bug you fixed after the
delivery, a different period, a different tool run). From here on, the
**reproduced** column is the baseline.

> ____

---

## 2. Objective and diagnosis

**2.1 The objective.** Pick **one** figure of merit and say it before you
optimise anything: throughput (items/s), area (µm²), energy per item (pJ), or
throughput per area (items/s/µm²). Why that one, for this accelerator — think
of Lab 0's Amdahl ceiling and of what Lab 3 will make of it.

| | |
|---|---|
| Objective | ____ |
| Baseline value | ____ |

> ____

**2.2 What limits it in the baseline.** From the reports, not from intuition.

| | |
|---|---|
| Critical path: start point → end point | ____ → ____ |
| Critical path: what dominates it (operator, mux chain, wire, ...) | ____ |
| Logic levels / data arrival time on it | ____ / ____ ns |
| Cycles per item, and where they go (FSM states, OBI waits, compute) | ____ |
| OBI words read + written per item | ____ |
| Largest area contributor (`area.rpt -hierarchy`) | ____ |
| Largest power group (Lab 1 §6.2) | ____ |

**2.3 The bandwidth ceiling.** The OBI port moves at most one 32-bit word per
cycle. With the words per item above, what is the fewest cycles per item any
datapath can reach behind this port? How far is the baseline from it?

> ____

**2.4 The plan.** Which explorations you will try first, and what each should
buy against the objective. Short — one line each. You may do more, or
different ones, later.

> ____

---

## 3. Explorations

As many as you want. One that makes things worse counts as much as one that
makes them better, if it is measured and explained. You need at least:

- **one architectural** exploration: retiming or pipelining in the RTL,
  folding, unfolding, an arithmetic change in the RTL (a Wallace or Dadda
  multiplier included);
- **one tool** exploration: a change to the synthesis script (retiming,
  operator architectures, ...) or to the place-and-route scripts.

Each exploration starts from a **parent** — `lab2-baseline` or an earlier
exploration — and is compared against it. Each has its own git tag, `expNN`,
numbered in the order you make them (TUTORIAL.md §2), pushed: **an
exploration without a pushed tag does not count.** Each runs at the clock
period you choose for it. The ones you keep go through the whole flow, up to
post-layout power; one you leave out may stop after synthesis and
`make power-sim`, unless it changes place and route (TUTORIAL.md §2.1).

Copy the block below once per exploration.

### Exploration NN — ____

| | |
|---|---|
| Tag | `expNN` |
| Parent | `lab2-baseline` / `expMM` |
| Kind | architectural (RTL retiming/pipelining · folding · unfolding · RTL arithmetic · Wallace/Dadda) / tool (synthesis script · place and route) |
| Kept in the final design | yes / no / partly |
| Flow | whole, up to post-layout power / synthesis only |

**What changed, and why.** In words. If the RTL changed, the modified block
diagram: `figures/expNN_____`. If a script changed: which file, and the
commands you added or changed.

> ____

**What happened.** What you expected against the objective of §2.1, and what
you got. If it is worse, why.

> ____

| | parent | this | ratio | from |
|---|---|---|---|---|
| Clock period (synthesis and PnR) | ____ ns | ____ ns | ____ | — |
| Setup WNS / violating paths, post-route | ____ ns / ____ | ____ ns / ____ | — | `08_export.timing_setup.rpt` |
| Hold WNS / violating paths, post-route | ____ ns / ____ | ____ ns / ____ | — | `08_export.timing_hold.rpt` |
| DRC violations | ____ | ____ | — | `08_export.drc.rpt` |
| Core size / achieved density | ____ × ____ µm / ____ % | ____ × ____ µm / ____ % | — | — |
| Area, post-layout | ____ µm² | ____ µm² | ____ | `08_export.area.rpt` |
| Cells / flip-flops, post-synthesis | ____ / ____ | ____ / ____ | ____ | `qor.rpt` |
| Cycles per item | ____ | ____ | ____ | simulation |
| Throughput | ____ items/s | ____ items/s | ____ | at the clock period above |
| Power, post-layout, simulated at ____ / ____ ns | ____ mW | ____ mW | ____ | `<accel>_pnr_power.rpt` |
| Energy per item | ____ pJ | ____ pJ | ____ | at the simulation clock |

Synthesis only: write — in the place-and-route rows, and give area and power
post-synthesis instead (`area.rpt`, `make power` → `<accel>_power.rpt`),
marked as such.

Testbench: `make sim` ____, `make questa` ____, `make power-sim` ____,
`make power-postlayout` ____. If you changed the testbench or the model: what,
and why that does not weaken the check.

> ____

**Evidence from the tool**, if it helps the explanation: what retiming moved
and the critical loop it printed (`-print_critical_loop`, the `MY_CLK_r_REG*`
cells), what `report_resources` says was built, the critical path before and
after, the congestion map.

> ____

---

## 4. The final design

What you deliver, tagged `lab2-delivery`: the explorations you decided to
keep, combined.

| | |
|---|---|
| Combines | `exp__`, `exp__`, ... |
| Release tag | `lab2-delivery` |

**What is in it, and why those.** Which explorations you kept and which you
left out, and how you combined them. The block diagram, if the RTL differs
from Lab 1: `figures/final_____`.

> ____

**4.1 Against the baseline.** Ratio = final / baseline.

| | baseline | final | ratio | from |
|---|---|---|---|---|
| Clock period (synthesis and PnR) | ____ ns | ____ ns | ____ | — |
| Setup WNS / violating paths, post-route | ____ ns / ____ | ____ ns / ____ | — | `08_export.timing_setup.rpt` |
| Hold WNS / violating paths, post-route | ____ ns / ____ | ____ ns / ____ | — | `08_export.timing_hold.rpt` |
| DRC violations | ____ | ____ | — | `08_export.drc.rpt` |
| Core size / achieved density | ____ × ____ µm / ____ % | ____ × ____ µm / ____ % | — | — |
| Area, post-layout | ____ µm² | ____ µm² | ____ | `08_export.area.rpt` |
| Cells / flip-flops, post-synthesis | ____ / ____ | ____ / ____ | ____ | `qor.rpt` |
| Cycles per item | ____ | ____ | ____ | simulation |
| Throughput | ____ items/s | ____ items/s | ____ | at the clock period above |
| Power, post-layout, simulated at ____ / ____ ns | ____ mW | ____ mW | ____ | `<accel>_pnr_power.rpt` |
| Energy per item | ____ pJ | ____ pJ | ____ | at the simulation clock |

Testbench on the final design: `make sim` ____, `make questa` ____,
`make power-sim` ____, `make power-postlayout` ____.

**Why it is different.** Row by row where it matters: which exploration
explains each difference, what you gained on the objective of §2.1, and what
it cost on the other numbers.

> ____

**4.2 At the same clock.** The table above mixes two effects: a different
clock and a different design. Synthesise the final design at the
**baseline's** period and separate them.

| at ____ ns | baseline | final | ratio |
|---|---|---|---|
| Area (µm²) | ____ | ____ | ____ |
| Cycles per item | ____ | ____ | ____ |
| Power, post-synthesis (mW) | ____ | ____ | ____ |
| Energy per item (pJ) | ____ | ____ | ____ |

> ____

---

## 5. Index of the explorations

One row per exploration of §3, in the order you made them. Every tag here must
be pushed.

| tag | parent | kind | what, in one line | kept? |
|---|---|---|---|---|
| `lab2-baseline` | `lab1-delivery` | — | Lab 1, reproduced | — |
| `exp01` | ____ | ____ | ____ | ____ |
| `exp02` | ____ | ____ | ____ | ____ |
| `lab2-delivery` | ____ | final | ____ | — |
