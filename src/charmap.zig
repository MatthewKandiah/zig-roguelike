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

test "load XRGB data from 3-channel RGB image data" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const width = 100;
    const height = 10;
    const bytes_per_pixel = 3;
    const r = 100;
    const g = 200;
    const b = 50;
    var buffer: [width * height * bytes_per_pixel]u8 = undefined;
    const data_builder = PngDataBuilder.init(&buffer, .{ .width = width, .height = height }, bytes_per_pixel).fill(.{ .r = r, .g = g, .b = b });
    data_builder.generate_snapshot(TestConstants.SNAPSHOT_DIR ++ "load_XRGB_from_RGB_data.png");

    const char_map = try CharMap.load(@ptrCast(data_builder.data), .{ .width = width, .height = height }, bytes_per_pixel, .{ .width = 5, .height = 6 }, allocator);

    try std.testing.expectEqual(5, char_map.char_dim.width);
    try std.testing.expectEqual(6, char_map.char_dim.height);
    for (0..width * height * bytes_per_pixel) |i| {
        const expected: u8 = if (i % 4 == 0) 0 else if (i % 4 == 1) r else if (i % 4 == 2) g else if (i % 4 == 3) b else unreachable;
        try std.testing.expectEqual(expected, char_map.data[i]);
    }
}
