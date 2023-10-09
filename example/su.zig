const std = @import("std");
const win2sys = @import("win2sys");
const win32 = @import("win32").everything;
fn pause() void {
    var l: [1]u8 = undefined;
    _ = std.io.getStdIn().read(&l) catch undefined;
}
pub fn main() void {
    const stdout = std.io.getStdOut();
    switch (win2sys.elevate()) {
        .RequireRestart => return,
        .UserCancelled => {
            _ = stdout.write("Please press \"Yes\" when the UAC prompt pops up.\n") catch undefined;
            pause();
            return;
        },
        .Error => {
            _ = stdout.write("An error occurred.\n") catch undefined;
            pause();
            return;
        },
        .Success => _ = stdout.write("You are system now.\n") catch undefined,
    }
    const startupInfo = win32.STARTUPINFOA {
        .cb = @sizeOf(win32.STARTUPINFOA),
        .lpReserved = null,
        .lpDesktop = null,
        .lpTitle = null,
        .dwX = 0,
        .dwY = 0,
        .dwXSize = 0,
        .dwYSize = 0,
        .dwXCountChars = 0,
        .dwYCountChars = 0,
        .dwFillAttribute = 0,
        .dwFlags = win32.STARTUPINFOW_FLAGS.initFlags(.{}),
        .wShowWindow = 0,
        .cbReserved2 = 0,
        .lpReserved2 = null,
        .hStdInput = null,
        .hStdOutput = null,
        .hStdError = null,
    };
    var procInfo: win32.PROCESS_INFORMATION = undefined;
    _ = win32.CreateProcessA("C:\\Windows\\System32\\cmd.exe", null, null, null, 0, win32.PROCESS_CREATION_FLAGS.initFlags(.{}), null, null, @constCast(&startupInfo), &procInfo);
    return;
}