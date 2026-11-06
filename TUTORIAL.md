# Lab 2 — Tutorial: make it better, and prove it

This is the guided path from your Lab 1 baseline to an optimised accelerator
with numbers that show what each change bought. It is a **guide**, not the
assignment — [ASSIGNMENT.md](ASSIGNMENT.md) says what you must do and hand in,
[REPORT.md](REPORT.md) is what you fill in, and
[implementation/design_compiler/OPTIMIZATION.md](implementation/design_compiler/OPTIMIZATION.md)
has the Design Compiler commands.

Do [SETUP.md](SETUP.md) first: your Lab 1 design, imported, with the baseline
reproduced and tagged `lab2-baseline`.

---

## 0. What you start from, and what you produce

| you have, from Lab 1 | Lab 2 gives you back |
|---|---|
| a design that works, at a measured f_max, area and power | a design that is measurably better at the one thing you chose |
| the Lab 1 scripts, untouched | your synthesis and place-and-route scripts, with every line you added explained |
| one version, tagged `lab1-delivery` | one tagged version per exploration, each measured against its parent, and a final design that combines the ones worth keeping |

Optimising is easy. Optimising **the right thing**, and knowing afterwards
how much of the gain came from where, is the lab. An exploration that makes
things worse is part of that answer.

---

## 1. Diagnose before you optimise

### 1.1 Choose what "better" means

One figure of merit, chosen before you start:

| objective | what it is | improve it by |
|---|---|---|
| **throughput** | items/s = f_clk / cycles per item | a faster clock, or fewer cycles per item |
| **area** | µm², post-layout | fewer, smaller, shared operators |
| **energy per item** | pJ = P × cycles per item × T_clk | less switching per item, fewer cycles, less clock |
| **throughput per area** | items/s/µm² | the throughput you get for the silicon you spend |

They pull in different directions. Pipelining buys throughput with area;
folding buys area with throughput; a faster clock usually costs energy per
item. Pick the one that matters for your accelerator — Lab 0's Amdahl ceiling
tells you how much a faster kernel can still give the application, and that
is a good reason to pick, or not to pick, throughput.

### 1.2 Read the critical path

`implementation/design_compiler/reports/timing.rpt`, from your baseline run:

- **Start and end point.** Two registers in your datapath? A CSR to a datapath
  register? An OBI input to a register? Each one has a different cure.
- **What is in between.** A multiplier, an adder chain, a wide mux, a
  comparator feeding an FSM. `report_resources` (`reports/resources.rpt`) tells
  you which DesignWare block each operator became.
- **Is it in a loop?** If the end point feeds back, through logic, to the
  start point — an accumulator, an iteration, a state register — no amount of
  retiming will shorten it (OPTIMIZATION.md §1.4). You need an RTL change.

### 1.3 Count the cycles

Cycles per item, from your simulation, and **where they go**: setup, compute,
waiting for OBI responses, writing results back. An FSM that spends three
cycles per item waiting for a memory response is not helped by a faster adder.

### 1.4 Know the ceiling

The OBI port moves at most **one 32-bit word per cycle**. Count the words your
accelerator reads and writes per item: that is the fewest cycles per item any
datapath can reach behind this port. If your baseline is already close, more
datapath speed is wasted — and the honest objective is area or energy, with
the datapath **folded** down to the speed the port can feed.

Fill in REPORT.md §2 before you go on.

---

## 2. Keeping track of your explorations

You are about to run the flow many times, on many versions of the design. An
**exploration** is one change, measured with the flow (rule 2 below), against
the version it started from — its **parent**. Each one lives on its own
branch and ends with its own tag, `expNN`, which REPORT.md names.

### 2.1 Four rules

1. **One change per exploration.** A run that adds retiming *and* changes the
   multiplier tells you nothing about either.
2. **The flow, at a stated period.** Each exploration at the clock period you
   choose for it. One you keep in the final design goes through the whole
   flow: synthesis, place and route, post-layout power. One you leave out may
   stop after synthesis and `make power-sim`, unless it changes place and
   route, and REPORT.md says so; if you decide to keep it later, run the rest
   then. When the period differs from the parent's, say how much of the
   difference is the clock: cycles per item do not depend on it, area and
   power do.
