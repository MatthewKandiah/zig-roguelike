const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
const stb = @cImport({
    @cInclude("stb_image.h");
});
const Rectangle = @import("rectangle.zig").Rectangle;
const Colour = @import("colour.zig").Colour;
const Position = @import("position.zig").Position;
const CharMap = @import("char-map.zig").CharMap;

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

const dungeon_width = 20;
const dungeon_height = 10;
const dungeon_tile = enum {
    WALL,
    FLOOR,
};

pub const TiledRectangle = struct {
    char_map: CharMap,
    pixel_position: Position,
    pixel_width: u32,
    pixel_height: u32,
    scale_factor: u32,

    const Self = @This();

    pub fn drawChar(self: *const Self, char: u8, tile_position: Position, pixels: [*]u8, pixels_per_row: u32, fg_colour: Colour, bg_colour: Colour) void {
        self.char_map.drawChar(
            char,
            pixels,
            .{
                .x = self.pixel_position.x + self.scale_factor * self.char_map.char_pixel_width * tile_position.x,
                .y = self.pixel_position.y + self.scale_factor * self.char_map.char_pixel_height * tile_position.y,
            },
            pixels_per_row,
            fg_colour,
            bg_colour,
            self.scale_factor,
        );
    }
};

pub fn main() !void {
    sdlInit();
    const window = createWindow("zig-roguelike", 1920, 1080);
    checkPixelFormat(window);
    var surface = Surface.from_sdl_window(window);

    var dungeon_map = std.mem.zeroes([dungeon_height][dungeon_width]dungeon_tile);
    dungeon_map[1][2] = .FLOOR;
    dungeon_map[3][4] = .FLOOR;
    dungeon_map[3][5] = .FLOOR;

    const char_map = CharMap.load("src/assets/charmap-oldschool-white.png", 7, 9);
    const char_scale_factor = 5;

    var running = true;
    var event: c.SDL_Event = undefined;
    while (running) {
        clearScreen(&surface);

        const tiled_rect = TiledRectangle{
            .char_map = char_map,
            .pixel_position = .{ .x = 0, .y = 0 },
            .pixel_width = surface.width,
            .pixel_height = surface.height,
            .scale_factor = char_scale_factor,
        };
        for (0..dungeon_height) |j| {
            for (0..dungeon_width) |i| {
                const char: u8 = switch (dungeon_map[j][i]) {
                    .WALL => '#',
                    .FLOOR => '.',
                };
                tiled_rect.drawChar(
                    char,
                    .{ .x = @intCast(i), .y = @intCast(j) },
                    surface.pixels,
                    surface.width,
                    Colour.white,
                    Colour.black,
                );
            }
        }

        tiled_rect.drawChar(
            '@',
            .{ .x = 30, .y = 15 },
            surface.pixels,
            surface.width,
            Colour.green,
            Colour.grey(122),
        );

        tiled_rect.drawChar(
            '$',
            .{ .x = 5, .y = 7 },
            surface.pixels,
            surface.width,
            .{ .r = 255, .g = 255, .b = 0 },
            .{ .r = 0, .g = 122, .b = 122 },
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

fn clearScreen(surface: *Surface) void {
    const clear_screen_colour_byte: u8 = 122;
    const whole_screen_rect = Rectangle{ .pos_x = 0, .pos_y = 0, .width = surface.width, .height = surface.height };
    whole_screen_rect.draw(
        surface.pixels,
        Colour.grey(clear_screen_colour_byte),
        surface.width,
    );
}

fn updateScreen(window: *c.struct_SDL_Window) void {
    if (c.SDL_UpdateWindowSurface(window) < 0) {
        sdlPanic();
    }
}
