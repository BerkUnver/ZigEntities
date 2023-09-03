const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const e = @import("entity.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    var allocator = gpa.allocator();

    var world = e.World.init(allocator);
    defer world.deinit();

    var entity_id = try world.entity_add(e.Player, .{});
    var entity_retrieved = world.entity_get(entity_id) orelse {
        print("Could not retrieve the entity!\n", .{});
        return;
    };
    world.update(0);
    var player_retrieved = entity_retrieved.cast(e.Player) orelse {
        print("Entity retrieved is not a player!", .{});
        return;
    };
    print("player retrieved counter: {d}\n", .{player_retrieved.counter});
}
