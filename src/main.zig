const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
const stb = @cImport({
    @cInclude("stb_image.h");
});

const CharMap = struct {
    data: [*]u8,
    total_width: u32,
    total_height: u32,
    bytes_per_pixel: u32,
    char_pixel_width: u32,
    char_pixel_height: u32,

    const Self = @This();

    // TODO - our font asset is tiny, could its data be baked in at compile time?
    fn load(path: []const u8, char_pixel_width: u32, char_pixel_height: u32) Self {
        var width: c_int = undefined;
        var height: c_int = undefined;
        var nrChannels: c_int = undefined;
        var data: [*]u8 = undefined;
        data = stb.stbi_load(@ptrCast(path), &width, &height, &nrChannels, 0);
        return .{
            .data = data,
            .total_width = @intCast(width),
            .total_height = @intCast(height),
            .bytes_per_pixel = @intCast(nrChannels),
            .char_pixel_width = char_pixel_width,
            .char_pixel_height = char_pixel_height,
        };
    }

    fn pixelPositionFromCharIndices(self: *const Self, charIndices: Position) Position {
        return .{
            .x = charIndices.x * self.char_pixel_width,
            .y = charIndices.y * self.char_pixel_height,
        };
    }

    fn drawChar(
        self: *const Self,
        char: u8,
        pixels: [*]u8,
        pixel_position: Position,
        pixels_per_row: u32,
        fg_colour: Colour,
        bg_colour: Colour,
        scale_factor: u32,
    ) void {
        for (0..self.char_pixel_height) |j| {
            for (0..self.char_pixel_width) |i| {
                const char_position = self.pixelPositionFromCharIndices(getCharIndices(char));
                const charmap_data_idx = (self.total_width * self.bytes_per_pixel * (j + char_position.y)) + (self.bytes_per_pixel * (i + char_position.x));
                const r = self.data[charmap_data_idx + 0];
                const g = self.data[charmap_data_idx + 1];
                const b = self.data[charmap_data_idx + 2];
                const colour = if (r != 0 and g != 0 and b != 0) fg_colour else bg_colour;
                const scaled_pixel = Rectangle{
                    .pos_x = @intCast(i * scale_factor + pixel_position.x),
                    .pos_y = @intCast(j * scale_factor + pixel_position.y),
                    .width = scale_factor,
                    .height = scale_factor,
                };
                scaled_pixel.draw(pixels, colour, pixels_per_row);
            }
        }
    }

    fn drawString(
        self: *const Self,
        str: []const u8,
        pixels: [*]u8,
        pixel_position: Position,
        pixels_per_row: u32,
        fg_colour: Colour,
        bg_colour: Colour,
        scale_factor: u32,
    ) void {
        for (str, 0..) |char, i| {
            self.drawChar(
                char,
                pixels,
                .{ .x = @intCast(pixel_position.x + i * scale_factor * self.char_pixel_width), .y = pixel_position.y },
                pixels_per_row,
                fg_colour,
                bg_colour,
                scale_factor,
            );
        }
    }
};

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
        pixels_per_row: u32,
    ) void {
        const bytes_per_pixel = 4;
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

const Position = struct { x: u32, y: u32 };

fn getCharIndices(char: u8) Position {
    return switch (char) {
        ' ' => .{ .x = 0, .y = 0 },
        '!' => .{ .x = 1, .y = 0 },
        '"' => .{ .x = 2, .y = 0 },
        '#' => .{ .x = 3, .y = 0 },
        '$' => .{ .x = 4, .y = 0 },
        '%' => .{ .x = 5, .y = 0 },
        '&' => .{ .x = 6, .y = 0 },
        '\'' => .{ .x = 7, .y = 0 },
        '(' => .{ .x = 8, .y = 0 },
        ')' => .{ .x = 9, .y = 0 },
        '*' => .{ .x = 10, .y = 0 },
        '+' => .{ .x = 11, .y = 0 },
        ',' => .{ .x = 12, .y = 0 },
        '-' => .{ .x = 13, .y = 0 },
        '.' => .{ .x = 14, .y = 0 },
        '/' => .{ .x = 15, .y = 0 },
        '0' => .{ .x = 16, .y = 0 },
        '1' => .{ .x = 17, .y = 0 },
        '2' => .{ .x = 0, .y = 1 },
        '3' => .{ .x = 1, .y = 1 },
        '4' => .{ .x = 2, .y = 1 },
        '5' => .{ .x = 3, .y = 1 },
        '6' => .{ .x = 4, .y = 1 },
        '7' => .{ .x = 5, .y = 1 },
        '8' => .{ .x = 6, .y = 1 },
        '9' => .{ .x = 7, .y = 1 },
        ':' => .{ .x = 8, .y = 1 },
        ';' => .{ .x = 9, .y = 1 },
        '<' => .{ .x = 10, .y = 1 },
        '=' => .{ .x = 11, .y = 1 },
        '>' => .{ .x = 12, .y = 1 },
        '?' => .{ .x = 13, .y = 1 },
        '@' => .{ .x = 14, .y = 1 },
        'A' => .{ .x = 15, .y = 1 },
        'B' => .{ .x = 16, .y = 1 },
        'C' => .{ .x = 17, .y = 1 },
        'D' => .{ .x = 0, .y = 2 },
        'E' => .{ .x = 1, .y = 2 },
        'F' => .{ .x = 2, .y = 2 },
        'G' => .{ .x = 3, .y = 2 },
        'H' => .{ .x = 4, .y = 2 },
        'I' => .{ .x = 5, .y = 2 },
        'J' => .{ .x = 6, .y = 2 },
        'K' => .{ .x = 7, .y = 2 },
        'L' => .{ .x = 8, .y = 2 },
        'M' => .{ .x = 9, .y = 2 },
        'N' => .{ .x = 10, .y = 2 },
        'O' => .{ .x = 11, .y = 2 },
        'P' => .{ .x = 12, .y = 2 },
        'Q' => .{ .x = 13, .y = 2 },
        'R' => .{ .x = 14, .y = 2 },
        'S' => .{ .x = 15, .y = 2 },
        'T' => .{ .x = 16, .y = 2 },
        'U' => .{ .x = 17, .y = 2 },
        'V' => .{ .x = 0, .y = 3 },
        'W' => .{ .x = 1, .y = 3 },
        'X' => .{ .x = 2, .y = 3 },
        'Y' => .{ .x = 3, .y = 3 },
        'Z' => .{ .x = 4, .y = 3 },
        '[' => .{ .x = 5, .y = 3 },
        '\\' => .{ .x = 6, .y = 3 },
        ']' => .{ .x = 7, .y = 3 },
        '^' => .{ .x = 8, .y = 3 },
        '_' => .{ .x = 9, .y = 3 },
        '`' => .{ .x = 10, .y = 3 },
        'a' => .{ .x = 11, .y = 3 },
        'b' => .{ .x = 12, .y = 3 },
        'c' => .{ .x = 13, .y = 3 },
        'd' => .{ .x = 14, .y = 3 },
        'e' => .{ .x = 15, .y = 3 },
        'f' => .{ .x = 16, .y = 3 },
        'g' => .{ .x = 17, .y = 3 },
        'h' => .{ .x = 0, .y = 4 },
        'i' => .{ .x = 1, .y = 4 },
        'j' => .{ .x = 2, .y = 4 },
        'k' => .{ .x = 3, .y = 4 },
        'l' => .{ .x = 4, .y = 4 },
        'm' => .{ .x = 5, .y = 4 },
        'n' => .{ .x = 6, .y = 4 },
        'o' => .{ .x = 7, .y = 4 },
        'p' => .{ .x = 8, .y = 4 },
        'q' => .{ .x = 9, .y = 4 },
        'r' => .{ .x = 10, .y = 4 },
        's' => .{ .x = 11, .y = 4 },
        't' => .{ .x = 12, .y = 4 },
        'u' => .{ .x = 13, .y = 4 },
        'v' => .{ .x = 14, .y = 4 },
        'w' => .{ .x = 15, .y = 4 },
        'x' => .{ .x = 16, .y = 4 },
        'y' => .{ .x = 17, .y = 4 },
        'z' => .{ .x = 0, .y = 5 },
        '{' => .{ .x = 1, .y = 5 },
        '|' => .{ .x = 2, .y = 5 },
        '}' => .{ .x = 3, .y = 5 },
        '~' => .{ .x = 4, .y = 5 },
        else => std.debug.panic("Illegal character {c} for current font", .{char}),
    };
}

pub fn main() !void {
    sdlInit();
    const window = createWindow("zig-roguelike", 1920, 1080);
    checkPixelFormat(window);
    var surface = Surface.from_sdl_window(window);

    const char_map = CharMap.load("src/assets/charmap-oldschool-white.png", 7, 9);
    const scale_factor = 3;

    var running = true;
    var event: c.SDL_Event = undefined;

    while (running) {
        const whole_screen_rect = Rectangle{ .pos_x = 0, .pos_y = 0, .width = surface.width, .height = surface.height };
        whole_screen_rect.draw(
            surface.pixels,
            Colour.grey(clear_screen_colour_byte),
            surface.width,
        );

        // draw whole font
        for (0..char_map.total_height) |j| {
            for (0..char_map.total_width) |i| {
                const charmap_data_idx = (char_map.total_width * char_map.bytes_per_pixel * j) + (char_map.bytes_per_pixel * i);
                const r = char_map.data[charmap_data_idx + 0];
                const g = char_map.data[charmap_data_idx + 1];
                const b = char_map.data[charmap_data_idx + 2];
                const colour = Colour{ .r = r, .g = g, .b = b };
                const scaled_pixel = Rectangle{
                    .pos_x = @intCast(i * scale_factor),
                    .pos_y = @intCast(j * scale_factor),
                    .width = scale_factor,
                    .height = scale_factor,
                };
                scaled_pixel.draw(surface.pixels, colour, surface.width);
            }
        }

        char_map.drawString(
            "So it turns out this font looks pretty gross[({.,`'\"!?$%#*})]",
            surface.pixels,
            .{ .x = 0, .y = 500 },
            surface.width,
            .{ .r = 255, .g = 255, .b = 0 },
            .{ .r = 0, .g = 122, .b = 122 },
            4,
        );

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
