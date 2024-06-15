const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
const stb = @cImport({
    @cInclude("stb_image.h");
});

pub const Position = struct { x: usize, y: usize };

pub const Dimensions = struct { width: usize, height: usize };

pub const Rectangle = struct { pos: Position, dim: Dimensions };

pub const Colour = struct {
    r: u8,
    g: u8,
    b: u8,

    const Self = @This();

    pub fn grey(value: u8) Self {
        return Self{ .r = value, .g = value, .b = value };
    }

    pub const black = Self{ .r = 0, .g = 0, .b = 0 };
    pub const white = Self{ .r = 255, .g = 255, .b = 255 };
    pub const red = Self{ .r = 255, .g = 0, .b = 0 };
    pub const green = Self{ .r = 0, .g = 255, .b = 0 };
    pub const blue = Self{ .r = 0, .g = 0, .b = 255 };
    pub const yellow = Self{ .r = 255, .g = 255, .b = 0 };
};

pub const CharMap = struct {
    data: []u8,
    width: usize,
    height: usize,
    char_width: usize,
    char_height: usize,

    const Self = @This();

    // TODO - our font asset is tiny, could its data be baked in at compile time?
    pub fn load(path: []const u8, char_width: usize, char_height: usize, allocator: std.mem.Allocator) !Self {
        var w: c_int = undefined;
        var h: c_int = undefined;
        var nrChannels: c_int = undefined;
        var input_data: [*]u8 = undefined;
        input_data = stb.stbi_load(@ptrCast(path), &w, &h, &nrChannels, 0);
        defer stb.stbi_image_free(input_data);
        const width: usize = @as(usize, @abs(w));
        const height: usize = @as(usize, @abs(h));
        const input_bytes_per_pixel = @as(usize, @abs(nrChannels));
        var output_data = try allocator.alloc(u8, width * height * 4);
        for (0..height / char_height) |tile_j| {
            for (0..width / char_width) |tile_i| {
                for (0..char_height) |pixel_j| {
                    for (0..char_width) |pixel_i| {
                        const pixel_index: usize = tile_i * char_width + pixel_i + width * (tile_j * char_height + pixel_j);
                        output_data[4 * pixel_index + 0] = input_data[input_bytes_per_pixel * pixel_index + 0];
                        output_data[4 * pixel_index + 1] = input_data[input_bytes_per_pixel * pixel_index + 1];
                        output_data[4 * pixel_index + 2] = input_data[input_bytes_per_pixel * pixel_index + 2];
                        output_data[4 * pixel_index + 3] = if (input_bytes_per_pixel == 4) input_data[input_bytes_per_pixel * pixel_index + 3] else 0;
                    }
                }
            }
        }
        return Self{
            .data = output_data,
            .width = width,
            .height = height,
            .char_width = char_width,
            .char_height = char_height,
        };
    }
};

pub fn getCharImageDataIndex(char: u8) usize {
    return switch (char) {
        ' ' => 0,
        '!' => 1,
        '"' => 2,
        '#' => 3,
        '$' => 4,
        '%' => 5,
        '&' => 6,
        '\'' => 7,
        '(' => 8,
        ')' => 9,
        '*' => 10,
        '+' => 11,
        ',' => 12,
        '-' => 13,
        '.' => 14,
        '/' => 15,
        '0' => 16,
        '1' => 17,
        '2' => 18,
        '3' => 19,
        '4' => 20,
        '5' => 21,
        '6' => 22,
        '7' => 23,
        '8' => 24,
        '9' => 25,
        ':' => 26,
        ';' => 27,
        '<' => 28,
        '=' => 29,
        '>' => 30,
        '?' => 31,
        '@' => 32,
        'A' => 33,
        'B' => 34,
        'C' => 35,
        'D' => 36,
        'E' => 37,
        'F' => 38,
        'G' => 39,
        'H' => 40,
        'I' => 41,
        'J' => 42,
        'K' => 43,
        'L' => 44,
        'M' => 45,
        'N' => 46,
        'O' => 47,
        'P' => 48,
        'Q' => 49,
        'R' => 50,
        'S' => 51,
        'T' => 52,
        'U' => 53,
        'V' => 54,
        'W' => 55,
        'X' => 56,
        'Y' => 57,
        'Z' => 58,
        '[' => 59,
        '\\' => 60,
        ']' => 61,
        '^' => 62,
        '_' => 63,
        '`' => 64,
        'a' => 65,
        'b' => 66,
        'c' => 67,
        'd' => 68,
        'e' => 69,
        'f' => 70,
        'g' => 71,
        'h' => 72,
        'i' => 73,
        'j' => 74,
        'k' => 75,
        'l' => 76,
        'm' => 77,
        'n' => 78,
        'o' => 79,
        'p' => 80,
        'q' => 81,
        'r' => 82,
        's' => 83,
        't' => 84,
        'u' => 85,
        'v' => 86,
        'w' => 87,
        'x' => 88,
        'y' => 89,
        'z' => 90,
        '{' => 91,
        '|' => 92,
        '}' => 93,
        '~' => 94,
        else => std.debug.panic("Illegal character {c} for current font", .{char}),
    };
}

const Surface = struct {
    pixels: [*]u8,
    width: usize,
    height: usize,

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

fn createWindow(title: []const u8, width: usize, height: usize) *c.struct_SDL_Window {
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

pub const TiledRectangle = struct {
    char_map: CharMap,
    pixel_position: Position,
    pixel_width: usize,
    pixel_height: usize,
    scale_factor: usize,
};

pub fn main() !void {
    sdlInit();
    const window = createWindow("zig-roguelike", 1920, 1080);
    checkPixelFormat(window);
    var surface = Surface.from_sdl_window(window);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const char_map = try CharMap.load("src/assets/charmap-oldschool-white.png", 7, 9, allocator);
    _ = char_map;
    const char_scale_factor = 3;
    _ = char_scale_factor;

    var running = true;
    var event: c.SDL_Event = undefined;
    while (running) {
        // TODO - clear screen
        // TODO - draw entities

        updateScreen(window);

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

fn updateScreen(window: *c.struct_SDL_Window) void {
    if (c.SDL_UpdateWindowSurface(window) < 0) {
        sdlPanic();
    }
}
