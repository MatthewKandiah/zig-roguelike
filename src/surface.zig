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

    // TODO - test
    // looks like char map loading works as expected, so the bug must be in the drawing logic
    // I think the bug only occurs for scale factor != 1, implies it's the scaling logic at fault
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
