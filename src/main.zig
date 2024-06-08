const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});

const Rectangle = struct {
    pos_x: u32,
    pos_y: u32,
    width: u32,
    height: u32,
};

const clear_screen_colour_byte: u8 = 0;

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
    rect: Rectangle,
    bytes_per_pixel: u32,
    pixels_per_row: u32,
) void {
    for (0..rect.height) |j| {
        for (0..rect.width) |i| {
            const idx = (pixels_per_row * bytes_per_pixel * (j + rect.pos_y)) + (bytes_per_pixel * (i + rect.pos_x));
            pixels[idx + 0] = b;
            pixels[idx + 1] = g;
            pixels[idx + 2] = r;
        }
    }
}

fn sdlInit() void {
    const sdl_init = c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_TIMER | c.SDL_INIT_EVENTS);
    if (sdl_init < 0) {
        sdlPanic();
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
    ) orelse sdlPanic();
}

fn checkPixelFormat(window: *c.struct_SDL_Window) void {
    const format = c.SDL_GetWindowPixelFormat(window);
    if (format != c.SDL_PIXELFORMAT_RGB888) {
        @panic("I've assumed RGB888 format so far, so expect wonky results if you push on!\n");
    }
}

pub fn main() !void {
    sdlInit();
    const window = createWindow("zig-roguelike", 1920, 1080);
    var surface: *c.struct_SDL_Surface = c.SDL_GetWindowSurface(window) orelse sdlPanic();
    checkPixelFormat(window);

    var pixels: [*]u8 = @ptrCast(surface.pixels orelse @panic("Surface has not allocated pixels"));
    var surface_width: u32 = @intCast(surface.w);
    var surface_height: u32 = @intCast(surface.h);
    const tile_count_x: u32 = 80;
    const tile_count_y: u32 = 60;
    var tile_width: u32 = surface_width / tile_count_x;
    var tile_height: u32 = surface_height / tile_count_y;

    var running = true;
    var event: c.SDL_Event = undefined;
    var pos_x: u32 = 0;
    var pos_y: u32 = 0;

    while (running) {
        drawRectangle(
            pixels,
            clear_screen_colour_byte,
            clear_screen_colour_byte,
            clear_screen_colour_byte,
            .{
                .pos_x = 0,
                .pos_y = 0,
                .width = surface_width,
                .height = surface_height,
            },
            4,
            surface_width,
        ); // clear
        for (0..tile_count_y) |j| {
            for (0..tile_count_x) |i| {
                const colour: u8 = if (@mod(i + j, 2) == 0) 255 else 0;
                drawRectangle(
                    pixels,
                    colour,
                    colour,
                    colour,
                    .{
                        .pos_x = @intCast(tile_width * i),
                        .pos_y = @intCast(tile_height * j),
                        .width = tile_width,
                        .height = tile_height,
                    },
                    4,
                    surface_width,
                );
            }
        }
        drawRectangle(
            pixels,
            255,
            0,
            255,
            .{
                .pos_x = pos_x,
                .pos_y = pos_y,
                .width = tile_width,
                .height = tile_height,
            },
            4,
            surface_width,
        ); // player

        if (c.SDL_UpdateWindowSurface(window) < 0) {
            sdlPanic();
        }

        while (c.SDL_PollEvent(@ptrCast(&event)) != 0) {
            if (event.type == c.SDL_QUIT) {
                running = false;
            }
            if (event.type == c.SDL_KEYDOWN) {
                switch (event.key.keysym.sym) {
                    c.SDLK_ESCAPE => running = false,
                    c.SDLK_UP => pos_y = safeSub(pos_y, tile_height, 0),
                    c.SDLK_DOWN => pos_y = safeAdd(pos_y + tile_height, tile_height, surface_height) - tile_height,
                    c.SDLK_LEFT => pos_x = safeSub(pos_x, tile_width, 0),
                    c.SDLK_RIGHT => pos_x = safeAdd(pos_x + tile_width, tile_width, surface_width) - tile_width,
                    else => {},
                }
            }
            if (event.type == c.SDL_WINDOWEVENT) {
                surface = c.SDL_GetWindowSurface(window) orelse sdlPanic();
                const updated_format = c.SDL_GetWindowPixelFormat(window);
                if (updated_format != c.SDL_PIXELFORMAT_RGB888) {
                    @panic("I've assumed RGB888 format so far, so expect wonky results if you push on!\n");
                }
                pixels = @ptrCast(surface.pixels orelse @panic("Surface has not allocated pixels"));
                surface_height = @intCast(surface.h);
                surface_width = @intCast(surface.w);
                tile_width = surface_width / tile_count_x;
                tile_height = surface_height / tile_count_y;
            }
        }
    }
}
