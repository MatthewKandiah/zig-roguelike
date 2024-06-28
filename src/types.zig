const std = @import("std");
const BYTES_PER_PIXEL = @import("main.zig").BYTES_PER_PIXEL;

pub const DrawData = struct {
    bytes: []u8,
    width: usize,

    const Self = @This();

    pub fn overloadColour(self: Self, colour: Colour, allocator: std.mem.Allocator) !Self {
        var result = try allocator.alloc(u8, self.bytes.len);
        for (0..self.bytes.len / BYTES_PER_PIXEL) |i| {
            const r = self.bytes[BYTES_PER_PIXEL * i + 1];
            const g = self.bytes[BYTES_PER_PIXEL * i + 2];
            const b = self.bytes[BYTES_PER_PIXEL * i + 3];
            const shouldDraw = r != 0 or g != 0 or b != 0;
            if (shouldDraw) {
                result[BYTES_PER_PIXEL * i] = 0;
                result[BYTES_PER_PIXEL * i + 1] = colour.r;
                result[BYTES_PER_PIXEL * i + 2] = colour.g;
                result[BYTES_PER_PIXEL * i + 3] = colour.b;
            } else {
                result[BYTES_PER_PIXEL * i] = 0;
                result[BYTES_PER_PIXEL * i + 1] = 0;
                result[BYTES_PER_PIXEL * i + 2] = 0;
                result[BYTES_PER_PIXEL * i + 3] = 0;
            }
        }
        return Self{ .bytes = result, .width = self.width };
    }
};

pub const Position = struct {
    x: usize,
    y: usize,

    const Self = @This();

    pub fn add(self: Self, delta: PositionDelta) Self {
        const new_x = switch (delta.x_sign) {
            .PLUS => self.x + delta.x,
            .MINUS => self.x - delta.x,
        };
        const new_y = switch (delta.y_sign) {
            .PLUS => self.y + delta.y,
            .MINUS => self.y - delta.y,
        };
        return .{ .x = new_x, .y = new_y };
    }
};

pub const Sign = enum { PLUS, MINUS };

pub const PositionDelta = struct { x: usize = 0, x_sign: Sign = .PLUS, y: usize = 0, y_sign: Sign = .PLUS };

pub const Dimensions = struct {
    width: usize,
    height: usize,

    const Self = @This();

    pub fn area(self: Self) usize {
        return self.width * self.height;
    }
};

pub const Rectangle = struct {
    pos: Position,
    dim: Dimensions,

    const Self = @This();

    pub fn left(self: Self) usize {
        return self.pos.x;
    }

    pub fn right(self: Self) usize {
        return self.pos.x + self.dim.width;
    }

    // NOTE - top as you look at it => lower y-value than bottom
    //        so be careful with comparisons
    pub fn top(self: Self) usize {
        return self.pos.y;
    }

    pub fn bottom(self: Self) usize {
        return self.pos.y + self.dim.height;
    }

    pub fn overlaps(self: Self, rect: Rectangle) bool {
        return self.left() <= rect.right() and self.right() >= rect.left() and self.top() <= rect.bottom() and self.bottom() >= rect.top();
    }
};

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

pub const TileGrid = struct {
    tiles: []Tile,
    is_tile_visible: []bool,
    seen_tiles: []?Tile,
    dim: Dimensions,

    const Self = @This();

    pub fn posToIndex(self: Self, pos: Position) usize {
        return pos.x + self.dim.width * pos.y;
    }

    pub fn get(self: Self, pos: Position) Tile {
        return self.tiles[self.posToIndex(pos)];
    }

    pub fn visible(self: Self, pos: Position) bool {
        return self.is_tile_visible[self.posToIndex(pos)];
    }

    pub fn seen(self: Self, pos: Position) ?Tile {
        return self.seen_tiles[self.posToIndex(pos)];
    }

    pub fn fill(dim: Dimensions, tile: Tile, allocator: std.mem.Allocator) !Self {
        const tiles = try allocator.alloc(Tile, dim.area());
        const vis = try allocator.alloc(bool, dim.area());
        const seen_tiles = try allocator.alloc(?Tile, dim.area());
        for (0..dim.area()) |i| {
            tiles[i] = tile;
            vis[i] = false;
            seen_tiles[i] = null;
        }
        return Self{
            .dim = dim,
            .tiles = tiles,
            .is_tile_visible = vis,
            .seen_tiles = seen_tiles,
        };
    }

    pub fn addRectangle(self: *Self, room: Rectangle) void {
        for (0..room.dim.height) |j| {
            for (0..room.dim.width) |i| {
                self.tiles[room.pos.x + i + (room.pos.y + j) * self.dim.width] = .FLOOR;
            }
        }
    }
};

pub const Tile = enum {
    WALL,
    FLOOR,

    const Self = @This();

    pub fn toU8(self: Self) u8 {
        return switch (self) {
            .WALL => '#',
            .FLOOR => '.',
        };
    }
};
