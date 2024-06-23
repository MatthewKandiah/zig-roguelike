const std = @import("std");

pub const DrawData = struct {
    bytes: []u8,
    width: usize,
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
    dim: Dimensions,

    const Self = @This();

    pub fn get(self: Self, pos: Position) Tile {
        return self.tiles[pos.x + self.dim.width * pos.y];
    }

    pub fn fill(dim: Dimensions, tile: Tile, allocator: std.mem.Allocator) !Self {
        const tiles = try allocator.alloc(Tile, dim.area());
        for (tiles) |*t| {
            t.* = tile;
        }
        return Self{
            .dim = dim,
            .tiles = tiles,
        };
    }

    pub fn add_room(self: *Self, room: Rectangle) void {
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
