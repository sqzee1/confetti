--[[

	@Author: sqzee1
	@Usage: Confetti is a lightweight library for creating confetti effects on Roblox UI.
	Designed to be simple: one line triggers the effect, the Handle gives you full control.
	
	BASIC USAGE:
		local handle = Confetti.explosion(gui)

	WAITING FOR THE EFFECT TO FINISH:
		local handle = Confetti.rain(gui)
		handle.Wait() -- yields the current thread until the effect is done

	CANCELLING AT ANY TIME:
		local handle = Confetti.sides(gui)
		task.delay(1, function()
			handle.Cancel()
		end)

	OPTIONS:
		All functions accept an optional Options table as their last parameter:

		Confetti.explosion(gui, {
			Blur = 20,            -- applies a BlurEffect to Lighting during the effect (size, <= 0 disables)
			CameraShake = true,   -- quick camera zoom-in at the start
			Container = frame,    -- confetti is spawned inside the given GuiObject
			Clip = true,          -- ClipsDescendants on the container + destroys particles on bounds exit (default: true)
			Shape = "Square",     -- "Square" | "Circle" | "Rectangle" | "Random"
			Colors = { Color3 },  -- color palette
		})

		when Clip = false, particles can visually escape the container
		and are destroyed when they leave the screen bounds instead.

	CUSTOM EFFECT:
		Confetti.create(gui, {
			Count = 80,                                  -- total number of particles
			EmitTime = 2,                                -- how long the emitter spawns particles (seconds)
			Colors = { Color3.fromRGB(255, 0, 0) },      -- color palette
			Size = NumberRange.new(6, 14),               -- particle size range (px)
			Gravity = 600,                               -- downward acceleration (px/s²)
			Drag = 0.01,                                 -- velocity damping per frame [0..1]
			Rotation = true,                             -- whether particles spin
			Shape = "Random",                            -- "Square" | "Circle" | "Rectangle" | "Random"
			SpawnRate = 40,                              -- particles per second (0 = instant burst)
			Lifetime = NumberRange.new(0.8, 1.6),        -- how long each particle lives (seconds)
		})

	DEFAULT: 
		You can also modify the presets however you see fit.

	AVAILABLE PRESETS:
		Confetti.rain(gui, options?)
		Confetti.sides(gui, options?)
		Confetti.rainbow(gui, options?)
		Confetti.cannon(gui, origin, options?)
		Confetti.explosion(gui, options?)
		Confetti.spark(gui, options?)
		Confetti.golden(gui, options?)
		Confetti.bubble(gui, options?)
		Confetti.parade(gui, options?)
		Confetti.create(gui, config, options?)
]]

--!strict
--!optimize 2

-- [ SERVICES ] --

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- [ TYPES ] --

type Shape = "Square" | "Circle" | "Rectangle" | "Random"

type Particle = {
	frame: Frame,
	x: number,
	y: number,
	vx: number,
	vy: number,
	rot: number,
	rotSpeed: number,
	lifetime: number,
}

export type Handle = {
	Cancel: () -> (),
	Wait: () -> (),
}

export type Config = {
	Count: number?,
	EmitTime: number?,
	Colors: { Color3 }?,
	Size: NumberRange?,
	Gravity: number?,
	Drag: number?,
	Rotation: boolean?,
	Shape: Shape?,
	SpawnRate: number?,
	Lifetime: NumberRange?,
}

export type Options = {
	Blur: number?,
	CameraShake: boolean?,
	Container: GuiObject?,
	Clip: boolean?,
	Shape: Shape?,
	Colors: { Color3 }?,
	Size: NumberRange?,
}

-- [ CONSTANTS ] --

local BLUR_FADE_IN = 0.15
local BLUR_FADE_OUT = 0.6
local BLUR_MAX_SIZE = 56

local SHAKE_FOV_PUNCH = 15
local SHAKE_PUNCH_IN = 0.12
local SHAKE_PUNCH_OUT = 0.6

local POOL_MAX_SIZE = 300

local DEFAULT_LIFETIME = NumberRange.new(1.0, 2.0)

local SHAPES: { Shape } = { "Square", "Circle", "Rectangle" }

local DEFAULT_COLORS = {
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(255, 80, 80),
	Color3.fromRGB(88, 181, 253),
	Color3.fromRGB(242, 255, 60),
	Color3.fromRGB(228, 158, 9),
	Color3.fromRGB(61, 5, 134),
	Color3.fromRGB(100, 220, 120),
	Color3.fromRGB(220, 100, 255),
}

