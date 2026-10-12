// SPDX-License-Identifier: MIT
// BRISC-V origin: ASCS Laboratory, Boston University (2018).
// RV64IM adaptation and integration: GEC students.
// Placeholder for future ECALL services. ECALL currently has no side effects.
module ecall_module #(
    parameter DATA_WIDTH = 64
)(
    input ecall_valid,
    input [8*DATA_WIDTH-1:0] ecall_args
);

// Intentionally empty: add ECALL service handling here in a future revision.

endmodule
