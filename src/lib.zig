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

pub fn drawRectangle(
    pixels: [*]u8,
    r: u8,
    g: u8,
    b: u8,
    pos_x: usize,
    pos_y: usize,
    rec_width: usize,
    rec_height: usize,
    screen_width: usize,
) void {
    for (0..rec_height) |j| {
        for (0..rec_width) |i| {
            pixels[(screen_width * 4 * (j + pos_y)) + (4 * (i + pos_x)) + 0] = b;
            pixels[(screen_width * 4 * (j + pos_y)) + (4 * (i + pos_x)) + 1] = g;
            pixels[(screen_width * 4 * (j + pos_y)) + (4 * (i + pos_x)) + 2] = r;
        }
    }
}