3. **The tag alone reproduces it.** Everything that decides a number has to
   be in the commit: the RTL, the scripts, **and the make variables**. A
   `PNR_UTIL=0.70` typed on the command line is lost; set the default in the
   `Makefile` (`PNR_UTIL ?= 0.70`, `CLK_PERIOD ?= 4.0`) and commit it. A
   switch of your own for `dc_script.tcl` needs `export` in front
   (`export RETIME ?= 1`): without it the default never reaches dc_shell, and
   nothing tells you (SETUP.md §4).
4. **Keep every result.** Every run overwrites `reports/`.

### 2.2 Snapshots

For the fourth rule, a snapshot after each run. A shell function does it:

```bash
# snap <name>: copy the reports of the last runs to runs/<name>/
snap() {
  local d=runs/$1; mkdir -p $d
  cp -r implementation/design_compiler/reports $d/synth
  cp implementation/design_compiler/scripts/dc_script.tcl $d/
  [ -d implementation/innovus/artefacts/reports ] && cp -r implementation/innovus/artefacts/reports $d/pnr
  [ -d implementation/power_analysis/reports ] && cp -r implementation/power_analysis/reports $d/power
  git rev-parse --short HEAD > $d/commit
  git diff --stat > $d/uncommitted
}

make synth && make pnr-all && make power-postlayout
snap exp03          # on its own line: it runs even if power-postlayout failed (§5.1)
grep -E "Critical Path Slack|Cell Area|Sequential Cell Count" runs/exp03/synth/qor.rpt
```

`runs/` is gitignored: the reports stay on the server, the numbers go in
REPORT.md. Name each snapshot after its tag. Remove the PnR and power reports
from the copy if they belong to an older netlist — a snapshot that mixes runs
is worse than none.

### 2.3 One branch and one tag per exploration

The explorations form a tree. Each starts from its parent — `lab2-baseline` or
an earlier exploration — and none has to start from the last one:

```
lab2-baseline ── exp01 ── exp03            exp01  pipeline, 2 stages at the output
     │             └───── exp04            exp02  set_optimize_registers on the baseline
     └── exp02                             exp03  exp01 + unfolding by 2
                                           exp04  exp01 + PNR_UTIL 0.70
```

A new exploration, here `exp04` with parent `exp01`:

```bash
git switch -c exp04-util70 exp01      # a new branch, starting at the parent's tag
# ... make the change, run the flow (rule 2), snap exp04 ...
git add rtl tb model data accel.core Makefile \
        implementation/design_compiler/scripts implementation/innovus/scripts
git commit -m "exp04: PNR_UTIL 0.70 (parent exp01)"
git tag exp04
git push -u origin exp04-util70       # the branch: a backup
git push origin exp04                 # the tag: required, REPORT.md names it
```

Give the branch a different name from the tag (`exp04-util70`, not `exp04`):
with both called `exp04`, git cannot tell which one you mean.

A few things that make this easier:

- **Write REPORT.md and commit `figures/` on `main`**, not on the
  exploration branches. The branches then carry only the design, and
  combining them later (§2.4) never conflicts on the report.
- **Where am I, and what is there:**

  ```bash
  git log --oneline --graph --decorate --all   # the whole tree, with the tags
  git diff exp01 exp04 --stat                  # what exp04 changed against its parent
  git diff exp01 exp04 -- rtl                  # ... in the RTL only
  ```

- **Switching branch does not switch the results.** `build/`, the netlist and
  the reports belong to the last run, whatever you checked out since. After a
  `git switch`, run the flow again before you read a report, or read the
  snapshot in `runs/`.
- **A tag is a promise** that the numbers in REPORT.md come from that commit.
  Found a bug in `exp04` after tagging it? Fix it on its branch and tag the
  fix as a new exploration (`exp07`, parent `exp04`), rather than moving
  `exp04`.

### 2.4 Combining explorations into the final design

The final design is built on `main`, which still points at `lab2-baseline`.
Bring in what you decided to keep:

