# 🎉 Confetti

A lightweight library for creating confetti effects on Roblox UI. Designed to be simple: one line triggers the effect, the Handle gives you full control.

## Installation

Install via [Wally] = "sqzee1/confetti@2.0.2"

```toml
[dependencies]
Confetti = "sqzee1/confetti@2.0.2"
```

Install via [Roblox Studio] = https://create.roblox.com/store/asset/86854023727330/Confetti

---

## Basic Usage

```luau
local handle = Confetti.explosion(gui)
```

### Waiting for the effect to finish

```luau
local handle = Confetti.rain(gui)
handle.Wait() -- yields the current thread until the effect is done
```

### Cancelling at any time

```luau
local handle = Confetti.sides(gui)
task.delay(1, function()
    handle.Cancel()
end)
```

---

## Example

```luau
-- explosion inside a frame with blur and camera shake, then wait for it to finish
local explosion = Confetti.explosion(confettiGui, {
    Container = confettiFrame,
    Clip = true,
    Blur = 24,
    CameraShake = true,
    Shape = "Circle",
})
explosion.Wait()

-- cannon from the center of the screen, cancelled after 1 second
local cannon = Confetti.cannon(confettiGui, UDim2.fromScale(0.5, 0.5), {
    Blur = 30,
    CameraShake = true,
    Size = NumberRange.new(5, 10),
})
task.wait(1)
cannon.Cancel()
```

---

## Options

All functions accept an optional `Options` table as their last parameter:

```luau
Confetti.explosion(gui, {
    Blur = 20,            -- applies a BlurEffect to Lighting during the effect (size, <= 0 disables)
    CameraShake = true,   -- quick punch zoom at the start
    Container = frame,    -- confetti is spawned inside the given GuiObject
    Clip = true,          -- clips particles to the container bounds (default: true)
    Shape = "Square",     -- "Square" | "Circle" | "Rectangle" | "Random"
    Colors = { Color3 },  -- custom color palette
    Size = NumberRange.new(6, 14), -- particle size range (px)
    Image = { "rbxassetid://111", "rbxassetid://222" }, -- list of asset ids; picked randomly per particle
    EmitTime = 3,         -- overrides the preset's emit duration (seconds)
})
```

When `Clip = false`, particles can visually escape the container and are destroyed when they leave the screen bounds instead.

### Image Notes

When `Image` is set, each particle becomes an `ImageLabel` instead of a colored `Frame`:
- **No `Colors` provided** → `ImageColor3 = white` (image renders with its original colors)
- **`Colors` provided** → `ImageColor3` is picked from the palette (tints the image)

---

## Custom Effect

```luau
Confetti.create(gui, {
    Count = 80,                             -- total number of particles
    EmitTime = 2,                           -- how long the emitter spawns particles (seconds)
    Colors = { Color3.fromRGB(255, 0, 0) }, -- color palette
    Size = NumberRange.new(6, 14),          -- particle size range (px)
    Gravity = 600,                          -- downward acceleration (px/s²)
    Drag = 0.01,                            -- velocity damping coefficient (frame-rate independent)
    Rotation = true,                        -- whether particles spin
    Shape = "Random",                       -- "Square" | "Circle" | "Rectangle" | "Random"
    SpawnRate = 40,                         -- particles per second (0 = instant burst)
    Lifetime = NumberRange.new(0.8, 1.6),   -- how long each particle lives (seconds)
})
```

---

## Available Presets

| Function | Description |
|---|---|
| `Confetti.rain(gui, options?)` | Particles fall from the top |
| `Confetti.sides(gui, options?)` | Particles shoot in from the sides |
| `Confetti.rainbow(gui, options?)` | Particles arc up from the bottom corners |
| `Confetti.cannon(gui, origin, options?)` | Shoots from a given UDim2 origin point |
| `Confetti.explosion(gui, options?)` | Instant burst from the center |
| `Confetti.spark(gui, options?)` | Fast ember-like sparks from the center |
| `Confetti.golden(gui, options?)` | Slow golden shimmer falling from the top |
| `Confetti.bubble(gui, options?)` | Pastel bubbles floating upward |
| `Confetti.parade(gui, options?)` | Dense colorful shower from the top |
| `Confetti.create(gui, config, options?)` | Fully custom effect |

---

## Handle

Every function returns a `Handle`:

```luau
export type Handle = {
    Cancel: () -> (), -- immediately stops the effect and cleans up
    Wait: () -> (),   -- yields the current thread until the effect finishes
}
```

---

*Made by sqzee1*