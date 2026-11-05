# Lab 2 — Optimise the accelerator: retiming, pipelining, folding, arithmetic

MSc lab, groups of 3. Third of four activities. In Lab 1 you built your kernel
as a standalone accelerator and measured it. **Lab 2 explores how to make it
better at one thing you choose — in the architecture and in the tools — and
proves each attempt with the same measurements.**

| | | |
|---|---|---|
| Lab 0 | profile the applications, pick the kernel, justify it with Amdahl | done |
| Lab 1 | build that kernel as a standalone accelerator: model, RTL, testbench, synthesis, layout, power | done |
| **Lab 2** | optimise it — retiming, pipelining, folding, arithmetic — and compare PPA against Lab 1 | *this repository* |
| Lab 3 | integrate it into X-HEEP over OBI+REG, write the C driver, measure the real speedup | |

Lab 1 ended with a baseline: a maximum frequency, an area, a power and a cycle
count, at stated corners. Lab 2 produces the same numbers for every
exploration you try, and ends with a final design — the explorations worth
keeping, combined — and an argument for every difference from the baseline.

## Start here

1. **[SETUP.md](SETUP.md)** — import your Lab 1 design from its
   `lab1-delivery` tag and reproduce the baseline here. Same server, same tools
   as Lab 1.
2. **[TUTORIAL.md](TUTORIAL.md)** — how to diagnose what limits your design,
   how to keep each exploration on its own branch and tag, pipelining by
   retiming, and a menu of explorations, architectural and in the tools.
3. **[implementation/design_compiler/OPTIMIZATION.md](implementation/design_compiler/OPTIMIZATION.md)**
   — the Design Compiler commands for retiming and for choosing operator
   architectures, as snippets, with what each one did on a real run and the
   traps (some are silently ignored).
4. **[ASSIGNMENT.md](ASSIGNMENT.md)** — what you must do and in what order.
5. **[REPORT.md](REPORT.md)** — what you hand in. Open it before the first run:
   it tells you which numbers to keep.

## What is different from Lab 1

**You start from your own design.** The template carries Lab 1's build system
and scripts, unchanged; SETUP.md copies your RTL, testbench, model, register
map, `accel.core` and `Makefile` in from `lab1-delivery`.

**You edit the tool scripts.** In Lab 1 no tool script needed editing. In
Lab 2 you may change `implementation/design_compiler/scripts/dc_script.tcl`
and the place-and-route scripts in `implementation/innovus/scripts/`:
OPTIMIZATION.md and TUTORIAL.md §4.7–§4.8 give you the commands and the knobs,
and how you put them together is yours to decide and to explain.

**You choose the objective.** Throughput, area, energy per item, or throughput
per area: one, declared before you start, and justified from what Lab 0 and
Lab 1 measured.

**You explore.** As many explorations as you want, each one change, each
tagged `expNN`, each through the whole flow up to post-layout power, each
compared against the version it started from. One that makes things worse
counts, if it is explained. At least:

| | |
|---|---|
| one architectural exploration | retiming or pipelining in the RTL, folding, unfolding, arithmetic in the RTL (your own Wallace or Dadda multiplier included) |
| one tool exploration | the synthesis script (retiming, operator architectures) or the place-and-route scripts |

At the end you choose what to keep — one exploration or several combined —
and compare that final design with the baseline.

Proposed exploration, if your kernel multiplies: write your own Wallace or
Dadda tree multiplier and race it against DesignWare's (TUTORIAL.md §4.6).

## Pipelining, the easy way

The single most useful idea in this lab: to pipeline a block, **put all the
extra registers at its output (or all at its input) and let the tool retime
them into the logic.** The RTL stays obviously correct — it is the old
function, a few cycles later — and the tool finds the cuts and cannot place
them wrongly. Doing the same by hand is a good comparison, and optional.
TUTORIAL.md §3 has the RTL; OPTIMIZATION.md §1 has the commands and the
numbers.

## What stays fixed

