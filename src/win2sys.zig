const std = @import("std");
const win = std.os.windows;
const win32 = @import("win32").everything;
var svcCtrl: win32.SERVICE_STATUS_HANDLE = undefined;

pub const Win2SysStatus = enum {
    RequireRestart,
    Error,
    Success,
    UserCancelled,
};

fn obtainAdmin(fileNameBuf: []u8) Win2SysStatus {
    if(@intFromPtr(win32.ShellExecuteA(null, "runas", @ptrCast(fileNameBuf.ptr), null, null, @intFromEnum(win32.SW_NORMAL))) <= 32)
        return if(win32.GetLastError() == win32.WIN32_ERROR.ERROR_CANCELLED) Win2SysStatus.UserCancelled else Win2SysStatus.Error;
    return Win2SysStatus.RequireRestart;
}

fn int2Base95(out: []u8, val: u32) ?[]u8 {
    var cv = val;
    if(out.len == 0)
        return null;
    out[out.len-1] = 0;
    const end = out.ptr;
    var cur = end+out.len-2;
    while(cv != 0) {
        if(@intFromPtr(cur) < @intFromPtr(end))
            break;
        cur[0] = ' ' + @as(u8, @truncate(cv % 95));
        cv /= 95;
        cur -= 1;
    } else {
        return cur[1..(@intFromPtr(out.ptr)+out.len)-@intFromPtr(cur)-1];
    }
    return null;
}

var gFakeName: [17] u8 = undefined;
pub fn elevate() Win2SysStatus {
    var fakeName: [17] u8 = undefined;
    generateFakeName(&fakeName);
    @memcpy(&gFakeName, &fakeName);
    const serviceTable = [2]win32.SERVICE_TABLE_ENTRYA{
        .{
            .lpServiceName = @ptrCast(&fakeName),
            .lpServiceProc = @ptrCast(&serviceMain),
        },
        .{
            .lpServiceName = null,
            .lpServiceProc = null,
        }
    };
    if(win32.StartServiceCtrlDispatcherA(@ptrCast(&serviceTable)) != win.FALSE)
        return Win2SysStatus.RequireRestart;
    if(win32.GetLastError() != win32.WIN32_ERROR.ERROR_FAILED_SERVICE_CONTROLLER_CONNECT)
        return Win2SysStatus.Error;
    if(isSystem())
        return Win2SysStatus.Success;
    var fileNameBuf: [512]u8 = undefined;
    if(win32.GetModuleFileNameA(null, @ptrCast(fileNameBuf[0..].ptr), 512) == 0)
        return Win2SysStatus.Error;
    const svcMan = win32.OpenSCManagerA(null, null, win32.SC_MANAGER_CREATE_SERVICE);
    if(svcMan == 0) {
        if(win32.GetLastError() != win32.WIN32_ERROR.ERROR_ACCESS_DENIED)
            return Win2SysStatus.Error;
        return obtainAdmin(&fileNameBuf);
    }
    defer _ = win32.CloseServiceHandle(svcMan);
    const svc = blk: {
        var newSvc = win32.CreateServiceA(
            svcMan,
            @ptrCast(&fakeName),
            "",
            win32.SERVICE_START | win32.DELETE,
            win32.SERVICE_WIN32_OWN_PROCESS,
            win32.SERVICE_START_TYPE.DEMAND_START,
            win32.SERVICE_ERROR.IGNORE,
            @ptrCast(&fileNameBuf),
            null,
            null,
            null,
            null,
            null
        );
        if(newSvc != 0)
            break :blk newSvc;
        switch (win32.GetLastError()) {
            win32.WIN32_ERROR.ERROR_ACCESS_DENIED => return obtainAdmin(&fileNameBuf),
            win32.WIN32_ERROR.ERROR_SERVICE_EXISTS => {},
            else => return Win2SysStatus.Error
        }
        newSvc = win32.OpenServiceA(svcMan, @ptrCast(&fakeName), win32.SERVICE_START | win32.DELETE);
        if(newSvc != 0)
            break :blk newSvc;
        if(win32.GetLastError() == win32.WIN32_ERROR.ERROR_ACCESS_DENIED)
            return obtainAdmin(&fileNameBuf);
        return Win2SysStatus.Error;
    };
    defer _ = win32.CloseServiceHandle(svc);
    var buf: [8]u8 = undefined;
    const parsed = int2Base95(&buf, win.teb().ProcessEnvironmentBlock.SessionId);
    if(parsed == null)
        return Win2SysStatus.Error;
    if(win32.StartServiceA(svc, 2, @ptrCast(@constCast(&[_]?[*:0]u8{
        @ptrCast(&fileNameBuf),
        @ptrCast(parsed.?.ptr)
    }))) == win.FALSE)
        return Win2SysStatus.Error;
    _ = win32.DeleteService(svc);
    return Win2SysStatus.RequireRestart;
}

fn isSystem() bool {
    const ntAuthority: win32.SID_IDENTIFIER_AUTHORITY = .{
        .Value = [1]u8{0}**5 ++ [1]u8{5},
    };
    var administratorsGroup: ?win32.PSID = undefined; 
    if(win32.AllocateAndInitializeSid(
        @constCast(&ntAuthority), 
        1, 
        win32.SECURITY_LOCAL_SYSTEM_RID,
        win32.DOMAIN_ALIAS_RID_ADMINS, 
        0, 
        0, 
        0, 
        0, 
        0, 
        0, 
        &administratorsGroup
    ) == win.FALSE)
        return false;
    defer _ = win32.FreeSid(administratorsGroup);
    var isMember: win32.BOOL = undefined;
    if(win32.CheckTokenMembership(null, administratorsGroup, &isMember) == win.FALSE)
        return false;
    return isMember == win.TRUE;
}