local GOLD_COLORS = {
	Color3.fromRGB(255, 215, 0),
	Color3.fromRGB(255, 185, 0),
	Color3.fromRGB(255, 240, 100),
	Color3.fromRGB(230, 160, 0),
	Color3.fromRGB(255, 255, 200),
}

local PASTEL_COLORS = {
	Color3.fromRGB(255, 182, 193),
	Color3.fromRGB(182, 213, 255),
	Color3.fromRGB(182, 255, 193),
	Color3.fromRGB(255, 240, 182),
	Color3.fromRGB(221, 182, 255),
	Color3.fromRGB(255, 218, 182),
}

local EMBER_COLORS = {
	Color3.fromRGB(255, 60, 0),
	Color3.fromRGB(255, 130, 0),
	Color3.fromRGB(255, 210, 0),
	Color3.fromRGB(255, 255, 120),
	Color3.fromRGB(180, 20, 0),
	Color3.fromRGB(255, 80, 20),
}

local RAIN_PRESET: Config = {
	Count = 120,
	EmitTime = 2,
	Colors = DEFAULT_COLORS,
	Size = NumberRange.new(5, 10),
	Gravity = 900,
	Drag = 0.008,
	Rotation = true,
	Shape = "Square",
	SpawnRate = 80,
	Lifetime = NumberRange.new(0.6, 1.2),
}

local SIDES_PRESET: Config = {
	Count = 150,
	EmitTime = 1,
	Colors = DEFAULT_COLORS,
	Size = NumberRange.new(6, 14),
	Gravity = 700,
	Drag = 0.003,
	Rotation = true,
	Shape = "Random",
	SpawnRate = 160,
	Lifetime = NumberRange.new(0.6, 1.2),
}

local RAINBOW_PRESET: Config = {
	Count = 200,
	EmitTime = 2,
	Colors = DEFAULT_COLORS,
	Size = NumberRange.new(6, 12),
	Gravity = 650,
	Drag = 0.006,
	Rotation = true,
	Shape = "Square",
	SpawnRate = 90,
	Lifetime = NumberRange.new(0.8, 1.6),
}

local CANNON_PRESET: Config = {
	Count = 90,
	EmitTime = 0.8,
	Colors = DEFAULT_COLORS,
	Size = NumberRange.new(6, 14),
	Gravity = 700,
	Drag = 0.004,
	Rotation = true,
	Shape = "Rectangle",
	SpawnRate = 120,
	Lifetime = NumberRange.new(1.4, 2.2),
}

local EXPLOSION_PRESET: Config = {
	Count = 180,
	EmitTime = 0,
	Colors = DEFAULT_COLORS,
	Size = NumberRange.new(6, 12),
	Gravity = 800,
	Drag = 0.005,
	Rotation = true,
	Shape = "Rectangle",
	SpawnRate = 0,
	Lifetime = NumberRange.new(0.7, 1.5),
}

local SPARK_PRESET: Config = {
	Count = 220,
	EmitTime = 0,
	Colors = EMBER_COLORS,
	Size = NumberRange.new(2, 5),
	Gravity = 1400,
	Drag = 0.002,
	Rotation = false,
	Shape = "Rectangle",
	SpawnRate = 0,
	Lifetime = NumberRange.new(0.2, 0.7),
}

local GOLDEN_PRESET: Config = {
	Count = 50,
	EmitTime = 2,
	Colors = GOLD_COLORS,
	Size = NumberRange.new(4, 9),
	Gravity = 300,
	Drag = 0.012,
	Rotation = true,
	Shape = "Rectangle",
	SpawnRate = 25,
	Lifetime = NumberRange.new(0.8, 1.6),
}

local BUBBLE_PRESET: Config = {
	Count = 35,
	EmitTime = 3,
	Colors = PASTEL_COLORS,
	Size = NumberRange.new(10, 20),
	Gravity = -200,
	Drag = 0.01,
	Rotation = true,
	Shape = "Circle",
	SpawnRate = 14,
	Lifetime = NumberRange.new(1.5, 3.0),
}

local PARADE_PRESET: Config = {
	Count = 140,
	EmitTime = 4,
	Colors = DEFAULT_COLORS,
	Size = NumberRange.new(8, 20),
	Gravity = 500,
	Drag = 0.01,
	Rotation = true,
	Shape = "Random",
	SpawnRate = 45,
	Lifetime = NumberRange.new(1.2, 2.5),
}

