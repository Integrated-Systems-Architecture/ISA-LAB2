# Lab 2 — Setup

Lab 2 runs on the same machine, with the same tools, the same PDK and the same
scripts as Lab 1. Nothing new to install. What is new is that you do not start
from an empty template: you start from **your own Lab 1 design**.

---

## 1. The environment

Exactly Lab 1's — [SETUP.md in your Lab 1 repository](https://github.com/Integrated-Systems-Architecture/ISA-LAB1/blob/main/SETUP.md)
has the login, the licences and the "when it breaks" list. Once per shell on
the ISA server:

```bash
source /oss-tools/init.sh                    # python, fusesoc, verilator, $IHP_PDK_ROOT
source /eda/scripts/init_design_vision       # dc_shell, lc_shell, pt_shell/pwr_shell
source /eda/scripts/init_cadence_2020-21     # innovus -- 2020-21, NOT 2021-22
source /eda/scripts/init_questa_core_prime   # vsim
```

Lab 2 runs many more syntheses than Lab 1. Use **tmux** for anything longer
than a coffee:

```bash
tmux new -s lab2       # Ctrl-b d to detach, tmux attach -t lab2 to come back
```

---

## 2. Bring your Lab 1 design in

Create your group repository from the ISA-LAB2 template on GitHub and clone it:

```bash
cd ~
git clone <your-lab2-group-repo> isa-lab2
cd isa-lab2
```

This template carries the same `Makefile`, the same `accel.core` skeleton and
the same `implementation/` scripts that Lab 1's did. Replace the skeleton with
the files you delivered, straight from the `lab1-delivery` tag of your Lab 1
repository — all of them except the `Makefile`:

```bash
git fetch <your-lab1-group-repo-url> lab1-delivery
git checkout FETCH_HEAD -- rtl tb model data accel.core
```

`git fetch` with a tag name downloads that one commit and leaves it in
`FETCH_HEAD`, without adding a remote or copying Lab 1's tags into this
repository; `git checkout FETCH_HEAD -- <paths>` copies those paths from it
into your working tree and stages them.

**Keep this template's `Makefile`.** It is Lab 1's latest version, and the
one in your Lab 1 repository may be older: before 5 October, for instance,
`PWR_CLK_PS` was fixed at 10 000 ps, so every power run simulated at 10 ns
whatever the clock, and nothing said so. Carry over by hand what you set in
yours — your top module and the clock period you implemented:

```make
ACCEL      ?= <your top module>
CLK_PERIOD ?= <your Lab 1 period>
```

Then check that nothing else of yours is missing:

```bash
git diff FETCH_HEAD -- Makefile
```

A `-` line is in your Lab 1 `Makefile` and not here: carry it over only if
you wrote it. A `+` line is the template's: keep it.

Then tidy up:

- If your top module is not `my_accel`, the template's placeholder
  `rtl/my_accel.sv` is still there: `git rm rtl/my_accel.sv`.
- If your model or testbench reads other directories (a `data/` subfolder, a
  script under `util/`), bring them too — same command, more paths.
- If you changed anything under `implementation/` in Lab 1, see what:
  `git diff FETCH_HEAD -- implementation/`, and bring what you need with the
  same `git checkout FETCH_HEAD -- <file>`.
- If you fixed a bug **after** `lab1-delivery`, import from the commit with the
  fix instead (`git fetch <url> main`), and say so in REPORT.md §1.

The core name stays `isa:lab1:<accel>`. It is just a name; keeping it means
the `accel.core` you import agrees with this `Makefile`
(`CORE ?= isa:lab1:$(ACCEL)`) and with the power scripts without a single
edit.

---

## 3. Reproduce the baseline

Before you change anything, run the whole flow on the imported design, at the
clock period you implemented in Lab 1:

```bash
make vendor && make regs
make sim && make questa                      # TEST PASSED, twice
make synth                                   # CLK_PERIOD from the Makefile: your Lab 1 period
make power-sim                               # the gate-level netlist passes too
make pnr-all
make power-postlayout
```

Compare against §7 of your Lab 1 report and fill in REPORT.md §1. They should
agree to the last digit: same RTL, same scripts, same tool versions. If they
do not, find out why now — later, you will not be able to tell a difference
you caused from one you inherited.

Keep these reports (TUTORIAL.md §2 shows how), commit, and tag:

```bash
git add -A && git commit -m "Lab 2: import Lab 1 design as baseline"
git tag lab2-baseline && git push && git push --tags
```

From here on, `lab2-baseline` is the parent of your first exploration and
what the final design is compared against (TUTORIAL.md §2.3).

---

## 4. Know the scripts you are going to edit

In Lab 1 none of the tool scripts needed editing. In Lab 2 you may edit
`implementation/design_compiler/scripts/dc_script.tcl` and the
place-and-route scripts in `implementation/innovus/scripts/` (TUTORIAL.md
§4.8 lists their knobs). Read `dc_script.tcl` top to bottom before you touch
it, and keep in mind how it runs:

- `make synth` runs it through FuseSoC, in
  `build/isa_lab1_<accel>_0.1.0/synth-design_compiler/` — **not** in
  `implementation/design_compiler/`. Paths in the script are relative to that
  directory, or built from `SCRIPT_DIR` and `REPORT_DIR`, which FuseSoC sets.
- Variables set on the `make` command line reach the script as environment
  variables: `make synth CLK_PERIOD=3.0 FOO=1` makes `$::env(FOO)` exist in
  dc_shell. `set_constraints.tcl` reads `CLK_PERIOD` exactly that way; copy
  the pattern if you want a switch instead of an edit.
- **A default in the `Makefile` reaches the script only if exported.** For a
  switch of your own, write `export FOO ?= 0`, not `FOO ?= 0`: without
  `export`, `make synth` runs with `FOO` unset, nothing warns you, and the
  tag — which has only the default — no longer reproduces the run.
  `CLK_PERIOD` needs no `export` because the `synth` target passes it
  explicitly, as `PNR_UTIL` and `PNR_ASPECT` are passed to Innovus.
- The script is also runnable by hand in `dc_shell` from
  `implementation/design_compiler/`. Try a new command there first, one line
  at a time, before you put it in the script.
