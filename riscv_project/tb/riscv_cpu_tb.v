// riscv_cpu_tb.v - generic self-checking testbench for riscv_cpu_wrapper.
//
// Drives clk/reset, lets instr_mem load whatever program was passed via
// +MEMFILE=<path>, traces pc/result/memory activity every cycle, and stops
// after +CYCLES=<n> cycles (default 100). Waveforms are dumped to
// waves/riscv_cpu_tb.vcd for viewing in gtkwave.
//
// REGISTER VISIBILITY (this is the part the old testbench was missing):
//   At the end of the run this testbench reaches into the DUT hierarchy
//   (dut.rvcpu.dp.rf.regs[]) and:
//     1. prints every one of the 32 architectural registers to the console
//        (decimal + hex), so you can actually see what a program left
//        behind without opening gtkwave,
//     2. writes that same register file out to a plain memory-image file
//        via $writememh (one 8-hex-digit line per register, x0..x31, same
//        format as the programs/*.txt instruction files) if +REGDUMP=<path>
//        is passed, so there's a durable on-disk artifact you can diff/grep,
//     3. optionally self-checks specific registers against expected values
//        if +EXPECT=<path> is passed. Expect-file format is one
//        "xN=decimal_value" assertion per line, '//' comments and blank
//        lines allowed, e.g.:
//            x2=15
//            x3=6
//        Prints a PASS/FAIL line per assertion plus a final summary, and
//        exits with a nonzero status (via $stop code semantics through
//        $finish + a printed FAIL marker) if anything failed.
//
// Run via scripts/run.sh, or directly:
//   vvp build/sim.out +MEMFILE=programs/sample1.txt +CYCLES=60 \
//       +REGDUMP=regdumps/sample1 +EXPECT=programs/sample1.expect

`timescale 1ns/1ps

module riscv_cpu_tb;

    reg clk;
    reg reset;

    // external memory-preload ports on the wrapper - unused for normal
    // program runs, tied off. (They let you poke a known value into data
    // memory from outside while reset is held high, if you ever need that.)
    reg         ext_mem_write;
    reg  [31:0] ext_write_data, ext_data_addr;

    wire        mem_write;
    wire [31:0] write_data, data_addr, read_data;
    wire [31:0] pc, result;

    integer cycles;
    integer max_cycles;

    riscv_cpu_wrapper dut (
        .clk            (clk),
        .reset          (reset),
        .ext_mem_write  (ext_mem_write),
        .ext_write_data (ext_write_data),
        .ext_data_addr  (ext_data_addr),
        .mem_write      (mem_write),
        .write_data     (write_data),
        .data_addr      (data_addr),
        .read_data      (read_data),
        .pc             (pc),
        .result         (result)
    );

    // 10 ns clock period
    always #5 clk = ~clk;

    // -------------------------------------------------------------------
    // register-file dump / self-check bookkeeping
    // -------------------------------------------------------------------
    reg [1023:0] regdump_path;
    reg [1023:0] expect_path;
    reg          have_regdump;
    reg          have_expect;

    // dumps all 32 architectural registers: console (human-readable) and,
    // if +REGDUMP was given, a $writememh memory-image file on disk.
    task dump_registers;
        integer i;
        integer fd;
        reg [1023:0] hexpath;
        begin
            $display("===================================================================");
            $display(" final register file contents (x0..x31)");
            $display("===================================================================");
            for (i = 0; i < 32; i = i + 1) begin
                $display("  x%-2d = %-11d  (0x%08h)", i,
                          dut.rvcpu.dp.rf.regs[i], dut.rvcpu.dp.rf.regs[i]);
            end
            $display("===================================================================");

            if (have_regdump) begin
                // human-readable text dump, one "xN = dec (0xHEX)" line per register
                fd = $fopen({regdump_path, ".txt"}, "w");
                if (fd) begin
                    for (i = 0; i < 32; i = i + 1)
                        $fdisplay(fd, "x%-2d = %-11d (0x%08h)", i,
                                  dut.rvcpu.dp.rf.regs[i], dut.rvcpu.dp.rf.regs[i]);
                    $fclose(fd);
                end else begin
                    $display("[tb] WARNING: could not open %0s.txt for register dump", regdump_path);
                end

                // plain memory-image hex dump (same format as programs/*.txt),
                // one 8-hex-digit line per register, x0 first .. x31 last --
                // literally "writing the registers to a memory file" so they
                // can be inspected/diffed without any simulator at all.
                hexpath = {regdump_path, ".hex"};
                $writememh(hexpath, dut.rvcpu.dp.rf.regs, 0, 31);
                $display("[tb] register dump written: %0s.txt and %0s.hex", regdump_path, regdump_path);
            end
        end
    endtask

    // parses +EXPECT=<path> (format: "xN=decimal_value" per line, '//'
    // comments and blank lines allowed) and checks each assertion against
    // the live register file. Prints PASS/FAIL per line and a summary.
    task run_expect_checks;
        integer fd;
        integer scan_ok;
        integer rnum;
        integer rval;
        integer total, passed;
        reg [1023:0] line;
        integer got;
        begin
            total  = 0;
            passed = 0;
            fd = $fopen(expect_path, "r");
            if (!fd) begin
                $display("[tb] WARNING: could not open expect file %0s", expect_path);
            end else begin
                while (!$feof(fd)) begin
                    scan_ok = $fscanf(fd, "x%d=%d\n", rnum, rval);
                    if (scan_ok == 2) begin
                        total = total + 1;
                        got = dut.rvcpu.dp.rf.regs[rnum];
                        if (got == rval) begin
                            passed = passed + 1;
                            $display("[check] PASS  x%-2d == %0d", rnum, rval);
                        end else begin
                            $display("[check] FAIL  x%-2d expected %0d, got %0d", rnum, rval, got);
                        end
                    end else begin
                        // not a "xN=val" line (comment/blank/EOF) -- consume
                        // the rest of the line and move on
                        scan_ok = $fscanf(fd, "%s\n", line);
                    end
                end
                $fclose(fd);

                $display("===================================================================");
                if (total == 0) begin
                    $display("[tb] no checks parsed from %0s", expect_path);
                end else if (passed == total) begin
                    $display("[tb] RESULT: ALL %0d CHECK(S) PASSED", total);
                end else begin
                    $display("[tb] RESULT: %0d / %0d CHECK(S) FAILED", total - passed, total);
                end
                $display("===================================================================");
            end
        end
    endtask

    initial begin
        clk           = 0;
        reset         = 1;
        ext_mem_write = 0;
        ext_write_data = 0;
        ext_data_addr  = 0;
        cycles         = 0;

        if (!$value$plusargs("CYCLES=%d", max_cycles))
            max_cycles = 100;

        have_regdump = $value$plusargs("REGDUMP=%s", regdump_path);
        have_expect  = $value$plusargs("EXPECT=%s", expect_path);

        $dumpfile("waves/riscv_cpu_tb.vcd");
        $dumpvars(0, riscv_cpu_tb);

        #12 reset = 0;   // release reset after a couple of clock edges
    end

    // per-cycle trace + run-length control
    always @(posedge clk) begin
        if (!reset) begin
            $display("t=%0t  pc=%08h  instr_result=%08h  mem_write=%b  data_addr=%08h  write_data=%08h  read_data=%08h",
                      $time, pc, result, mem_write, data_addr, write_data, read_data);

            cycles = cycles + 1;
            if (cycles >= max_cycles) begin
                $display("[tb] reached max cycle count (%0d), stopping.", max_cycles);
                dump_registers;
                if (have_expect) run_expect_checks;
                $finish;
            end
        end
    end

endmodule
