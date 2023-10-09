# Win2Sys
![Win2Sys Logo](./logo.png)  
This library allows your program to ascend to SYSTEM easily.
## Usage
### Add to your project
1. Add this library to `build.zig.zon`  
```rust
.{
    .name = "YOUR PROJECT NAME",
    .version = "YOUR PROJECT VERSION",
    .dependencies = .{
        .win2sys = .{
            .url = "[Your win2sys url]",
            .hash = "[hash]",
        },
    },
}
```
2. Add module to compile task  
```rust
const win2sys = b.dependency("win2sys", .{});
exe.addModule("win2sys", win2sys);
```
### Using the library
```rust
const win2sys = @import("win2sys");
_ = win2sys.elevate();
```
You can see an example [here](./example/su.zig)