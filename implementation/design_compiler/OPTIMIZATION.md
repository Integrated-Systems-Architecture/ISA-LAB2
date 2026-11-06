# Optimising with Design Compiler: retiming and operator architectures

Lab 1's [README.md](README.md) took you through synthesis one command at a
time. This guide adds the commands Lab 2 needs, as **snippets**: what each one
does, where it goes, what it prints, and what it did on a real run. It is not a
script. Deciding which snippets go into your
[`scripts/dc_script.tcl`](scripts/dc_script.tcl), in what combination, behind
what switch, is part of the lab — and you will be asked to explain every line
you added.

Everything below was run on the ISA server: Design Compiler 2021.06-SP4, IHP
SG13G2, slow corner `slow_1p08V_125C`. The numbers come from a small test
design, so yours will be different; what carries over is the *direction* and
the *traps*.

---

## 0. Where the snippets go

Every command in this guide is an instruction **to the next compile**, so it
goes after the design is linked and constrained and before `compile_ultra`.
In `dc_script.tcl` that is here:

```tcl
source ${SCRIPT_DIR}/set_constraints.tcl
report_clocks > ${REPORT_DIR}/clocks.rpt

# <-- retiming and operator-architecture commands go here

compile_ultra -gate_clock
```

Try every new command by hand first, in `dc_shell` started from
`implementation/design_compiler/` (README §1): run the script up to the line
above, type the command, and read what it answers. A command that is silently
ignored — §2.6 has one — looks exactly like a command that worked, until you
read the report.

### The test design

A 16 × 16 multiply-add with registered inputs and `S` register stages, all
bunched at the output:

```systemverilog
assign p = a_q * b_q + c_q;                  // the whole datapath, one cycle

always_ff @(posedge clk_i) begin             // S stages, all after the logic
  pipe_q[0] <= p;
  for (int i = 1; i < S; i++) pipe_q[i] <= pipe_q[i-1];
end
assign y_o = pipe_q[S-1];
```

With `S = 1` it is an ordinary registered multiply-add: **9.73 ns** of logic,
19 901 µm², 96 flip-flops. It closes at 10 ns and nothing faster.

---

## 1. Retiming

### 1.1 What it does

Retiming moves registers **across combinational logic** — backwards through
it or forwards through it — without changing what the circuit does at its
ports: the same outputs, on the same cycle, for the same inputs (Leiserson and
Saxe, 1981, in the Lab 1 reading list). It can change how many registers
there are, and where they sit. It cannot change the latency, and it cannot add
a register to a loop.

That is exactly what you need to turn "S registers after the logic" into "a
pipeline of S stages": the RTL says *how many* cycles, the tool decides
*where* the cuts go.

### 1.2 Two ways to ask for it

**Adaptive retiming, inside the compile.** A flag on `compile_ultra`. It moves
registers locally, around the critical paths it is already working on:

```tcl
compile_ultra -gate_clock -retime
```

**Register retiming of a whole design.** An attribute set before the compile.
`compile_ultra` then retimes the designs that carry it, globally: first for the
minimum period, then for the minimum number of registers at that period.

```tcl
set_optimize_registers true -designs [current_design]
compile_ultra -gate_clock
```

`-designs` takes any list of designs, so you can retime only your datapath
sub-module: `-designs [get_designs my_datapath*]` (the `*` because elaborated
designs carry their parameters in the name). Two more options worth knowing:

```tcl
# print the loop that limits the period retiming can reach -- see 1.4
set_optimize_registers true -designs [current_design] -print_critical_loop
# and a standalone command, if you want retiming after an ordinary compile:
#   compile_ultra -gate_clock ; optimize_registers
```

Both print, in `synth.log`:

```
Information: Retiming is enabled. SVF file must be used for formal verification. (OPT-1210)
```

and `set_optimize_registers` also tells you what it did, design by design:

```
  Retiming mac_pipe_S3_RESET_PIPE0 (top)
  Retiming base-clock clk, rising edge.
  Beginning minimum period retiming ...
  ... minimum period retiming done.
  Beginning minimum area retiming step 1 ...
```

### 1.3 Pipelining by retiming

