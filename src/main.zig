const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});

pub fn main() !void {
    std.debug.print("Yes I'm working\n", .{});
}