-- [ POOL ] --

local _stack: { Frame } = {}
local _depth = 0

local function poolGet(): Frame?
	if _depth > 0 then
		local frame = _stack[_depth]
		_stack[_depth] = nil
		_depth -= 1
		return frame
	end
	return nil
end

local function poolPush(frame: Frame)
	if _depth >= POOL_MAX_SIZE then
		frame:Destroy()
		return
	end
	_depth += 1
	_stack[_depth] = frame
end

-- [ UTILS ] --

local function randomShape(): Shape
	return SHAPES[math.random(1, #SHAPES)]
end

local function randomFrom<T>(t: { T }): T
	return t[math.random(1, #t)]
end

local function getScreenSize(container: GuiObject?): Vector2
	if container then
		return container.AbsoluteSize
	end
	local camera = workspace.CurrentCamera :: Camera
	return camera.ViewportSize
end

local function resolveShape(shape: Shape?): Shape
	if shape == "Random" or shape == nil then
		return randomShape()
	end
	return shape
end

local function resetFrame(frame: Frame, parent: GuiObject | ScreenGui, shape: Shape, size: number, color: Color3)
	frame:ClearAllChildren()

	local w = size
	local h = if shape == "Rectangle" then math.ceil(size / 2) else size

	frame.Size = UDim2.fromOffset(w, h)
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = 0
	frame.BorderSizePixel = 0
	frame.Rotation = 0
	frame.ZIndex = 10
	frame.ClipsDescendants = false
	frame.Parent = parent

	if shape == "Circle" then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = frame
	end
end

local function acquireFrame(parent: GuiObject | ScreenGui, shape: Shape, size: number, color: Color3): Frame
	local frame: Frame = poolGet() or Instance.new("Frame")
	resetFrame(frame, parent, shape, size, color)
	return frame
end

local function releaseFrame(frame: Frame)
	frame.Parent = nil
	poolPush(frame)
end

local function getInitialState(preset: string, screenSize: Vector2, origin: UDim2?)
	local x: number
	local y: number
	local vx: number
	local vy: number

	local sizeX = math.floor(screenSize.X)
	local sizeY = math.floor(screenSize.Y)

	if preset == "rain" then
		x = math.random(0, sizeX)
		y = -20
		vx = math.random(-80, 80)
		vy = math.random(200, 400)
	elseif preset == "sides" then
		local fromLeft = math.random() < 0.5
		x = fromLeft and -20 or sizeX + 20
		y = math.random(0, math.floor(sizeY * 0.7))
		vx = fromLeft and math.random(600, 900) or -math.random(600, 900)
		vy = math.random(-200, 300)
	elseif preset == "rainbow" then
		local fromLeft = math.random() < 0.5
		x = fromLeft and math.random(0, math.floor(sizeX * 0.3)) or math.random(math.floor(sizeX * 0.7), sizeX)
		y = math.floor(sizeY * 0.7)
		local dir = fromLeft and 1 or -1
		vx = dir * math.random(150, 300)
		vy = -math.random(600, 900)
	elseif preset == "cannon" then
		local ox = (origin and origin.X.Scale * sizeX + origin.X.Offset) or sizeX * 0.5
		local oy = (origin and origin.Y.Scale * sizeY + origin.Y.Offset) or sizeY
		x = ox
		y = oy
		local angle = math.rad(math.random(50, 130))
		local speed = math.random(400, 800)
		vx = math.cos(angle) * speed
		vy = -math.sin(angle) * speed
	elseif preset == "explosion" then
		x = sizeX * 0.5
		y = sizeY * 0.5
		local angle = math.random() * math.pi * 2
		local speed = math.random(400, 1000)
		vx = math.cos(angle) * speed
		vy = math.sin(angle) * speed
	elseif preset == "spark" then
		x = sizeX * 0.5
		y = sizeY * 0.5
		local angle = math.random() * math.pi * 2
		local speed = math.random(600, 1400)
		vx = math.cos(angle) * speed
		vy = math.sin(angle) * speed
	elseif preset == "golden" then
		x = math.random(0, sizeX)
		y = -20
		vx = math.random(-60, 60)
		vy = math.random(80, 160)
	elseif preset == "bubble" then
		x = math.random(0, sizeX)
		y = sizeY + 20
		vx = math.random(-60, 60)
		vy = -math.random(200, 380)
	elseif preset == "parade" then
		x = math.random(0, sizeX)
		y = -20
		vx = math.random(-120, 120)
		vy = math.random(150, 350)
	end

	return x :: number, y :: number, vx :: number, vy :: number
end

local function applyBlur(size: number?): BlurEffect?
	if not size or size <= 0 then
		return nil
	end

	local blur = Instance.new("BlurEffect")
	blur.Size = 0
	blur.Parent = game:GetService("Lighting")
	TweenService:Create(blur, TweenInfo.new(BLUR_FADE_IN), { Size = math.clamp(size, 0, BLUR_MAX_SIZE) }):Play()

	return blur
end

local function applyShake(active: boolean)
	if not active then
		return
	end

	local camera = workspace.CurrentCamera :: Camera
	local originalFov = camera.FieldOfView

	local t1 = TweenService:Create(
		camera,
		TweenInfo.new(SHAKE_PUNCH_IN, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ FieldOfView = originalFov + SHAKE_FOV_PUNCH }
	)
	local t2 = TweenService:Create(
		camera,
		TweenInfo.new(SHAKE_PUNCH_OUT, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ FieldOfView = originalFov }
	)

	t1:Play()
	t1.Completed:Connect(function()
		t2:Play()
	end)
end

-- [ EMITTER ] --

type EmitConfig = {
	gui: ScreenGui,
	config: Config,
	options: Options?,
	origin: UDim2?,
	preset: string,
}

local function emit(cfg: EmitConfig): Handle
	local thread = coroutine.running()
	local waited = false
	local cancelled = false
	local cleaned = false

	local options: Options = cfg.options or {}
	local config = cfg.config
	local container = options.Container
	local clip = if options.Clip == false then false else true
	local screenSize = getScreenSize(container)
	local parent: GuiObject | ScreenGui = container or cfg.gui

	if container and clip then
		container.ClipsDescendants = true
	end

	local count = config.Count or 100
	local emitTime = config.EmitTime or 3
	local colors = options.Colors or config.Colors or DEFAULT_COLORS
	local sizeRange = options.Size or config.Size or NumberRange.new(8, 16)
	local lifetimeRange = config.Lifetime or DEFAULT_LIFETIME
	local gravity = config.Gravity or 600
	local drag = config.Drag or 0.008
	local rotation = if config.Rotation == nil then true else config.Rotation
	local spawnRate = config.SpawnRate or 60
	local isBurst = spawnRate == 0
	local interval = if isBurst then 0 else 1 / spawnRate

	local blur = applyBlur(options.Blur)
	applyShake(options.CameraShake == true)

	local particles: { Particle } = {}
	local connection: RBXScriptConnection

	local function spawnParticle()
		local shape = resolveShape(options.Shape or config.Shape)
		local size = math.random(sizeRange.Min, sizeRange.Max)
		local color = randomFrom(colors)
		local frame = acquireFrame(parent, shape, size, color)
		local x, y, vx, vy = getInitialState(cfg.preset, screenSize, cfg.origin)
		frame.Position = UDim2.fromOffset(x, y)

		table.insert(particles, {
			frame = frame,
			x = x,
			y = y,
			vx = vx,
			vy = vy,
			rot = math.random(0, 360),
			rotSpeed = math.random(-360, 360),
			lifetime = lifetimeRange.Min + math.random() * (lifetimeRange.Max - lifetimeRange.Min),
		})
	end

	local function cleanup()
		if cleaned then
			return
		end
		cleaned = true

		if connection then
			connection:Disconnect()
		end

		if container and clip then
			container.ClipsDescendants = false
		end

		for _, p in particles do
			releaseFrame(p.frame)
		end
		table.clear(particles)

		if blur then
			local blurRef = blur
			blur = nil
			TweenService:Create(blurRef, TweenInfo.new(BLUR_FADE_OUT), { Size = 0 }):Play()
			task.delay(BLUR_FADE_OUT, function()
				if blurRef and blurRef.Parent then
					blurRef:Destroy()
				end
			end)
		end

		if coroutine.status(thread) == "suspended" then
			task.spawn(thread)
		end
	end

	local boundsX0 = 0
	local boundsY0 = 0
	local boundsX1 = screenSize.X
	local boundsY1 = screenSize.Y

	local effectThread = task.spawn(function()
		if isBurst then
			for _ = 1, count do
				spawnParticle()
			end
		end

		local spawned = 0
		local spawnAccum = 0

		connection = RunService.Heartbeat:Connect(function(dt: number)
			if cancelled then
				return
			end

			if not isBurst and spawned < count then
				spawnAccum += dt
				while spawnAccum >= interval and spawned < count do
					spawnParticle()
					spawned += 1
					spawnAccum -= interval
				end
			end

			local i = #particles
			while i > 0 do
				local p = particles[i]

				p.lifetime -= dt
				p.vy += gravity * dt
				p.vx = p.vx * (1 - drag)
				p.vy = p.vy * (1 - drag)
				p.x += p.vx * dt
				p.y += p.vy * dt

				if rotation then
					p.rot += p.rotSpeed * dt
					p.frame.Rotation = p.rot
				end

				local w = p.frame.Size.X.Offset
				local h = p.frame.Size.Y.Offset

				if container and clip then
					p.x = math.clamp(p.x, boundsX0, boundsX1 - w)
					p.y = math.clamp(p.y, boundsY0, boundsY1 - h)
					p.vx = if p.x <= boundsX0 or p.x >= boundsX1 - w then 0 else p.vx
					p.vy = if p.y <= boundsY0 or p.y >= boundsY1 - h then 0 else p.vy
				end

				p.frame.Position = UDim2.fromOffset(p.x, p.y)

				local outOfBounds = p.lifetime <= 0
					or p.x < boundsX0 - 50
					or p.x > boundsX1 + 50
					or p.y < boundsY0 - 50
					or p.y > boundsY1 + 50

				if outOfBounds then
					releaseFrame(p.frame)
					particles[i] = particles[#particles]
					particles[#particles] = nil
				end

				i -= 1
			end
		end)

		local startTime = os.clock()
		repeat
			task.wait()
		until cancelled or (os.clock() - startTime >= emitTime)

		if not cancelled then
			repeat
				task.wait()
			until cancelled or #particles == 0
		end

		cleanup()
	end)

	return {
		Cancel = function()
			cancelled = true
			if connection then
				connection:Disconnect()
			end
			task.cancel(effectThread)
			cleanup()
		end,

		Wait = function()
			assert(not waited, "Wait already called")
			waited = true
			coroutine.yield()
		end,
	}
end

-- [ PUBLIC ] --

local Confetti = {}

function Confetti.rain(gui: ScreenGui, options: Options?): Handle
	return emit({
		gui = gui,
		config = RAIN_PRESET,
		options = options,
		preset = "rain",
	})
end

function Confetti.sides(gui: ScreenGui, options: Options?): Handle
	return emit({
		gui = gui,
		config = SIDES_PRESET,
		options = options,
		preset = "sides",
	})
end

function Confetti.rainbow(gui: ScreenGui, options: Options?): Handle
	return emit({
		gui = gui,
		config = RAINBOW_PRESET,
		options = options,
		preset = "rainbow",
	})
end

function Confetti.cannon(gui: ScreenGui, origin: UDim2, options: Options?): Handle
	return emit({
		gui = gui,
		config = CANNON_PRESET,
		options = options,
		origin = origin,
		preset = "cannon",
	})
end

function Confetti.explosion(gui: ScreenGui, options: Options?): Handle
	return emit({
		gui = gui,
		config = EXPLOSION_PRESET,
		options = options,
		preset = "explosion",
	})
end

function Confetti.spark(gui: ScreenGui, options: Options?): Handle
	return emit({
		gui = gui,
		config = SPARK_PRESET,
		options = options,
		preset = "spark",
	})
end

function Confetti.golden(gui: ScreenGui, options: Options?): Handle
	return emit({
		gui = gui,
		config = GOLDEN_PRESET,
		options = options,
		preset = "golden",
	})
end

function Confetti.bubble(gui: ScreenGui, options: Options?): Handle
	return emit({
		gui = gui,
		config = BUBBLE_PRESET,
		options = options,
		preset = "bubble",
	})
end

function Confetti.parade(gui: ScreenGui, options: Options?): Handle
	return emit({
		gui = gui,
		config = PARADE_PRESET,
		options = options,
		preset = "parade",
	})
end

function Confetti.create(gui: ScreenGui, config: Config, options: Options?): Handle
	return emit({
		gui = gui,
		config = config,
		options = options,
		preset = "explosion",
	})
end

export type Confetti = typeof(Confetti)

return Confetti :: Confetti
