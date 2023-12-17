const std = @import("std");
const GitRepoStep = @import("GitRepoStep.zig");

pub fn build(b: *std.Build) void {
    const zigwin32_repo = GitRepoStep.create(b, .{
        .url = "https://github.com/marlersoft/zigwin32",
        .branch = "main",
        .sha = "6777f1db221d0cb50322842f558f03e3c3a4099f",
    });
    b.getInstallStep().dependOn(&zigwin32_repo.step);
    const zigwin32 = b.addModule("zigwin32", .{
        .source_file = .{
            .path = b.pathJoin(&.{ zigwin32_repo.path, "win32.zig" }),
        }
    });
    const win2sys = b.addModule("win2sys", .{
        .source_file = .{
            .path = "src/win2sys.zig",
        },
        .dependencies = &.{
            .{
                .name = "win32",
                .module = zigwin32
            }
        }
    });
    const tests = b.addTest(.{
        .root_source_file = .{
            .path = "src/win2sys.zig"
        },
    });
    tests.step.dependOn(&zigwin32_repo.step);
    tests.addModule("win32", zigwin32);
    b.step("test", "Run library tests.").dependOn(&tests.step);
    const exe = b.addExecutable(.{
        .name = "Win2Sys Su",
        .root_source_file = .{
            .path = "example/su.zig"
        },
    });
    exe.step.dependOn(&zigwin32_repo.step);
    exe.addModule("win32", zigwin32);
    exe.addModule("win2sys", win2sys);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
