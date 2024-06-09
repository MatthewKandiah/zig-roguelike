const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
const stb = @cImport({
    @cInclude("stb_image.h");
});

const LoadImageResult = struct {
    data: [*]u8,
    width: u32,
    height: u32,
    nrChannels: u32,
};

// character bitmap is 18 x 6 characters
// pixel dimensions of character bitmap
// TODO - not sure how much padding there is between characters
const char_width = 5;
const char_height = 7;

fn loadCharmap() LoadImageResult {
    // stb.stbi_set_flip_vertically_on_load(1);
    var width: c_int = undefined;
    var height: c_int = undefined;
    var nrChannels: c_int = undefined;
    var data: [*]u8 = undefined;
    data = stb.stbi_load("src/assets/charmap-oldschool-white.png", &width, &height, &nrChannels, 0);
    return .{
        .data = data,
        .width = @intCast(width),
        .height = @intCast(height),
        .nrChannels = @intCast(nrChannels),
    };
}

const Zone = struct {
    pos_x: u32,
    pos_y: u32,
    width: u32,
    height: u32,
};

const Surface = struct {
    pixels: [*]u8,
    width: u32,
    height: u32,

    const Self = @This();

    fn from_sdl_window(window: *c.struct_SDL_Window) Self {
        const surface: *c.struct_SDL_Surface = c.SDL_GetWindowSurface(window) orelse sdlPanic();
        const pixels: [*]u8 = @ptrCast(surface.pixels orelse @panic("SDL surface has not allocated pixels"));
        return Self{
            .pixels = pixels,
            .width = @intCast(surface.w),
            .height = @intCast(surface.h),
        };
    }

    fn update(self: *Self, window: *c.struct_SDL_Window) void {
        const surface: *c.struct_SDL_Surface = c.SDL_GetWindowSurface(window) orelse sdlPanic();
        const pixels: [*]u8 = @ptrCast(surface.pixels orelse @panic("SDL surface has not allocated pixels"));
        self.pixels = pixels;
        self.width = @intCast(surface.w);
        self.height = @intCast(surface.h);
    }
};

const Rectangle = struct {
    pos_x: u32,
    pos_y: u32,
    width: u32,
    height: u32,

    const Self = @This();

    fn draw(
        self: Self,
        pixels: [*]u8,
        colour: Colour,
        bytes_per_pixel: u32,
        pixels_per_row: u32,
    ) void {
        for (0..self.height) |j| {
            for (0..self.width) |i| {
                const idx = (pixels_per_row * bytes_per_pixel * (j + self.pos_y)) + (bytes_per_pixel * (i + self.pos_x));
                pixels[idx + 0] = colour.b;
                pixels[idx + 1] = colour.g;
                pixels[idx + 2] = colour.r;
            }
        }
    }
};

const Colour = struct {
    r: u8,
    g: u8,
    b: u8,

    const Self = @This();

    fn grey(value: u8) Self {
        return Self{ .r = value, .g = value, .b = value };
    }
};

const clear_screen_colour_byte: u8 = 122;

fn sdlPanic() noreturn {
    const sdl_error_string = c.SDL_GetError();
    std.debug.panic("{s}", .{sdl_error_string});
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
    const charmap = loadCharmap();
    const scale_factor = 3;
    sdlInit();
    const window = createWindow("zig-roguelike", 1920, 1080);
    checkPixelFormat(window);
    var surface = Surface.from_sdl_window(window);
    var running = true;
    var event: c.SDL_Event = undefined;
    while (running) {
        const whole_screen_rect = Rectangle{ .pos_x = 0, .pos_y = 0, .width = surface.width, .height = surface.height };
        whole_screen_rect.draw(
            surface.pixels,
            Colour.grey(clear_screen_colour_byte),
            4,
            surface.width,
        ); // clear

        for (0..charmap.height) |j| {
            for (0..charmap.width) |i| {
                const charmap_data_idx = (charmap.width * 3 * j) + (3 * i);
                const r = charmap.data[charmap_data_idx + 0];
                const g = charmap.data[charmap_data_idx + 1];
                const b = charmap.data[charmap_data_idx + 2];
                const colour = Colour{ .r = r, .g = g, .b = b };
                const rect = Rectangle{
                    .pos_x = @intCast(i * scale_factor),
                    .pos_y = @intCast(j * scale_factor),
                    .width = scale_factor,
                    .height = scale_factor,
                };
                rect.draw(surface.pixels, colour, 4, surface.width);
            }
        }

        for (0..9) |j| {
            for (0..7) |i| {
                const offset_x = 7 * 14;
                const offset_y = 9 * 1;
                const charmap_data_idx = (charmap.width * 3 * (j + offset_y)) + (3 * (i + offset_x));
                const r = charmap.data[charmap_data_idx + 0];
                const g = charmap.data[charmap_data_idx + 1];
                const b = charmap.data[charmap_data_idx + 2];
                const char_colour = Colour{ .r = 255, .g = 255, .b = 0 };
                const bg_colour = Colour{ .r = 0, .g = 100, .b = 100 };
                const colour = if (r != 0 and g != 0 and b != 0) char_colour else bg_colour;
                const rect = Rectangle{
                    .pos_x = @intCast(i * scale_factor + 1000),
                    .pos_y = @intCast(j * scale_factor + 500),
                    .width = scale_factor,
                    .height = scale_factor,
                };
                rect.draw(surface.pixels, colour, 4, surface.width);
            }
        }

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
                    else => {},
                }
            }
            if (event.type == c.SDL_WINDOWEVENT) {
                checkPixelFormat(window);
                surface.update(window);
            }
        }
    }
}
