# Lab 2 — Assignment

Take the accelerator you built in Lab 1 and explore how to make it better at
**one thing you choose**: change its architecture, change how the tools build
it, measure every attempt through the whole flow, then keep what works. Hand
in [REPORT.md](REPORT.md), filled in, a tag per exploration, and a release.

This file says **what to do and in what order**. [TUTORIAL.md](TUTORIAL.md)
says how, and how to keep each exploration in git;
[implementation/design_compiler/OPTIMIZATION.md](implementation/design_compiler/OPTIMIZATION.md)
has the Design Compiler commands, as snippets; [SETUP.md](SETUP.md) brings
your Lab 1 design into this repository.

Create your group repository from the ISA-LAB2 template and work at its root.

---

## Group

Fill in the group table at the top of [REPORT.md](REPORT.md).

---

## What stays fixed

Lab 3 integrates what you deliver here, so the contract from Lab 1 still holds:

1. **The same interface.** Same top module name and ports (`clk_i`, `rst_ni`,
   the register interface, the OBI manager port). The register map in
   `data/accel.hjson` may **grow** — a new mode field, a new status bit — but
   nothing that exists may change meaning or address. A Lab 3 driver written
   against your Lab 1 header must still work.
2. **The same function.** Bit-exact against the same golden model. If an
   optimization changes the arithmetic (a narrower datapath, a different
   rounding), the model changes first, you justify it, and the report says so.
3. **The same testbench passes**, on Verilator and QuestaSim, and on the
   gate-level netlist (`make power-sim`). You may extend the testbench; you may
   not weaken it. If it hard-codes a latency, fix that first: a pipelined
   design is *supposed* to take more cycles before the first result.
4. **The same flow and corners.** Timing at `slow_1p08V_125C`, power at
   `typ_1p20V_25C`, the Lab 1 scripts as the starting point.
5. **The naming contract** of Lab 1
   ([its README](https://github.com/Integrated-Systems-Architecture/ISA-LAB1/blob/main/README.md#the-naming-contract)).
   The core name stays `isa:lab1:<accel>` — you import it unchanged.

What changes is up to you: the microarchitecture, the arithmetic, the
synthesis and place-and-route scripts.

---

## Step 0 — Bring in Lab 1 and reproduce the baseline

Follow [SETUP.md](SETUP.md): import your design from `lab1-delivery`, run the
flow (sim, synth at your Lab 1 period, PnR, post-layout power), and check the
numbers against your Lab 1 report.

Fill in **Section 1** of REPORT.md. Commit, then tag that commit:

```bash
git tag lab2-baseline && git push origin lab2-baseline
```

`lab2-baseline` is the parent of your first exploration, and what the final
design is compared against.

---

## Step 1 — Choose the objective, read the reports

Pick **one** figure of merit: throughput, area, energy per item, or throughput
per area. Write it in **Section 2.1** before you change anything.

Then find out what limits it — the critical path, the cycles per item, the OBI
bandwidth, the biggest block in `area.rpt`. TUTORIAL.md §1 walks you through
it. Fill in **Section 2**, with a first plan in §2.4.

---

## Step 2 — Explore

Try as many changes as you want, one per exploration. An exploration that
makes things worse is still an exploration: measure it, explain it, keep it in
the report. The kinds:

| kind | what | where to read |
|---|---|---|
| architectural | retiming or pipelining in the RTL — the easiest: registers at the input or output of a block, then let the tool spread them | TUTORIAL.md §3, §4.1 |
| architectural | unfolding, folding | TUTORIAL.md §4.2, §4.3 |
| architectural | arithmetic in the RTL: constant multiplication, carry-save, word length, resource sharing, your own Wallace or Dadda multiplier | TUTORIAL.md §4.4, §4.6 |
| tool | the synthesis script: retiming (`compile_ultra -retime`, `set_optimize_registers`), operator architectures (`set_dp_smartgen_options`, `set_dont_use`) | TUTORIAL.md §4.7, OPTIMIZATION.md |
| tool | place and route: utilisation, aspect ratio, clock-tree targets, anything else in the Innovus scripts | TUTORIAL.md §4.8 |

**At least one architectural and at least one tool exploration are
required.**

For each exploration:

1. **Start from its parent** — `lab2-baseline` or an earlier exploration — on
   a branch of its own (TUTORIAL.md §2).
2. **Make one change**, in the RTL or in the scripts.
3. **Run the whole flow** at the clock period you choose for it:

   ```bash
   make sim && make questa
   make synth CLK_PERIOD=<p>
   make power-sim              # the gate-level netlist still passes
   make pnr-all
   make power-postlayout
   ```

   At a short period `make power-postlayout` may fail on a correct netlist,
   because the testbench drives inputs before the clock tree delivers the
   edge. TUTORIAL.md §5.1 explains it and gives the fix: simulate at a
   relaxed clock with `PWR_CLK_PS`, and say so in the report.
4. **Commit, tag it `expNN`** (`exp01`, `exp02`, ..., in the order you make
   them) and push the tag.
5. **Fill in its block in Section 3**: the parent, what changed and why, the
   block diagram if the RTL changed, what happened, the table against the
   parent.

---

## Step 3 — The final design

Decide what to keep. The final design can be one exploration, or several
combined — a pipeline from one, a synthesis option from another, a floorplan
from a third. Combine them on `main` (TUTORIAL.md §2.4), and run the whole
flow on the result, as in Step 2.

Then synthesise the final design at the **baseline's** clock period as well,
for §4.2.

Fill in **Section 4** — what you kept and why, the table against the
baseline, why each number is different, the same-clock comparison — and the
index of **Section 5**.

---

## Step 4 — Write the report and release

> **The release tag must be exactly `lab2-delivery`** — lower case, with a
> hyphen, no version suffix. We look for that name: a release called
> `lab2-final`, `Lab2`, `v2.0` or anything else is not found, and counts as
> not delivered. The release *title* can be anything.

```bash
git status                        # check nothing generated sneaks in
git add rtl tb model data accel.core Makefile implementation/design_compiler/scripts \
        implementation/innovus/scripts REPORT.md figures
git commit -m "Lab 2: <accel> -- final design and report"
git push
git push origin --tags            # lab2-baseline and every expNN
gh release create lab2-delivery --title "Lab 2" --notes "<accel>: optimised accelerator"
```

The release is the submission, and it has to exist by the deadline announced
on the course page. After it you may keep committing **minor fixes only**: we
look at the diff from `lab2-delivery`.

Do **not** commit `build/`, `vendor/pulp_platform/*/`, the generated CSR
files, `vectors/`, `runs/`, or anything under `implementation/*/artefacts/`,
`.../netlist/`, `.../reports/`, `.../db/` or `.../vcd/`. Commit the numbers, in
REPORT.md, and the figures.

---

## What you hand in

- **[REPORT.md](REPORT.md)**, every `____` filled with your own measurements.
- **`figures/`** — the block diagram of every exploration that changed the
  RTL, and of the final design.
- **The code**: RTL, testbench, model, `data/accel.hjson`, `accel.core`, and
  the synthesis and place-and-route scripts as you modified them.
- **Tags**: `lab2-baseline` on the reproduced Lab 1 design, one `expNN` per
  exploration in Section 3, all pushed, and a **GitHub release** tagged
  exactly `lab2-delivery`, by the deadline.

Nothing is graded automatically. We read the report, check out your tags, run
your flow, and discuss it with your group: be ready to reproduce any number,
to explain every command you added to the scripts, and to say why you chose
the objective you chose and the explorations you kept.