fn generateFakeName(buf: []u8) void {
    var hasher = blk: {
        var hasher = std.crypto.hash.Blake3.init(.{
            .key = [32] u8 {
                0x48, 0xB9, 0xE5, 0xBE, 0x1C, 0x2B, 0xA1, 0x8B, 0x18, 0x85, 0x12, 0x72, 0x1B, 0x1E, 0xDA, 0xFB, 0x31, 0x7B, 0x05, 0xD4, 0x7D, 0xED, 0x10, 0x00, 0x36, 0xCC, 0x98, 0x22, 0x70, 0x7F, 0xA0, 0xFA
            },
        });
        var buffer: [4096]u8 = undefined;
        const bytesWritten = win32.GetSystemFirmwareTable(win32.FIRMWARE_TABLE_PROVIDER.RSMB, 0, &buffer, buffer.len);
        hasher.update(buffer[0..bytesWritten]);
        break :blk hasher;
    };
    hasher.final(buf[0..buf.len-1]);
    for(buf[0..buf.len-1]) |*val| {
        val.* = 'a' + (val.* % 26);
    }
    buf[16] = 0;
}


fn attemptCreateProcess(processPath: ?[*:0]const u8, activeSessionId: u32) void {
    const procToken = blk: {
        var originalToken: ?win32.HANDLE = undefined;
        if(win32.OpenProcessToken(win.self_process_handle, win32.TOKEN_ACCESS_MASK.initFlags(.{
            .DUPLICATE = 1,
        }), &originalToken) == win.FALSE)
            return;
        defer _ = win32.CloseHandle(originalToken);
        var newToken: ?win32.HANDLE = undefined;
        if(win32.DuplicateTokenEx(
                originalToken,
                @enumFromInt(0x02000000),
                null, 
                win32.SECURITY_IMPERSONATION_LEVEL.Anonymous, 
                win32.TOKEN_TYPE.Primary, 
                &newToken
            ) == win.FALSE)
            return;
        break :blk newToken;
    };
    defer _ = win32.CloseHandle(procToken);
    if(win32.SetTokenInformation(
        procToken, 
        win32.TOKEN_INFORMATION_CLASS.TokenSessionId, 
        @ptrCast(@constCast(&activeSessionId)), 
        @sizeOf(@TypeOf(activeSessionId))
        ) == win.FALSE)
        return;
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
    if(win32.CreateProcessAsUserA(
        procToken,
        processPath, 
        null, 
        null, 
        null, 
        win.FALSE, 
        @intFromEnum(win32.PROCESS_CREATION_FLAGS.CREATE_NEW_CONSOLE), 
        null, 
        null,
        @ptrCast(@constCast(&startupInfo)),
        &procInfo) == win.FALSE)
        return;
}

fn parseNullTermInt(beg: [*:0]const u8) u32 {
    var ret: u32 = 0;
    var cur = beg;
    while(true) {
        const ch = cur[0];
        if(ch == 0)
            return ret;
        ret *= 95;
        ret += ch-' ';
        cur += 1;
    }
}

fn ServiceCtrlHandler(ctrlCode: u32)  callconv(win.WINAPI) void {
    _ = ctrlCode;
}

fn serviceMain(dwNumServicesArgs: u32, lpServiceArgVectors: ?[*]?win32.PSTR) callconv(win.WINAPI) void {
    if(dwNumServicesArgs == 3)
        attemptCreateProcess(lpServiceArgVectors.?[1], parseNullTermInt(lpServiceArgVectors.?[2].?));
    const statusHandle = win32.RegisterServiceCtrlHandlerA(@ptrCast(&gFakeName), ServiceCtrlHandler);
    if(statusHandle == 0)
        std.process.exit(0);
    _ = win32.SetServiceStatus(statusHandle, @constCast(&win32.SERVICE_STATUS {
        .dwServiceType = win32.SERVICE_WIN32_OWN_PROCESS,
        .dwControlsAccepted = 0,
        .dwCurrentState = win32.SERVICE_STOPPED,
        .dwWin32ExitCode = 0,
        .dwServiceSpecificExitCode = 0,
        .dwCheckPoint = 1,
        .dwWaitHint = 0,
    }));
}


test "elevation" {
    switch (elevate()) {
        .RequireRestart => return,
        .UserCancelled => {
            _ = win32.MessageBoxA(null, "Please press \"Yes\" when the UAC prompt pops up.", "Action Cancelled by user.", win32.MESSAGEBOX_STYLE.initFlags(.{
                .ICONASTERISK = 1,
                .SETFOREGROUND = 1,
                .TOPMOST = 1,
            }));
            return;
        },
        .Error => {
            _ = win32.MessageBoxA(null, "An error occurred.", "Error.", win32.MESSAGEBOX_STYLE.ICONHAND);
            return;
        },
        .Success => {}
    }
    _ = win32.MessageBoxA(null, "Noice", "Nice", win32.MESSAGEBOX_STYLE.OK);
    return;
}