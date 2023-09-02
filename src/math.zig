pub const Vector2 = struct {
    x: f32,
    y: f32,
};

pub fn vector2(x: f32, y: f32) Vector2 {
    return Vector2{
        .x = x,
        .y = y,
    };
}

pub const Transform2D = struct {
    x: Vector2,
    y: Vector2,
    o: Vector2,
};
