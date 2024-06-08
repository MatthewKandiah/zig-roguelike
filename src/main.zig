const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});

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
    const window = createWindow("zig-roguelike", 1920, 1080);
    var surface: *c.struct_SDL_Surface = c.SDL_GetWindowSurface(window) orelse sdlPanic();
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
        drawRectangle(
            pixels,
            clear_screen_colour_byte,
            clear_screen_colour_byte,
            clear_screen_colour_byte,
            0,
            0,
            screen_data.surface_width,
            screen_data.surface_height,
            4,
            screen_data.surface_width,
        ); // clear
        for (0..screen_data.tile_count_y) |j| {
            for (0..screen_data.tile_count_x) |i| {
                const colour: u8 = if (@mod(i + j, 2) == 0) 255 else 0;
                drawRectangle(
                    pixels,
                    colour,
                    colour,
                    colour,
                    @intCast(screen_data.tile_width() * i),
                    @intCast(screen_data.tile_height() * j),
                    screen_data.tile_width(),
                    screen_data.tile_height(),
                    4,
                    screen_data.surface_width,
                );
            }
        }
        drawRectangle(
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
                    c.SDLK_UP => pos_y = safeSub(pos_y, screen_data.tile_height(), 0),
                    c.SDLK_DOWN => pos_y = safeAdd(pos_y + screen_data.tile_height(), screen_data.tile_height(), screen_data.surface_height) - screen_data.tile_height(),
                    c.SDLK_LEFT => pos_x = safeSub(pos_x, screen_data.tile_width(), 0),
                    c.SDLK_RIGHT => pos_x = safeAdd(pos_x + screen_data.tile_width(), screen_data.tile_width(), screen_data.surface_width) - screen_data.tile_width(),
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
                screen_data.surface_height = @intCast(surface.h);
                screen_data.surface_width = @intCast(surface.w);
            }
        }
    }
}
