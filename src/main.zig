// Port of https://github.com/tsoding/subframes/tree/main to zig

const std = @import("std");
const rl = @import("raylib");
const rm = @import("raylib-math");

const Control = struct {
    key: i32,
    vec: rl.Vector2,
};

const PLAYER_SPEED = 1000;
const REAL_FPS = 24;
const TARGET_FPS: f32 = 480.0;
const TARGET_DT: f32 = 1.0 / TARGET_FPS;
const GRAVITY = 1000.0;
const COLLISION_DAMPING = 0.8;

const Vector2s = struct {
    items: []rl.Vector2,
    vcount: usize,
    capacity: usize,
};

const Colors = struct {
    items: []rl.Color,
    ccount: usize,
    capacity: usize,
};

pub fn main() anyerror!void {
    const screenWidth = 800;
    const screenHeight = 420;

    rl.initWindow(screenWidth, screenHeight, "SubFrames");
    defer rl.closeWindow();

    rl.setTargetFPS(REAL_FPS);

    var positions = std.ArrayList(rl.Vector2).init(std.heap.page_allocator);
    defer positions.deinit();

    var velocities = std.ArrayList(rl.Vector2).init(std.heap.page_allocator);
    defer velocities.deinit();

    var colors = std.ArrayList(rl.Color).init(std.heap.page_allocator);
    defer colors.deinit();

    var prev_winpos = rl.getWindowPosition();

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(rl.Color.dark_gray);

        const winpos = rl.getWindowPosition();
        const dwinpos = rm.vector2Subtract(winpos, prev_winpos);
        const w = rl.getScreenWidth();
        const h = rl.getScreenHeight();
        const real_dt = rl.getFrameTime();
        const radius: f32 = 20.0;

        if (rl.isMouseButtonPressed(rl.MouseButton.mouse_button_left)) {
            try positions.append(rl.getMousePosition());
            try velocities.append(.{ .x = 500, .y = 500 });
            try colors.append(rl.colorFromHSV(@floatFromInt(rl.getRandomValue(0, 360)), 0.5, 0.8));
        }

        var t: f32 = 0.0;
        while (t < real_dt) : (t += TARGET_DT) {
            for (positions.items, 0..) |*pos, i| {
                const f = t / real_dt;

                pos.* = rm.vector2Subtract(pos.*, rm.vector2Scale(dwinpos, TARGET_DT / real_dt));
                velocities.items[i].y += GRAVITY * TARGET_DT;

                const nx = pos.x + velocities.items[i].x * TARGET_DT;
                if (nx - radius <= 0) {
                    pos.x = radius;
                    velocities.items[i].x *= -COLLISION_DAMPING;
                } else if (nx + radius >= @as(f32, @floatFromInt(w))) {
                    pos.x = @as(f32, @floatFromInt(w)) - radius;
                    velocities.items[i].x *= -COLLISION_DAMPING;
                } else {
                    pos.x = nx;
                }

                const ny = pos.y + velocities.items[i].y * TARGET_DT;
                if (ny - radius <= 0) {
                    pos.y = radius;
                    velocities.items[i].y *= -COLLISION_DAMPING;
                } else if (ny + radius >= @as(f32, @floatFromInt(h))) {
                    pos.y = @as(f32, @floatFromInt(h)) - radius;
                    velocities.items[i].y *= -COLLISION_DAMPING;
                } else {
                    pos.y = ny;
                }

                rl.drawRing(pos.*, radius * 0.8, radius, 0, 360, 100, rl.colorAlpha(colors.items[i], f));
            }
        }

        rl.drawText(rl.textFormat("%f %f", .{ dwinpos.x, dwinpos.y }), 0, 0, 32, rl.Color.ray_white);

        prev_winpos = winpos;
    }
}
