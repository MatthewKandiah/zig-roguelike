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

fn sdlInit() void {
    const sdl_init = c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_TIMER | c.SDL_INIT_EVENTS);
    if (sdl_init < 0) {
        lib.sdlPanic();
    }
}

fn createWindow(title: []const u8, width: u32, height: u32) *c.struct_SDL_Window {
    return c.SDL_CreateWindow(
        @ptrCast(title),
        c.SDL_WINDOWPOS_UNDEFINED,
        c.SDL_WINDOWPOS_UNDEFINED,
        @intCast(width),
        @intCast(height),
        c.SDL_WINDOW_RESIZABLE,
    ) orelse lib.sdlPanic();
}

fn checkPixelFormat(window: *c.struct_SDL_Window) void {
    const format = c.SDL_GetWindowPixelFormat(window);
    if (format != c.SDL_PIXELFORMAT_RGB888) {
        @panic("I've assumed RGB888 format so far, so expect wonky results if you push on!\n");
    }
}

const TiledScreenData = struct {
    surface_width: u32,
    surface_height: u32,
    tile_count_x: u32,
    tile_count_y: u32,

    const Self = @This();

    fn tile_width(self: Self) u32 {
        return self.surface_width / self.tile_count_x;
    }

    fn tile_height(self: Self) u32 {
        return self.surface_height / self.tile_count_y;
    }
};

pub fn main() !void {
    sdlInit();
    const window = createWindow("zig-roguelike", 800, 600);
    var surface: *c.struct_SDL_Surface = c.SDL_GetWindowSurface(window) orelse lib.sdlPanic();
    checkPixelFormat(window);

    var pixels: [*]u8 = @ptrCast(surface.pixels orelse @panic("Surface has not allocated pixels"));
    var screen_data = TiledScreenData{
        .surface_width = @intCast(surface.w),
        .surface_height = @intCast(surface.h),
        .tile_count_x = 80,
        .tile_count_y = 60,
    };

    var running = true;
    var event: c.SDL_Event = undefined;
    var pos_x: u32 = 0;
    var pos_y: u32 = 0;

    while (running) {
        lib.drawRectangle(
            pixels,
            @truncate(border_colour_byte),
            @truncate(border_colour_byte),
            @truncate(border_colour_byte),
            0,
            0,
            screen_data.surface_width,
            screen_data.surface_height,
            4,
            screen_data.surface_width,
        ); // clear
        for (0..screen_data.tile_count_y) |j| {
            for (0..screen_data.tile_count_x) |i| {
                const colour: u32 = if (@mod(i + j, 2) == 0) 255 else 0;
                lib.drawRectangle(
                    pixels,
                    @truncate(colour),
                    @truncate(colour),
                    @truncate(colour),
                    @intCast(screen_data.tile_width() * i),
                    @intCast(screen_data.tile_height() * j),
                    screen_data.tile_width(),
                    screen_data.tile_height(),
                    4,
                    screen_data.surface_width,
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
            screen_data.tile_width(),
            screen_data.tile_height(),
            4,
            screen_data.surface_width,
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
                    c.SDLK_UP => pos_y = lib.safeSub(pos_y, screen_data.tile_height(), 0),
                    c.SDLK_DOWN => pos_y = lib.safeAdd(pos_y + screen_data.tile_height(), screen_data.tile_height(), screen_data.surface_height) - screen_data.tile_height(),
                    c.SDLK_LEFT => pos_x = lib.safeSub(pos_x, screen_data.tile_width(), 0),
                    c.SDLK_RIGHT => pos_x = lib.safeAdd(pos_x + screen_data.tile_width(), screen_data.tile_width(), screen_data.surface_width) - screen_data.tile_width(),
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
                screen_data.surface_height = @intCast(surface.h);
                screen_data.surface_width = @intCast(surface.w);
            }
        }
    }
}
