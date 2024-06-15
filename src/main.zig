const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
const stb = @cImport({
    @cInclude("stb_image.h");
});

pub fn main() !void {
    sdlInit();
    const window = createWindow("zig-roguelike", 800, 600);
    checkPixelFormat(window);
    var surface = Surface.from_sdl_window(window);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var input_width: c_int = undefined;
    var input_height: c_int = undefined;
    var input_bytes_per_pixel: c_int = undefined;
    var input_data: [*]u8 = undefined;
    input_data = stb.stbi_load(@ptrCast("src/assets/charmap-oldschool-white.png"), &input_width, &input_height, &input_bytes_per_pixel, 0);

    std.debug.print("input_width: {}\n", .{input_width});

    const char_map = try CharMap.load(
        input_data,
        .{ .width = @as(usize, @abs(input_width)), .height = @as(usize, @abs(input_height)) },
        @as(usize, @abs(input_bytes_per_pixel)),
        .{ .width = 7, .height = 9 },
        allocator,
    );

    var running = true;
    var event: c.SDL_Event = undefined;
    while (running) {
        // TODO - clear screen
        // TODO - draw entities
        surface.draw(char_map.drawData(getCharImageDataIndex('J')), .{ .x = 0, .y = 0 }, 5);

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

const BYTES_PER_PIXEL = 4;

pub const Position = struct { x: usize, y: usize };

pub const Dimensions = struct {
    width: usize,
    height: usize,

    const Self = @This();

    pub fn area(self: Self) usize {
        return self.width * self.height;
    }
};

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
    dim: Dimensions,
    char_dim: Dimensions,

    const Self = @This();

    // TODO - our font asset is tiny, could its data be baked in at compile time?
    pub fn load(input_data: [*]u8, image_dim: Dimensions, input_bytes_per_pixel: usize, char_dim: Dimensions, allocator: std.mem.Allocator) !Self {
        std.debug.print("image_dim: {any}\n", .{image_dim});
        var output_data = try allocator.alloc(u8, image_dim.area() * BYTES_PER_PIXEL);
        var output_index: usize = 0;
        for (0..image_dim.height / char_dim.height) |tile_j| {
            for (0..image_dim.width / char_dim.width) |tile_i| {
                for (0..char_dim.height) |pixel_j| {
                    for (0..char_dim.width) |pixel_i| {
                        const pixel_index: usize = tile_i * char_dim.width + pixel_i + image_dim.width * (tile_j * char_dim.height + pixel_j);
                        output_data[output_index] = input_data[input_bytes_per_pixel * pixel_index + 0];
                        output_index += 1;
                        output_data[output_index] = input_data[input_bytes_per_pixel * pixel_index + 1];
                        output_index += 1;
                        output_data[output_index] = input_data[input_bytes_per_pixel * pixel_index + 2];
                        output_index += 1;
                        output_data[output_index] = if (input_bytes_per_pixel == 4) input_data[input_bytes_per_pixel * pixel_index + 3] else 0;
                        output_index += 1;
                    }
                }
            }
        }

        return Self{
            .data = output_data,
            .dim = image_dim,
            .char_dim = char_dim,
        };
    }

    pub fn drawData(self: Self, index: usize) DrawData {
        const byte_count = self.char_dim.area() * BYTES_PER_PIXEL;
        const start_index = index * self.char_dim.area() * BYTES_PER_PIXEL;
        return DrawData{
            .bytes = self.data[start_index .. start_index + byte_count],
            .width = self.char_dim.width,
        };
    }
};

const DrawData = struct {
    bytes: []u8,
    width: usize,
};

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

    fn draw(self: Self, draw_data: DrawData, pos: Position, scale_factor: usize) void {
        for (0..draw_data.bytes.len) |i| {
            for (0..scale_factor) |scale_j| {
                for (0..scale_factor) |scale_i| {
                    const x = i % (draw_data.width * BYTES_PER_PIXEL);
                    const y = i / (draw_data.width * BYTES_PER_PIXEL);
                    self.pixels[pos.x + (x * scale_factor) + scale_i + self.width * BYTES_PER_PIXEL * (pos.y + (y * scale_factor) + scale_j)] = draw_data.bytes[i];
                }
            }
        }
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

fn updateScreen(window: *c.struct_SDL_Window) void {
    if (c.SDL_UpdateWindowSurface(window) < 0) {
        sdlPanic();
    }
}

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
