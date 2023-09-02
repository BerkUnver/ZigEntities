const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const math = @import("math.zig");

pub fn main() !void {
    var GPA = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = std.heap.page_allocator;
    defer _ = GPA.deinit();

    var world = World.init(allocator);
    defer world.deinit();

    var entity_ptr = try allocator.create(Player);
    var entity_id = try world.entity_add(Player, entity_ptr);
    var entity_ptr_retrieved = world.entity_get(entity_id) orelse {
        print("Could not retrieve the entity!\n", .{});
        return;
    };

    print("Entity ptrs equivalent: {any}\n", .{entity_ptr == entity_ptr_retrieved});
}

// goofy ahh way to get unique type ids at runtime
// basically this function's result is memoized when it is called on the same type.
pub fn type_id(comptime T: type) usize {
    _ = T;
    const H = struct {
        var byte: u8 = 0;
    };
    return @intFromPtr(&H.byte);
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

// const Entity = struct {
//     position: math.Vector2 = math.vector2(0, 0),
//     shear_x: math.Vector2 = math.vector2(1, 0),
//     shear_y: math.Vector2 = math.vector2(0, 1),
//     entity_type: usize = undefined, // Used to make sure casting entities works properly. Is initialized when the entity is added to World.
//
//     update: ?*const fn (f32) void = null,
//
//     pub fn cast(self: *Entity, comptime T: type) ?*T {
//         if (self.entity_type != type_id(T)) return null;
//         return @ptrCast(self);
//     }
// };

pub fn EntityVTable(comptime T: type) type {
    return struct {
        update: ?*const fn (*T, f32) void = null,
        render: ?*const fn (*T) void = null,
        area_entered: ?*const fn (*T, *Entity(Empty)) void = null,
        area_exited: ?*const fn (*T, *Entity(Empty)) void = null,
        world_added: ?*const fn (*T) void = null,
        deinit: ?*const fn (*T) void = null,
        serialized_fields: ?*const fn () [][]u8 = null,
    };
}

pub fn Entity(comptime T: type) type {
    return struct {
        position: math.Vector2 = math.vector2(0, 0),
        shear_x: math.Vector2 = math.vector2(1, 0),
        shear_y: math.Vector2 = math.vector2(0, 1),
        world: *World = undefined,
        vtable: *const EntityVTable(T),

        data: T,
    };
}

const Empty = struct {};

const EntityId = struct {
    index: i32,
    generation: i32,
};

const EntityArrayEntry = struct {
    generation: i32,
    entity: *Entity(Empty),
};

const World = struct {
    entities: std.ArrayList(EntityArrayEntry),
    open_indicies: std.ArrayList(i32),

    pub fn init(allocator: Allocator) World {
        return World{
            .entities = std.ArrayList(EntityArrayEntry).init(allocator),
            .open_indicies = std.ArrayList(i32).init(allocator),
        };
    }

    pub fn deinit(self: World) void {
        self.entities.deinit();
        self.open_indicies.deinit();
    }

    pub fn entity_add(self: *World, comptime T: type, entity: *T) !EntityId {
        comptime {
            if (T != Entity(anytype)) @compileError("E");
        }

        if (self.open_indicies.items.len > 0) {
            const index: i32 = self.open_indicies.items[self.open_indicies.items.len - 1];
            self.open_indicies.items.len -= 1;

            const generation = self.entities.items[@intCast(index)].generation + 1;
            self.entities.items[@intCast(index)] = EntityArrayEntry{
                .generation = generation,
                .entity = @ptrCast(entity),
            };
            return .{
                .index = index,
                .generation = generation,
            };
        } else {
            const entry = EntityArrayEntry{
                .generation = 0,
                .entity = @ptrCast(entity),
            };
            try self.entities.append(entry);
            return .{
                .index = @intCast(self.entities.items.len - 1),
                .generation = 0,
            };
        }
    }

    pub fn entity_get(self: World, id: EntityId) ?*Entity(Empty) {
        if (self.entities.items.len <= id.index) return null;
        if (self.entities.items[@intCast(id.index)].generation != id.generation) return null;
        return self.entities.items[@intCast(id.index)].entity;
    }
};

const Player = Entity(struct {
    name: []const u8,
});

fn player_update(self: *Player, delta: f32) void {
    _ = self;
    _ = delta;
}

pub fn player_init() Player {
    return Player{
        .vtable = &EntityVTable(Player){
            .update = player_update,
        },
        .data = .{
            .name = "Gamer",
        },
    };
}
