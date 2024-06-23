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
const PositionDelta = @import("types.zig").PositionDelta;
const DrawData = @import("types.zig").DrawData;
const TileGrid = @import("types.zig").TileGrid;
const Surface = @import("surface.zig").Surface;
const CharMap = @import("charmap.zig").CharMap;
const Tile = @import("types.zig").Tile;

pub const GameState = struct {
    // map data
    tile_grid: TileGrid,
    rooms: []Rectangle,
    // player data
    player_pos: Position,

    const Self = @This();

    pub fn handleMove(self: *Self, delta: PositionDelta) void {
        const new_pos = self.player_pos.add(delta);
        if (self.tile_grid.get(new_pos) == .FLOOR) {
            self.player_pos = new_pos;
        }
    }
};

pub fn main() !void {
    sdlInit();
    const window = createWindow("zig-roguelike", 1920, 1080);
    checkPixelFormat(window);
    var surface = Surface.from_sdl_window(window);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var input_width: c_int = undefined;
    var input_height: c_int = undefined;
    var input_bytes_per_pixel: c_int = undefined;
    var input_data: [*]u8 = undefined;
    input_data = stb.stbi_load(@ptrCast("src/assets/16px_font.png"), &input_width, &input_height, &input_bytes_per_pixel, 0);

    const PLAYER_CHAR = '@';

    const char_map = try CharMap.load(
        input_data,
        .{ .width = @as(usize, @abs(input_width)), .height = @as(usize, @abs(input_height)) },
        @as(usize, @abs(input_bytes_per_pixel)),
        .{ .width = 16, .height = 16 },
        allocator,
    );
    stb.stbi_image_free(input_data);

    const tile_grid_dim: Dimensions = .{ .width = 60, .height = 30 };
    var rng = std.rand.DefaultPrng.init(@intCast(std.time.timestamp()));
    var random = rng.random();
    const ROOMS_PER_FLOOR = 3;
    const ROOM_MIN_SIZE = 4;
    const ROOM_MAX_SIZE = 12;
    var rooms: [ROOMS_PER_FLOOR]Rectangle = undefined;
    var rooms_count: usize = 0;
    var rooms_attempt_count: usize = 0;
    while (rooms_count < ROOMS_PER_FLOOR) : (rooms_attempt_count += 1) {
        if (rooms_attempt_count > 10_000) {
            // assume early placements have made it impossible to complete, abandon and restart
            rooms_count = 0;
            rooms_attempt_count = 0;
        }
        const new_room_x = random.uintLessThan(usize, tile_grid_dim.width - ROOM_MIN_SIZE) + 1;
        const new_room_y = random.uintLessThan(usize, tile_grid_dim.height - ROOM_MIN_SIZE) + 1;
        const new_room_height = random.uintAtMost(usize, ROOM_MAX_SIZE - ROOM_MIN_SIZE) + ROOM_MIN_SIZE;
        const new_room_width = random.uintAtMost(usize, ROOM_MAX_SIZE - ROOM_MIN_SIZE) + ROOM_MIN_SIZE;
        var new_room_valid = new_room_x + new_room_width < tile_grid_dim.width and new_room_y + new_room_height < tile_grid_dim.height;
        const new_room = Rectangle{
            .pos = .{ .x = new_room_x, .y = new_room_y },
            .dim = .{ .width = new_room_width, .height = new_room_height },
        };
        for (0..rooms_count) |i| {
            if (new_room.overlaps(rooms[i])) {
                new_room_valid = false;
                break;
            }
        }
        if (new_room_valid) {
            rooms[rooms_count] = new_room;
            rooms_count += 1;
        }
    }
    const player_initial_pos: Position = .{
        .x = random.uintLessThan(usize, rooms[0].dim.width) + rooms[0].pos.x,
        .y = random.uintLessThan(usize, rooms[0].dim.height) + rooms[0].pos.y,
    };
    var game_state: GameState = .{
        .tile_grid = try TileGrid.fill(tile_grid_dim, .WALL, allocator),
        .player_pos = player_initial_pos,
        .rooms = &rooms,
    };
    for (game_state.rooms, 0..) |room, i| {
        game_state.tile_grid.add_room(room);
        if (i > 0) {
            const room1x = random.uintLessThan(usize, rooms[i].dim.width) + rooms[i].pos.x;
            const room2x = random.uintLessThan(usize, rooms[i - 1].dim.width) + rooms[i - 1].pos.x;
            const room1y = random.uintLessThan(usize, rooms[i].dim.height) + rooms[i].pos.y;
            const room2y = random.uintLessThan(usize, rooms[i - 1].dim.height) + rooms[i - 1].pos.y;
            const corridor_x_start = @min(room1x, room2x);
            const corridor_x_end = @max(room1x, room2x);
            const corridor_y_start = @min(room1y, room2y);
            const corridor_y_end = @max(room1y, room2y);
            if (i % 2 == 0) {
                const corridor_across = Rectangle{
                    .pos = .{ .x = corridor_x_start, .y = corridor_y_start },
                    .dim = .{ .width = corridor_x_end - corridor_x_start, .height = 1 },
                };
                const corridor_up = Rectangle{
                    .pos = .{ .x = corridor_x_end, .y = corridor_y_start },
                    .dim = .{ .width = 1, .height = corridor_y_end - corridor_y_start },
                };
                game_state.tile_grid.add_room(corridor_across);
                game_state.tile_grid.add_room(corridor_up);
            } else {
                const corridor_up = Rectangle{
                    .pos = .{ .x = corridor_x_start, .y = corridor_y_start },
                    .dim = .{ .width = 1, .height = corridor_y_end - corridor_y_start },
                };
                const corridor_across = Rectangle{
                    .pos = .{ .x = corridor_x_start, .y = corridor_y_end },
                    .dim = .{ .width = corridor_x_end - corridor_x_start, .height = 1 },
                };
                game_state.tile_grid.add_room(corridor_up);
                game_state.tile_grid.add_room(corridor_across);
            }
        }
    }

    var running = true;
    var event: c.SDL_Event = undefined;
    const grid_pos = Position{ .x = 1, .y = 1 };
    const scale_factor = 2;
    while (running) {
        surface.clear();

        surface.drawGrid(
            grid_pos,
            char_map,
            game_state.tile_grid,
            scale_factor,
        );

        surface.drawTile(
            PLAYER_CHAR,
            grid_pos,
            game_state.player_pos,
            char_map,
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
                    c.SDLK_UP => game_state.handleMove(.{ .y = 1, .y_sign = .MINUS }),
                    c.SDLK_DOWN => game_state.handleMove(.{ .y = 1, .y_sign = .PLUS }),
                    c.SDLK_RIGHT => game_state.handleMove(.{ .x = 1, .x_sign = .PLUS }),
                    c.SDLK_LEFT => game_state.handleMove(.{ .x = 1, .x_sign = .MINUS }),
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
