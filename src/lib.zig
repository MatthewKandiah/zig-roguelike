const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL_error.h");
});

pub fn sdlPanic() noreturn {
    const sdl_error_string = c.SDL_GetError();
    std.debug.panic("{s}", .{sdl_error_string});
}

pub fn safeAdd(x: u32, d: u32, max: u32) u32 {
    const result = x + d;
    if (result >= max) return max;
    return result;
}

pub fn safeSub(x: u32, d: u32, min: u32) u32 {
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
    pos_x: u32,
    pos_y: u32,
    rec_width: u32,
    rec_height: u32,
    bytes_per_pixel: u32,
    pixels_per_row: u32,
) void {
    for (0..rec_height) |j| {
        for (0..rec_width) |i| {
            pixels[(pixels_per_row * bytes_per_pixel * (j + pos_y)) + (bytes_per_pixel * (i + pos_x)) + 0] = b;
            pixels[(pixels_per_row * bytes_per_pixel * (j + pos_y)) + (bytes_per_pixel * (i + pos_x)) + 1] = g;
            pixels[(pixels_per_row * bytes_per_pixel * (j + pos_y)) + (bytes_per_pixel * (i + pos_x)) + 2] = r;
        }
    }
}
