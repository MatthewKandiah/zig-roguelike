const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL_error.h");
});

pub fn sdlPanic() noreturn {
    const sdl_error_string = c.SDL_GetError();
    std.debug.panic("{s}", .{sdl_error_string});
}

pub fn safeAdd(x: usize, d: usize, max: usize) usize {
    const result = x + d;
    if (result >= max) return max;
    return result;
}

pub fn safeSub(x: usize, d: usize, min: usize) usize {
    if (d >= x) return 0;
    const result = x - d;
    if (result <= min) return min;
    return result;
}
