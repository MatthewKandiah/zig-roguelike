const std = @import("std");
const Dimensions = @import("types.zig").Dimensions;
const DrawData = @import("types.zig").DrawData;
const BYTES_PER_PIXEL = @import("main.zig").BYTES_PER_PIXEL;

pub const CharMap = struct {
    data: []u8,
    dim: Dimensions,
    char_dim: Dimensions,

    const Self = @This();

    // TODO - our font asset is tiny, could its data be baked in at compile time?
    pub fn load(input_data: [*]u8, image_dim: Dimensions, input_bytes_per_pixel: usize, char_dim: Dimensions, allocator: std.mem.Allocator) !Self {
        var output_data = try allocator.alloc(u8, image_dim.area() * BYTES_PER_PIXEL);
        var output_index: usize = 0;
        for (0..image_dim.height / char_dim.height) |tile_j| {
            for (0..image_dim.width / char_dim.width) |tile_i| {
                for (0..char_dim.height) |pixel_j| {
                    for (0..char_dim.width) |pixel_i| {
                        // TODO - should these be reordered from bgrx to xrgb?
                        const pixel_index: usize = tile_i * char_dim.width + pixel_i + image_dim.width * (tile_j * char_dim.height + pixel_j);
                        if (input_bytes_per_pixel != 3) {
                            @panic("Input image using more than 3 channels, not supported yet");
                        }
                        output_data[output_index] = 0; // x
                        output_index += 1;
                        output_data[output_index] = input_data[input_bytes_per_pixel * pixel_index + 0]; // r
                        output_index += 1;
                        output_data[output_index] = input_data[input_bytes_per_pixel * pixel_index + 1]; // g
                        output_index += 1;
                        output_data[output_index] = input_data[input_bytes_per_pixel * pixel_index + 2]; // b
                        output_index += 1;
                    }
                }
            }
        }

        return Self{
            .data = output_data,
            .dim = image_dim,
            .char_dim = char_dim,
        };
    }

    pub fn drawData(self: Self, index: usize) DrawData {
        const byte_count = self.char_dim.area() * BYTES_PER_PIXEL;
        const start_index = index * self.char_dim.area() * BYTES_PER_PIXEL;
        return DrawData{
            .bytes = self.data[start_index .. start_index + byte_count],
            .width = self.char_dim.width,
        };
    }
};

const PngDataBuilder = @import("test-util/png-data-builder.zig").PngDataBuilder;
const TestConstants = @import("test-util/constants.zig");

test "load XRGB data from 3-channel RGB image data when character dimensions fit input perfectly" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const image_width = 100;
    const image_height = 10;
    const bytes_per_pixel = 3;
    const r = 100;
    const g = 200;
    const b = 50;
    const char_width = 5;
    const char_height = 2;
    try std.testing.expect(image_width % char_width == 0);
    try std.testing.expect(image_height % char_height == 0);
    var buffer: [image_width * image_height * bytes_per_pixel]u8 = undefined;
    const data_builder = PngDataBuilder.init(&buffer, .{ .width = image_width, .height = image_height }, bytes_per_pixel).fill(.{ .r = r, .g = g, .b = b });
    data_builder.generate_snapshot(TestConstants.SNAPSHOT_DIR ++ "load_XRGB_from_RGB_data_simple.png");

    const char_map = try CharMap.load(
        @ptrCast(data_builder.data),
        .{ .width = image_width, .height = image_height },
        bytes_per_pixel,
        .{ .width = char_width, .height = char_height },
        allocator,
    );

    for (0..image_width * image_height * bytes_per_pixel) |i| {
        const expected: u8 = switch (i % 4) {
            0 => 0,
            1 => r,
            2 => g,
            3 => b,
            else => unreachable,
        };
        errdefer std.debug.print("Test failed: i = {}\n", .{i});
        try std.testing.expectEqual(expected, char_map.data[i]);
    }
}

test "load XRGB data from 3-channel RGB image data when character dimensions do not fit input perfectly" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const image_width = 100;
    const image_height = 10;
    const bytes_per_pixel = 3;
    const r = 100;
    const g = 200;
    const b = 50;
    const char_width = 7;
    const char_height = 6;
    try std.testing.expect(image_width % char_width != 0);
    try std.testing.expect(image_height % char_height != 0);
    var buffer: [image_width * image_height * bytes_per_pixel]u8 = undefined;
    const data_builder = PngDataBuilder.init(&buffer, .{ .width = image_width, .height = image_height }, bytes_per_pixel).fill(.{ .r = r, .g = g, .b = b });
    data_builder.generate_snapshot(TestConstants.SNAPSHOT_DIR ++ "load_XRGB_from_RGB_data_simple.png");

    const char_map = try CharMap.load(
        @ptrCast(data_builder.data),
        .{ .width = image_width, .height = image_height },
        bytes_per_pixel,
        .{ .width = char_width, .height = char_height },
        allocator,
    );

    // this size is wrong if it's only reading in the pixels for the tiles
    // a border on the right and bottom won't be read in
    // in debug builds this shows up as a bunch of 0xAA bytes at the end of the buffer
    for (0..image_width * image_height * bytes_per_pixel) |i| {
        const expected: u8 = switch (i % 4) {
            0 => 0,
            1 => r,
            2 => g,
            3 => b,
            else => unreachable,
        };
        errdefer std.debug.print("Test failed: i = {}\n", .{i});
        try std.testing.expectEqual(expected, char_map.data[i]);
    }
}
