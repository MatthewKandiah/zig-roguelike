const std = @import("std");
const Dimensions = @import("../main.zig").Dimensions;
const Colour = @import("../main.zig").Colour;

const PdfDataBuilder = struct {
    data: []u8,
    dim: Dimensions,
    bytes_per_pixel: usize,

    const Self = @This();

    fn init(buffer: []u8, dim: Dimensions, bytes_per_pixel: usize) Self {
        if (buffer.len % bytes_per_pixel != 0) {
            std.debug.panic("PdfDataBuilder buffer length {} is not a multiple of its bytes_per_pixel {}", .{ buffer.len, bytes_per_pixel });
        }
        if (buffer.len != bytes_per_pixel * dim.area()) {
            std.debug.panic("PdfDataBuilder buffer length {} is not equal to expected number of pixels for bytes per pixel {} and area {}", .{ buffer.len, bytes_per_pixel, dim.area() });
        }
        return Self{
            .data = buffer,
            .dim = dim,
            .bytes_per_pixel = bytes_per_pixel,
        };
    }

    fn fill(self: Self, colour: struct { r: usize = 0, g: usize = 0, b: usize = 0, a: usize = 0 }) Self {
        for (self.data, 0..) |*byte, i| {
            if (i % self.bytes_per_pixel == 0) {
                byte = colour.r;
            } else if (i % self.bytes_per_pixel == 1) {
                byte = colour.g;
            } else if (i % self.bytes_per_pixel == 2) {
                byte = colour.b;
            } else if (i % self.bytes_per_pixel == 3) {
                byte = colour.a;
            }
        }
        return self;
    }

    fn horizontal(self: Self, row: usize, colour: struct { r: usize = 0, g: usize = 0, b: usize = 0, a: usize = 0 }) Self {
        if (row >= self.dim.height) {
            std.debug.panic("PdfDataBuilder horizontal specifies row {} out of bounds given dimensions {}", .{ row, self.dim });
        }
        const row_start = row * self.bytes_per_pixel * self.width;
        for (0..self.dim.width * self.bytes_per_pixel) |i| {
            if (i % self.bytes_per_pixel == 0) {
                self.data[row_start + i] = colour.r;
            } else if (i % self.bytes_per_pixel == 1) {
                self.data[row_start + i] = colour.g;
            } else if (i % self.bytes_per_pixel == 2) {
                self.data[row_start + i] = colour.b;
            } else if (i % self.bytes_per_pixel == 3) {
                self.data[row_start + i] = colour.a;
            }
        }
        return self;
    }

    fn vertical(self: Self, col: usize, colour: struct { r: usize = 0, g: usize = 0, b: usize = 0, a: usize = 0 }) Self {
        if (col >= self.dim.width) {
            std.debug.panic("PdfDataBuilder vertical specifies column {} out of bounds given dimensions {}", .{ col, self.dim });
        }
        const col_start = col * self.bytes_per_pixel;
        for (0..self.height) |i| {
            const idx = col_start + self.width * self.bytes_per_pixel * i;
            self.data[idx] = colour.r;
            if (self.bytes_per_pixel >= 2) self.data[idx + 1] = colour.g;
            if (self.bytes_per_pixel >= 3) self.data[idx + 2] = colour.b;
            if (self.bytes_per_pixel >= 4) self.data[idx + 3] = colour.a;
        }
        return self;
    }
};
