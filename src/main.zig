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
const WINDOW_FORCE_FACTOR = 1.1;
const WINDOW_VELOCITY_FACTOR = 0.5;

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
    const screenWidth = 1000;
    const screenHeight = 1000;

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

        if (rl.isMouseButtonPressed(rl.MouseButton.mouse_button_left)) {
            try positions.append(rl.getMousePosition());
            try velocities.append(.{ .x = @floatFromInt(rl.getRandomValue(-500, 500)), .y = @floatFromInt(rl.getRandomValue(-500, 500)) });
            try colors.append(rl.colorFromHSV(@floatFromInt(rl.getRandomValue(0, 360)), 0.5, 0.8));
        }

        if (rl.isKeyPressed(rl.KeyboardKey.key_r)) {
            positions.clearAndFree();
            velocities.clearAndFree();
            colors.clearAndFree();
        }

        const winpos = rl.getWindowPosition();
        const dwinpos = rm.vector2Scale(rm.vector2Subtract(winpos, prev_winpos), WINDOW_FORCE_FACTOR);
        const w = rl.getScreenWidth();
        const h = rl.getScreenHeight();
        const real_dt = rl.getFrameTime();
        const radius: f32 = 20.0;

        var t: f32 = 0.0;
        while (t < real_dt) : (t += TARGET_DT) {
            for (positions.items, 0..) |*pos, i| {
                const f = t / real_dt;

                pos.* = rm.vector2Subtract(pos.*, rm.vector2Scale(dwinpos, TARGET_DT / real_dt));
                velocities.items[i].y += GRAVITY * TARGET_DT;

                // Check if the circle is hit by the movement of the window
                if (rm.vector2Length(dwinpos) != 0) {
                    const window_velocity = rm.vector2Scale(dwinpos, WINDOW_VELOCITY_FACTOR);
                    velocities.items[i] = rm.vector2Add(velocities.items[i], window_velocity);
                }

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

                // a really bad collision detection. not real physics. just for fun yolo
                for (positions.items, 0..) |*other_pos, j| {
                    if (i != j) {
                        const delta = rm.vector2Distance(pos.*, other_pos.*);
                        if (delta < 2 * radius) {
                            const correction = rm.vector2Scale(rm.vector2Normalize(rm.vector2Subtract(pos.*, other_pos.*)), radius - 0.5 * delta);
                            pos.* = rm.vector2Add(pos.*, correction);
                            other_pos.* = rm.vector2Subtract(other_pos.*, correction);
                            const rel_velocity = rm.vector2Subtract(velocities.items[i], velocities.items[j]);
                            const dot_product = rm.vector2DotProduct(rm.vector2Subtract(pos.*, other_pos.*), rel_velocity);
                            if (dot_product < 0) {
                                // ad hoc clamp
                                const impulse = rm.vector2Scale(rm.vector2Subtract(pos.*, other_pos.*), rm.clamp(-COLLISION_DAMPING * dot_product, -1.0, 1.0));
                                velocities.items[i] = rm.vector2Subtract(velocities.items[i], impulse);
                                velocities.items[j] = rm.vector2Add(velocities.items[j], impulse);
                            }
                        }
                    }
                }
                rl.drawRing(pos.*, radius * 0.8, radius, 0, 360, 100, rl.colorAlpha(colors.items[i], f));
            }
        }
        rl.drawText(rl.textFormat("%d %f %f", .{ rl.getFPS(), dwinpos.x, dwinpos.y }), 0, 0, 32, rl.Color.ray_white);
        prev_winpos = winpos;
    }
}
