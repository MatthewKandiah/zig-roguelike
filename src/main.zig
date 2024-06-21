const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
const stb = @cImport({
    @cInclude("stb_image.h");
});

const Dimensions = @import("types.zig").Dimensions;
const Colour = @import("types.zig").Colour;
const Rectangle = @import("types.zig").Rectangle;
const Position = @import("types.zig").Position;
const DrawData = @import("types.zig").DrawData;
const Surface = @import("surface.zig").Surface;
const CharMap = @import("charmap.zig").CharMap;

pub fn main() !void {
    sdlInit();
    const window = createWindow("zig-roguelike", 300, 300);
    checkPixelFormat(window);
    var surface = Surface.from_sdl_window(window);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var input_width: c_int = undefined;
    var input_height: c_int = undefined;
    var input_bytes_per_pixel: c_int = undefined;
    var input_data: [*]u8 = undefined;
    input_data = stb.stbi_load(@ptrCast("src/assets/charmap-oldschool-white.png"), &input_width, &input_height, &input_bytes_per_pixel, 0);

    const char_map = try CharMap.load(
        input_data,
        .{ .width = @as(usize, @abs(input_width)), .height = @as(usize, @abs(input_height)) },
        @as(usize, @abs(input_bytes_per_pixel)),
        .{ .width = 7, .height = 9 },
        allocator,
    );

    stb.stbi_image_free(input_data);

    var running = true;
    var event: c.SDL_Event = undefined;
    while (running) {
        // TODO - clear screen
        // TODO - draw entities
        const scale_factor = 8;
        const image_data_index = getCharImageDataIndex('J');
        const char_draw_data = char_map.drawData(image_data_index);
        surface.draw(
            char_draw_data,
            .{ .x = 0, .y = 0 },
            scale_factor,
        );

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

pub const BYTES_PER_PIXEL = 4;

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

pub fn sdlPanic() noreturn {
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

test "all tests" {
    std.testing.refAllDecls(@This());
}
