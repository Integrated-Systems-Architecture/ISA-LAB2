# Read every source of my_accel, in dependency order.
#
# This is the by-hand equivalent of what FuseSoC generates: when Design
# Compiler is driven through FuseSoC, edalize writes a
# <core>-read-sources.tcl with exactly these `analyze` commands, derived from
# the .core dependency tree. This file exists so the same synthesis script
# also runs standalone, and so you can see what the generated one contains.
#
# Paths are relative to implementation/design_compiler/.

set LAB    ../..
set VENDOR ${LAB}/vendor/pulp_platform

# Header files are found through search_path, not through analyze.
set search_path [concat [list ${VENDOR}/common_cells/include \
                              ${VENDOR}/register_interface/include \
                              ${VENDOR}/obi/include ] $search_path]

# --- vendored IPs -------------------------------------------------------
# Packages first: everything below imports from them.
analyze -f sverilog -lib WORK ${VENDOR}/common_cells/src/cf_math_pkg.sv
analyze -f sverilog -lib WORK ${VENDOR}/common_cells/src/fifo_v3.sv
analyze -f sverilog -lib WORK ${VENDOR}/common_cells/src/credit_counter.sv

# The technology cells. NOT the behavioural ones from tech_cells_generic:
# for synthesis, tc_clk_gating is the wrapper around sg13g2_lgcp_1, the
# library's integrated clock gating cell. Same module name, same ports, real
# cell inside. Synthesising the behavioural model instead would build a latch
# out of standard cells and AND it with the clock -- see the README.
analyze -f sverilog -lib WORK ${LAB}/implementation/tech/sg13g2/tc_clk_gating_sg13g2.sv

# The register interface protocol and the OpenTitan register primitives the
# generated CSR block instantiates.
analyze -f sverilog -lib WORK ${VENDOR}/register_interface/src/reg_intf.sv
analyze -f sverilog -lib WORK ${VENDOR}/register_interface/vendor/lowrisc_opentitan/src/prim_subreg_arb.sv
analyze -f sverilog -lib WORK ${VENDOR}/register_interface/vendor/lowrisc_opentitan/src/prim_subreg.sv
analyze -f sverilog -lib WORK ${VENDOR}/register_interface/vendor/lowrisc_opentitan/src/prim_subreg_ext.sv

# The OBI protocol package (types only; the interfaces are simulation-side).
analyze -f sverilog -lib WORK ${VENDOR}/obi/src/obi_pkg.sv

# --- your accelerator ----------------------------------------------------
# The authoritative source list is the `rtl` fileset of accel.core: FuseSoC
# resolves it, in order, and `make synth` hands the result straight to
# dc_shell. This file exists only for the by-hand run, so the glob below is
# a convenience -- it takes rtl/*_pkg.sv first, then everything else.
#
# If a by-hand run fails with `Error: Could not find design ...', that is a
# file-order problem in THIS file only, and the fix is to run the flow the
# way the lab does: `make synth`, or
#   fusesoc --cores-root . run --setup --target synth <core>
# which writes the ordered list FuseSoC derived from accel.core.
set RTL_PKGS [lsort [glob -nocomplain ${LAB}/rtl/*_pkg.sv]]
set RTL_REST {}
foreach f [lsort [glob -nocomplain ${LAB}/rtl/*.sv]] {
  if {[lsearch -exact $RTL_PKGS $f] < 0} { lappend RTL_REST $f }
}
if {[llength [concat $RTL_PKGS $RTL_REST]] == 0} {
  error "no sources in ${LAB}/rtl/ -- write your RTL first"
}
foreach f [concat $RTL_PKGS $RTL_REST] {
  analyze -f sverilog -lib WORK $f
}
