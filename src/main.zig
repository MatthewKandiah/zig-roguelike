const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
const lib = @import("lib.zig");

const background_tiles = enum {
    FLOOR,
    WALL,
};

const wall_colour_byte: u8 = 240;
const floor_colour_byte: u8 = 60;
const border_colour_byte: u8 = 0;

const tilemap_width: comptime_int = 4;
const tilemap_height: comptime_int = 4;
const background_tilemap = [tilemap_height][tilemap_width]background_tiles{
    [tilemap_width]background_tiles{
        background_tiles.WALL,
        background_tiles.WALL,
        background_tiles.WALL,
        background_tiles.WALL,
    },
    [tilemap_width]background_tiles{
        background_tiles.WALL,
        background_tiles.FLOOR,
        background_tiles.FLOOR,
        background_tiles.FLOOR,
    },
    [tilemap_width]background_tiles{
        background_tiles.WALL,
        background_tiles.FLOOR,
        background_tiles.WALL,
        background_tiles.FLOOR,
    },
    [tilemap_width]background_tiles{
        background_tiles.WALL,
        background_tiles.WALL,
        background_tiles.WALL,
        background_tiles.WALL,
    },
};

pub fn main() !void {
    const sdl_init = c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_TIMER | c.SDL_INIT_EVENTS);
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

    var surface: *c.SDL_Surface = c.SDL_GetWindowSurface(window) orelse lib.sdlPanic();

    const format = c.SDL_GetWindowPixelFormat(window);
    if (format != c.SDL_PIXELFORMAT_RGB888) {
        @panic("I've assumed RGB888 format so far, so expect wonky results if you push on!\n");
    }

    var pixels: [*]u8 = @ptrCast(surface.pixels orelse @panic("Surface has not allocated pixels"));
    var width: usize = @intCast(surface.w);
    var height: usize = @intCast(surface.h);
    var tile_width: usize = width / tilemap_width;
    var tile_height: usize = height / tilemap_height;
    std.debug.print("screen_width: {}\nscreen_height: {}\ntile_width: {}\ntile_height: {}\n\n", .{ width, height, tile_width, tile_height });

    var run_count: usize = 0;
    var running = true;
    var event: c.SDL_Event = undefined;

    var pos_x: usize = 0;
    var pos_y: usize = 0;
    var speed_x: usize = tilemap_width;
    var speed_y: usize = tilemap_height;

    while (running) {
        lib.drawRectangle(
            pixels,
            @truncate(border_colour_byte),
            @truncate(border_colour_byte),
            @truncate(border_colour_byte),
            0,
            0,
            width,
            height,
            width,
        ); // clear
        inline for (0..tilemap_height) |j| {
            inline for (0..tilemap_width) |i| {
                const colour = switch (background_tilemap[j][i]) {
                    .FLOOR => floor_colour_byte,
                    .WALL => wall_colour_byte,
                };
                lib.drawRectangle(
                    pixels,
                    @truncate(colour),
                    @truncate(colour),
                    @truncate(colour),
                    tile_width * i,
                    tile_height * j,
                    tile_width,
                    tile_height,
                    width,
                );
            }
        }
        lib.drawRectangle(
            pixels,
            255,
            0,
            255,
            pos_x,
            pos_y,
            tile_width,
            tile_height,
            width,
        ); // player

        const update = c.SDL_UpdateWindowSurface(window);
        if (update < 0) {
            lib.sdlPanic();
        }

        while (c.SDL_PollEvent(@ptrCast(&event)) != 0) {
            if (event.type == c.SDL_QUIT) {
                running = false;
            }
            if (event.type == c.SDL_KEYDOWN) {
                switch (event.key.keysym.sym) {
                    c.SDLK_ESCAPE => running = false,
                    c.SDLK_UP => pos_y = lib.safeSub(pos_y, speed_y, 0),
                    c.SDLK_DOWN => pos_y = lib.safeAdd(pos_y + tile_height, speed_y, height) - tile_height,
                    c.SDLK_LEFT => pos_x = lib.safeSub(pos_x, speed_x, 0),
                    c.SDLK_RIGHT => pos_x = lib.safeAdd(pos_x + tile_width, speed_x, width) - tile_width,
                    else => {},
                }
            }
            if (event.type == c.SDL_WINDOWEVENT) {
                surface = c.SDL_GetWindowSurface(window) orelse lib.sdlPanic();
                const updated_format = c.SDL_GetWindowPixelFormat(window);
                if (updated_format != c.SDL_PIXELFORMAT_RGB888) {
                    @panic("I've assumed RGB888 format so far, so expect wonky results if you push on!\n");
                }
                pixels = @ptrCast(surface.pixels orelse @panic("Surface has not allocated pixels"));
                width = @intCast(surface.w);
                height = @intCast(surface.h);
                tile_width = width / tilemap_width;
                tile_height = height / tilemap_height;
                speed_x = tile_width;
                speed_y = tile_height;
                std.debug.print("screen_width: {}\nscreen_height: {}\ntile_width: {}\ntile_height: {}\n\n", .{ width, height, tile_width, tile_height });
            }
        }

        run_count += 1;
    }
}
