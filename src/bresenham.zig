const std = @import("std");
const Position = @import("types.zig").Position;

// octant where gradient is between 0 and 1
fn plotLineLowPos(p0: Position, p1: Position, allocator: std.mem.Allocator) ![]Position {
    const dx = p1.x - p0.x;
    const dy = p1.y - p0.y;
    var D = 2 * dy - dx;
    var y = p0.y;

    var result = try allocator.alloc(Position, p1.x - p0.x + 1);
    for (p0.x..p1.x + 1, 0..) |x, i| {
        result[i] = Position{ .x = x, .y = y };
        D += 2 * dy;
        if (D - 2 * dy > 0) {
            y += 1;
            D -= 2 * dx;
        }
    }
    return result;
}

test "should work where gradient is between 0 and 1" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const p0 = Position{ .x = 0, .y = 1 };
    const p1 = Position{ .x = 6, .y = 4 };

    const result = try plotLineLowPos(p0, p1, allocator);

    const expected = [_]Position{
        .{ .x = 0, .y = 1 },
        .{ .x = 1, .y = 1 },
        .{ .x = 2, .y = 2 },
        .{ .x = 3, .y = 2 },
        .{ .x = 4, .y = 3 },
        .{ .x = 5, .y = 3 },
        .{ .x = 6, .y = 4 },
    };
    try std.testing.expectEqualSlices(Position, &expected, result);
}

// octant where gradient is between -1 and 0
fn plotLineLowNeg(p0: Position, p1: Position, allocator: std.mem.Allocator) ![]Position {
    const dx = p1.x - p0.x;
    const dy = p0.y - p1.y;
    var D = 2 * dy - dx;
    var y = p0.y;

    var result = try allocator.alloc(Position, p1.x - p0.x + 1);
    for (p0.x..p1.x + 1, 0..) |x, i| {
        result[i] = Position{ .x = x, .y = y };
        D += 2 * dy;
        if (D - 2 * dy > 0) {
            y -= 1;
            D -= 2 * dx;
        }
    }
    return result;
}

test "should work where gradient is between -1 and 0" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const p0 = Position{ .x = 0, .y = 4 };
    const p1 = Position{ .x = 6, .y = 1 };

    const result = try plotLineLowNeg(p0, p1, allocator);

    const expected = [_]Position{
        .{ .x = 0, .y = 4 },
        .{ .x = 1, .y = 4 },
        .{ .x = 2, .y = 3 },
        .{ .x = 3, .y = 3 },
        .{ .x = 4, .y = 2 },
        .{ .x = 5, .y = 2 },
        .{ .x = 6, .y = 1 },
    };
    try std.testing.expectEqualSlices(Position, &expected, result);
}

// octant where gradient is greater than 1
fn plotLineHighPos(p0: Position, p1: Position, allocator: std.mem.Allocator) ![]Position {
    const dx = p1.x - p0.x;
    const dy = p1.y - p0.y;
    var D = 2 * dx - dy;
    var x = p0.x;

    var result = try allocator.alloc(Position, p1.y - p0.y + 1);
    for (p0.y..p1.y + 1, 0..) |y, i| {
        result[i] = Position{ .x = x, .y = y };
        D += 2 * dx;
        if (D - 2 * dx > 0) {
            x += 1;
            D -= 2 * dy;
        }
    }
    return result;
}

test "should work where gradient is between 1 and infinity" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const p0 = Position{ .x = 1, .y = 0 };
    const p1 = Position{ .x = 4, .y = 6 };

    const result = try plotLineHighPos(p0, p1, allocator);

    const expected = [_]Position{
        .{ .x = 1, .y = 0 },
        .{ .x = 1, .y = 1 },
        .{ .x = 2, .y = 2 },
        .{ .x = 2, .y = 3 },
        .{ .x = 3, .y = 4 },
        .{ .x = 3, .y = 5 },
        .{ .x = 4, .y = 6 },
    };
    try std.testing.expectEqualSlices(Position, &expected, result);
}

// octant where gradient is less than -1
fn plotLineHighNeg(p0: Position, p1: Position, allocator: std.mem.Allocator) ![]Position {
    const dx = p0.x - p1.x;
    const dy = p1.y - p0.y;
    var D = 2 * dx - dy;
    var x = p0.x;

    var result = try allocator.alloc(Position, p1.y - p0.y + 1);
    for (p0.y..p1.y + 1, 0..) |y, i| {
        result[i] = Position{ .x = x, .y = y };
        D += 2 * dx;
        if (D - 2 * dx > 0) {
            x -= 1;
            D -= 2 * dy;
        }
    }
    return result;
}

test "should work where gradient is between -1 and -infinity" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const p0 = Position{ .x = 4, .y = 0 };
    const p1 = Position{ .x = 1, .y = 6 };

    const result = try plotLineHighNeg(p0, p1, allocator);

    const expected = [_]Position{
        .{ .x = 4, .y = 0 },
        .{ .x = 4, .y = 1 },
        .{ .x = 3, .y = 2 },
        .{ .x = 3, .y = 3 },
        .{ .x = 2, .y = 4 },
        .{ .x = 2, .y = 5 },
        .{ .x = 1, .y = 6 },
    };
    try std.testing.expectEqualSlices(Position, &expected, result);
}