```bash
git switch main
git merge --no-ff exp03-unfold2 -m "final: take exp03"   # exp03 and its ancestors, exp01 included
git cherry-pick exp04                                     # only exp04's own commit, not exp01
# an exploration made of several commits: all of them, from its parent's tag to its own
#   git cherry-pick <parent>..<expNN>
```

`merge` brings an exploration with everything it was built on; `cherry-pick`
brings only the change itself, onto whatever `main` already has. If two
explorations changed the same lines, git stops and asks you to resolve the
conflict by hand.

Then run the whole flow on `main`. The combination is a new design: its
numbers are not the sum of its parts, and they are the ones REPORT.md §4
reports. Commit, and that commit is the one you release as `lab2-delivery`.

---

## 3. Pipelining by retiming

The most effective pipelining you can do in this lab takes about ten lines of
RTL and no thinking about where the cuts go:

1. **put all the extra registers at the output** of the combinational block —
   or all at its input;
2. **let retiming move them** into the logic (OPTIMIZATION.md §1).

The RTL is trivially correct: it is your Lab 1 function, delayed by a few
cycles. Retiming preserves that by construction, so the tool cannot cut in
the wrong place, forget to delay a side signal, or split a carry chain wrongly
— it never cuts anything you did not give it a register for. What it did on
a test design is in OPTIMIZATION.md §1.3.

### 3.1 The RTL

Your Lab 1 datapath stays as it is. After it:

```systemverilog
// res_d = f(operands): the Lab 1 combinational datapath, unchanged
localparam int unsigned NStages = 3;

logic [W-1:0]       res_q [NStages];
logic [NStages-1:0] vld_q;

// Data: no reset, so retiming can move these anywhere in f()
always_ff @(posedge clk_i) begin
  res_q[0] <= res_d;
  for (int i = 1; i < NStages; i++) res_q[i] <= res_q[i-1];
end

// Valid: does need a reset -- it says whether res_q means anything
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) vld_q <= '0;
  else begin
    vld_q[0] <= in_valid;
    for (int i = 1; i < NStages; i++) vld_q[i] <= vld_q[i-1];
  end
end
// consume res_q[NStages-1] when vld_q[NStages-1]
```

`NStages` as a parameter lets you sweep it. Put the stages in the **same
module** as the logic they should cut — retiming does not move registers
across a boundary it is not allowed into.

**If your objective is energy per item, look at this first.** The data
registers above have no enable: they load on every cycle, `valid` or not, and
switch whenever `res_d` does. An enable from the valid chain
(`if (in_valid) res_q[0] <= res_d;`, and `vld_q[i-1]` for stage `i`) lets
`compile_ultra -gate_clock` put a clock gate in front of them and stop them
when there is nothing to carry — at the price of less freedom for retiming.
Which one wins is a measurement, and an exploration of its own.

### 3.2 The control has to keep the pipeline full

A pipeline only buys throughput if a new item enters **every cycle**. If your
FSM issues an item, waits for its result, and only then issues the next, three
stages make each item three cycles *slower*. Look at your FSM before you add a
stage:

- issue the next item while the previous ones are still in flight; the
  `valid` chain tells you when each result comes out;
- keep the OBI reads running ahead of the datapath, and the writes behind it;
- keep the clock gate open until the last `valid` has drained.

An iterative datapath — one that feeds its own output back for the next
iteration — is a loop, and stages added to a loop do not help. The cure there
is unfolding (§4.2) first, then pipelining.

### 3.3 Find the right number of stages

Sweep `NStages` (1, 2, 3, ...; the parent is the point with none) at
synthesis and record, for each, the f_max and the area. Each stage adds a
row of flip-flops and a cycle of latency; at some point the critical path
stops being in the logic — it moves to the OBI handshake, the FSM, or a
loop — and further stages only add area. Take the number at that knee
through the whole flow: that is the exploration, and the sweep is the
argument for it, in its text in REPORT.md §3.

### 3.4 Gate level

Data registers without a reset start at `X` in a gate-level simulation. That
is fine as long as nothing *decides* anything on them before `valid` says so.
If `make power-sim` fails where `make sim` passes, look for a data register
that feeds the FSM or a comparator directly: gate that decision with the valid
bit, or give that one register a reset.