The test design with **`S = 3`** — two extra stages, still bunched at the
output — at **4.0 ns**:

| run | slack (ns) | area (µm²) | flip-flops |
|---|---|---|---|
| no retiming | **−1.07** | 28 734 | 160 |
| `compile_ultra -retime` | 0.00 | 30 126 | 295 |
| `set_optimize_registers` + `compile_ultra` | 0.00 | **22 531** | 189 |

Without retiming the two extra stages are useless: they sit after the logic
and the 9.7 ns path is still in one piece, so the tool upsizes everything and
still misses by a nanosecond. With retiming, both runs close — and the
whole-design retiming does it with **13 % more area than the 10 ns `S = 1`
version, for 2.5 × the clock**. The adaptive one closes too, but spends a
third more area and half again as many flip-flops to get there. That is the
general picture: `-retime` is cheap to try, `set_optimize_registers` usually
finds the better answer. Try both on your design.

That is pipelining by retiming: the extra registers all at the output of the
block in the RTL, and the tool decides where the cuts go. Why it is the safe
way to pipeline, the RTL, and the comparison by hand are in TUTORIAL.md §3.

### 1.4 What retiming cannot do

**Add registers to a loop.** In a feedback loop — an accumulator, a state
machine, an iterative datapath that feeds its own output back — retiming can
slide the registers around the loop but the number in it is fixed. The loop's
delay divided by its register count is a period no retiming will beat.
`-print_critical_loop` prints it:

```tcl
set_optimize_registers true -designs [current_design] -print_critical_loop
```

