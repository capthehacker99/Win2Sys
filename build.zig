const std = @import("std");


pub fn build(b: *std.Build) void {
    const zigwin32 = b.dependency("zigwin32", .{});
    const win2sys = b.addModule("win2sys", .{
        .source_file = .{
            .path = "src/win2sys.zig",
        },
        .dependencies = &.{
            .{
                .name = "win32",
                .module = zigwin32.module("zigwin32")
            }
        }
    });
    const tests = b.addTest(.{
        .root_source_file = .{
            .path = "src/win2sys.zig"
        },
    });
    tests.addModule("win32", zigwin32.module("zigwin32"));
    b.step("test", "Run library tests.").dependOn(&tests.step);
    const exe = b.addExecutable(.{
        .name = "Win2Sys Su",
        .root_source_file = .{
            .path = "example/su.zig"
        },
    });
    exe.addModule("win32", zigwin32.module("zigwin32"));
    exe.addModule("win2sys", win2sys);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
