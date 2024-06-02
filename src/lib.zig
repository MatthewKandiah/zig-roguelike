const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL_error.h");
});

pub fn sdlPanic() noreturn {
    const sdl_error_string = c.SDL_GetError();
    std.debug.panic("{s}", .{sdl_error_string});
}
