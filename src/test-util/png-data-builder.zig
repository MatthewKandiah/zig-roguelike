const std = @import("std");
const stb = @cImport({
    @cInclude("stb_image_write.h");
});
const Dimensions = @import("../types.zig").Dimensions;
const Colour = @import("../types.zig").Colour;

pub const PngDataBuilder = struct {
    data: []u8,
    dim: Dimensions,
    bytes_per_pixel: usize,

    const Self = @This();

    pub fn init(buffer: []u8, dim: Dimensions, bytes_per_pixel: usize) Self {
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

    pub fn fill(self: Self, colour: struct { r: u8 = 0, g: u8 = 0, b: u8 = 0, a: u8 = 0 }) Self {
        for (self.data, 0..) |*byte, i| {
            if (i % self.bytes_per_pixel == 0) {
                byte.* = colour.r;
            } else if (i % self.bytes_per_pixel == 1) {
                byte.* = colour.g;
            } else if (i % self.bytes_per_pixel == 2) {
                byte.* = colour.b;
            } else if (i % self.bytes_per_pixel == 3) {
                byte.* = colour.a;
            }
        }
        return self;
    }

    pub fn horizontal(self: Self, row: usize, colour: struct { r: u8 = 0, g: u8 = 0, b: u8 = 0, a: u8 = 0 }) Self {
        if (row >= self.dim.height) {
            std.debug.panic("PdfDataBuilder horizontal specifies row {} out of bounds given dimensions {}", .{ row, self.dim });
        }
        const row_start = row * self.bytes_per_pixel * self.dim.width;
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

    pub fn vertical(self: Self, col: usize, colour: struct { r: u8 = 0, g: u8 = 0, b: u8 = 0, a: u8 = 0 }) Self {
        if (col >= self.dim.width) {
            std.debug.panic("PdfDataBuilder vertical specifies column {} out of bounds given dimensions {}", .{ col, self.dim });
        }
        const col_start = col * self.bytes_per_pixel;
        for (0..self.dim.height) |i| {
            const idx = col_start + self.dim.width * self.bytes_per_pixel * i;
            self.data[idx] = colour.r;
            if (self.bytes_per_pixel >= 2) self.data[idx + 1] = colour.g;
            if (self.bytes_per_pixel >= 3) self.data[idx + 2] = colour.b;
            if (self.bytes_per_pixel >= 4) self.data[idx + 3] = colour.a;
        }
        return self;
    }

    pub fn generate_snapshot(self: Self, path: []const u8) void {
        const result = stb.stbi_write_png(@ptrCast(path), @intCast(self.dim.width), @intCast(self.dim.height), @intCast(self.bytes_per_pixel), @ptrCast(self.data.ptr), @intCast(self.dim.width * self.bytes_per_pixel));
        if (result == 0) {
            @panic("stb_image_write error: failed to generate snapshot image");
        }
    }
};
