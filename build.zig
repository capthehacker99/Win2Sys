const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const zigwin32 = b.modules.get("zigwin32") orelse b.dependency("zigwin32", .{}).module("zigwin32");
    const win2sys = b.addModule("win2sys", .{
        .root_source_file = b.path("src/win2sys.zig"),
        .imports = &.{
            .{
                .name = "win32",
                .module = zigwin32
            }
        }
    });
    const tests = b.addTest(.{
        .root_source_file = b.path("src/win2sys.zig"),
    });
    tests.root_module.addImport("win32", zigwin32);
    b.step("test", "Run library tests.").dependOn(&tests.step);
    const exe = b.addExecutable(.{
        .name = "Win2Sys Su",
        .root_source_file = b.path("example/su.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("win32", zigwin32);
    exe.root_module.addImport("win2sys", win2sys);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
