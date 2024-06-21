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
                output_pixel_index += self.width - (draw_data.width * scale_factor) + 1;
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
