// SPDX-License-Identifier: MIT
// BRISC-V origin: ASCS Laboratory, Boston University (2018).
// RV64IM adaptation and integration: GEC students.
/** @module : tb_RISC_V_Core
 *  @author : Adaptive & Secure Computing Systems (ASCS) Laboratory
 *
 *  Testbench for RISC-V Core
 */

module tb_RISC_V_Core();

reg clock;
reg reset;
reg start;

reg [63:0] prog_address;
reg report;

wire stop;

// Core
RISC_V_Core CORE (
    .clock(clock),
    .reset(reset),
    .start(start),
    .prog_address(prog_address),
    .stop(stop),
    .report(report)
);


// Clock
always #1 clock = ~clock;

// Print each character emitted by the semihost output path.
always @(posedge clock) begin
    if (!reset && CORE.semihost_char_valid)
        $fwrite(32'h80000002, "%c", CORE.semihost_char_data);
end


// Reset and start
initial begin

    clock = 1'b0;

    reset = 1'b1;
    start = 1'b0;

    report = 1'b0;
    prog_address = 64'h0000000000000000;
    // Picolibc-linked images commonly use 0x80000000 as their link address.
    // Pass +prog_address=80000000 when loading such an image; the RAM interface
    // uses the low address bits while the core keeps the full architectural PC.
    if ($value$plusargs("prog_address=%h", prog_address)) begin end

    // Reset
    repeat (2) @(posedge clock);

    reset = 1'b0;
    start = 1'b1;

    // Start core
    repeat (2) @(posedge clock);

    start = 1'b0;

end


// Writeback monitor
always @(posedge clock) begin

    if (!reset && CORE.write_writeback) begin

        $display(
            "WB: x%0d = %016h",
            CORE.write_reg_writeback,
            CORE.write_data_writeback
        );

    end

end


// Stop simulation on EBREAK
always @(posedge clock) begin

    if (!reset && stop) begin

        // Finish the ECALL character stream before the shell prompt returns.
        $fwrite(32'h80000002, "\n");

        $display("");
        $display("=================================");
        $display("PROGRAM STOPPED BY EBREAK");
        $display("=================================");

        dump_results;

        $finish;

    end

end


// Dump results
task dump_results;

integer i;
integer reg_file;

begin

    $display("");
    $display("=== Writing simulation results ===");


    // Registers
    reg_file = $fopen("results/registers.txt", "w");

    if (reg_file == 0) begin
        $display("ERROR: Could not open registers.txt");
    end
    else begin

        for (i = 0; i < 32; i = i + 1) begin

            $fdisplay(
                reg_file,
                "x%-2d = %016h",
                i,
                CORE.ID.registers.register_file[i]
            );

        end

        $fclose(reg_file);

        $display("registers.txt written");

    end


    // Data memory
    $writememh(
        "results/data_memory.txt",
        CORE.mem_hierarchy_inst.d_mem_interface0.RAM.ram
    );

    $display("data_memory.txt written");

    $display("=================================");
    $display("");

end

endtask


endmodule