### 3.5 By hand, to compare

Placing the cuts yourself is optional and worth doing once: same number of
stages, registers where *you* think the path should split, retiming off. Then
compare with the tool. You will either learn that the tool is better at it
than you, or find a cut it could not see — a stage boundary that also lets
you share an operator, say. Either way it is an exploration of its own, with
the retimed version as its parent.

---

## 4. Explorations: the menu

§4.1–§4.6 are **architectural**: they change the logic itself. §4.7–§4.8 are
**tool** explorations: same RTL, a different way of building it. You need at
least one of each. Pick from the diagnosis, not from the list.

### 4.1 Pipelining by hand

§3.5. The registers go where you decide; useful when a stage boundary is also
a natural point to store something (a partial sum, a decoded operand), or when
retiming is blocked by a hierarchy boundary or a reset you cannot remove.

### 4.2 Unfolding

An iterative datapath does one step of the algorithm per cycle and feeds the
result back. Unfolding by a factor *k* does *k* steps per cycle: *k* copies of
the step logic, chained, inside the same loop.

```systemverilog
// folded: one CORDIC micro-rotation per cycle, N cycles per item
always_ff @(posedge clk_i) {x_q, y_q, z_q} <= rot(x_q, y_q, z_q, iter_q);

// unfolded by 2: two micro-rotations per cycle, N/2 cycles per item
assign {x_m, y_m, z_m} = rot(x_q, y_q, z_q, iter_q);
always_ff @(posedge clk_i) {x_q, y_q, z_q} <= rot(x_m, y_m, z_m, iter_q + 1);
```

