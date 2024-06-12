const Colour = @import("colour.zig").Colour;

pub const Rectangle = struct {
    pos_x: u32,
    pos_y: u32,
    width: u32,
    height: u32,

    const Self = @This();

    pub fn draw(
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
