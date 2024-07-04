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
const bresenham = @import("bresenham.zig");

const MAX_ENEMIES = 10;

pub const EnemyState = enum {
    IDLE,
    IDLE_TRANSITION,
    ALERT,
    ALERT_TRANSITION,
    SEARCHING,
};

pub const EnemyData = struct {
    pos: Position,
    char: u8,
    state: EnemyState,

    const Self = @This();

    pub fn colour(self: Self) Colour {
        return switch (self.state) {
            .IDLE => Colour.green,
            .IDLE_TRANSITION => Colour.white,
            .ALERT => Colour.red,
            .ALERT_TRANSITION => Colour.blue,
            .SEARCHING => Colour.yellow,
        };
    }
};

pub const GameState = struct {
    // map data
    tile_grid: TileGrid,
    rooms: []Rectangle,
    // player data
    player_pos: Position,
    // enemy data
    enemy_count: usize,
    enemies: []EnemyData,

    const Self = @This();

    pub fn handleMove(self: *Self, delta: PositionDelta) void {
        const new_pos = self.player_pos.add(delta);
        if (self.tile_grid.get(new_pos) == .FLOOR) {
            self.player_pos = new_pos;
        }
    }

    // TODO - current plan is inefficient, can probably do something to avoid having to check every tile every tick
    pub fn updateVisibleTiles(self: *Self, allocator: std.mem.Allocator) !void {
        for (0..self.tile_grid.dim.height) |j| {
            tile_loop: for (0..self.tile_grid.dim.width) |i| {
                const tile_pos = Position{ .x = i, .y = j };
                const ray = try bresenham.plotLine(.{ .x = i, .y = j }, self.player_pos, allocator);
                for (ray, 0..) |pos, k| {
                    if (k == 0 or k == ray.len - 1) {
                        continue;
                    }
                    if (self.tile_grid.get(pos) == .WALL) {
                        self.tile_grid.is_tile_visible[self.tile_grid.posToIndex(.{ .x = i, .y = j })] = false;
                        if (self.findEnemyIndex(tile_pos)) |idx| {
                            self.updateNonVisibleEnemyState(idx);
                        }
                        continue :tile_loop;
                    }
                }
                self.tile_grid.is_tile_visible[self.tile_grid.posToIndex(tile_pos)] = true;
                if (self.findEnemyIndex(tile_pos)) |idx| {
                    self.updateVisibleEnemyState(idx);
                }
                self.tile_grid.seen_tiles[self.tile_grid.posToIndex(.{ .x = i, .y = j })] = self.tile_grid.tiles[self.tile_grid.posToIndex(.{ .x = i, .y = j })];
            }
        }
    }

    fn findEnemyIndex(self: Self, pos: Position) ?usize {
        for (self.enemies, 0..) |enemy, i| {
            if (enemy.pos.x == pos.x and enemy.pos.y == pos.y) {
                return i;
            }
        }
        return null;
    }

    fn updateNonVisibleEnemyState(self: Self, enemyIndex: usize) void {
        self.enemies[enemyIndex].state = switch (self.enemies[enemyIndex].state) {
            .IDLE => .IDLE,
            .IDLE_TRANSITION => .IDLE,
            .ALERT => .ALERT_TRANSITION,
            .ALERT_TRANSITION => .SEARCHING,
            .SEARCHING => .SEARCHING,
        };
    }

    fn updateVisibleEnemyState(self: Self, enemyIndex: usize) void {
        self.enemies[enemyIndex].state = switch (self.enemies[enemyIndex].state) {
            .IDLE => .IDLE_TRANSITION,
            .IDLE_TRANSITION => .ALERT,
            .ALERT => .ALERT,
            .ALERT_TRANSITION => .ALERT,
            .SEARCHING => .ALERT_TRANSITION,
        };
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
    const random_seed: u64 = @intCast(std.time.timestamp());
    var rng = std.rand.DefaultPrng.init(random_seed);
    var random = rng.random();
    const ROOMS_PER_FLOOR = 12;
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
    const enemies = try allocator.alloc(EnemyData, MAX_ENEMIES);
    var game_state: GameState = .{
        .tile_grid = try TileGrid.fill(tile_grid_dim, .WALL, allocator),
        .player_pos = player_initial_pos,
        .rooms = &rooms,
        .enemy_count = 0,
        .enemies = enemies,
    };
    for (game_state.rooms, 0..) |room, i| {
        // draw room
        game_state.tile_grid.addRectangle(room);
        // draw corridors
        const room2_index = if (i > 0) i - 1 else ROOMS_PER_FLOOR - 1;
        const room1 = rooms[i];
        const room2 = rooms[room2_index];
        const room1x = random.uintLessThan(usize, room1.dim.width) + room1.pos.x;
        const room2x = random.uintLessThan(usize, room2.dim.width) + room2.pos.x;
        const room1y = random.uintLessThan(usize, room1.dim.height) + room1.pos.y;
        const room2y = random.uintLessThan(usize, room2.dim.height) + room2.pos.y;
        const corridor_x_start = @min(room1x, room2x);
        const corridor_x_end = @max(room1x, room2x);
        const corridor_y_start = @min(room1y, room2y);
        const corridor_y_end = @max(room1y, room2y);
        if (i % 2 == 0) {
            const corridor_across = Rectangle{
                .pos = .{ .x = corridor_x_start, .y = room1y },
                .dim = .{ .width = corridor_x_end - corridor_x_start, .height = 1 },
            };
            const corridor_up = Rectangle{
                .pos = .{ .x = room2x, .y = corridor_y_start },
                .dim = .{ .width = 1, .height = corridor_y_end - corridor_y_start },
            };
            game_state.tile_grid.addRectangle(corridor_across);
            game_state.tile_grid.addRectangle(corridor_up);
        } else {
            const corridor_up = Rectangle{
                .pos = .{ .x = room1x, .y = corridor_y_start },
                .dim = .{ .width = 1, .height = corridor_y_end - corridor_y_start },
            };
            const corridor_across = Rectangle{
                .pos = .{ .x = corridor_x_start, .y = room2y },
                .dim = .{ .width = corridor_x_end - corridor_x_start, .height = 1 },
            };
            game_state.tile_grid.addRectangle(corridor_up);
            game_state.tile_grid.addRectangle(corridor_across);
        }
        // spawn enemies
        if (i > 0 and i < MAX_ENEMIES) {
            game_state.enemies[game_state.enemy_count] = EnemyData{
                .pos = room.centre(),
                .char = 'g',
                .state = .IDLE,
            };
            game_state.enemy_count += 1;
        }
    }

    var running = true;
    var event: c.SDL_Event = undefined;
    const grid_pos = Position{ .x = 1, .y = 1 };
    const scale_factor = 2;
    while (running) {
        surface.clear();

        try game_state.updateVisibleTiles(allocator);

        try surface.drawGrid(
            grid_pos,
            char_map,
            game_state.tile_grid,
            scale_factor,
            allocator,
        );

        try surface.drawTileOverloadColour(
            PLAYER_CHAR,
            grid_pos,
            game_state.player_pos,
            char_map,
            scale_factor,
            Colour.yellow,
            allocator,
        );

        for (0..game_state.enemy_count) |i| {
            const enemy = game_state.enemies[i];
            if (game_state.tile_grid.visible(enemy.pos)) {
                try surface.drawTileOverloadColour(
                    enemy.char,
                    grid_pos,
                    enemy.pos,
                    char_map,
                    scale_factor,
                    enemy.colour(),
                    allocator,
                );
            }
        }

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