Half the cycles, a longer path per cycle, twice the step logic. Unfolded all
the way, the loop disappears: the datapath becomes a straight chain of *N*
steps — and a straight chain can be pipelined by retiming (§3), up to one item
per cycle. The CORDIC of
[ISA-LAB1-EXAMPLE](https://github.com/Integrated-Systems-Architecture/ISA-LAB1-EXAMPLE)
is folded; its critical loop is in OPTIMIZATION.md §1.4.

### 4.3 Folding

The other direction: one operator time-shared by several operations, with a
mux in front and a few more cycles per item. It is the right move when the
objective is area or energy, or when §1.4 says the OBI port cannot feed the
datapath you have anyway. Parhi, Wang and Brown (1992, Lab 1 reading list) is
the systematic version.

### 4.4 Arithmetic

Where the tool cannot see the opportunity, you can:

- **Constant multiplication.** If a coefficient is known at elaboration time
  — a `localparam`, not a CSR — Design Compiler already turns the
  multiplication into shifts and adds. If it comes from a CSR, it cannot. Fixed
  coefficients are an architecture decision (flexibility against area), and a
  canonic signed digit form makes the trade-off visible:
  `x * 45 = (x << 6) - (x << 4) - (x << 2) + x`.
- **Carry-save accumulation.** An accumulator is a loop with an adder in it.
  Keep the running sum as two vectors (sum and carry), add each new term with
  a row of full adders, and resolve the carry once, after the last term. The
  carry chain leaves the loop.
- **Strength reduction.** Division or modulo by a constant as a multiplication
  and a shift (Barrett, Montgomery — the `pqcrypto` papers in the Lab 1
  reading list); a multiplication by a power of two as a shift.
- **Word length.** Every bit you carry costs area in every stage. Range
  analysis on your golden model tells you how many bits each signal needs;
  trim to that, and change the model first if the result changes.
- **Resource sharing.** Two operations that never happen in the same cycle
  can use one operator behind a mux.

To change how a multiplier is built, ask the tool first (OPTIMIZATION.md
§2.4) — and then, if you want to know whether you can beat it, build your own
(§4.6).

### 4.5 The data path around the datapath

Cycles per item are not only compute. Overlapping the OBI reads of the next
item with the compute of this one, keeping more than one request in flight,
writing results while reading operands — these change cycles per item without
touching the arithmetic, and §1.3 tells you whether they are worth it.

### 4.6 Exploration: your own multiplier, as a Wallace or Dadda tree

If your kernel multiplies, one of the possible explorations is to build the
multiplier yourself and race it against DesignWare. It counts as an
architectural exploration.

A parallel multiplier has three parts:

1. **Partial products.** For unsigned *N* × *N*, `a[j] & b[i]` lands in
   column `i + j`: an *N* × *N* parallelogram of bits.
2. **Reduction tree.** Full adders (three bits of a column in, a sum in the
   same column and a carry in the next one out) and half adders (two in), in
   layers, until every column has at most two bits. No carry propagates
   inside the tree: each layer costs one full-adder delay, whatever the width.
3. **Final adder.** The two remaining rows, added with one carry-propagate
   adder. Write it as `+`: Design Compiler then picks the adder
   architecture for it (§2.3 of OPTIMIZATION.md), and you compare trees, not
   final adders.

The two classic trees differ only in *when* they reduce:

- **Wallace** (1964, Lab 1 reading list) reduces as much as it can in every
  layer: every group of three bits becomes a full adder, every leftover pair a
  half adder.
- **Dadda** (L. Dadda, *Some schemes for parallel multipliers*, Alta
  Frequenza, 1965 — Politecnico di Milano) reduces as little as it can: the
  column heights after each layer follow the sequence 2, 3, 4, 6, 9, 13, 19,
  ... (each the previous × 3/2, rounded down), read backwards, and a layer only
  adds the adders needed to bring every column down to the next height. Same
  number of layers, far fewer half adders.

For 16 × 16 that is 195 full and 15 half adders for Dadda (the textbook
counts: *N*² − 4*N* + 3 and *N* − 1), against 196 and 78 for Wallace: a
first check for your generator.

How to go about it:

- **Generate it, do not type it.** Several hundred adders are a job for a
  script (Python writing SystemVerilog) or for SystemVerilog `generate` loops.
  The algorithm is a loop over columns per layer; the code is short, the
  bookkeeping of who-goes-where is the whole difficulty.
- **Check it before you synthesise it.** Against `a * b` in a small testbench:
  exhaustive at 8 bits (65 536 cases), random plus the corners (`0`, all ones)
  at 16. A tree with one carry in the wrong column passes most random vectors.
- **Signed operands** — your kernels are int8 and int16 — need the
  Baugh–Wooley form of the partial products (C. R. Baugh, B. A. Wooley,
  *A Two's Complement Parallel Array Multiplication Algorithm*, IEEE Trans.
  Computers, 1973): a few partial products inverted and two constant ones
  added, and the tree is unchanged.
- **Compare like with like.** Your tree against `a * b` with the tool's choice
  *and* with the `-mult_arch` options (OPTIMIZATION.md §2.4), at a relaxed
  period and pushed for speed, same corner. Then in your accelerator: that is
  the exploration, reported like any other.
- **Keep it in its own module**, so `area.rpt -hierarchy` shows its area
  separately.

Where it gets interesting — and where the tool cannot follow you:

- **Fuse the multiply with what comes after.** A multiply-accumulate does not
  need the product resolved: feed the accumulator into the tree as one more
  row, or keep the accumulator in carry-save form (§4.4), and the
  carry-propagate adder leaves the loop.
- **Booth recoding** (radix 4: half the partial products, plus the encoders),
  or **4:2 compressors** instead of full adders.
- **Pipelining the tree** by retiming (§3): registers at its output, and the
  tool cuts between layers.

### 4.7 Tool: the synthesis script

Same RTL, built differently. Every command goes in your copy of
`implementation/design_compiler/scripts/dc_script.tcl`, and is committed with
the exploration's tag.

- **Retiming** the design as it is: `compile_ultra -retime`, or
  `set_optimize_registers` (OPTIMIZATION.md §1). With no register added in the
  RTL this is a tool exploration; with registers added for the tool to spread,
  it is pipelining (§3), an architectural one.
- **Operator architectures**: find what Design Compiler built
  (`report_resources`, OPTIMIZATION.md §2.2), then ask for something else —
  `set_dp_smartgen_options`, `set_dont_use` (§2.4, §2.5). Read §2.6 first:
  some requests are ignored without an error, and a run that ignored yours
  looks exactly like one that applied it.
- **Anything else** in `man compile_ultra`, if you can explain what it did.

"The tool already picked the best one" is a valid result, if the numbers show
it.

### 4.8 Tool: place and route

Same netlist, laid out differently. The knobs the flow already has:

| knob | where | what it changes |
|---|---|---|
| `PNR_UTIL` (0.60) | `Makefile`, read by `scripts/globals.tcl` | target utilisation, so the core size: lower leaves room for buffers and wires, higher saves area and risks congestion |
| `PNR_ASPECT` (1.00) | `Makefile`, read by `scripts/globals.tcl` | the core's height over width |
| `design(cts_target_skew)` (0.10 ns) | `scripts/globals.tcl` | how hard the clock tree works to deliver the same edge everywhere: tighter means more buffers and more clock power |
| `design(cts_target_max_trans)` (0.40 ns) | `scripts/globals.tcl` | the clock slew; the comment above it says why 0.40 is close to the floor in this library |
| `design(cts_buffers)`, `design(cts_inverters)` | `scripts/globals.tcl` | which cells the clock tree may use |
| `place_global_clock_gate_aware` | `scripts/place.tcl` | whether the placer keeps the flops behind one clock gate together |

What each stage does and why is in
[implementation/innovus/README.md](implementation/innovus/README.md): §2 for
the floorplan, §4 for placement, §5 for the clock tree. For anything else —
placement and optimisation effort, useful skew, other `set_db` attributes —
the reference is Cadence's documentation and `man <command>` inside Innovus.

Where to see the effect: core size and density, `04_place.congestion.rpt`,
`05_cts.clock_trees.rpt`, the insertion delay in `05_cts.log`, and the
`clock_network` group of the post-layout power report.

---

## 5. Compare fairly

- **The same corner**: timing at `slow_1p08V_125C`, power at `typ_1p20V_25C`,
  for both designs.
- **Against the parent.** Each exploration is compared with the version it
  started from, not with the baseline, so each row says what that one change
  did.
- **Each at its own clock, and say what the clock did.** A design at a shorter
  period is bigger and draws more power for reasons that have nothing to do
  with the change. For the final design, the synthesis at the **baseline's**
  period separates "a better design" from "a faster clock" (REPORT.md §4.2).
- **Post-layout for what you keep.** Synthesis is a good place to look for
  the right setting (a sweep of pipeline stages, of multiplier
  architectures), and enough for an exploration you leave out (§2.1); what
  you keep, and the final design, go through place and route and post-layout
  power.
- **Energy per item, not power.** A design that draws twice the power and
  finishes in a third of the cycles is the better one.

### 5.1 Post-layout power at a short clock

Expect this one. Push the period down far enough and `make power-postlayout`
fails — `[TB] N read back as ...`, or `timeout waiting for STATUS.DONE` — while
`make sim`, `make questa` and `make power` all pass. Your netlist is very
probably fine; the testbench is not fast enough for it.

The Lab 1 testbench applies every input a fraction of the period after the
ideal clock edge (`ApplDelay`, 20 % in
[ISA-LAB1-EXAMPLE](https://github.com/Integrated-Systems-Architecture/ISA-LAB1-EXAMPLE)).
After place and route
the flops see that edge later, by the clock tree's insertion delay, and it
grows with the tree, not with the period:

```bash
grep "insertion delay" implementation/innovus/artefacts/reports/05_cts.log | tail -1
#   skew_group MY_CLK/func_mode: insertion delay [min=0.481, max=1.100, avg=0.830, ...
```

That is the CORDIC of ISA-LAB1-EXAMPLE at 4 ns: 20 % of 4 ns is 0.8 ns, the
latest flop sees the edge at 1.1 ns, and it captures the testbench's *next*
value — a hold violation that exists only in the testbench. The OBI response
path, which goes through the testbench's memory model and back within the
same cycle, runs out of time in the same way. Both the baseline and the
retimed netlist failed like this at 4 ns; both passed at 10 ns.

What to do:

1. **Prove the netlist is right** at a relaxed simulation clock — the same
   netlist, the same SDF, a longer period:

   ```bash
   make power-postlayout PWR_CLK_PS=10000
   ```

   `TEST PASSED` there means the routed netlist computes the right results.
   Start at 10 000 ps, where ISA-LAB1-EXAMPLE passes, and go down while it
   still passes if you want a closer point.
2. **Report the power at that clock, and say so.** Dynamic energy per item is
   set by what switches per item, not by how fast, so it carries over to the
   real clock almost unchanged; leakage per item is overestimated at the slower
   clock (more time per item). Report energy per item with the simulation
   clock next to it; the post-synthesis power at the real period (`make
   power`, which has no clock tree and passes) is a useful second number in
   the text.
3. **Compare energy per item, not power,** when an exploration and its parent
   were simulated at different clocks, and say so.

---

## 6. When a Lab 2 run goes wrong

| symptom | look at |
|---|---|
| `TEST FAILED` after adding stages | a latency hard-coded in the testbench, or the FSM reading a result before its `valid` |
| `make sim` passes, `make power-sim` fails | a reset-less data register feeding a decision (§3.4) |
| `make power` passes, `make power-postlayout` fails at a short period | the testbench, not the netlist: clock insertion delay against `ApplDelay` (§5.1) — rerun with `PWR_CLK_PS=10000` |
| more stages, no faster | the critical path is a loop, or has moved to the FSM / OBI handshake — `timing.rpt` again |
| `compile_ultra -retime` explodes the flip-flop count | try `set_optimize_registers` (OPTIMIZATION.md §1.3) |
| retiming did nothing | `-print_critical_loop`; reset values on the registers; registers in another module |
| `set_implementation` had no effect | `compile_ultra` ignores it — OPTIMIZATION.md §2.6 |
| `Error: Can't find object 'dw_foundation.sldb/...' (UID-109)` | that implementation does not exist in this release; the whole `set_dont_use` was dropped |
| `Error: Invalid datapath smart generation option ... (UISN-81)` | a value `set_dp_smartgen_options` does not accept — `help -verbose set_dp_smartgen_options` |
| your environment switch is always set, to something odd | you named it `ARCH`: the Synopsys launch script sets that one. Pick another name |

For everything that is not Lab 2 specific, Lab 1's lists still apply: the
TUTORIAL §8 table, and
[the example's "When it breaks"](https://github.com/Integrated-Systems-Architecture/ISA-LAB1-EXAMPLE/blob/main/README.md#when-it-breaks).

---

## 7. Cheat sheet

```bash
# once per shell
source /oss-tools/init.sh
source /eda/scripts/init_design_vision
source /eda/scripts/init_cadence_2020-21
source /eda/scripts/init_questa_core_prime

# every exploration -- §2.3
git switch -c expNN-<what> <parent tag>      # branch from the parent
make sim && make questa                      # still TEST PASSED, twice
make synth                                   # CLK_PERIOD, PNR_UTIL, ... as Makefile defaults
make power-sim                               # the netlist still passes
make pnr-all && make power-postlayout        # if you keep it, or it changes PnR: §2.1
make power-postlayout PWR_CLK_PS=10000       # if it fails at a short period: §5.1
snap expNN                                   # §2.2
git commit ... && git tag expNN && git push origin expNN

# the final design -- §2.4
git switch main && git merge --no-ff <branch>   # or: git cherry-pick <tag>
# the whole flow again, then REPORT.md §4
```

```tcl
# Design Compiler, before compile_ultra -- OPTIMIZATION.md
compile_ultra -gate_clock -retime                          ;# adaptive retiming
set_optimize_registers true -designs [current_design]      ;# register retiming
set_optimize_registers true -designs [current_design] -print_critical_loop
set_dont_retime [get_cells <reg_top instance>] true        ;# keep the CSRs where they are
set_dp_smartgen_options -mult_arch and                     ;# multiplier architecture
set_dp_smartgen_options -optimize_for area                 ;# generator goal
set_dont_use dw_foundation.sldb/DW01_add/pparch            ;# forbid an implementation
set_implementation DW01_add/rpl <cell>                     ;# plain compile only
```

```tcl
# after the compile
report_resources -hierarchy                                ;# what it built
report_timing -nosplit                                     ;# where the path is now
report_qor                                                 ;# slack, area, flip-flops
```
