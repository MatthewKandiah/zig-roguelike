[1mdiff --git a/src/main.zig b/src/main.zig[m
[1mindex beaf363..14a262c 100644[m
[1m--- a/src/main.zig[m
[1m+++ b/src/main.zig[m
[36m@@ -3,6 +3,32 @@[m [mconst c = @cImport({[m
     @cInclude("SDL2/SDL.h");[m
 });[m
 [m
[32m+[m[32mconst Surface = struct {[m
[32m+[m[32m    pixels: [*]u8,[m
[32m+[m[32m    width: u32,[m
[32m+[m[32m    height: u32,[m
[32m+[m
[32m+[m[32m    const Self = @This();[m
[32m+[m
[32m+[m[32m    fn from_sdl_window(window: *c.struct_SDL_Window) Self {[m
[32m+[m[32m        const surface: *c.struct_SDL_Surface = c.SDL_GetWindowSurface(window) orelse sdlPanic();[m
[32m+[m[32m        const pixels: [*]u8 = @ptrCast(surface.pixels orelse @panic("SDL surface has not allocated pixels"));[m
[32m+[m[32m        return Self{[m
[32m+[m[32m            .pixels = pixels,[m
[32m+[m[32m            .width = @intCast(surface.w),[m
[32m+[m[32m            .height = @intCast(surface.h),[m
[32m+[m[32m        };[m
[32m+[m[32m    }[m
[32m+[m
[32m+[m[32m    fn update(self: *Self, window: *c.struct_SDL_Window) void {[m
[32m+[m[32m        const surface: *c.struct_SDL_Surface = c.SDL_GetWindowSurface(window) orelse sdlPanic();[m
[32m+[m[32m        const pixels: [*]u8 = @ptrCast(surface.pixels orelse @panic("SDL surface has not allocated pixels"));[m
[32m+[m[32m        self.pixels = pixels;[m
[32m+[m[32m        self.width = @intCast(surface.w);[m
[32m+[m[32m        self.height = @intCast(surface.h);[m
[32m+[m[32m    }[m
[32m+[m[32m};[m
[32m+[m
 const Rectangle = struct {[m
     pos_x: u32,[m
     pos_y: u32,[m
[36m@@ -48,19 +74,6 @@[m [mfn sdlPanic() noreturn {[m
     std.debug.panic("{s}", .{sdl_error_string});[m
 }[m
 [m
[31m-fn safeAdd(x: u32, d: u32, max: u32) u32 {[m
[31m-    const result = x + d;[m
[31m-    if (result >= max) return max;[m
[31m-    return result;[m
[31m-}[m
[31m-[m
[31m-fn safeSub(x: u32, d: u32, min: u32) u32 {[m
[31m-    if (d >= x) return 0;[m
[31m-    const result = x - d;[m
[31m-    if (result <= min) return min;[m
[31m-    return result;[m
[31m-}[m
[31m-[m
 fn sdlInit() void {[m
     const sdl_init = c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_TIMER | c.SDL_INIT_EVENTS);[m
     if (sdl_init < 0) {[m
[36m@@ -89,63 +102,26 @@[m [mfn checkPixelFormat(window: *c.struct_SDL_Window) void {[m
 pub fn main() !void {[m
     sdlInit();[m
     const window = createWindow("zig-roguelike", 1920, 1080);[m
[31m-    var surface: *c.struct_SDL_Surface = c.SDL_GetWindowSurface(window) orelse sdlPanic();[m
     checkPixelFormat(window);[m
 [m
[31m-    var pixels: [*]u8 = @ptrCast(surface.pixels orelse @panic("Surface has not allocated pixels"));[m
[31m-    var surface_width: u32 = @intCast(surface.w);[m
[31m-    var surface_height: u32 = @intCast(surface.h);[m
[32m+[m[32m    var surface = Surface.from_sdl_window(window);[m
[32m+[m
     const tile_count_x: u32 = 80;[m
     const tile_count_y: u32 = 60;[m
[31m-    var tile_width: u32 = surface_width / tile_count_x;[m
[31m-    var tile_height: u32 = surface_height / tile_count_y;[m
[32m+[m[32m    var tile_width: u32 = surface.width / tile_count_x;[m
[32m+[m[32m    var tile_height: u32 = surface.height / tile_count_y;[m
 [m
     var running = true;[m
     var event: c.SDL_Event = undefined;[m
[31m-    var pos_x: u32 = 0;[m
[31m-    var pos_y: u32 = 0;[m
 [m
     while (running) {[m
[31m-        const whole_screen_rect = Rectangle{ .pos_x = 0, .pos_y = 0, .width = surface_width, .height = surface_height };[m
[32m+[m[32m        const whole_screen_rect = Rectangle{ .pos_x = 0, .pos_y = 0, .width = surface.width, .height = surface.height };[m
         whole_screen_rect.draw([m
[31m-            pixels,[m
[32m+[m[32m            surface.pixels,[m
             Colour.grey(clear_screen_colour_byte),[m
             4,[m
[31m-            surface_width,[m
[32m+[m[32m            surface.width,[m
         ); // clear[m
[31m-        for (0..tile_count_y) |j| {[m
[31m-            for (0..tile_count_x) |i| {[m
[31m-                const colour_value: u8 = if (@mod(i + j, 2) == 0) 255 else 0;[m
[31m-                const background_tile_rect = Rectangle{[m
[31m-                    .pos_x = @intCast(tile_width * i),[m
[31m-                    .pos_y = @intCast(tile_height * j),[m
[31m-                    .width = tile_width,[m
[31m-                    .height = tile_height,[m
[31m-                };[m
[31m-                background_tile_rect.draw([m
[31m-                    pixels,[m
[31m-                    Colour.grey(colour_value),[m
[31m-                    4,[m
[31m-                    surface_width,[m
[31m-                );[m
[31m-            }[m
[31m-        }[m
[31m-        const player_rect = Rectangle{[m
[31m-            .pos_x = pos_x,[m
[31m-            .pos_y = pos_y,[m
[31m-            .width = tile_width,[m
[31m-            .height = tile_height,[m
[31m-        };[m
[31m-        player_rect.draw([m
[31m-            pixels,[m
[31m-            .{[m
[31m-                .r = 255,[m
[31m-                .g = 0,[m
[31m-                .b = 255,[m
[31m-            },[m
[31m-            4,[m
[31m-            surface_width,[m
[31m-        ); // player[m
 [m
         if (c.SDL_UpdateWindowSurface(window) < 0) {[m
             sdlPanic();[m
[36m@@ -158,24 +134,14 @@[m [mpub fn main() !void {[m
             if (event.type == c.SDL_KEYDOWN) {[m
                 switch (event.key.keysym.sym) {[m
                     c.SDLK_ESCAPE => running = false,[m
[31m-                    c.SDLK_UP => pos_y = safeSub(pos_y, tile_height, 0),[m
[31m-                    c.SDLK_DOWN => pos_y = safeAdd(pos_y + tile_height, tile_height, surface_height) - tile_height,[m
[31m-                    c.SDLK_LEFT => pos_x = safeSub(pos_x, tile_width, 0),[m
[31m-                    c.SDLK_RIGHT => pos_x = safeAdd(pos_x + tile_width, tile_width, surface_width) - tile_width,[m
                     else => {},[m
                 }[m
             }[m
             if (event.type == c.SDL_WINDOWEVENT) {[m
[31m-                surface = c.SDL_GetWindowSurface(window) orelse sdlPanic();[m
[31m-                const updated_format = c.SDL_GetWindowPixelFormat(window);[m
[31m-                if (updated_format != c.SDL_PIXELFORMAT_RGB888) {[m
[31m-                    @panic("I've assumed RGB888 format so far, so expect wonky results if you push on!\n");[m
[31m-                }[m
[31m-                pixels = @ptrCast(surface.pixels orelse @panic("Surface has not allocated pixels"));[m
[31m-                surface_height = @intCast(surface.h);[m
[31m-                surface_width = @intCast(surface.w);[m
[31m-                tile_width = surface_width / tile_count_x;[m
[31m-                tile_height = surface_height / tile_count_y;[m
[32m+[m[32m                checkPixelFormat(window);[m
[32m+[m[32m                surface.update(window);[m
[32m+[m[32m                tile_width = surface.width / tile_count_x;[m
[32m+[m[32m                tile_height = surface.height / tile_count_y;[m
             }[m
         }[m
     }[m
