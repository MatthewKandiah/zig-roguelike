const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
const stb = @cImport({
    @cInclude("stb_image.h");
});
const sdlPanic = @import("main.zig").sdlPanic;
const DrawData = @import("types.zig").DrawData;
const Position = @import("types.zig").Position;
const BYTES_PER_PIXEL = @import("main.zig").BYTES_PER_PIXEL;

pub const Surface = struct {
    pixels: [*]u8,
    width: usize,
    height: usize,

    const Self = @This();

    pub fn from_sdl_window(window: *c.struct_SDL_Window) Self {
        const surface: *c.struct_SDL_Surface = c.SDL_GetWindowSurface(window) orelse sdlPanic();
        const pixels: [*]u8 = @ptrCast(surface.pixels orelse @panic("SDL surface has not allocated pixels"));
        return Self{
            .pixels = pixels,
            .width = @intCast(surface.w),
            .height = @intCast(surface.h),
        };
    }

    pub fn update(self: *Self, window: *c.struct_SDL_Window) void {
        const surface: *c.struct_SDL_Surface = c.SDL_GetWindowSurface(window) orelse sdlPanic();
        const pixels: [*]u8 = @ptrCast(surface.pixels orelse @panic("SDL surface has not allocated pixels"));
        self.pixels = pixels;
        self.width = @intCast(surface.w);
        self.height = @intCast(surface.h);
    }

    pub fn draw(self: Self, draw_data: DrawData, pos: Position, scale_factor: usize) void {
        const total_pixels_to_draw = scale_factor * scale_factor * draw_data.bytes.len / BYTES_PER_PIXEL;
        var pixels_drawn: usize = 0;
        var output_pixel_index: usize = pos.x + pos.y * self.width;
        var input_pixel_index: usize = 0;
        var pixels_drawn_on_this_line: usize = 0;
        var scale_repeats_x: usize = 0;
        var scale_repeats_y: usize = 0;
        while (pixels_drawn < total_pixels_to_draw) : (pixels_drawn += 1) {
            self.pixels[BYTES_PER_PIXEL * output_pixel_index + 0] = draw_data.bytes[BYTES_PER_PIXEL * input_pixel_index + 3];
            self.pixels[BYTES_PER_PIXEL * output_pixel_index + 1] = draw_data.bytes[BYTES_PER_PIXEL * input_pixel_index + 2];
            self.pixels[BYTES_PER_PIXEL * output_pixel_index + 2] = draw_data.bytes[BYTES_PER_PIXEL * input_pixel_index + 1];
            self.pixels[BYTES_PER_PIXEL * output_pixel_index + 3] = draw_data.bytes[BYTES_PER_PIXEL * input_pixel_index + 0];
            if (pixels_drawn_on_this_line + 1 < draw_data.width * scale_factor) {
                pixels_drawn_on_this_line += 1;
                output_pixel_index += 1;
                if (scale_repeats_x + 1 < scale_factor) {
                    scale_repeats_x += 1;
                } else {
                    scale_repeats_x = 0;
                    input_pixel_index += 1;
                }
            } else {
                pixels_drawn_on_this_line = 0;
                scale_repeats_x = 0;
                output_pixel_index += self.width - (draw_data.width * scale_factor);
                if (scale_repeats_y + 1 < scale_factor) {
                    scale_repeats_y += 1;
                    input_pixel_index = input_pixel_index + 1 - draw_data.width;
                } else {
                    scale_repeats_y = 0;
                    input_pixel_index += 1;
                }
            }
        }
    }
};

test "it should draw row with scale 1" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const pixels = try allocator.alloc(u8, 4000);
    for (pixels) |*p| {
        p.* = 0;
    }
    const surface = Surface{
        .pixels = @ptrCast(pixels),
        .width = 100,
        .height = 10,
    };
    var bytes: [400]u8 = undefined;
    for (0..400) |i| {
        bytes[i] = @intCast(i % 256);
    }
    const draw_data = DrawData{ .bytes = &bytes, .width = 100 };

    surface.draw(draw_data, .{ .x = 0, .y = 0 }, 1);

    for (0..4000) |i| {
        const expected = if (i < 400) i % 256 else 0;
        errdefer std.debug.print("Test failed in first loop: i = {}\n", .{i});
        try std.testing.expectEqual(expected, surface.pixels[i]);
    }

    surface.draw(draw_data, .{ .x = 0, .y = 5 }, 1);

    for (0..4000) |i| {
        const expected = if (i < 400) i % 256 else if (i >= 2000 and i < 2400) (i - 2000) % 256 else 0;
        errdefer std.debug.print("Test failed in second loop: i = {}\n", .{i});
        try std.testing.expectEqual(expected, surface.pixels[i]);
    }
}

