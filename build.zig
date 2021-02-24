const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const lib = b.addStaticLibrary("winmd-zig", "src/winmd.zig");
    lib.setBuildMode(mode);
    lib.install();

    var winmd_tests = b.addTest("src/winmd_test.zig");
    winmd_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&winmd_tests.step);
}
