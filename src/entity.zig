const std = @import("std");
const Allocator = std.mem.Allocator;
const math = @import("math.zig");

// goofy ahh way to get unique type ids at runtime
// basically this function's result is memoized when it is called on the same type. Therefore we get a unique ptr for everything.
pub fn type_id(comptime T: type) usize {
    _ = T;
    const H = struct {
        var byte: u8 = 0;
    };
    return @intFromPtr(&H.byte);
}

pub const EntityVTable = struct {
    update: ?*const fn (*Entity, f32) void = null,
    render: ?*const fn (*Entity) void = null,
    area_entered: ?*const fn (*Entity, *Entity) void = null,
    area_exited: ?*const fn (*Entity, *Entity) void = null,
    world_added: ?*const fn (*Entity) void = null,
    deinit: ?*const fn (*Entity) void = null,
    serialized_fields: ?*const fn () [][]u8 = null,
};

pub const Entity = struct {
    vtable: EntityVTable = .{}, // @todo: make this a ptr
    position: math.Vector2 = math.vector2(0, 0),
    shear_x: math.Vector2 = math.vector2(1, 0),
    shear_y: math.Vector2 = math.vector2(0, 1),
    type_id: usize = undefined, // Used to make sure casting entities works properly. Is initialized when the entity is added to World.
    world: *World = undefined,

    pub fn cast(self: *Entity, comptime T: type) ?*T {
        if (type_id(T) != self.type_id) return null;
        return @ptrCast(self);
    }
};

pub const EntityId = struct {
    index: i32,
    generation: i32,
};

pub const EntityArrayEntry = struct {
    entity: *Entity,
    generation: i32,
};

pub fn is_entity(comptime T: type) bool {
    if (T == Entity) return true;
    const info = @typeInfo(T);
    if (info != .Struct) return false;
    const fields = info.Struct.fields;
    if (fields.len == 0) return false;
    return is_entity(fields[0].type); // Maybe we should also do offset check
}

pub const World = struct {
    entities: std.ArrayList(EntityArrayEntry),
    open_indicies: std.ArrayList(i32),

    pub fn init(allocator: Allocator) World {
        return World{
            .entities = std.ArrayList(EntityArrayEntry).init(allocator),
            .open_indicies = std.ArrayList(i32).init(allocator),
        };
    }

    pub fn deinit(self: *World) void {
        self.entities.deinit();
        self.open_indicies.deinit();
    }

    pub fn entity_add(self: *World, comptime T: type, entity: *T) !EntityId {
        comptime {
            if (!is_entity(T)) @compileError("E");
        }

        var entity_base: *Entity = @ptrCast(entity);
        entity_base.type_id = type_id(T);

        // Match each function to one in the vtable if it exists and insert it.
        comptime var vtable = EntityVTable{};
        comptime {
            for (std.meta.fields(EntityVTable)) |funcInfo| {
                const func = funcInfo.name;
                if (!@hasDecl(T, func)) continue;
                const func_ptr = &@field(T, func);
                @field(vtable, func) = @ptrCast(func_ptr);

                // @todo: Add type safety pls

                // const base = @typeInfo(@TypeOf(@field(vtable, func)));
                // const override = @typeInfo(@TypeOf(@field(T, func)));

                // if (override != .Function or base != .Function) continue;
                // if (override.Func.returnType != base.Func.returnType) continue;

                // if (override.Func.parameters.len != base.Func.parameters.len) continue;
                // if (override.Func.parameters.len == 0) continue;
                // if (!is_entity(override.Func.parameters[0].type) or !is_entity(override.Func.parameters[0].type)) return false;

                // var matching = true;
                // for (1..override.Func.parameters.len - 1) |i| {
                //     if (override.Func.parameters[i].type == base.Func.parameters[i].type) continue;
                //     matching = false;
                //     break;
                // }
                // if (!matching) continue;
                // vtable.func = @ptrCast(T.func);
            }
        }

        entity_base.vtable = vtable;
        entity_base.world = self;

        if (self.open_indicies.items.len > 0) {
            const index: i32 = self.open_indicies.items[self.open_indicies.items.len - 1];
            self.open_indicies.items.len -= 1;

            const generation = self.entities.items[@intCast(index)].generation + 1;
            self.entities.items[@intCast(index)] = EntityArrayEntry{
                .generation = generation,
                .entity = entity_base,
            };
            return .{
                .index = index,
                .generation = generation,
            };
        } else {
            const entry = EntityArrayEntry{
                .generation = 0,
                .entity = entity_base,
            };
            try self.entities.append(entry);
            return .{
                .index = @intCast(self.entities.items.len - 1),
                .generation = 0,
            };
        }
    }

    pub fn entity_get(self: *World, id: EntityId) ?*Entity {
        if (self.entities.items.len <= id.index) return null;
        if (self.entities.items[@intCast(id.index)].generation != id.generation) return null;
        return self.entities.items[@intCast(id.index)].entity;
    }

    pub fn update(self: *World, delta: f32) void {
        for (self.entities.items) |entry| {
            const func = entry.entity.vtable.update orelse continue;
            func(entry.entity, delta);
        }
    }
};

pub const Player = struct {
    e: Entity = .{},
    counter: i32 = 0,
    name: []const u8 = "Gamer",

    pub fn update(player: *Player, delta: f32) void {
        _ = delta;
        player.counter += 1;
    }
};