test "it should draw block with scale 1" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const pixels = try allocator.alloc(u8, 4000);
    for (pixels) |*p| {
        p.* = 0;
    }
    const surface = Surface{
        .pixels = @ptrCast(pixels),
        .width = 100,
        .height = 10,
    };
    var bytes: [400]u8 = undefined;
    for (0..400) |i| {
        bytes[i] = @intCast(i % 256);
    }
    const draw_data = DrawData{ .bytes = &bytes, .width = 10 };

    surface.draw(draw_data, .{ .x = 0, .y = 0 }, 1);

    var seen: usize = 0;
    for (0..4000) |i| {
        var expected: usize = 0;
        if (i < 40 //
        or (i >= 400 and i < 440) //
        or (i >= 800 and i < 840) //
        or (i >= 1200 and i < 1240) //
        or (i >= 1600 and i < 1640) //
        or (i >= 2000 and i < 2040) //
        or (i >= 2400 and i < 2440) //
        or (i >= 2800 and i < 2840) //
        or (i >= 3200 and i < 3240) //
        or (i >= 3600 and i < 3640)) {
            expected = seen % 256;
            seen += 1;
        }
        errdefer std.debug.print("Test failed: i = {}\n", .{i});
        try std.testing.expectEqual(expected, surface.pixels[i]);
    }
}

test "it should draw block with scale >1" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const pixels = try allocator.alloc(u8, 4000);
    for (pixels) |*p| {
        p.* = 0;
    }
    const surface = Surface{
        .pixels = @ptrCast(pixels),
        .width = 100,
        .height = 10,
    };
    var bytes: [400]u8 = undefined;
    for (0..400) |i| {
        bytes[i] = @intCast(i % 256);
    }
    const draw_data = DrawData{ .bytes = &bytes, .width = 10 };

    surface.draw(draw_data, .{ .x = 0, .y = 0 }, 3);

    var seen: usize = 0;
    var seen_count: usize = 0;
    for (0..4000) |i| {
        var expected: usize = 0;
        if (i < 120 //
        or (i >= 400 and i < 520) //
        or (i >= 800 and i < 920) //
        or (i >= 1200 and i < 1320) //
        or (i >= 1600 and i < 1720) //
        or (i >= 2000 and i < 2120) //
        or (i >= 2400 and i < 2420) //
        or (i >= 2800 and i < 2820) //
        or (i >= 3200 and i < 3220) //
        or (i >= 3600 and i < 3720) //
        or (i >= 4000 and i < 4120) //
        or (i >= 4400 and i < 4520) //
        or (i >= 4800 and i < 4920) //
        or (i >= 5200 and i < 5320) //
        or (i >= 5600 and i < 5720) //
        or (i >= 6000 and i < 6120) //
        or (i >= 6400 and i < 6420) //
        or (i >= 6800 and i < 6820) //
        or (i >= 7200 and i < 7220) //
        or (i >= 7600 and i < 7720) //
        or (i >= 8000 and i < 8120) //
        or (i >= 8400 and i < 8520) //
        or (i >= 8800 and i < 8920) //
        or (i >= 9200 and i < 9320) //
        or (i >= 9600 and i < 9720) //
        or (i >= 10000 and i < 10120) //
        or (i >= 10400 and i < 10420) //
        or (i >= 10800 and i < 10820) //
        or (i >= 11200 and i < 11220) //
        or (i >= 11600 and i < 11720)) {
            expected = seen % 256;
            seen_count += 1;
            if (seen_count == 3) {
                seen_count = 0;
                seen += 1;
            }
        }
        errdefer std.debug.print("Test failed: i = {}\n", .{i});
        try std.testing.expectEqual(expected, surface.pixels[i]);
    }
}
