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
        for (0..draw_data.bytes.len) |byte_index| {
            for (0..scale_factor) |scale_j| {
                for (0..scale_factor) |scale_i| {
                    const x = byte_index % (draw_data.width * BYTES_PER_PIXEL);
                    const y = byte_index / (draw_data.width * BYTES_PER_PIXEL);
                    self.pixels[pos.x + (x * scale_factor) + scale_i + (self.width * BYTES_PER_PIXEL * (pos.y + (y * scale_factor) + scale_j))] = draw_data.bytes[byte_index];
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
