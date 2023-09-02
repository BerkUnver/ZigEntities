const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const game = @import("entity.zig");

pub fn main() !void {
    var GPA = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = std.heap.page_allocator;
    defer _ = GPA.deinit();

    var world = game.World.init(allocator);
    defer world.deinit();

    var player = try allocator.create(game.Player);
    var entity_id = try world.entity_add(game.Player, player);
    var entity_retrieved = world.entity_get(entity_id) orelse {
        print("Could not retrieve the entity!\n", .{});
        return;
    };
    var player_retrieved = entity_retrieved.cast(game.Player) orelse {
        print("Entity retrieved is not a player!", .{});
        return;
    };
    print("Entity ptrs equivalent: {any}\n", .{player == player_retrieved});
}

// pub fn Array(comptime T: type) type {
//     return struct {
//         const Self = @This();
//
//         items: ?*T,
//         count: i32,
//         count_allocated: i32,
//         allocator: Allocator,
//
//         pub fn new(a: Allocator) Self {
//             return .{
//                 .items = null,
//                 .count = 0,
//                 .count_allocated = 0,
//                 .allocator = a,
//             };
//         }
//
//         pub fn get(self: *Self, i: i32) T {
//             if (i < 0 or i >= self.count) @panic("Out of bounds Array access");
//             const items = self.items orelse @panic("Array members are uninitialized!");
//             return items[i];
//         }
//
//         pub fn set(self: *Self, i: i32, item: T) void {
//             if (i < 0 or i >= self.count) @panic("Out of bounds Array access")
//         }
//     };
// }