The interface and the function, because Lab 3 integrates what you deliver:
same top module and ports, a register map that may grow but not change,
bit-exact against the same golden model, and the same testbench passing on
Verilator, QuestaSim and the gate-level netlist. Same corners as Lab 1. The
full list is in [ASSIGNMENT.md](ASSIGNMENT.md#what-stays-fixed).

## The flow

The same targets as Lab 1. On the ISA server, once per shell:

```bash
source /oss-tools/init.sh                    # python, fusesoc, verilator, $IHP_PDK_ROOT
source /eda/scripts/init_design_vision       # dc_shell, lc_shell, pt_shell/pwr_shell
source /eda/scripts/init_cadence_2020-21     # innovus -- 2020-21, NOT 2021-22
source /eda/scripts/init_questa_core_prime   # vsim
```

Then:

```bash
make vendor      # fetch the IPs
make regs        # reggen: data/accel.hjson -> rtl/<accel>_reg_{pkg,top}.sv + sw header
make lint        # Verilator lint
make sim         # Verilator, your testbench
make questa      # QuestaSim, the same testbench -- they must agree
make synth       # Design Compiler, with your dc_script.tcl   (ISA server)
make power-sim   # your testbench on the synthesised netlist  (ISA server)
make pnr-all     # Innovus, route + opt                        (ISA server)
make power-postlayout   # gate sim + PrimePower on the routed netlist
make help        # every target and every knob
```

## Where the outputs land

Same places as Lab 1, and every run overwrites the previous one — TUTORIAL.md
§2 shows how to keep a snapshot of each exploration under `runs/`.

| after | where to look |
|---|---|
| `make synth` | `implementation/design_compiler/reports/` — `qor.rpt`, `timing.rpt`, `resources.rpt`, and `synth.log`, the full transcript (retiming messages, critical loops) |
| `make pnr-all` | `implementation/innovus/artefacts/reports/08_export.*` |
| `make power-postlayout` | `implementation/power_analysis/reports/<accel>_pnr_power.rpt` |

## Reading

Read these while you decide what to change. Links go to IEEE Xplore: full text
from the Politecnico network or the VPN. The master list is
[`READING.md` in ISA-BOOKS](https://github.com/Integrated-Systems-Architecture/ISA-BOOKS/blob/main/READING.md).

- [Optimizing Synchronous Systems](https://ieeexplore.ieee.org/document/4568313) — Leiserson, Saxe, FOCS 1981. *retiming: what the tool is doing.*
- [Pipeline Interleaving and Parallelism in Recursive Digital Filters, Part I](https://ieeexplore.ieee.org/document/32286) — Parhi, Messerschmitt, TASSP 1989. *pipelining loops with feedback — what retiming cannot do alone.*
- [Synthesis of Control Circuits in Folded Pipelined DSP Architectures](https://ieeexplore.ieee.org/document/109555) — Parhi, Wang, Brown, JSSC 1992. *folding.*
- [A Suggestion for a Fast Multiplier](https://ieeexplore.ieee.org/document/4038071) — Wallace, IEEE Trans. Electronic Computers 1964. *carry-save trees.*
- [High-Speed Arithmetic in Binary Computers](https://ieeexplore.ieee.org/document/4066249) — MacSorley, Proc. IRE 1961. *radix-4 Booth, carry-save.*
- L. Dadda, *Some Schemes for Parallel Multipliers*, Alta Frequenza, 1965. *the Dadda tree: reduce as late as possible.*
- C. R. Baugh, B. A. Wooley, *A Two's Complement Parallel Array Multiplication Algorithm*, IEEE Trans. Computers, 1973. *signed partial products for any tree.*
- [Subexpression Sharing in Filters Using Canonic Signed Digit Multipliers](https://ieeexplore.ieee.org/document/539000) — Hartley, TCAS-II 1996. *constant multiplication as shared shifts and adds.*
- [A Formal Method for Optimal High-Level Casting of Heterogeneous Fixed-Point Adders and Subtractors](https://ieeexplore.ieee.org/document/6936317) — Sierra, Carreras, Caffarena, López Barrio (UPM), TCAD 2015. *sizing adder trees.*
- K. K. Parhi, *VLSI Digital Signal Processing Systems: Design and Implementation*, Wiley 1999 — chapters on retiming, unfolding, folding and pipelining. *the textbook version of all of the above.*

The kernel-specific papers of Lab 1's README (CORDIC, FIR, systolic arrays,
NTT) show how others pipelined and folded the same kernels: go back to the
ones for yours.

For Design Compiler itself, `man <command>` and `help -verbose <command>`
inside `dc_shell` are the reference for every option in OPTIMIZATION.md.

## Layout

```
README.md  SETUP.md  TUTORIAL.md  ASSIGNMENT.md  REPORT.md
                                 read them in that order; REPORT.md is what you hand in

rtl/ tb/ model/ data/ accel.core Makefile
                your Lab 1 design, imported by SETUP.md, then optimised
sw/             <accel>_regs.h, generated
figures/        the block diagrams your report refers to -- committed
runs/           your snapshots of each exploration (gitignored)

implementation/
  design_compiler/    scripts/ (you edit dc_script.tcl) + README.md + OPTIMIZATION.md
  innovus/            scripts/ (yours to edit, for a PnR exploration) + README.md
  power_analysis/     scripts/ questa/ + README.md
  tech/               tc_clk_gating and sram_wrapper, generic vs SG13G2

vendor/         pinned IP snapshots (gitignored, `make vendor`)
```

## What you hand in

[REPORT.md](REPORT.md) filled in, `figures/`, your code and your scripts, a
tag `lab2-baseline` on the reproduced Lab 1 design, one tag `expNN` per
exploration, and a GitHub release tagged `lab2-delivery`, created by the
deadline announced on the course page.

> **The release tag must be exactly `lab2-delivery`** — lower case, with a
> hyphen, no version suffix. A release called `lab2-final`, `Lab2`, `v2.0` or
> anything else is not found, and counts as not delivered. The release *title*
> can be anything.

[ASSIGNMENT.md](ASSIGNMENT.md#what-you-hand-in) has the details and the
`gh release` command.
