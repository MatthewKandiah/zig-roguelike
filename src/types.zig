pub const DrawData = struct {
    bytes: []u8,
    width: usize,
};

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

pub const TileGrid = struct {
    tiles: []const Tile,
    dim: Dimensions,

    const Self = @This();

    pub fn get(self: Self, pos: Position) Tile {
        return self.tiles[pos.x + self.dim.width * pos.y];
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
