const std = @import("std");
const Position = @import("types.zig").Position;

pub fn plotLine(p0: Position, p1: Position, allocator: std.mem.Allocator) ![]Position {
    const x0: i32 = @intCast(p0.x);
    const x1: i32 = @intCast(p1.x);
    const y0: i32 = @intCast(p0.y);
    const y1: i32 = @intCast(p1.y);

    if (@abs(y1 - y0) < @abs(x1 - x0)) {
        if (x0 > x1) {
            return plotLineLow(x1, y1, x0, y0, allocator);
        } else {
            return plotLineLow(x0, y0, x1, y1, allocator);
        }
    } else {
        if (y0 > y1) {
            return plotLineHigh(x1, y1, x0, y0, allocator);
        } else {
            return plotLineHigh(x0, y0, x1, y1, allocator);
        }
    }
}

pub fn plotLineLow(
    x_left: i32,
    y_left: i32,
    x_right: i32,
    y_right: i32,
    allocator: std.mem.Allocator,
) ![]Position {
    var result = try allocator.alloc(Position, @intCast(x_right - x_left + 1));
    const dx = x_right - x_left;
    var dy = y_right - y_left;
    var yi: i32 = 1;
    if (dy < 0) {
        yi = -1;
        dy = -dy;
    }
    var D = 2 * dy - dx;
    var y = y_left;

    for (0..@intCast(x_right - x_left + 1)) |i| {
        const i_i32: i32 = @intCast(i);
        const x: i32 = x_left + i_i32;
        result[i] = Position{ .x = @intCast(x), .y = @intCast(y) };
        if (D > 0) {
            y += yi;
            D += 2 * (dy - dx);
        } else {
            D += 2 * dy;
        }
    }
    return result;
}

pub fn plotLineHigh(
    x_low: i32,
    y_low: i32,
    x_high: i32,
    y_high: i32,
    allocator: std.mem.Allocator,
) ![]Position {
    var result = try allocator.alloc(Position, @intCast(y_high - y_low + 1));
    var dx = x_high - x_low;
    const dy = y_high - y_low;
    var xi: i32 = 1;
    if (dx < 0) {
        xi = -1;
        dx = -dx;
    }
    var D = 2 * dx - dy;
    var x = x_low;

    for (0..@intCast(y_high - y_low + 1)) |i| {
        const i_i32: i32 = @intCast(i);
        const y: i32 = y_low + i_i32;
        result[i] = Position{ .x = @intCast(x), .y = @intCast(y) };
        if (D > 0) {
            x += xi;
            D += 2 * (dx - dy);
        } else {
            D += 2 * dx;
        }
    }
    return result;
}
