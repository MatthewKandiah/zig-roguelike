const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
const lib = @import("lib.zig");

pub fn main() !void {
    const sdl_init = c.SDL_Init(c.SDL_INIT_VIDEO);
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

    const surface = c.SDL_GetWindowSurface(window) orelse lib.sdlPanic();
    const pixels = surface.*.pixels;
    _ = pixels;
    std.time.sleep(1_000_000_000);
}
