const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zig-roguelike",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.addIncludePath(.{ .src_path = .{ .owner = b, .sub_path = "deps/include" } });
    exe.addCSourceFile(.{ .file = .{ .src_path = .{ .owner = b, .sub_path = "deps/src/stb_image_impl.c" } } });
    exe.addCSourceFile(.{ .file = .{ .src_path = .{ .owner = b, .sub_path = "deps/src/stb_image_write_impl.c" } } });
    // TODO - consider static linking SDL2
    exe.linkSystemLibrary("SDL2");
    exe.linkLibC();
    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const tests = b.addTest(.{ .root_source_file = b.path("src/main.zig") });
    tests.addIncludePath(.{ .src_path = .{ .owner = b, .sub_path = "deps/include" } });
    tests.addCSourceFile(.{ .file = .{ .src_path = .{ .owner = b, .sub_path = "deps/src/stb_image_impl.c" } } });
    tests.addCSourceFile(.{ .file = .{ .src_path = .{ .owner = b, .sub_path = "deps/src/stb_image_write_impl.c" } } });
    // TODO - consider static linking SDL2
    tests.linkSystemLibrary("SDL2");
    tests.linkLibC();
    b.installArtifact(tests);
    const test_cmd = b.addRunArtifact(tests);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const test_step = b.step("test", "Run the tests");
    test_step.dependOn(&test_cmd.step);
}
