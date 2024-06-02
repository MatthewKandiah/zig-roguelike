const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
const lib = @import("lib.zig");

pub fn main() !void {
    const sdl_init = c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_TIMER);
    if (sdl_init < 0) {
        lib.sdlPanic();
    }

    const window = c.SDL_CreateWindow(
        "zig-roguelike",
        c.SDL_WINDOWPOS_UNDEFINED,
        c.SDL_WINDOWPOS_UNDEFINED,
        800,
        600,
        c.SDL_WINDOW_RESIZABLE,
    ) orelse lib.sdlPanic();

    const surface: *c.SDL_Surface = c.SDL_GetWindowSurface(window) orelse lib.sdlPanic();

    const format = c.SDL_GetWindowPixelFormat(window);
    if (format != c.SDL_PIXELFORMAT_RGB888) {
        @panic("I've assumed RGB888 format so far, so expect wonky results if you push on!\n");
    }

    var pixels: [*]u8 = @ptrCast(surface.pixels orelse @panic("Surface has not allocated pixels"));
    const width: usize = @intCast(surface.w);
    const height: usize = @intCast(surface.h);

    var run_count: usize = 0;
    const timeout = c.SDL_GetTicks64() + 5_000; // 5 seconds
    while (c.SDL_GetTicks64() < timeout) {
        for (0..height) |j| {
            for (0..width) |i| {
                pixels[(width * 4 * j) + (4 * i) + 0] = @truncate(i + run_count); // B
                pixels[(width * 4 * j) + (4 * i) + 1] = @truncate(run_count); // G
                pixels[(width * 4 * j) + (4 * i) + 2] = @truncate(j); // R
                pixels[(width * 4 * j) + (4 * i) + 3] = 0; // X
            }
        }
        const update = c.SDL_UpdateWindowSurface(window);
        if (update < 0) {
            lib.sdlPanic();
        }
        run_count += 1;
    }
}