The CORDIC of
[ISA-LAB1-EXAMPLE](https://github.com/Integrated-Systems-Architecture/ISA-LAB1-EXAMPLE)
is exactly this case. Its rotator is iterative:
one micro-rotation per cycle, the result fed back into the same adders. At
4.0 ns:

| run | slack (ns) | area (µm²) | flip-flops |
|---|---|---|---|
| baseline | −0.45 | 47 621 | 469 |
| `set_optimize_registers` | −0.38 | 49 001 | 503 |

Retiming bought 70 ps for 3 % more area, and `synth.log` says why:

```
Critical Loop(s) for Minimum Period Retiming
---- loop limited by node bound(s) ----
```

followed by the chain of cells around the iteration loop. No placement of the
existing registers makes that loop shorter. (The retimed netlist still passed
the testbench at gate level — retiming is safe even when it is useless.)

If that loop is your critical path, the answer is in the RTL, not in the tool:
unfold the loop, or shorten what is inside it — TUTORIAL.md §4.

**Move reset registers as freely.** The same `S = 3` test, with an
asynchronous reset on the pipeline registers:

| run | area, no reset (µm²) | area, async reset (µm²) |
|---|---|---|
| `compile_ultra -retime` | 30 126 | 34 603 |
| `set_optimize_registers` | 22 531 | 23 704 |

A register with a reset value can only move where the tool can compute the
reset value of its new position; that constrains it and costs registers.
Datapath pipeline registers do not need a reset — the `valid` bit that travels
with them does, and that one is enough to say whether their content means
anything.

**Cross a hierarchy boundary it is not allowed into.** Registers move inside
the designs you retime. A pipeline register in one module and the logic it
should cut into in another stay apart unless `compile_ultra` happens to
ungroup the boundary. Put the stages in the same module as the logic.

**Leave alone what you need left alone.** The CSR block and the OBI
handshake registers are part of your interface; there is no reason for them to
move. Exclude them, or retime only the datapath design:

```tcl
# i_regs is the reggen block's instance name in ISA-LAB1-EXAMPLE; use yours.
# set_dont_retime takes registers, the hierarchical cells around them, or designs.
set_dont_retime [get_cells i_regs] true
set_optimize_registers true -designs [current_design]
```

On the CORDIC, without that line, all but 5 of the CSR block's registers came
out of the compile renamed `MY_CLK_r_REG*` — moved, merged or split; with it,
119 kept their RTL names, and the tool retimed 360 registers instead of 475.

### 1.5 Reading the result

- `qor.rpt`: slack, area, and the flip-flop count (*Sequential Cell Count*) —
  retiming changes it, in either direction.
- `timing.rpt`: retimed registers have new names, `<clock>_r_REG<n>_S<k>` —
  with the lab's constraints, `MY_CLK_r_REG19_S5`. A critical path that starts
  or ends at one of them goes through a register the tool placed.
- `synth.log`: the `Retiming ...` lines above, and the critical loop if you
  asked for it. One warning is expected and harmless — the clock gates
  `-gate_clock` inserted are buffers on the clock, and Innovus builds the real
  clock tree anyway:

  ```
  Warning: There are buffer or inverter cells in the
  	clock tree. The clock tree has to be recreated after
  	retiming. (RTDC-47)
  ```

### 1.6 Check it

Retiming changes the netlist's state encoding, and it is the one optimization
in this guide that a formal check would need the SVF file for. You check it
with your testbench instead: simulate the **gate-level** netlist.

```bash
make synth CLK_PERIOD=...
make power-sim            # your testbench on the synthesised netlist
```

---

## 2. Operator architectures

### 2.1 What the tool does with `+` and `*`

Design Compiler does not build what the RTL literally says. Every `+`, `-`,
`*`, comparison or shift it recognises becomes a *synthetic operator* from
the DesignWare library (`dw_foundation.sldb`, set up in `dc_script.tcl` as
`synthetic_library`), and the tool picks an **implementation** of it that
meets the constraint: a ripple adder when there is time, a parallel-prefix one
when there is not.

Under `compile_ultra` it goes further: a chain of operators is **merged into
one datapath block** and built as a single carry-save tree with one final
adder. `a * b + c` is not a multiplier followed by an adder — it is one block,
`DP_OP_...`, whose partial products and `c` are summed together.

### 2.2 What it built: `report_resources`

`dc_script.tcl` already writes it, to `reports/resources.rpt`. For the test
design, the merged block:

```
| DP_OP_3J1_122_362    | mult_26 (mac_pipe.sv:26) add_26 (mac_pipe.sv:26)    |
...
| Cell               | Module           | Current            | Set            |
| DP_OP_3J1_122_362  | DP_OP_3J1_122_362 | str (area,speed)  |                |
|                    |                  | mult_arch: benc_radix4              |
```

`str` is the datapath generator, `benc_radix4` a radix-4 Booth-encoded
multiplier — the tool's own choice. For a lone 32-bit adder:

```
| add_x_1            | DW01_add         | pparch (area,speed)                 |
```

The **Set** column shows what you asked for. If you asked and it is empty,
your request did not reach the compile (§2.6).

### 2.3 The implementations this release has

`report_synlib dw_foundation.sldb > synlib.rpt` lists them all. The short
version, for the operators you are likely to have:

| operator | implementations |
|---|---|
| `DW01_add`, `DW01_sub`, `DW01_addsub`, `DW01_inc`, `DW01_cmp2` | `pparch` (delay-optimised parallel prefix), `apparch` (area-optimised), and `rpl` (ripple, from the built-in standard library) |
| `DW02_mult`, `DW02_mac`, `DW02_prod_sum1` | `pparch`, `apparch` — the architecture is chosen with `set_dp_smartgen_options` (§2.4) |

Older names you will find in papers and forum posts — `cla`, `clf`, `bk`,
`csm`, `wall`, `nbw` — are listed as `replaced with pparch`: asking for them
gets you `pparch`, or an error (§2.5).

### 2.4 Knob 1: `set_dp_smartgen_options`

The one that works with `compile_ultra`, on merged datapath blocks as well as
on single operators. It steers the generator rather than naming an
implementation:

```tcl
# multiplier architecture:
#   auto and nand and_radix4 nand_radix4 benc_radix4 benc_radix8
#   benc_radix4_mux benc_radix8_mux
set_dp_smartgen_options -mult_arch and

# Booth encoding on or off, adder families, what to optimise for
set_dp_smartgen_options -booth_encoding false
set_dp_smartgen_options -sklansky_adder true     ;# or -brent_kung_adder, -ling_adder, ...
set_dp_smartgen_options -optimize_for area       ;# default area speed area,speed

# all of them back to the tool's choice
set_dp_smartgen_options -all_options auto
```

With no object list it applies to the whole design; give it cells or designs
(and `-hierarchy`) to aim it at one block. `help -verbose
set_dp_smartgen_options` in dc_shell lists every option.

What it did:

| design, period | setting | reported | path (ns) | area (µm²) |
|---|---|---|---|---|
| multiply-add, 10 ns | default | `mult_arch: benc_radix4` | 9.73 | 19 901 |
| multiply-add, 10 ns | `-mult_arch and` | `mult_arch: and` | 9.48 | 19 300 |
| 32-bit adder, 3 ns | default | `pparch (area,speed)` | 2.73 | 6 793 |
| 32-bit adder, 3 ns | `-optimize_for area` | `apparch (area)` | 2.78 | 7 256 |

Two lessons. The non-Booth multiplier was *both* smaller and faster here: at
16 bits, Booth's fewer partial products do not pay for the encoders. And
"optimise for area" produced **more** area than the default: the area-oriented
adder needed more upsizing to meet the same clock. Neither result generalises —
which is the point. The option's name is a request, the report is the answer.

### 2.5 Knob 2: `set_dont_use` on an implementation

Forbid an implementation and the tool must pick another. Works with
`compile_ultra`:

```tcl
set_dont_use dw_foundation.sldb/DW01_add/pparch
```

On the lone adder at 1.2 ns this turned `pparch` into `apparch`. A name the
library does not have is an error, and the **whole command** is discarded, not
just the bad name:

```
Error: Can't find object 'dw_foundation.sldb/DW01_add/cla'. (UID-109)
```

### 2.6 Knob 3: `set_implementation` — plain `compile` only

Names one implementation for one operator cell. The operator cells exist
after `elaborate`, named after the operator and the source line, sometimes
with a suffix: `add_26` and `mult_26` in the multiply-add, `add_3_S4` in the
lone 32-bit adder below. List them with `get_object_name [get_cells *]`, or
`-hierarchical`. The implementation needs its module:

```tcl
set_implementation DW01_add/rpl add_3_S4
# without the module:
#   Error: Module name is required to set implementation on operator 'add_26'. (UID-463)
```

**`compile_ultra` ignores it — silently.** It re-extracts the datapath, the
cell you named is dissolved and rebuilt under a new name (`add_3_S4` became
`add_x_1`), and the *Set* column of `report_resources` stays empty. With plain
`compile` it is honoured:

| 32-bit adder, 1.2 ns | compile | reported | path (ns) | area (µm²) |
|---|---|---|---|---|
| default | `compile_ultra` | `pparch` | 1.62 | 8 047 |
| `set_implementation DW01_add/rpl` | `compile_ultra` | `pparch` — ignored | 1.62 | 8 047 |
| `set_implementation DW01_add/rpl` | `compile` | `rpl` | 1.95 | 9 126 |

Under `compile_ultra`, use §2.4 and §2.5 instead. If you want `compile` for
this experiment, remember that it changes everything else too: compare it
against plain `compile` without `set_implementation`, not against
`compile_ultra`.

### 2.7 The tool's arithmetic or yours

A multiplier written by hand in RTL — AND gates for the partial products, a
tree of full and half adders to reduce them — is, to Design Compiler, just
logic. It no longer recognises a multiplier, so nothing earlier in this section
applies to it: `report_resources` shows only the final `+`, if you left one.
Whether that loses or wins against `dw_foundation` is a measurement, not a
belief: building the tree and measuring it is one of the possible
explorations, TUTORIAL.md §4.6.

The other place where RTL arithmetic pays is where the tool *cannot* see the
opportunity at all: multiplying by a constant you know, sharing one operator
between two uses that never happen together, an accumulator kept in
carry-save form across cycles. TUTORIAL.md §4.4.

---

## 3. Keep the evidence

Every `make synth` overwrites `reports/`. Before the next run, copy what you
want to keep (TUTORIAL.md §2), and write down, with each snapshot, the exact
lines you added to the script. A number whose script you cannot reproduce is
not a result.
