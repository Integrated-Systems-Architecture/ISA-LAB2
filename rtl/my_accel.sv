// Top level of YOUR accelerator.
//
// Rename the file and the module together with ACCEL in the Makefile, the
// `toplevel:` fields in accel.core and `name:` in data/accel.hjson.
//
// Two port names are a contract with the back-end scripts: `clk_i` and
// `rst_ni` (see implementation/design_compiler/scripts/set_constraints.tcl,
// which creates the clock on clk_i and declares rst_ni a false path).
//
// What a standalone accelerator normally has around the kernel:
//   - a CSR port (reg_req_i / reg_rsp_o) feeding the generated
//     <accel>_reg_top, so software configures it the X-HEEP way
//   - a data port (OBI manager) it uses to read its inputs and write its
//     results, because payload data does not belong in registers
//   - a control FSM between the two
//   - tc_clk_gating around the datapath, so an idle accelerator stops
//     clocking (tech_cells_generic; NEVER hand-write the gate)
//
// Build the kernel out of common_cells where one fits: fifo_v3, counter,
// lzc, rr_arb_tree, stream_*. See vendor/pulp_platform/ after `make vendor`.

module my_accel (
  input logic clk_i,
  input logic rst_ni
  // TODO(you): CSR port, data port, and anything else your kernel needs.
);

  // TODO(you): the accelerator.

endmodule
