local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local VERSION = "2.0.0"

local previous = playerGui:FindFirstChild("Paw")
if previous then
	previous:Destroy()
end

local colors = {
	black = Color3.fromRGB(0, 0, 0),
	panel = Color3.fromRGB(10, 11, 11),
	row = Color3.fromRGB(17, 18, 18),
	rowHover = Color3.fromRGB(25, 26, 26),
	line = Color3.fromRGB(72, 72, 76),
	white = Color3.fromRGB(236, 236, 240),
	muted = Color3.fromRGB(132, 132, 140),
	off = Color3.fromRGB(46, 46, 50),
	accent = Color3.fromRGB(165, 120, 255),
	player = Color3.fromRGB(255, 120, 145),
	npc = Color3.fromRGB(100, 225, 205),
	green = Color3.fromRGB(80, 205, 135),
	red = Color3.fromRGB(235, 70, 80),
	blue = Color3.fromRGB(90, 150, 255),
}

local palette = {
	colors.accent,
	colors.blue,
	colors.npc,
	colors.green,
	colors.player,
	Color3.fromRGB(255, 214, 90),
	colors.red,
	colors.white,
}

local connections = {}
local cleanups = {}

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

local function onCleanup(fn)
	table.insert(cleanups, fn)
end

local function new(className, props, parent)
	local instance = Instance.new(className)
	for key, value in pairs(props) do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

local function corner(object, radius)
	return new("UICorner", {
		CornerRadius = typeof(radius) == "UDim" and radius or UDim.new(0, radius),
	}, object)
end

local function stroke(object, color, transparency, thickness)
	return new("UIStroke", {
		Color = color,
		Transparency = transparency,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, object)
end

local function tween(object, duration, properties, style, direction)
	local t = TweenService:Create(
		object,
		TweenInfo.new(duration, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out),
		properties
	)
	t:Play()
	return t
end

local function makeLabel(parent, text, size, position, textSize, color, bold)
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Size = size,
		Position = position,
		Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
		Text = text,
		TextSize = textSize,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, parent)
end

local keyCache = {}

local function keyCode(name)
	local code = keyCache[name]

	if code == nil then
		local ok, result = pcall(function()
			return Enum.KeyCode[name]
		end)
		code = ok and result or false
		keyCache[name] = code
	end

	return code or nil
end

local function isDown(name)
	local code = keyCode(name)
	return code ~= nil and UserInputService:IsKeyDown(code)
end

local Log = { entries = {}, listeners = {} }

function Log.add(source, message)
	table.insert(Log.entries, string.format("[%s] %s: %s", os.date("%H:%M:%S"), source, tostring(message)))

	if #Log.entries > 80 then
		table.remove(Log.entries, 1)
	end

	for _, listener in ipairs(Log.listeners) do
		pcall(listener)
	end
end

local lastErrorTime = {}

local function safe(name, fn, ...)
	local ok, err = pcall(fn, ...)

	if not ok then
		local now = os.clock()

		if not lastErrorTime[name] or now - lastErrorTime[name] > 5 then
			lastErrorTime[name] = now
			Log.add(name, err)
		end
	end

	return ok
end

local PRIORITIES = { "Closest to mouse", "Closest distance", "Lowest health" }
local DEF = {}
local DEF_ORDER = {}

local function def(key, kind, default, a, b, scope)
	DEF[key] = { kind = kind, default = default, a = a, b = b, scope = scope or "p" }
	table.insert(DEF_ORDER, key)
end

def("autoEnabled", "bool", false, nil, nil, "r")
def("assistEnabled", "bool", false, nil, nil, "r")
def("speedOn", "bool", false, nil, nil, "r")
def("jumpOn", "bool", false, nil, nil, "r")
def("playerListMode", "str", "Blacklist", { "Blacklist", "Priority" }, nil, "r")

def("playersEnabled", "bool", true)
def("npcsEnabled", "bool", true)
def("ignoreForcefield", "bool", true)
def("triggerMode", "str", "Always", { "Always", "Hold Key", "Hold RMB" })
def("fireMode", "str", "Auto", { "Auto", "Semi", "Burst" })
def("triggerPart", "str", "Any", { "Any", "Head", "Torso" })
def("triggerPriority", "str", "Closest to mouse", PRIORITIES)
def("toolFilter", "str", "")
def("fovRadius", "num", 55, 12, 140)
def("maxRange", "num", 300, 50, 500)
def("fireDelayMs", "num", 180, 80, 500)
def("burstSize", "num", 3, 2, 8)

def("tracerEnabled", "bool", true)
def("sightEnabled", "bool", true)
def("skeletonEnabled", "bool", true)
def("skeletonThickness", "num", 2, 1, 5)
def("sightStyle", "str", "Image", { "Image", "Dot", "Cross", "Circle" })
def("sightSize", "num", 20, 4, 40)
def("sightGap", "num", 4, 0, 20)
def("hitMarker", "bool", true)
def("hitSoundId", "str", "")
def("damageNumbers", "bool", false)
def("cameraFovOn", "bool", false)
def("cameraFov", "num", 70, 30, 120)
def("fullbright", "bool", false)

def("fovColor", "color", colors.accent, nil, false)
def("lockColor", "color", colors.green, nil, false)
def("tracerColor", "color", nil, nil, true)
def("sightColor", "color", colors.white, nil, false)
def("skeletonColor", "color", nil, nil, true)
def("espColor", "color", nil, nil, true)
def("assistColor", "color", palette[2], nil, false)

def("skipFriends", "bool", true)
def("protectTeam", "bool", false)
def("protectGroup", "bool", false)
def("protectGroupId", "num", 0, 0, 999999999)
def("protectGroupRank", "num", 1, 1, 255)
def("blacklist", "map")
def("priority", "map")

def("espEnabled", "bool", true)
def("espBoxStyle", "str", "Box", { "Box", "Corners", "Filled" })
def("espBoxes", "bool", true)
def("espNames", "bool", true)
def("espHealth", "bool", true)
def("espHealthText", "bool", false)
def("espDistance", "bool", true)
def("espTools", "bool", false)
def("espHeadDots", "bool", false)
def("espArrows", "bool", false)
def("espSkeleton", "bool", false)
def("espChams", "bool", false)
def("espTracers", "bool", false)
def("espTracerOrigin", "str", "Bottom", { "Bottom", "Center", "Mouse" })
def("espTeamColors", "bool", false)
def("espFade", "bool", false)
def("espNpcs", "bool", false)
def("lootEsp", "bool", false)
def("espRange", "num", 1000, 100, 2000)
def("espMaxPlayers", "num", 20, 1, 50)
def("chamsFill", "num", 55, 0, 100)
def("chamsOutline", "num", 0, 0, 100)
def("radar", "bool", false)
def("radarSize", "num", 150, 100, 300)
def("radarRange", "num", 150, 50, 500)

def("assistFov", "num", 90, 10, 300)
def("assistStrength", "num", 40, 1, 100)
def("assistRange", "num", 300, 50, 500)
def("assistShowFov", "bool", true)
def("assistWall", "bool", true)
def("assistTeam", "bool", false)
def("assistDynamic", "bool", false)
def("assistPart", "str", "Head", { "Head", "Torso", "Closest" })
def("assistMode", "str", "Always", { "Always", "Hold RMB", "Hold LMB", "Hold Key" })
def("assistCurve", "str", "Linear", { "Linear", "Ease In", "Ease Out" })
def("assistPriority", "str", "Closest to mouse", PRIORITIES)
def("assistDeadzone", "num", 2, 0, 30)
def("assistLead", "num", 0, 0, 100)
def("assistBulletSpeed", "num", 800, 100, 3000)
def("assistStickyMs", "num", 0, 0, 2000)
def("assistOverdrive", "num", 0, 0, 100)
def("overdriveConfirmed", "bool", false, nil, nil, "g")

def("walkSpeed", "num", 20, 16, 100)
def("jumpPower", "num", 75, 50, 200)
def("antiAfk", "bool", false, nil, nil, "g")
def("perfMode", "bool", false, nil, nil, "g")

def("silentEnabled", "bool", false, nil, nil, "r")
def("silentFov", "num", 120, 10, 400)
def("silentHit", "num", 100, 1, 100)
def("silentPredict", "num", 25, 0, 100)
def("silentRange", "num", 500, 50, 1000)
def("silentShowFov", "bool", true)
def("silentWall", "bool", true)
def("silentTeam", "bool", false)
def("silentSticky", "bool", false)
def("silentPart", "str", "Head", { "Head", "Torso", "Closest", "Random" })
def("silentColor", "color", palette[2], nil, false)
def("bindSilent", "str", "RightAlt", nil, nil, "g")

def("coinFarm", "bool", false, nil, nil, "r")
def("farmSpeed", "num", 30, 10, 120)
def("farmDelayMs", "num", 300, 50, 2000)
def("farmNames", "str", "coin,money,gem,gold,cash,collect,loot")

def("hudModules", "bool", false, nil, nil, "g")
def("hudFps", "bool", false, nil, nil, "g")
def("hudPing", "bool", false, nil, nil, "g")
def("toasts", "bool", true, nil, nil, "g")
def("uiScale", "num", 100, 70, 130, "g")
def("uiOpacity", "num", 100, 40, 100, "g")
def("accentColor", "color", colors.white, nil, false, "g")
def("updateUrl", "str", "", nil, nil, "g")

def("mm2Colors", "bool", true)
def("mm2Gun", "bool", true)
def("mm2MurdererColor", "color", palette[7], nil, false)
def("mm2SheriffColor", "color", palette[2], nil, false)
def("mm2InnocentColor", "color", palette[4], nil, false)
def("mm2GunColor", "color", palette[8], nil, false)

def("bindPanel", "str", "RightShift", nil, nil, "g")
def("bindTrigger", "str", "LeftAlt", nil, nil, "g")
def("bindAssist", "str", "RightControl", nil, nil, "g")
def("bindEsp", "str", "None", nil, nil, "g")
def("bindHold", "str", "Q", nil, nil, "g")
def("bindSwitch", "str", "T", nil, nil, "g")

local S = {}

for _, key in ipairs(DEF_ORDER) do
	local d = DEF[key]
	S[key] = d.kind == "map" and {} or d.default
end

local function encodeValue(d, value)
	if d.kind == "color" then
		if not value then
			return nil
		end

		return {
			math.floor(value.R * 255 + 0.5),
			math.floor(value.G * 255 + 0.5),
			math.floor(value.B * 255 + 0.5),
		}
	elseif d.kind == "map" then
		local list = {}

		for id, name in pairs(value) do
			table.insert(list, { id = id, name = name })
		end

		return list
	end

	return value
end

local function decodeValue(d, raw)
	local kind = d.kind

	if kind == "bool" then
		if type(raw) == "boolean" then
			return raw
		end
	elseif kind == "num" then
		if type(raw) == "number" then
			return math.floor(math.clamp(raw, d.a, d.b) + 0.5)
		end
	elseif kind == "str" then
		if type(raw) == "string" and (not d.a or table.find(d.a, raw)) then
			return raw
		end
	elseif kind == "color" then
		if type(raw) == "table" and #raw == 3 and type(raw[1]) == "number"
			and type(raw[2]) == "number" and type(raw[3]) == "number" then
			return Color3.fromRGB(math.clamp(raw[1], 0, 255), math.clamp(raw[2], 0, 255), math.clamp(raw[3], 0, 255))
		end
	elseif kind == "map" then
		local map = {}

		if type(raw) == "table" then
			for _, entry in ipairs(raw) do
				if type(entry) == "table" and type(entry.id) == "number" then
					map[entry.id] = type(entry.name) == "string" and entry.name or "Unknown"
				end
			end
		end

		return map
	end

	return d.default
end

local CONFIG_FILE = "paw_config.json"

local canSave = typeof(writefile) == "function"
	and typeof(readfile) == "function"
	and typeof(isfile) == "function"

local meta = {
	profiles = {},
	currentProfile = "Default",
	gameProfiles = {},
	window = {},
	appHome = {},
}

local Config = { hooks = {} }

local function runHooks()
	for _, hook in ipairs(Config.hooks) do
		pcall(hook)
	end
end

local function inScope(d, includeGlobal)
	return d.scope == "p" or (includeGlobal and d.scope == "g")
end

function Config.collect(includeGlobal)
	local out = {}

	for _, key in ipairs(DEF_ORDER) do
		local d = DEF[key]

		if inScope(d, includeGlobal) then
			local encoded = encodeValue(d, S[key])

			if encoded ~= nil then
				out[key] = encoded
			end
		end
	end

	return out
end

function Config.apply(data, includeGlobal)
	if type(data) ~= "table" then
		return false
	end

	for _, key in ipairs(DEF_ORDER) do
		local d = DEF[key]

		if inScope(d, includeGlobal) then
			S[key] = decodeValue(d, data[key])
		end
	end

	if not S.overdriveConfirmed then
		S.assistOverdrive = 0
	end

	runHooks()
	return true
end

function Config.reset()
	for _, key in ipairs(DEF_ORDER) do
		local d = DEF[key]

		if d.scope == "p" then
			S[key] = d.kind == "map" and {} or d.default
		end
	end

	S.assistOverdrive = 0
	runHooks()
end

local saveQueued = false

function Config.save()
	if not canSave then
		return
	end

	pcall(function()
		writefile(CONFIG_FILE, HttpService:JSONEncode({
			version = VERSION,
			settings = Config.collect(true),
			profiles = meta.profiles,
			currentProfile = meta.currentProfile,
			gameProfiles = meta.gameProfiles,
			window = meta.window,
			appHome = meta.appHome,
		}))
	end)
end

local function queueSave()
	if saveQueued then
		return
	end

	saveQueued = true

	task.delay(0.6, function()
		saveQueued = false
		Config.save()
	end)
end

function Config.load()
	if not canSave then
		return
	end

	local ok, data = pcall(function()
		if not isfile(CONFIG_FILE) then
			return nil
		end

		return HttpService:JSONDecode(readfile(CONFIG_FILE))
	end)

	if not ok or type(data) ~= "table" then
		return
	end

	if type(data.profiles) == "table" then
		meta.profiles = data.profiles
	end

	if type(data.gameProfiles) == "table" then
		meta.gameProfiles = data.gameProfiles
	end

	if type(data.currentProfile) == "string" then
		meta.currentProfile = data.currentProfile
	end

	if type(data.window) == "table" then
		meta.window = data.window
	end

	if type(data.appHome) == "table" then
		meta.appHome = data.appHome
	end

	Config.apply(data.settings, true)

	local assigned = meta.gameProfiles[tostring(game.PlaceId)]

	if type(assigned) == "string" and type(meta.profiles[assigned]) == "table" then
		Config.apply(meta.profiles[assigned], false)
		meta.currentProfile = assigned
	end
end

function Config.profileNames()
	local names = {}

	for name in pairs(meta.profiles) do
		table.insert(names, name)
	end

	table.sort(names, function(a, b)
		return a:lower() < b:lower()
	end)

	return names
end

function Config.saveProfile(name)
	meta.profiles[name] = Config.collect(false)
	meta.currentProfile = name
	queueSave()
end

function Config.loadProfile(name)
	if type(meta.profiles[name]) ~= "table" then
		return false
	end

	Config.apply(meta.profiles[name], false)
	meta.currentProfile = name
	queueSave()
	return true
end

function Config.deleteProfile(name)
	meta.profiles[name] = nil

	for placeId, assigned in pairs(meta.gameProfiles) do
		if assigned == name then
			meta.gameProfiles[placeId] = nil
		end
	end

	queueSave()
end

function Config.export()
	return HttpService:JSONEncode(Config.collect(false))
end

function Config.import(text)
	local ok, data = pcall(function()
		return HttpService:JSONDecode(text)
	end)

	if not ok or type(data) ~= "table" then
		return false
	end

	Config.apply(data, false)
	queueSave()
	return true
end

Config.load()
local gui = new("ScreenGui", {
	Name = "Paw",
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 50,
}, playerGui)

local State = {
	currentTarget = nil,
	locked = false,
	panelHover = false,
	lastFire = 0,
	lastFireModel = nil,
	assistLocked = false,
	mm2Loaded = false,
}

local TIPS = {
	["Auto Trigger"] = "Fires your equipped tool when your cursor is on a valid target.",
	["Players"] = "Allow players as targets.",
	["NPCs"] = "Allow NPC models with a Humanoid as targets.",
	["Ignore Forcefield"] = "Skip targets that have a ForceField.",
	["Trigger Mode"] = "Always, only while a key is held, or only while holding right mouse.",
	["Fire Mode"] = "Auto repeats, Semi fires once per target, Burst fires a few shots then pauses.",
	["Hit Part"] = "Only fire when the cursor is on this body part.",
	["Priority"] = "How the best target is chosen when several are in the FOV.",
	["Tool Filter"] = "Comma separated tool names. Empty means any tool.",
	["Mouse FOV"] = "Radius in pixels around your cursor used to find targets.",
	["Max Range"] = "Maximum distance in studs for the trigger scan.",
	["Fire Delay"] = "Minimum time between shots in milliseconds.",
	["Burst Size"] = "Shots per burst in Burst mode.",
	["Aim Assist"] = "Gently pulls your aim toward targets near your cursor.",
	["Strength"] = "How hard the assist pulls. Moderate by default.",
	["Deadzone"] = "Pixels around the target where the assist stops pulling.",
	["Dynamic FOV"] = "Shrinks the assist FOV for far away targets.",
	["Lead"] = "Predicts target movement using the bullet speed.",
	["Bullet Speed"] = "Projectile speed in studs per second used for lead.",
	["Sticky Time"] = "Keeps the current target for this long before switching.",
	["Overdrive"] = "Extremely strong extra pull. Asks for confirmation once.",
	["Curve"] = "Shape of the pull from the edge of the FOV to the target.",
	["Wall Check"] = "Ignore targets that are behind walls.",
	["Team Check"] = "Ignore players on your team.",
	["Skip Friends"] = "Never target your Roblox friends.",
	["Protect Team"] = "Never target players on your team.",
	["Protect Group"] = "Never target members of a group at or above a rank.",
	["Range"] = "Maximum distance in studs.",
	["Boxes"] = "Draw a box around players.",
	["Box Style"] = "Box, Corners or Filled.",
	["Names"] = "Show player names.",
	["Health"] = "Show a health bar.",
	["Health Text"] = "Show health as a number.",
	["Distance"] = "Show distance in studs.",
	["Tool Names"] = "Show the tool a player is holding.",
	["Head Dots"] = "Draw a dot on heads.",
	["Off-screen Arrows"] = "Arrows at the screen edge pointing to players you cannot see.",
	["Skeleton"] = "Draw bones on the character.",
	["Chams"] = "Full body highlight through walls.",
	["Tracers"] = "Lines from the screen to players.",
	["Team Colors"] = "Use each team's color for ESP.",
	["Distance Fade"] = "Fade ESP with distance.",
	["Loot ESP"] = "Show tools lying on the ground.",
	["Max Players"] = "Only draw the closest players up to this number.",
	["Radar"] = "Small top-down radar of nearby players.",
	["Crosshair Style"] = "Image, Dot, Cross or Circle.",
	["Hit Markers"] = "Flash a marker when your shots reduce a target's health.",
	["Hit Sound ID"] = "Optional Roblox sound asset id played on hit.",
	["Damage Numbers"] = "Floating numbers when a player loses health.",
	["Camera FOV"] = "Override the camera field of view.",
	["Fullbright"] = "Brighten the world.",
	["Walk Speed"] = "Walk speed used while Speed is on.",
	["Jump Power"] = "Jump power used while Jump is on.",
	["Anti-AFK"] = "Prevents the idle kick.",
	["Performance Mode"] = "Lower update rates to save frames.",
	["UI Scale"] = "Size of this window.",
	["UI Opacity"] = "Transparency of this window.",
	["Toasts"] = "Small notifications when you toggle things.",
	["Silent Aim"] = "Redirects where your shots land without moving your camera.",
	["Hit Chance"] = "Chance that a shot is redirected. Re-rolled a few times per second.",
	["Prediction"] = "Leads moving targets.",
	["Sticky Target"] = "Keeps the current target until it leaves a slightly larger FOV.",
	["Aim Part"] = "Head, Torso, Closest to your cursor, or Random.",
	["Auto Farm Coins"] = "Flies to the nearest coin and collects it. Walks through walls while it runs.",
	["Fly Speed"] = "How fast you fly between coins in studs per second.",
	["Collect Delay"] = "Pause after each coin in milliseconds.",
	["Coin Names"] = "Comma separated words. Parts with a matching name and no collision count as coins.",
}

local Toast = {}

do
	local frame = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 20),
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = colors.black,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 40,
	}, gui)
	corner(frame, 4)
	local frameStroke = stroke(frame, colors.line, 1, 1)

	new("UIPadding", {
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
	}, frame)

	local label = new("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 30),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextColor3 = colors.white,
		TextTransparency = 1,
		ZIndex = 41,
	}, frame)

	local token = 0

	function Toast.show(text)
		if not S.toasts then
			return
		end

		token += 1
		local id = token

		label.Text = text
		frame.Visible = true
		frame.Position = UDim2.new(0.5, 0, 1, 10)

		tween(frame, 0.2, { Position = UDim2.new(0.5, 0, 1, -48), BackgroundTransparency = 0.1 })
		tween(frameStroke, 0.2, { Transparency = 0 })
		tween(label, 0.2, { TextTransparency = 0 })

		task.delay(1.8, function()
			if token ~= id then
				return
			end

			tween(frame, 0.25, { BackgroundTransparency = 1 })
			tween(frameStroke, 0.25, { Transparency = 1 })
			tween(label, 0.25, { TextTransparency = 1 })

			task.delay(0.3, function()
				if token == id then
					frame.Visible = false
				end
			end)
		end)
	end
end

local Tooltip = {}

do
	local tipFrame = new("Frame", {
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = colors.black,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 45,
	}, gui)
	corner(tipFrame, 4)
	stroke(tipFrame, colors.line, 0, 1)

	new("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
	}, tipFrame)

	local tipLabel = new("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextColor3 = colors.white,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 46,
	}, tipFrame)

	new("UISizeConstraint", { MaxSize = Vector2.new(240, 400) }, tipLabel)

	local token = 0

	local function place(x, y)
		local viewport = gui.AbsoluteSize
		local size = tipFrame.AbsoluteSize
		tipFrame.Position = UDim2.fromOffset(
			math.clamp(x + 16, 4, math.max(viewport.X - size.X - 8, 4)),
			math.clamp(y + 20, 4, math.max(viewport.Y - size.Y - 8, 4))
		)
	end

	function Tooltip.attach(object, text)
		if not text then
			return
		end

		object.MouseEnter:Connect(function(x, y)
			token += 1
			local id = token

			task.delay(0.55, function()
				if token == id then
					tipLabel.Text = text
					tipFrame.Visible = true
					place(x, y)
				end
			end)
		end)

		object.MouseMoved:Connect(function(x, y)
			if tipFrame.Visible then
				place(x, y)
			end
		end)

		object.MouseLeave:Connect(function()
			token += 1
			tipFrame.Visible = false
		end)
	end

	function Tooltip.hide()
		token += 1
		tipFrame.Visible = false
	end
end

local Targets = { npcModels = {}, npcTracking = false, onUpdate = nil }

local friendCache = {}
local friendPending = {}
local groupCache = {}
local groupPending = {}

function Targets.checkFriend(other)
	local id = other.UserId

	if other == player or friendCache[id] ~= nil or friendPending[id] then
		return
	end

	friendPending[id] = true

	task.spawn(function()
		local ok, result = pcall(function()
			return player:IsFriendsWith(id)
		end)

		friendPending[id] = nil

		if ok then
			friendCache[id] = result == true
		end

		if Targets.onUpdate then
			Targets.onUpdate()
		end
	end)
end

function Targets.checkGroup(other)
	local groupId = S.protectGroupId

	if groupId <= 0 or other == player then
		return
	end

	local id = other.UserId

	if groupCache[id] ~= nil or groupPending[id] then
		return
	end

	groupPending[id] = true

	task.spawn(function()
		local ok, rank = pcall(function()
			return other:GetRankInGroup(groupId)
		end)

		groupPending[id] = nil

		if ok and groupId == S.protectGroupId then
			groupCache[id] = rank
		end

		if Targets.onUpdate then
			Targets.onUpdate()
		end
	end)
end

function Targets.resetGroup()
	table.clear(groupCache)
	table.clear(groupPending)
end

function Targets.isFriend(other)
	return friendCache[other.UserId] == true
end

function Targets.friendKnown(other)
	return friendCache[other.UserId] ~= nil
end

function Targets.markFriend(id, value)
	friendCache[id] = value
end

function Targets.protected(other)
	local id = other.UserId

	if S.blacklist[id] then
		return true
	end

	if S.skipFriends and friendCache[id] ~= false then
		return true
	end

	if S.protectTeam and other.Team ~= nil and other.Team == player.Team then
		return true
	end

	if S.protectGroup and S.protectGroupId > 0 then
		local rank = groupCache[id]

		if rank == nil or rank >= S.protectGroupRank then
			return true
		end
	end

	return false
end

function Targets.isPriority(other)
	return other ~= nil and S.priority[other.UserId] ~= nil
end

function Targets.fromHit(hit)
	local current = hit

	while current and current ~= workspace do
		if current:IsA("Model") then
			local owner = Players:GetPlayerFromCharacter(current)

			if owner == player then
				return nil
			end

			local humanoid = current:FindFirstChildOfClass("Humanoid")
			local marked = current:GetAttribute("Targetable") == true
				or CollectionService:HasTag(current, "Damageable")

			if (humanoid and humanoid.Health > 0) or marked then
				if S.ignoreForcefield and current:FindFirstChildOfClass("ForceField") then
					return nil
				end

				if owner then
					if not S.playersEnabled or Targets.protected(owner) then
						return nil
					end

					return current
				end

				return S.npcsEnabled and current or nil
			end
		end

		current = current.Parent
	end

	return nil
end

local function trackNpc(instance)
	if instance:IsA("Humanoid") then
		local model = instance.Parent

		if model and model:IsA("Model") and model ~= player.Character then
			Targets.npcModels[model] = true
		end
	end
end

function Targets.ensureNpcTracking()
	if Targets.npcTracking then
		return
	end

	Targets.npcTracking = true

	for _, descendant in ipairs(workspace:GetDescendants()) do
		trackNpc(descendant)
	end

	connect(workspace.DescendantAdded, trackNpc)
	connect(workspace.DescendantRemoving, function(instance)
		if instance:IsA("Humanoid") and instance.Parent then
			Targets.npcModels[instance.Parent] = nil
		end
	end)
end

local Bones = {}

Bones.R15 = {
	{ "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
	{ "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
	{ "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
	{ "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
	{ "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
}

Bones.R6 = {
	{ "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" },
	{ "Torso", "Left Leg" }, { "Torso", "Right Leg" },
}

function Bones.setFor(character)
	if character:FindFirstChild("UpperTorso") then
		return Bones.R15
	elseif character:FindFirstChild("Torso") then
		return Bones.R6
	end

	return nil
end

function Bones.draw(lines, set, character, camera, color, thickness, transparency)
	local used = 0

	if set and camera then
		used = #set

		for index, pair in ipairs(set) do
			local line = lines[index]

			if not line then
				line = new("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Size = UDim2.fromOffset(0, thickness),
					BorderSizePixel = 0,
					Visible = false,
					ZIndex = 2,
				}, gui)
				corner(line, UDim.new(1, 0))
				lines[index] = line
			end

			local visible = false
			local partA = character:FindFirstChild(pair[1])
			local partB = character:FindFirstChild(pair[2])

			if partA and partB and partA:IsA("BasePart") and partB:IsA("BasePart") then
				local a = camera:WorldToViewportPoint(partA.Position)
				local b = camera:WorldToViewportPoint(partB.Position)

				if a.Z > 0 and b.Z > 0 then
					local pointA = Vector2.new(a.X, a.Y)
					local pointB = Vector2.new(b.X, b.Y)
					local delta = pointB - pointA
					local middle = (pointA + pointB) / 2

					line.Position = UDim2.fromOffset(middle.X, middle.Y)
					line.Size = UDim2.fromOffset(delta.Magnitude, thickness)
					line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
					line.BackgroundColor3 = color
					line.BackgroundTransparency = transparency
					visible = true
				end
			end

			line.Visible = visible
		end
	end

	for index = used + 1, #lines do
		lines[index].Visible = false
	end
end

function Bones.clear(lines)
	for _, line in ipairs(lines) do
		line:Destroy()
	end

	table.clear(lines)
end
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local TORSO_NAMES = { HumanoidRootPart = true, UpperTorso = true, LowerTorso = true, Torso = true }

local function getAimPart(model)
	return model:FindFirstChild("Head", true)
		or model:FindFirstChild("HumanoidRootPart", true)
		or model.PrimaryPart
		or model:FindFirstChildWhichIsA("BasePart", true)
end

local Overlay = {}

do
	local ring = new("Frame", {
		Name = "FOV",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(S.fovRadius * 2, S.fovRadius * 2),
		BackgroundColor3 = S.fovColor,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 1,
	}, gui)
	corner(ring, UDim.new(1, 0))
	local ringStroke = stroke(ring, S.fovColor, 1, 1.5)

	local ringAlpha = 0
	local ringRadius = S.fovRadius
	local ringLock = 0
	local crossAlpha = 0

	local cross = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 3,
	}, gui)

	local crossImage = new("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = "rbxassetid://14400935532",
		ImageTransparency = 1,
		Visible = false,
		ZIndex = 3,
	}, cross)

	local crossBars = {}

	for index = 1, 4 do
		crossBars[index] = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 3,
		}, cross)
	end

	local crossDot = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 3,
	}, cross)
	corner(crossDot, UDim.new(1, 0))

	local crossCircle = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 3,
	}, cross)
	corner(crossCircle, UDim.new(1, 0))
	local crossCircleStroke = stroke(crossCircle, colors.white, 1, 1.5)

	local tracerLine = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(0, 2),
		BackgroundColor3 = colors.accent,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 2,
	}, gui)
	corner(tracerLine, UDim.new(1, 0))
	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.9),
			NumberSequenceKeypoint.new(1, 0),
		}),
	}, tracerLine)

	local tracerDot = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(5, 5),
		BackgroundColor3 = colors.npc,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 4,
	}, gui)
	corner(tracerDot, UDim.new(1, 0))
	stroke(tracerDot, colors.white, 0.55, 1)

	local tracerOpacity = 0
	local smoothTarget
	local tracerColor = colors.white

	local skeletonLines = {}
	local skeletonModel
	local skeletonSet

	local hitFrame = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 5,
	}, gui)

	local hitLines = {}

	for index, spec in ipairs({ { -8, -8, 45 }, { 8, 8, 45 }, { 8, -8, -45 }, { -8, 8, -45 } }) do
		hitLines[index] = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(spec[1], spec[2]),
			Size = UDim2.fromOffset(7, 2),
			Rotation = spec[3],
			BackgroundColor3 = colors.white,
			BorderSizePixel = 0,
			ZIndex = 5,
		}, hitFrame)
	end

	local hitTime = -10

	function Overlay.hit()
		hitTime = os.clock()

		local digits = string.gsub(S.hitSoundId, "%D", "")

		if digits ~= "" then
			local sound = Instance.new("Sound")
			sound.SoundId = "rbxassetid://" .. digits
			sound.Volume = 1
			sound.Parent = gui
			sound:Play()
			Debris:AddItem(sound, 4)
		end
	end

	function Overlay.damage(worldPosition, amount)
		local camera = workspace.CurrentCamera

		if not camera then
			return
		end

		local point = camera:WorldToViewportPoint(worldPosition)

		if point.Z <= 0 then
			return
		end

		local label = new("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(point.X, point.Y),
			Size = UDim2.fromOffset(60, 16),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Text = "-" .. tostring(math.floor(amount + 0.5)),
			TextSize = 14,
			TextColor3 = colors.red,
			TextStrokeTransparency = 0.4,
			ZIndex = 6,
		}, gui)

		tween(label, 0.8, {
			Position = UDim2.fromOffset(point.X, point.Y - 36),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		})

		Debris:AddItem(label, 1)
	end

	local function updateCross(alpha, mouse)
		local style = S.sightStyle
		local size = S.sightSize
		local gap = S.sightGap
		local color = S.sightColor
		local transparency = 1 - alpha

		cross.Position = UDim2.fromOffset(mouse.X, mouse.Y)

		crossImage.Visible = style == "Image"
		crossImage.Size = UDim2.fromOffset(size, size)
		crossImage.ImageColor3 = color
		crossImage.ImageTransparency = transparency

		crossDot.Visible = style == "Dot"
		local dotSize = math.max(2, math.floor(size / 4))
		crossDot.Size = UDim2.fromOffset(dotSize, dotSize)
		crossDot.BackgroundColor3 = color
		crossDot.BackgroundTransparency = transparency

		crossCircle.Visible = style == "Circle"
		crossCircle.Size = UDim2.fromOffset(size, size)
		crossCircleStroke.Color = color
		crossCircleStroke.Transparency = transparency

		local barsVisible = style == "Cross"
		local length = math.max(2, size / 2)
		local offset = gap + length / 2

		for index, bar in ipairs(crossBars) do
			bar.Visible = barsVisible
			bar.BackgroundColor3 = color
			bar.BackgroundTransparency = transparency

			if index <= 2 then
				bar.Size = UDim2.fromOffset(2, length)
				bar.Position = UDim2.fromOffset(0, index == 1 and -offset or offset)
			else
				bar.Size = UDim2.fromOffset(length, 2)
				bar.Position = UDim2.fromOffset(index == 3 and -offset or offset, 0)
			end
		end
	end

	local function updateTracer(dt, mouse)
		local camera = workspace.CurrentCamera
		local target = State.currentTarget
		local aimPart = target and getAimPart(target)
		local desired

		if camera and aimPart and aimPart:IsA("BasePart") and aimPart:IsDescendantOf(workspace) then
			local projected = camera:WorldToViewportPoint(aimPart.Position)

			if projected.Z > 0 then
				desired = Vector2.new(projected.X, projected.Y)
				local owner = Players:GetPlayerFromCharacter(target)
				tracerColor = S.tracerColor or (owner and colors.player or colors.npc)
			end
		end

		if S.tracerEnabled and desired then
			tracerOpacity += (1 - tracerOpacity) * (1 - math.exp(-dt * 14))
		else
			tracerOpacity = 0
		end

		if desired then
			if not smoothTarget or tracerOpacity < 0.05 then
				smoothTarget = desired
			else
				smoothTarget = smoothTarget:Lerp(desired, 1 - math.exp(-dt * 18))
			end
		end

		if smoothTarget and tracerOpacity > 0.02 then
			local delta = smoothTarget - mouse
			local distance = delta.Magnitude

			if distance > 12 then
				local direction = delta / distance
				local startPoint = mouse + direction * 7
				local endPoint = smoothTarget - direction * 4
				local middle = (startPoint + endPoint) / 2

				tracerLine.Position = UDim2.fromOffset(middle.X, middle.Y)
				tracerLine.Size = UDim2.fromOffset((endPoint - startPoint).Magnitude, 2)
				tracerLine.Rotation = math.deg(math.atan2(direction.Y, direction.X))
				tracerLine.BackgroundColor3 = tracerColor
				tracerLine.BackgroundTransparency = 1 - tracerOpacity * 0.9
				tracerLine.Visible = true
			else
				tracerLine.Visible = false
			end

			tracerDot.Position = UDim2.fromOffset(smoothTarget.X, smoothTarget.Y)
			tracerDot.BackgroundColor3 = tracerColor
			tracerDot.BackgroundTransparency = 1 - tracerOpacity
			tracerDot.Visible = true
		else
			tracerLine.Visible = false
			tracerDot.Visible = false

			if tracerOpacity <= 0.02 then
				smoothTarget = nil
			end
		end
	end

	local function updateSkeleton()
		local camera = workspace.CurrentCamera
		local target = State.currentTarget

		if not (S.skeletonEnabled and target and camera and target.Parent) then
			skeletonModel = nil
			Bones.draw(skeletonLines, nil, nil, nil, colors.white, 1, 0)
			return
		end

		if skeletonModel ~= target then
			skeletonModel = target
			skeletonSet = Bones.setFor(target)
		end

		local owner = Players:GetPlayerFromCharacter(target)
		local color = S.skeletonColor or (owner and colors.player or colors.npc)

		Bones.draw(skeletonLines, skeletonSet, target, camera, color, S.skeletonThickness, 0.1)
	end

	function Overlay.update(dt, mouse)
		local hover = State.panelHover

		local ringGoal = (S.autoEnabled and not hover) and 1 or 0
		ringAlpha += (ringGoal - ringAlpha) * (1 - math.exp(-dt * 14))
		ringRadius += (S.fovRadius - ringRadius) * (1 - math.exp(-dt * 22))

		if State.locked then
			ringLock += (1 - ringLock) * (1 - math.exp(-dt * 18))
		else
			ringLock = 0
		end

		if ringAlpha > 0.01 then
			local diameter = math.floor(ringRadius + 0.5) * 2
			local ringColor = S.fovColor:Lerp(S.lockColor, ringLock)

			ring.Size = UDim2.fromOffset(diameter, diameter)
			ring.Position = UDim2.fromOffset(mouse.X, mouse.Y)
			ring.BackgroundColor3 = ringColor
			ring.BackgroundTransparency = 1 - (0.04 + 0.05 * ringLock) * ringAlpha
			ringStroke.Color = ringColor
			ringStroke.Transparency = 1 - (0.7 + 0.2 * ringLock) * ringAlpha
			ringStroke.Thickness = 1.5 + 0.5 * ringLock
			ring.Visible = true
		else
			ring.Visible = false
		end

		local crossGoal = (S.autoEnabled and S.sightEnabled and not hover) and 1 or 0
		crossAlpha += (crossGoal - crossAlpha) * (1 - math.exp(-dt * 14))

		if crossAlpha > 0.01 then
			updateCross(crossAlpha, mouse)
			cross.Visible = true
		else
			cross.Visible = false
		end

		updateTracer(dt, mouse)
		updateSkeleton()

		local elapsed = os.clock() - hitTime

		if elapsed < 0.22 then
			hitFrame.Position = UDim2.fromOffset(mouse.X, mouse.Y)
			hitFrame.Visible = true

			for _, line in ipairs(hitLines) do
				line.BackgroundTransparency = elapsed / 0.22
			end
		else
			hitFrame.Visible = false
		end
	end

	function Overlay.cleanup()
		Bones.clear(skeletonLines)
	end
end

local Fx = {}

do
	local lastHealth = setmetatable({}, { __mode = "k" })
	local timer = 0

	function Fx.tick(dt)
		timer += dt

		if timer < 0.1 then
			return
		end

		timer = 0

		if not (S.damageNumbers or S.hitMarker) then
			return
		end

		local now = os.clock()
		local camera = workspace.CurrentCamera

		for _, other in ipairs(Players:GetPlayers()) do
			local character = other ~= player and other.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")

			if humanoid then
				local before = lastHealth[humanoid]
				local health = humanoid.Health
				lastHealth[humanoid] = health

				if before and health < before - 0.5 then
					local head = character:FindFirstChild("Head") or character.PrimaryPart

					if S.damageNumbers and head and camera
						and (head.Position - camera.CFrame.Position).Magnitude <= S.espRange then
						Overlay.damage(head.Position + Vector3.new(0, 1.5, 0), before - health)
					end

					if S.hitMarker and now - State.lastFire < 0.6 and State.lastFireModel == character then
						Overlay.hit()
					end
				end
			end
		end
	end
end

local Trigger = {}

do
	local samples = {}
	local scanTimer = 0
	local lastShot = 0
	local semiLatch = false
	local burstShots = 0
	local burstResume = 0

	function Trigger.rebuild()
		table.clear(samples)

		local radius = S.fovRadius
		local step = math.clamp(math.floor(radius / 4), 6, 14)

		for y = -radius, radius, step do
			for x = -radius, radius, step do
				if x * x + y * y <= radius * radius then
					table.insert(samples, Vector2.new(x, y))
				end
			end
		end

		table.insert(samples, Vector2.zero)

		table.sort(samples, function(a, b)
			return a.X * a.X + a.Y * a.Y < b.X * b.X + b.Y * b.Y
		end)
	end

	Trigger.rebuild()

	function Trigger.scan()
		local character = player.Character
		local camera = workspace.CurrentCamera

		if not character or not camera then
			return nil, nil
		end

		rayParams.FilterDescendantsInstances = { character }

		local mouse = UserInputService:GetMouseLocation()
		local origin = camera.CFrame.Position
		local earlyExit = S.triggerPriority == "Closest to mouse" and next(S.priority) == nil
		local found = {}
		local seen = {}
		local center

		for index, offset in ipairs(samples) do
			local ray = camera:ViewportPointToRay(mouse.X + offset.X, mouse.Y + offset.Y)
			local result = workspace:Raycast(ray.Origin, ray.Direction * S.maxRange, rayParams)

			if result then
				local target = Targets.fromHit(result.Instance)

				if target then
					if offset.X == 0 and offset.Y == 0 and not center then
						center = { model = target, part = result.Instance }
					end

					if not seen[target] then
						seen[target] = true
						table.insert(found, {
							model = target,
							order = index,
							distance = (result.Position - origin).Magnitude,
						})

						if earlyExit then
							break
						end
					end
				end
			end
		end

		if #found == 0 then
			return nil, center
		end

		local metric = "order"

		if S.triggerPriority == "Closest distance" then
			metric = "distance"
		elseif S.triggerPriority == "Lowest health" then
			metric = "health"
		end

		local best

		for _, entry in ipairs(found) do
			local owner = Players:GetPlayerFromCharacter(entry.model)
			local humanoid = entry.model:FindFirstChildOfClass("Humanoid")

			entry.priority = Targets.isPriority(owner)
			entry.health = humanoid and humanoid.Health or math.huge

			if not best
				or (entry.priority and not best.priority)
				or (entry.priority == best.priority and entry[metric] < best[metric]) then
				best = entry
			end
		end

		return best, center
	end

	local function toolAllowed(tool)
		local filter = S.toolFilter

		if filter == "" then
			return true
		end

		local name = tool.Name:lower()

		for token in string.gmatch(filter:lower(), "[^,]+") do
			token = token:match("^%s*(.-)%s*$")

			if token ~= "" and name:find(token, 1, true) then
				return true
			end
		end

		return false
	end

	local function fireTool()
		local character = player.Character

		if not character then
			return false
		end

		for _, item in ipairs(character:GetChildren()) do
			if item:IsA("Tool") and item.Enabled and toolAllowed(item) then
				item:Activate()

				task.delay(0.04, function()
					if character and item.Parent == character then
						item:Deactivate()
					end
				end)

				return true
			end
		end

		return false
	end

	local function modeActive()
		local mode = S.triggerMode

		if mode == "Always" then
			return true
		elseif mode == "Hold Key" then
			return isDown(S.bindHold)
		end

		return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
	end

	local function partAllowed(part)
		local mode = S.triggerPart

		if mode == "Any" then
			return true
		elseif mode == "Head" then
			return part.Name == "Head"
		end

		return TORSO_NAMES[part.Name] == true
	end

	function Trigger.tick(dt)
		scanTimer += dt

		if scanTimer < (S.perfMode and 0.05 or 0.016) then
			return
		end

		scanTimer = 0

		if not S.autoEnabled then
			State.currentTarget = nil
			State.locked = false
			return
		end

		local best
		local center

		if not State.panelHover then
			best, center = Trigger.scan()
		end

		if best then
			State.currentTarget = best.model
			State.locked = true
		else
			State.currentTarget = nil
			State.locked = false
		end

		local now = os.clock()

		if not center then
			semiLatch = false
			burstShots = 0
			return
		end

		if not modeActive() or not partAllowed(center.part) then
			return
		end

		if now - lastShot < S.fireDelayMs / 1000 or now < burstResume then
			return
		end

		if S.fireMode == "Semi" and semiLatch then
			return
		end

		if fireTool() then
			lastShot = now
			State.lastFire = now
			State.lastFireModel = center.model
			semiLatch = true

			if S.fireMode == "Burst" then
				burstShots += 1

				if burstShots >= S.burstSize then
					burstShots = 0
					burstResume = now + 0.4
				end
			end
		end
	end
end
local Assist = {}

do
	local TORSO = { "HumanoidRootPart", "UpperTorso", "Torso" }
	local BODY = {
		"Head",
		"UpperTorso",
		"Torso",
		"LowerTorso",
		"HumanoidRootPart",
		"LeftUpperArm",
		"RightUpperArm",
		"Left Arm",
		"Right Arm",
		"LeftUpperLeg",
		"RightUpperLeg",
		"Left Leg",
		"Right Leg",
	}

	local residual = Vector2.zero
	local ringAlpha = 0
	local ringRadius = S.assistFov
	local ringLock = 0
	local lastModel
	local lockStart = 0
	local switchSkip = 0

	local ring = new("Frame", {
		Name = "AssistFOV",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(S.assistFov * 2, S.assistFov * 2),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 1,
	}, gui)
	corner(ring, UDim.new(1, 0))
	local ringStroke = stroke(ring, S.assistColor, 1, 1.5)

	function Assist.switchTarget()
		switchSkip += 1
	end

	local function firstPart(model, names)
		for _, name in ipairs(names) do
			local part = model:FindFirstChild(name)

			if part and part:IsA("BasePart") then
				return part
			end
		end

		return nil
	end

	local function choosePart(model, camera, mouse)
		if S.assistPart == "Head" then
			return firstPart(model, { "Head" }) or firstPart(model, TORSO)
		elseif S.assistPart == "Torso" then
			return firstPart(model, TORSO)
		end

		local best
		local bestDistance

		for _, name in ipairs(BODY) do
			local part = model:FindFirstChild(name)

			if part and part:IsA("BasePart") then
				local point = camera:WorldToViewportPoint(part.Position)

				if point.Z > 0 then
					local distance = (Vector2.new(point.X, point.Y) - mouse).Magnitude

					if not bestDistance or distance < bestDistance then
						best = part
						bestDistance = distance
					end
				end
			end
		end

		return best
	end

	local function evaluate(model, owner, camera, mouse, origin)
		local humanoid = model:FindFirstChildOfClass("Humanoid")

		if not humanoid or humanoid.Health <= 0 then
			return nil
		end

		if S.ignoreForcefield and model:FindFirstChildOfClass("ForceField") then
			return nil
		end

		if owner then
			if not S.playersEnabled or Targets.protected(owner) then
				return nil
			end

			if S.assistTeam and owner.Team ~= nil and owner.Team == player.Team then
				return nil
			end
		elseif not S.npcsEnabled then
			return nil
		end

		local part = choosePart(model, camera, mouse)

		if not part then
			return nil
		end

		local distance = (part.Position - origin).Magnitude

		if distance > S.assistRange then
			return nil
		end

		local aim = part.Position

		if S.assistLead > 0 then
			aim += part.AssemblyLinearVelocity * (distance / S.assistBulletSpeed) * (S.assistLead / 100)
		end

		local point = camera:WorldToViewportPoint(aim)

		if point.Z <= 0 then
			return nil
		end

		local limit = S.assistFov

		if S.assistDynamic then
			limit = limit * (1 - 0.5 * math.clamp(distance / S.assistRange, 0, 1))
		end

		local offset = (Vector2.new(point.X, point.Y) - mouse).Magnitude

		if offset > limit then
			return nil
		end

		if S.assistWall then
			local character = player.Character
			rayParams.FilterDescendantsInstances = character and { character } or {}

			local result = workspace:Raycast(origin, part.Position - origin, rayParams)

			if result and not result.Instance:IsDescendantOf(model) then
				return nil
			end
		end

		return {
			model = model,
			part = part,
			aim = aim,
			screen = Vector2.new(point.X, point.Y),
			offset = offset,
			distance = distance,
			health = humanoid.Health,
			limit = limit,
			priority = Targets.isPriority(owner),
		}
	end

	local function modeActive()
		local mode = S.assistMode

		if mode == "Always" then
			return true
		elseif mode == "Hold RMB" then
			return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
		elseif mode == "Hold LMB" then
			return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
		end

		return isDown(S.bindHold)
	end

	function Assist.update(dt, mouse)
		local camera = workspace.CurrentCamera
		local active = S.assistEnabled and camera ~= nil and not State.panelHover
		local now = os.clock()
		local best

		if active then
			local origin = camera.CFrame.Position
			local list = {}

			if S.npcsEnabled and not Targets.npcTracking then
				Targets.ensureNpcTracking()
			end

			for _, other in ipairs(Players:GetPlayers()) do
				if other ~= player and other.Character then
					local data = evaluate(other.Character, other, camera, mouse, origin)

					if data then
						table.insert(list, data)
					end
				end
			end

			if S.npcsEnabled then
				for model in pairs(Targets.npcModels) do
					if model ~= player.Character
						and not Players:GetPlayerFromCharacter(model)
						and model:IsDescendantOf(workspace) then
						local data = evaluate(model, nil, camera, mouse, origin)

						if data then
							table.insert(list, data)
						end
					end
				end
			end

			if #list > 0 then
				local metric = "offset"

				if S.assistPriority == "Closest distance" then
					metric = "distance"
				elseif S.assistPriority == "Lowest health" then
					metric = "health"
				end

				table.sort(list, function(a, b)
					if a.priority ~= b.priority then
						return a.priority
					end

					return a[metric] < b[metric]
				end)

				best = list[1]

				if switchSkip > 0 then
					best = list[(switchSkip % #list) + 1]
				end

				if S.assistStickyMs > 0 and lastModel and now - lockStart < S.assistStickyMs / 1000 then
					for _, entry in ipairs(list) do
						if entry.model == lastModel then
							best = entry
							break
						end
					end
				end
			else
				switchSkip = 0
			end
		end

		if best then
			if best.model ~= lastModel then
				lastModel = best.model
				lockStart = now
			end
		else
			lastModel = nil
		end

		State.assistLocked = best ~= nil

		if best and modeActive() then
			local delta = best.screen - mouse
			local distance = delta.Magnitude

			if distance > S.assistDeadzone then
				local t = math.clamp(distance / math.max(best.limit, 1), 0, 1)
				local falloff

				if S.assistCurve == "Ease Out" then
					falloff = 1 - 0.6 * t * t
				elseif S.assistCurve == "Ease In" then
					falloff = 0.4 + 0.6 * (1 - t) * (1 - t)
				else
					falloff = 1 - 0.6 * t
				end

				local boost = S.assistOverdrive / 100
				local rate = (S.assistStrength / 100) * 10 * falloff + boost * 45
				local alpha = 1 - math.exp(-rate * dt)
				local move = delta * alpha
				local cap = (30 + boost * 120) * math.max(dt * 60, 1)

				if move.Magnitude > cap then
					move = move.Unit * cap
				end

				if type(mousemoverel) == "function" then
					local total = residual + move
					local whole = Vector2.new(math.round(total.X), math.round(total.Y))
					residual = total - whole

					if whole.X ~= 0 or whole.Y ~= 0 then
						mousemoverel(whole.X, whole.Y)
					end
				else
					local blend = math.clamp(alpha * 0.5, 0, 1)
					camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(camera.CFrame.Position, best.aim), blend)
				end
			end
		else
			residual = Vector2.zero
		end

		local ringGoal = (S.assistEnabled and S.assistShowFov and not State.panelHover) and 1 or 0
		ringAlpha += (ringGoal - ringAlpha) * (1 - math.exp(-dt * 14))
		ringRadius += (S.assistFov - ringRadius) * (1 - math.exp(-dt * 22))

		if best then
			ringLock += (1 - ringLock) * (1 - math.exp(-dt * 18))
		else
			ringLock = 0
		end

		if ringAlpha > 0.01 then
			local diameter = math.floor(ringRadius + 0.5) * 2
			ring.Size = UDim2.fromOffset(diameter, diameter)
			ring.Position = UDim2.fromOffset(mouse.X, mouse.Y)
			ringStroke.Color = S.assistColor:Lerp(S.lockColor, ringLock)
			ringStroke.Transparency = 1 - (0.75 + 0.2 * ringLock) * ringAlpha
			ring.Visible = true
		else
			ring.Visible = false
		end
	end
end
local function mm2Active()
	return State.mm2Loaded == true
end

local Roles = { murderer = nil, sheriff = nil }

local ESP = {}

do
	local entries = {}
	local frameCount = 0
	local footNames = { "LeftFoot", "RightFoot", "Left Leg", "Right Leg" }

	function ESP.colorFor(owner)
		if owner and mm2Active() and S.mm2Colors then
			if owner == Roles.murderer then
				return S.mm2MurdererColor
			elseif owner == Roles.sheriff then
				return S.mm2SheriffColor
			end

			return S.mm2InnocentColor
		end

		if S.espColor then
			return S.espColor
		end

		if owner then
			if S.espTeamColors and owner.Team then
				return owner.TeamColor.Color
			end

			if S.blacklist[owner.UserId] or Targets.isFriend(owner) then
				return colors.green
			end

			return colors.player
		end

		return colors.npc
	end

	local function getBounds(model, root)
		local position = root.Position
		local topY = position.Y + 2.6
		local bottomY = position.Y - 3
		local head = model:FindFirstChild("Head")

		if head and head:IsA("BasePart") then
			topY = head.Position.Y + head.Size.Y / 2
		end

		local lowest

		for _, name in ipairs(footNames) do
			local part = model:FindFirstChild(name)

			if part and part:IsA("BasePart") then
				local y = part.Position.Y - part.Size.Y / 2
				lowest = lowest and math.min(lowest, y) or y
			end
		end

		if lowest then
			bottomY = lowest
		end

		return Vector3.new(position.X, topY, position.Z), Vector3.new(position.X, bottomY, position.Z)
	end

	local function textLabel(height, bold, textSize)
		return new("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Size = UDim2.fromOffset(180, height),
			BackgroundTransparency = 1,
			Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
			TextSize = textSize,
			TextColor3 = colors.white,
			TextStrokeTransparency = 0.45,
			TextStrokeColor3 = colors.black,
			Visible = false,
			ZIndex = 1,
		}, gui)
	end

	local function createEntry()
		local e = { corners = {}, arrow = {}, bones = {} }

		e.box = new("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 1,
		}, gui)
		e.boxStroke = stroke(e.box, colors.white, 0, 1.5)

		for index = 1, 8 do
			e.corners[index] = new("Frame", { BorderSizePixel = 0, Visible = false, ZIndex = 1 }, gui)
		end

		e.name = textLabel(14, true, 12)
		e.name.AnchorPoint = Vector2.new(0.5, 1)
		e.distance = textLabel(13, false, 11)
		e.tool = textLabel(13, false, 11)
		e.healthText = textLabel(12, true, 10)
		e.healthText.AnchorPoint = Vector2.new(1, 0.5)

		e.healthBack = new("Frame", {
			BackgroundColor3 = colors.black,
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 1,
		}, gui)

		e.healthFill = new("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 1),
			BorderSizePixel = 0,
			ZIndex = 2,
		}, e.healthBack)

		e.headDot = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(6, 6),
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 1,
		}, gui)
		corner(e.headDot, UDim.new(1, 0))

		e.tracer = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 1,
		}, gui)

		for index = 1, 2 do
			e.arrow[index] = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(12, 2),
				BorderSizePixel = 0,
				Visible = false,
				ZIndex = 1,
			}, gui)
		end

		return e
	end

	local function hide(e)
		e.box.Visible = false
		e.name.Visible = false
		e.distance.Visible = false
		e.tool.Visible = false
		e.healthText.Visible = false
		e.healthBack.Visible = false
		e.headDot.Visible = false
		e.tracer.Visible = false

		for _, piece in ipairs(e.corners) do
			piece.Visible = false
		end

		for _, piece in ipairs(e.arrow) do
			piece.Visible = false
		end

		Bones.draw(e.bones, nil, nil, nil, colors.white, 1, 0)
	end

	local function clearChams(e)
		if e.chams then
			e.chams:Destroy()
			e.chams = nil
		end
	end

	local function destroy(model)
		local e = entries[model]

		if not e then
			return
		end

		e.box:Destroy()
		e.name:Destroy()
		e.distance:Destroy()
		e.tool:Destroy()
		e.healthText:Destroy()
		e.healthBack:Destroy()
		e.headDot:Destroy()
		e.tracer:Destroy()

		for _, piece in ipairs(e.corners) do
			piece:Destroy()
		end

		for _, piece in ipairs(e.arrow) do
			piece:Destroy()
		end

		Bones.clear(e.bones)
		clearChams(e)
		entries[model] = nil
	end

	local function drawArrow(e, camera, root, viewport, color, transparency)
		local relative = camera.CFrame:PointToObjectSpace(root.Position)
		local angle = math.atan2(relative.X, -relative.Z)
		local radius = math.min(viewport.X, viewport.Y) / 2 - 60
		local direction = Vector2.new(math.sin(angle), -math.cos(angle))
		local tip = viewport / 2 + direction * radius
		local back = -direction

		for index, wing in ipairs({ 30, -30 }) do
			local rad = math.rad(wing)
			local w = Vector2.new(
				back.X * math.cos(rad) - back.Y * math.sin(rad),
				back.X * math.sin(rad) + back.Y * math.cos(rad)
			)
			local middle = tip + w * 6
			local piece = e.arrow[index]

			piece.Position = UDim2.fromOffset(middle.X, middle.Y)
			piece.Rotation = math.deg(math.atan2(w.Y, w.X))
			piece.BackgroundColor3 = color
			piece.BackgroundTransparency = transparency
			piece.Visible = true
		end
	end

	local function draw(data, camera, mouse, viewport)
		local model = data.model
		local owner = data.owner
		local root = data.root
		local humanoid = data.humanoid
		local distance = data.distance

		local e = entries[model]

		if not e then
			e = createEntry()
			entries[model] = e
		end

		e.seen = true

		local color = ESP.colorFor(owner)
		local fade = S.espFade and (1 - 0.6 * math.clamp(distance / S.espRange, 0, 1)) or 1
		local transparency = 1 - fade

		if S.espChams then
			if not e.chams or not e.chams.Parent then
				local highlight = Instance.new("Highlight")
				highlight.Name = "PawCham"
				highlight.Adornee = model
				highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				highlight.Parent = model
				e.chams = highlight
			end

			e.chams.FillColor = color
			e.chams.OutlineColor = color
			e.chams.FillTransparency = S.chamsFill / 100
			e.chams.OutlineTransparency = S.chamsOutline / 100
		else
			clearChams(e)
		end

		local top, bottom = getBounds(model, root)
		local topPoint = camera:WorldToViewportPoint(top)
		local bottomPoint = camera:WorldToViewportPoint(bottom)
		local centerX = (topPoint.X + bottomPoint.X) / 2
		local centerY = (topPoint.Y + bottomPoint.Y) / 2

		local inView = topPoint.Z > 0
			and bottomPoint.Z > 0
			and centerX > -60
			and centerX < viewport.X + 60
			and centerY > -60
			and centerY < viewport.Y + 60

		if not inView or distance < 1.5 then
			hide(e)

			if S.espArrows then
				drawArrow(e, camera, root, viewport, color, transparency)
			end

			return
		end

		local height = math.max(bottomPoint.Y - topPoint.Y, 4)

		if height > viewport.Y * 3 then
			hide(e)
			return
		end

		local width = math.max(height * 0.55, 4)
		local minX = centerX - width / 2
		local minY = topPoint.Y
		local maxX = minX + width
		local maxY = minY + height
		local style = S.espBoxStyle

		if S.espBoxes and style ~= "Corners" then
			e.box.Position = UDim2.fromOffset(minX, minY)
			e.box.Size = UDim2.fromOffset(width, height)
			e.box.BackgroundColor3 = color
			e.box.BackgroundTransparency = style == "Filled" and (0.85 + transparency * 0.15) or 1
			e.boxStroke.Color = color
			e.boxStroke.Transparency = transparency
			e.box.Visible = true
		else
			e.box.Visible = false
		end

		if S.espBoxes and style == "Corners" then
			local length = math.clamp(math.min(width, height) * 0.25, 6, 20)
			local specs = {
				{ minX, minY, length, 2 },
				{ minX, minY, 2, length },
				{ maxX - length, minY, length, 2 },
				{ maxX - 2, minY, 2, length },
				{ minX, maxY - 2, length, 2 },
				{ minX, maxY - length, 2, length },
				{ maxX - length, maxY - 2, length, 2 },
				{ maxX - 2, maxY - length, 2, length },
			}

			for index, spec in ipairs(specs) do
				local piece = e.corners[index]
				piece.Position = UDim2.fromOffset(spec[1], spec[2])
				piece.Size = UDim2.fromOffset(spec[3], spec[4])
				piece.BackgroundColor3 = color
				piece.BackgroundTransparency = transparency
				piece.Visible = true
			end
		else
			for _, piece in ipairs(e.corners) do
				piece.Visible = false
			end
		end

		if S.espNames then
			e.name.Text = owner and owner.Name or model.Name
			e.name.TextColor3 = color
			e.name.TextTransparency = transparency
			e.name.Position = UDim2.fromOffset(centerX, minY - 2)
			e.name.Visible = true
		else
			e.name.Visible = false
		end

		local labelY = maxY + 2

		if S.espDistance then
			e.distance.Text = string.format("%d studs", math.floor(distance + 0.5))
			e.distance.TextTransparency = transparency
			e.distance.Position = UDim2.fromOffset(centerX, labelY)
			e.distance.Visible = true
			labelY += 13
		else
			e.distance.Visible = false
		end

		local tool = S.espTools and model:FindFirstChildOfClass("Tool")

		if tool then
			e.tool.Text = tool.Name
			e.tool.TextTransparency = transparency
			e.tool.Position = UDim2.fromOffset(centerX, labelY)
			e.tool.Visible = true
		else
			e.tool.Visible = false
		end

		local ratio = 0

		if humanoid.MaxHealth > 0 then
			ratio = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
		end

		if S.espHealth then
			e.healthBack.Position = UDim2.fromOffset(minX - 6, minY)
			e.healthBack.Size = UDim2.fromOffset(3, height)
			e.healthFill.Size = UDim2.fromScale(1, ratio)
			e.healthFill.BackgroundColor3 = colors.red:Lerp(colors.green, ratio)
			e.healthBack.Visible = true
		else
			e.healthBack.Visible = false
		end

		if S.espHealthText then
			e.healthText.Text = tostring(math.floor(humanoid.Health + 0.5))
			e.healthText.TextTransparency = transparency
			e.healthText.Position = UDim2.fromOffset(minX - 10, minY + height * (1 - ratio))
			e.healthText.Visible = true
		else
			e.healthText.Visible = false
		end

		local head = S.espHeadDots and model:FindFirstChild("Head")

		if head and head:IsA("BasePart") then
			local point = camera:WorldToViewportPoint(head.Position)

			if point.Z > 0 then
				e.headDot.Position = UDim2.fromOffset(point.X, point.Y)
				e.headDot.BackgroundColor3 = color
				e.headDot.BackgroundTransparency = transparency
				e.headDot.Visible = true
			else
				e.headDot.Visible = false
			end
		else
			e.headDot.Visible = false
		end

		if S.espTracers then
			local origin

			if S.espTracerOrigin == "Center" then
				origin = viewport / 2
			elseif S.espTracerOrigin == "Mouse" then
				origin = mouse
			else
				origin = Vector2.new(viewport.X / 2, viewport.Y)
			end

			local target = Vector2.new(centerX, maxY)
			local delta = target - origin
			local middle = (origin + target) / 2

			e.tracer.Position = UDim2.fromOffset(middle.X, middle.Y)
			e.tracer.Size = UDim2.fromOffset(delta.Magnitude, 1)
			e.tracer.Rotation = math.deg(math.atan2(delta.Y, delta.X))
			e.tracer.BackgroundColor3 = color
			e.tracer.BackgroundTransparency = math.min(transparency + 0.2, 1)
			e.tracer.Visible = true
		else
			e.tracer.Visible = false
		end

		for _, piece in ipairs(e.arrow) do
			piece.Visible = false
		end

		if S.espSkeleton then
			e.set = e.set or Bones.setFor(model)
			Bones.draw(e.bones, e.set, model, camera, color, 1, math.min(transparency + 0.1, 1))
		else
			Bones.draw(e.bones, nil, nil, nil, color, 1, 0)
		end
	end

	local function gather(list, model, owner, origin)
		local humanoid = model:FindFirstChildOfClass("Humanoid")

		if not humanoid or humanoid.Health <= 0 then
			return
		end

		local root = model:FindFirstChild("HumanoidRootPart")
			or model.PrimaryPart
			or model:FindFirstChildWhichIsA("BasePart")

		if not root then
			return
		end

		local distance = (root.Position - origin).Magnitude

		if distance <= S.espRange then
			table.insert(list, {
				model = model,
				owner = owner,
				root = root,
				humanoid = humanoid,
				distance = distance,
			})
		end
	end

	function ESP.update(dt, mouse)
		frameCount += 1

		local camera = workspace.CurrentCamera

		if not S.espEnabled or not camera then
			for _, e in pairs(entries) do
				hide(e)
				clearChams(e)
			end

			return
		end

		if S.perfMode and frameCount % 2 == 0 then
			return
		end

		local origin = camera.CFrame.Position
		local viewport = camera.ViewportSize
		local list = {}

		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= player and other.Character then
				gather(list, other.Character, other, origin)
			end
		end

		if S.espNpcs then
			Targets.ensureNpcTracking()

			for model in pairs(Targets.npcModels) do
				if Players:GetPlayerFromCharacter(model) or not model:IsDescendantOf(workspace) then
					Targets.npcModels[model] = nil
				else
					gather(list, model, nil, origin)
				end
			end
		end

		table.sort(list, function(a, b)
			return a.distance < b.distance
		end)

		for _, e in pairs(entries) do
			e.seen = false
		end

		for index = 1, math.min(#list, S.espMaxPlayers) do
			draw(list[index], camera, mouse, viewport)
		end

		for model, e in pairs(entries) do
			if not e.seen then
				local owner = Players:GetPlayerFromCharacter(model)

				if not model:IsDescendantOf(workspace) or (not owner and not S.espNpcs) then
					destroy(model)
				else
					hide(e)
					clearChams(e)
				end
			end
		end
	end

	function ESP.cleanup()
		for model in pairs(entries) do
			destroy(model)
		end
	end
end

local Loot = {}

do
	local tools = {}
	local labels = {}
	local tracking = false

	local function track(instance)
		if instance:IsA("Tool") then
			tools[instance] = true
		end
	end

	local function ensure()
		if tracking then
			return
		end

		tracking = true

		for _, descendant in ipairs(workspace:GetDescendants()) do
			track(descendant)
		end

		connect(workspace.DescendantAdded, track)
		connect(workspace.DescendantRemoving, function(instance)
			if tools[instance] then
				tools[instance] = nil

				if labels[instance] then
					labels[instance]:Destroy()
					labels[instance] = nil
				end
			end
		end)
	end

	local function hideAll()
		for _, label in pairs(labels) do
			label.Visible = false
		end
	end

	function Loot.update()
		local camera = workspace.CurrentCamera

		if not S.lootEsp or not camera then
			hideAll()
			return
		end

		ensure()

		local origin = camera.CFrame.Position

		for tool in pairs(tools) do
			local handle = tool:FindFirstChild("Handle")
			local holder = tool.Parent
			local loose = handle
				and handle:IsA("BasePart")
				and holder ~= nil
				and not tool:FindFirstAncestorOfClass("Backpack")
				and not holder:FindFirstChildOfClass("Humanoid")

			local label = labels[tool]
			local shown = false

			if loose then
				local distance = (handle.Position - origin).Magnitude
				local point = camera:WorldToViewportPoint(handle.Position)

				if distance <= S.espRange and point.Z > 0 then
					if not label then
						label = new("TextLabel", {
							AnchorPoint = Vector2.new(0.5, 0.5),
							Size = UDim2.fromOffset(160, 14),
							BackgroundTransparency = 1,
							Font = Enum.Font.Gotham,
							TextSize = 11,
							TextColor3 = colors.white,
							TextStrokeTransparency = 0.45,
							Visible = false,
							ZIndex = 1,
						}, gui)
						labels[tool] = label
					end

					label.Text = string.format("%s [%d]", tool.Name, math.floor(distance + 0.5))
					label.Position = UDim2.fromOffset(point.X, point.Y)
					label.Visible = true
					shown = true
				end
			end

			if label and not shown then
				label.Visible = false
			end
		end
	end

	function Loot.cleanup()
		for _, label in pairs(labels) do
			label:Destroy()
		end

		table.clear(labels)
	end
end

local Radar = {}

do
	local frame = new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -14),
		Size = UDim2.fromOffset(S.radarSize, S.radarSize),
		BackgroundColor3 = colors.black,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 3,
	}, gui)
	corner(frame, UDim.new(1, 0))
	stroke(frame, colors.line, 0, 1)

	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -8, 0, 1),
		BackgroundColor3 = colors.line,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, frame)

	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 1, 1, -8),
		BackgroundColor3 = colors.line,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, frame)

	local center = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(5, 5),
		BackgroundColor3 = colors.white,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, frame)
	corner(center, UDim.new(1, 0))

	local dots = {}

	function Radar.update()
		local camera = workspace.CurrentCamera

		if not S.radar or not camera then
			frame.Visible = false
			return
		end

		frame.Size = UDim2.fromOffset(S.radarSize, S.radarSize)
		frame.Visible = true

		local look = camera.CFrame.LookVector
		local forward = Vector3.new(look.X, 0, look.Z)

		if forward.Magnitude < 0.01 then
			forward = Vector3.new(0, 0, -1)
		else
			forward = forward.Unit
		end

		local right = forward:Cross(Vector3.new(0, 1, 0))
		local origin = camera.CFrame.Position
		local radius = S.radarSize / 2 - 6
		local used = 0

		for _, other in ipairs(Players:GetPlayers()) do
			local character = other ~= player and other.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")

			if root then
				local relative = root.Position - origin
				local x = relative:Dot(right)
				local z = relative:Dot(forward)

				if math.sqrt(x * x + z * z) <= S.radarRange then
					used += 1

					local dot = dots[used]

					if not dot then
						dot = new("Frame", {
							AnchorPoint = Vector2.new(0.5, 0.5),
							Size = UDim2.fromOffset(5, 5),
							BorderSizePixel = 0,
							ZIndex = 4,
						}, frame)
						corner(dot, UDim.new(1, 0))
						dots[used] = dot
					end

					dot.Position = UDim2.new(0.5, x / S.radarRange * radius, 0.5, -z / S.radarRange * radius)
					dot.BackgroundColor3 = ESP.colorFor(other)
					dot.Visible = true
				end
			end
		end

		for index = used + 1, #dots do
			dots[index].Visible = false
		end
	end
end
local Util = {}

do
	local normalSpeed = 16
	local normalJump = 50
	local originalFov
	local fullbrightSaved
	local afkConnection

	local function getHumanoid()
		local character = player.Character
		return character and character:FindFirstChildOfClass("Humanoid")
	end

	function Util.setSpeed(on)
		local humanoid = getHumanoid()

		if not humanoid then
			return
		end

		if on then
			if humanoid.WalkSpeed ~= S.walkSpeed then
				normalSpeed = humanoid.WalkSpeed
			end
		else
			humanoid.WalkSpeed = normalSpeed
		end
	end

	function Util.setJump(on)
		local humanoid = getHumanoid()

		if not humanoid then
			return
		end

		humanoid.UseJumpPower = true

		if on then
			if humanoid.JumpPower ~= S.jumpPower then
				normalJump = humanoid.JumpPower
			end
		else
			humanoid.JumpPower = normalJump
		end
	end

	function Util.tick()
		local humanoid = getHumanoid()

		if not humanoid then
			return
		end

		if S.speedOn and humanoid.WalkSpeed ~= S.walkSpeed then
			humanoid.WalkSpeed = S.walkSpeed
		end

		if S.jumpOn and humanoid.JumpPower ~= S.jumpPower then
			humanoid.UseJumpPower = true
			humanoid.JumpPower = S.jumpPower
		end
	end

	function Util.syncCamera()
		local camera = workspace.CurrentCamera

		if not camera then
			return
		end

		if S.cameraFovOn then
			if not originalFov then
				originalFov = camera.FieldOfView
			end

			camera.FieldOfView = S.cameraFov
		elseif originalFov then
			camera.FieldOfView = originalFov
			originalFov = nil
		end
	end

	function Util.syncFullbright()
		if S.fullbright then
			if not fullbrightSaved then
				fullbrightSaved = {
					Brightness = Lighting.Brightness,
					ClockTime = Lighting.ClockTime,
					FogEnd = Lighting.FogEnd,
					GlobalShadows = Lighting.GlobalShadows,
					Ambient = Lighting.Ambient,
					OutdoorAmbient = Lighting.OutdoorAmbient,
				}
			end

			Lighting.Brightness = 2
			Lighting.ClockTime = 14
			Lighting.FogEnd = 100000
			Lighting.GlobalShadows = false
			Lighting.Ambient = Color3.fromRGB(178, 178, 178)
			Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
		elseif fullbrightSaved then
			for key, value in pairs(fullbrightSaved) do
				Lighting[key] = value
			end

			fullbrightSaved = nil
		end
	end

	function Util.syncAfk()
		if S.antiAfk and not afkConnection then
			afkConnection = player.Idled:Connect(function()
				local ok, virtualUser = pcall(function()
					return game:GetService("VirtualUser")
				end)

				if ok and virtualUser then
					virtualUser:CaptureController()
					virtualUser:ClickButton2(Vector2.new())
				end
			end)
		elseif not S.antiAfk and afkConnection then
			afkConnection:Disconnect()
			afkConnection = nil
		end
	end

	function Util.syncAll()
		Util.syncFullbright()
		Util.syncAfk()
	end

	function Util.restore()
		local humanoid = getHumanoid()

		if humanoid then
			if S.speedOn then
				humanoid.WalkSpeed = normalSpeed
			end

			if S.jumpOn then
				humanoid.JumpPower = normalJump
			end
		end

		local camera = workspace.CurrentCamera

		if camera and originalFov then
			camera.FieldOfView = originalFov
		end

		originalFov = nil

		if fullbrightSaved then
			for key, value in pairs(fullbrightSaved) do
				Lighting[key] = value
			end

			fullbrightSaved = nil
		end

		if afkConnection then
			afkConnection:Disconnect()
			afkConnection = nil
		end
	end
end

local Farm = {}

do
	local cache = {}
	local lastScan = 0
	local currentTween
	local modified = {}

	local function getRoot()
		local character = player.Character
		return character and character:FindFirstChild("HumanoidRootPart")
	end

	local function cancelTween()
		if currentTween then
			currentTween:Cancel()
			currentTween = nil
		end
	end

	local function noclip(on)
		if on then
			local character = player.Character

			if not character then
				return
			end

			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") then
					if modified[part] == nil then
						modified[part] = part.CanCollide
					end

					part.CanCollide = false
				end
			end
		else
			for part, original in pairs(modified) do
				if part.Parent then
					part.CanCollide = original
				end

				modified[part] = nil
			end
		end
	end

	local function parseNames()
		local tokens = {}

		for token in string.gmatch(S.farmNames:lower(), "[^,]+") do
			token = token:match("^%s*(.-)%s*$")

			if token ~= "" then
				table.insert(tokens, token)
			end
		end

		return tokens
	end

	local function findCoins()
		local tokens = parseNames()
		local coins = {}

		if #tokens == 0 then
			return coins
		end

		local character = player.Character

		for _, object in ipairs(workspace:GetDescendants()) do
			if object:IsA("BasePart")
				and not object:IsA("Terrain")
				and not object.CanCollide
				and not (character and object:IsDescendantOf(character)) then
				local name = object.Name:lower()

				for _, token in ipairs(tokens) do
					if name:find(token, 1, true) then
						local model = object:FindFirstAncestorOfClass("Model")

						if not (model and model:FindFirstChildOfClass("Humanoid")) then
							table.insert(coins, object)
						end

						break
					end
				end
			end
		end

		return coins
	end

	local function collect(coin)
		if not coin or not coin.Parent then
			return false
		end

		local root = getRoot()

		if not root then
			return false
		end

		root.CFrame = CFrame.new(coin.Position + Vector3.new(0, 2, 0))
		task.wait(0.05)

		if type(firetouchinterest) == "function" then
			firetouchinterest(root, coin, 0)
			firetouchinterest(root, coin, 1)
		end

		local detector = coin:FindFirstChildOfClass("ClickDetector")

		if detector and type(fireclickdetector) == "function" then
			fireclickdetector(detector)
		end

		local prompt = coin:FindFirstChildOfClass("ProximityPrompt")
			or (coin.Parent and coin.Parent:FindFirstChildOfClass("ProximityPrompt"))

		if prompt and type(fireproximityprompt) == "function" then
			fireproximityprompt(prompt)
		end

		task.wait(0.1)
		return not coin.Parent
	end

	local function moveTo(target)
		local root = getRoot()

		if not root then
			return false
		end

		cancelTween()

		local distance = (root.Position - target).Magnitude

		if distance < 0.5 then
			return true
		end

		local duration = math.clamp(distance / S.farmSpeed, 0.2, 3)
		local tween = TweenService:Create(
			root,
			TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
			{ CFrame = CFrame.new(target) }
		)

		currentTween = tween

		local finished = false
		tween.Completed:Connect(function()
			finished = true
		end)

		tween:Play()

		local started = os.clock()

		while not finished do
			if not root.Parent or not S.coinFarm then
				cancelTween()
				return false
			end

			noclip(true)

			if os.clock() - started > 5 then
				cancelTween()
				break
			end

			task.wait(0.1)
		end

		currentTween = nil
		return true
	end

	function Farm.stop()
		cancelTween()
		noclip(false)
		table.clear(cache)
		lastScan = 0
	end

	function Farm.loop()
		while gui.Parent do
			if S.coinFarm then
				local root = getRoot()

				if root then
					noclip(true)

					if root.Position.Y < -10 then
						root.CFrame = CFrame.new(root.Position.X, 5, root.Position.Z)
					end

					if os.clock() - lastScan > 1.2 then
						cache = findCoins()
						lastScan = os.clock()
					end

					local nearest
					local nearestDistance = math.huge

					for index = #cache, 1, -1 do
						local coin = cache[index]

						if not coin.Parent then
							table.remove(cache, index)
						else
							local distance = (root.Position - coin.Position).Magnitude

							if distance < nearestDistance then
								nearest = coin
								nearestDistance = distance
							end
						end
					end

					if nearest then
						if moveTo(nearest.Position + Vector3.new(0, 3, 0)) then
							collect(nearest)
						end

						local index = table.find(cache, nearest)

						if index then
							table.remove(cache, index)
						end

						task.wait(S.farmDelayMs / 1000)
					else
						task.wait(1)
					end
				else
					task.wait(1)
				end
			else
				if next(modified) or #cache > 0 then
					Farm.stop()
				end

				task.wait(0.5)
			end

			task.wait(0.05)
		end
	end

	connect(player.CharacterAdded, function()
		cancelTween()
		table.clear(modified)
		table.clear(cache)
		lastScan = 0
	end)

	task.spawn(Farm.loop)
end

local MM2 = { onChange = nil }

do
	local gunBoxes = {}
	local timer = 0

	local function hasTool(other, name)
		local backpack = other:FindFirstChildOfClass("Backpack")

		if backpack and backpack:FindFirstChild(name) then
			return true
		end

		local character = other.Character
		return character ~= nil and character:FindFirstChild(name) ~= nil
	end

	function MM2.scan()
		local murderer
		local sheriff

		for _, other in ipairs(Players:GetPlayers()) do
			if hasTool(other, "Knife") then
				murderer = other
			end

			if hasTool(other, "Gun") then
				sheriff = other
			end
		end

		Roles.murderer = murderer
		Roles.sheriff = sheriff

		if MM2.onChange then
			MM2.onChange()
		end
	end

	function MM2.updateGun()
		local visible = S.mm2Gun and mm2Active()

		for _, box in pairs(gunBoxes) do
			box.Color3 = S.mm2GunColor
			box.Visible = visible
		end
	end

	local function trackGun(child)
		if child.Name ~= "GunDrop" or not child:IsA("BasePart") or gunBoxes[child] then
			return
		end

		local box = Instance.new("BoxHandleAdornment")
		box.Name = "PawGunDrop"
		box.Size = child.Size + Vector3.new(0.1, 0.1, 0.1)
		box.Adornee = child
		box.AlwaysOnTop = true
		box.ZIndex = 5
		box.Transparency = 0.5
		box.Color3 = S.mm2GunColor
		box.Visible = S.mm2Gun and mm2Active()
		box.Parent = child
		gunBoxes[child] = box

		child.AncestryChanged:Connect(function()
			if not child:IsDescendantOf(workspace) then
				box:Destroy()
				gunBoxes[child] = nil
			end
		end)
	end

	connect(workspace.ChildAdded, trackGun)

	for _, child in ipairs(workspace:GetChildren()) do
		trackGun(child)
	end

	function MM2.tick(dt)
		timer += dt

		if timer < 0.25 then
			return
		end

		timer = 0

		if not mm2Active() then
			if Roles.murderer or Roles.sheriff then
				Roles.murderer = nil
				Roles.sheriff = nil
			end

			return
		end

		MM2.scan()
		MM2.updateGun()
	end

	function MM2.notify()
		local sent = false

		for _, pair in ipairs({ { "Murderer", Roles.murderer }, { "Sheriff", Roles.sheriff } }) do
			local who = pair[2]

			if who then
				sent = true

				task.spawn(function()
					local image = ""

					pcall(function()
						image = Players:GetUserThumbnailAsync(
							who.UserId,
							Enum.ThumbnailType.HeadShot,
							Enum.ThumbnailSize.Size420x420
						)
					end)

					pcall(function()
						StarterGui:SetCore("SendNotification", {
							Title = pair[1],
							Text = who.Name,
							Icon = image,
							Duration = 5,
						})
					end)
				end)
			end
		end

		if not sent then
			Toast.show("No roles found yet")
		end
	end

	function MM2.load()
		if State.mm2Loaded then
			return
		end

		State.mm2Loaded = true
		MM2.scan()
		MM2.updateGun()

		if MM2.onLoaded then
			MM2.onLoaded()
		end

		Toast.show("MM2 section loaded")
	end

	function MM2.cleanup()
		for _, box in pairs(gunBoxes) do
			box:Destroy()
		end

		table.clear(gunBoxes)
	end
end

local HUD = {}

do
	local label = new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 56),
		Size = UDim2.fromOffset(220, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextColor3 = colors.white,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextStrokeTransparency = 0.6,
		Visible = false,
		ZIndex = 2,
	}, gui)

	local timer = 0
	local frames = 0

	function HUD.update(dt)
		frames += 1
		timer += dt

		if timer < 0.25 then
			return
		end

		local fps = math.floor(frames / timer + 0.5)
		frames = 0
		timer = 0

		local lines = {}

		if S.hudFps then
			table.insert(lines, "FPS " .. fps)
		end

		if S.hudPing then
			local ok, ping = pcall(function()
				return player:GetNetworkPing()
			end)

			if ok then
				table.insert(lines, string.format("Ping %d ms", math.floor(ping * 1000 + 0.5)))
			end
		end

		if S.hudModules then
			local modules = {
				{ S.autoEnabled, "Auto Trigger" },
				{ S.assistEnabled, "Aim Assist" },
				{ S.espEnabled, "ESP" },
				{ S.radar, "Radar" },
				{ S.speedOn, "Speed" },
				{ S.jumpOn, "Jump" },
				{ S.fullbright, "Fullbright" },
				{ S.coinFarm, "Coin Farm" },
				{ S.silentEnabled, "Silent Aim" },
			}

			for _, module in ipairs(modules) do
				if module[1] then
					table.insert(lines, module[2])
				end
			end
		end

		label.Text = table.concat(lines, "\n")
		label.Visible = #lines > 0
	end
end
local Silent = { loaded = false, supported = false, onLoaded = nil }

do
	local env = (type(getgenv) == "function" and getgenv()) or _G
	local token = {}
	local playerMouse = player:GetMouse()
	local aim
	local ownCall = false
	local lastModel
	local rollTime = 0
	local rollPass = true
	local randomPick = {}
	local ringAlpha = 0
	local ringRadius = S.silentFov
	local ringLock = 0
	local ring
	local ringStroke
	local dot
	local oldIndex
	local oldNamecall

	local TORSO = { "HumanoidRootPart", "UpperTorso", "Torso" }
	local BODY = {
		"Head",
		"UpperTorso",
		"Torso",
		"LowerTorso",
		"HumanoidRootPart",
		"LeftUpperArm",
		"RightUpperArm",
		"Left Arm",
		"Right Arm",
		"LeftUpperLeg",
		"RightUpperLeg",
		"Left Leg",
		"Right Leg",
	}

	local function isOwnCall()
		return ownCall or (type(checkcaller) == "function" and checkcaller())
	end

	local function restoreMethod(method)
		if type(setnamecallmethod) == "function" then
			setnamecallmethod(method)
		end
	end

	local function nearShooter(origin)
		local camera = workspace.CurrentCamera

		if camera and (origin - camera.CFrame.Position).Magnitude < 15 then
			return true
		end

		local character = player.Character
		local root = character and character.PrimaryPart

		return root ~= nil and (origin - root.Position).Magnitude < 15
	end

	local function indexHook(self, key)
		if (key == "Hit" or key == "Target" or key == "UnitRay") and self == playerMouse then
			local current = aim

			if current and env.PawSilentToken == token and not isOwnCall() then
				if key == "Hit" then
					return CFrame.new(current.position)
				elseif key == "Target" then
					return current.part
				end

				local origin = workspace.CurrentCamera.CFrame.Position
				return Ray.new(origin, (current.position - origin).Unit)
			end
		end

		return oldIndex(self, key)
	end

	local function namecallHook(self, ...)
		local current = aim

		if not current or env.PawSilentToken ~= token or isOwnCall() then
			return oldNamecall(self, ...)
		end

		local method = getnamecallmethod()

		if self == workspace then
			if method == "Raycast" then
				local origin, direction = ...

				if typeof(origin) == "Vector3"
					and typeof(direction) == "Vector3"
					and direction.Magnitude >= 50
					and nearShooter(origin) then
					local args = table.pack(...)
					args[2] = (current.position - origin).Unit * direction.Magnitude
					restoreMethod(method)
					return oldNamecall(self, table.unpack(args, 1, args.n))
				end
			elseif method == "FindPartOnRay"
				or method == "FindPartOnRayWithIgnoreList"
				or method == "FindPartOnRayWithWhitelist" then
				local ray = ...

				if typeof(ray) == "Ray" and ray.Direction.Magnitude >= 50 and nearShooter(ray.Origin) then
					local args = table.pack(...)
					args[1] = Ray.new(ray.Origin, (current.position - ray.Origin).Unit * ray.Direction.Magnitude)
					restoreMethod(method)
					return oldNamecall(self, table.unpack(args, 1, args.n))
				end
			end
		elseif method == "ViewportPointToRay" or method == "ScreenPointToRay" then
			if self == workspace.CurrentCamera then
				restoreMethod(method)
				local ray = oldNamecall(self, ...)

				if typeof(ray) == "Ray" then
					return Ray.new(ray.Origin, (current.position - ray.Origin).Unit * math.max(ray.Direction.Magnitude, 1))
				end

				return ray
			end
		end

		restoreMethod(method)
		return oldNamecall(self, ...)
	end

	local function hookMeta(name, replacement)
		if type(hookmetamethod) == "function" then
			return hookmetamethod(game, name, replacement)
		end

		local metatable = getrawmetatable(game)
		local old = metatable[name]
		local usesReadonly = type(setreadonly) == "function"

		if usesReadonly then
			setreadonly(metatable, false)
		else
			make_writeable(metatable)
		end

		metatable[name] = replacement

		if usesReadonly then
			setreadonly(metatable, true)
		end

		return old
	end

	local function hooksAvailable()
		return type(newcclosure) == "function"
			and type(getnamecallmethod) == "function"
			and (
				type(hookmetamethod) == "function"
				or (
					type(getrawmetatable) == "function"
					and (type(setreadonly) == "function" or type(make_writeable) == "function")
				)
			)
	end

	local function firstPart(model, names)
		for _, name in ipairs(names) do
			local part = model:FindFirstChild(name)

			if part and part:IsA("BasePart") then
				return part
			end
		end

		return nil
	end

	local function choosePart(model, camera, mouse, now)
		if S.silentPart == "Head" then
			return firstPart(model, { "Head" }) or firstPart(model, TORSO)
		elseif S.silentPart == "Torso" then
			return firstPart(model, TORSO)
		elseif S.silentPart == "Random" then
			local pick = randomPick[model]

			if not pick or now - pick.time > 0.6 or not pick.part.Parent then
				local available = {}

				for _, name in ipairs(BODY) do
					local part = model:FindFirstChild(name)

					if part and part:IsA("BasePart") then
						table.insert(available, part)
					end
				end

				if #available == 0 then
					return nil
				end

				pick = { part = available[math.random(1, #available)], time = now }
				randomPick[model] = pick
			end

			return pick.part
		end

		local best
		local bestDistance

		for _, name in ipairs(BODY) do
			local part = model:FindFirstChild(name)

			if part and part:IsA("BasePart") then
				local point = camera:WorldToViewportPoint(part.Position)

				if point.Z > 0 then
					local distance = (Vector2.new(point.X, point.Y) - mouse).Magnitude

					if not bestDistance or distance < bestDistance then
						best = part
						bestDistance = distance
					end
				end
			end
		end

		return best
	end

	local function evaluate(model, owner, camera, mouse, origin, now, fovLimit)
		local humanoid = model:FindFirstChildOfClass("Humanoid")

		if not humanoid or humanoid.Health <= 0 then
			return nil
		end

		if S.ignoreForcefield and model:FindFirstChildOfClass("ForceField") then
			return nil
		end

		if owner then
			if not S.playersEnabled or Targets.protected(owner) then
				return nil
			end

			if S.silentTeam and owner.Team ~= nil and owner.Team == player.Team then
				return nil
			end
		elseif not S.npcsEnabled then
			return nil
		end

		local part = choosePart(model, camera, mouse, now)

		if not part then
			return nil
		end

		local distance = (part.Position - origin).Magnitude

		if distance > S.silentRange then
			return nil
		end

		local point = camera:WorldToViewportPoint(part.Position)

		if point.Z <= 0 then
			return nil
		end

		local offset = (Vector2.new(point.X, point.Y) - mouse).Magnitude

		if offset > fovLimit then
			return nil
		end

		if S.silentWall then
			local character = player.Character
			rayParams.FilterDescendantsInstances = character and { character } or {}

			local result = workspace:Raycast(origin, part.Position - origin, rayParams)

			if result and not result.Instance:IsDescendantOf(model) then
				return nil
			end
		end

		return {
			model = model,
			part = part,
			distance = distance,
			offset = offset,
			priority = Targets.isPriority(owner),
		}
	end

	local function better(a, b)
		if not b then
			return true
		end

		if a.priority ~= b.priority then
			return a.priority
		end

		return a.offset < b.offset
	end

	function Silent.update(dt, mouse)
		if not Silent.loaded then
			return
		end

		local camera = workspace.CurrentCamera
		local now = os.clock()
		local best

		if S.silentEnabled and camera and not State.panelHover then
			ownCall = true

			pcall(function()
				local origin = camera.CFrame.Position

				if S.npcsEnabled and not Targets.npcTracking then
					Targets.ensureNpcTracking()
				end

				if S.silentSticky and lastModel and lastModel.Parent then
					best = evaluate(
						lastModel,
						Players:GetPlayerFromCharacter(lastModel),
						camera,
						mouse,
						origin,
						now,
						S.silentFov * 1.3
					)
				end

				if not best then
					for _, other in ipairs(Players:GetPlayers()) do
						if other ~= player and other.Character then
							local data = evaluate(other.Character, other, camera, mouse, origin, now, S.silentFov)

							if data and better(data, best) then
								best = data
							end
						end
					end

					if S.npcsEnabled then
						for model in pairs(Targets.npcModels) do
							if model ~= player.Character
								and not Players:GetPlayerFromCharacter(model)
								and model:IsDescendantOf(workspace) then
								local data = evaluate(model, nil, camera, mouse, origin, now, S.silentFov)

								if data and better(data, best) then
									best = data
								end
							end
						end
					end
				end
			end)

			ownCall = false
		end

		if best then
			lastModel = best.model

			local velocity = best.part.AssemblyLinearVelocity
			local lead = (S.silentPredict / 100) * (0.12 + best.distance / 1500)
			best.position = best.part.Position + velocity * lead

			if now - rollTime > 0.25 then
				rollTime = now
				rollPass = math.random(1, 100) <= S.silentHit
			end

			aim = rollPass and best or nil
		else
			lastModel = nil
			aim = nil

			if S.silentPart ~= "Random" and next(randomPick) then
				table.clear(randomPick)
			end
		end

		local ringGoal = (S.silentEnabled and S.silentShowFov and not State.panelHover) and 1 or 0
		ringAlpha += (ringGoal - ringAlpha) * (1 - math.exp(-dt * 14))
		ringRadius += (S.silentFov - ringRadius) * (1 - math.exp(-dt * 22))

		if best then
			ringLock += (1 - ringLock) * (1 - math.exp(-dt * 18))
		else
			ringLock = 0
		end

		local ringColor = S.silentColor:Lerp(S.lockColor, ringLock)

		if ringAlpha > 0.01 then
			local diameter = math.floor(ringRadius + 0.5) * 2
			ring.Size = UDim2.fromOffset(diameter, diameter)
			ring.Position = UDim2.fromOffset(mouse.X, mouse.Y)
			ringStroke.Color = ringColor
			ringStroke.Transparency = 1 - (0.75 + 0.2 * ringLock) * ringAlpha
			ring.Visible = true
		else
			ring.Visible = false
		end

		if best and best.position and S.silentEnabled and not State.panelHover and camera then
			local point = camera:WorldToViewportPoint(best.position)

			if point.Z > 0 then
				dot.Position = UDim2.fromOffset(point.X, point.Y)
				dot.BackgroundColor3 = ringColor
				dot.Visible = true
			else
				dot.Visible = false
			end
		else
			dot.Visible = false
		end
	end

	function Silent.enable()
		if Silent.loaded then
			return
		end

		Silent.loaded = true
		env.PawSilentToken = token

		onCleanup(function()
			env.PawSilentToken = nil
		end)

		if hooksAvailable() then
			Silent.supported = pcall(function()
				oldIndex = hookMeta("__index", newcclosure(indexHook))
				oldNamecall = hookMeta("__namecall", newcclosure(namecallHook))
			end)
		end

		ring = new("Frame", {
			Name = "SilentFOV",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(S.silentFov * 2, S.silentFov * 2),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 1,
		}, gui)
		corner(ring, UDim.new(1, 0))
		ringStroke = stroke(ring, S.silentColor, 1, 1.5)

		dot = new("Frame", {
			Name = "SilentDot",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(6, 6),
			BackgroundColor3 = S.silentColor,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 4,
		}, gui)
		corner(dot, UDim.new(1, 0))
		stroke(dot, colors.white, 0.4, 1)

		if Silent.onLoaded then
			Silent.onLoaded()
		end

		Toast.show(Silent.supported and "Silent aim loaded" or "Silent aim loaded, but hooks are not supported here")
	end
end
local Window = { open = true }

local UI = {
	byKey = {},
	items = {},
	refreshers = {},
	pages = {},
	tabs = {},
	tabOrder = {},
	order = 0,
	active = nil,
}

local function nextOrder()
	UI.order += 1
	return UI.order
end

do
	local defaultSize = Vector2.new(890, 500)
	local saved = meta.window

	local startSize = Vector2.new(
		math.clamp(tonumber(saved.w) or defaultSize.X, 420, 1200),
		math.clamp(tonumber(saved.h) or defaultSize.Y, 280, 800)
	)

	local startPosition = UDim2.new(
		tonumber(saved.sx) or 0.5,
		tonumber(saved.ox) or 0,
		tonumber(saved.sy) or 0.5,
		tonumber(saved.oy) or 0
	)

	local appHome = UDim2.new(0.5, 0, 0, 12)

	if tonumber(meta.appHome.x) and tonumber(meta.appHome.y) then
		appHome = UDim2.fromOffset(meta.appHome.x, meta.appHome.y)
	end

	local appButton = new("TextButton", {
		Name = "PawAppButton",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(appHome.X.Scale, appHome.X.Offset, 0, -50),
		Size = UDim2.fromOffset(76, 30),
		BackgroundColor3 = colors.black,
		Text = "Paw",
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = colors.white,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 10,
	}, gui)
	corner(appButton, 4)
	local appStroke = stroke(appButton, colors.line, 0, 1)

	appButton.MouseEnter:Connect(function()
		tween(appStroke, 0.12, { Color = colors.white })
	end)
	appButton.MouseLeave:Connect(function()
		tween(appStroke, 0.12, { Color = colors.line })
	end)

	local main = new("CanvasGroup", {
		Name = "Main",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = startPosition,
		Size = UDim2.fromOffset(startSize.X, startSize.Y),
		BackgroundColor3 = colors.black,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		ZIndex = 6,
	}, gui)
	corner(main, 4)
	local mainStroke = stroke(main, colors.line, 1, 1)
	local scale = new("UIScale", { Scale = 0.96 }, main)

	new("UISizeConstraint", {
		MinSize = Vector2.new(420, 280),
		MaxSize = Vector2.new(1200, 800),
	}, main)

	local topBar = new("Frame", {
		Name = "TopBar",
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
	}, main)

	makeLabel(topBar, "Paw  " .. VERSION, UDim2.new(1, -130, 1, 0), UDim2.fromOffset(14, 0), 13, colors.white)

	new("Frame", {
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = colors.line,
		BorderSizePixel = 0,
	}, main)

	local function makeControl(index, hoverColor, hoverTransparency)
		local button = new("TextButton", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -((index - 1) * 38 + 6), 0, 2),
			Size = UDim2.fromOffset(34, 30),
			BackgroundColor3 = hoverColor,
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			BorderSizePixel = 0,
		}, topBar)
		corner(button, 4)

		button.MouseEnter:Connect(function()
			tween(button, 0.1, { BackgroundTransparency = hoverTransparency })
		end)
		button.MouseLeave:Connect(function()
			tween(button, 0.1, { BackgroundTransparency = 1 })
		end)

		return button
	end

	local closeControl = makeControl(1, Color3.fromRGB(220, 60, 70), 0.35)
	local maximizeControl = makeControl(2, colors.white, 0.88)
	local minimizeControl = makeControl(3, colors.white, 0.88)

	for _, angle in ipairs({ 45, -45 }) do
		new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(15, 1),
			Rotation = angle,
			BackgroundColor3 = colors.white,
			BorderSizePixel = 0,
		}, closeControl)
	end

	local maximizeGlyph = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(11, 11),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, maximizeControl)
	stroke(maximizeGlyph, colors.white, 0, 1)

	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(12, 1),
		BackgroundColor3 = colors.white,
		BorderSizePixel = 0,
	}, minimizeControl)

	local panel = new("Frame", {
		Name = "Panel",
		Position = UDim2.fromOffset(8, 43),
		Size = UDim2.new(1, -16, 1, -73),
		BackgroundColor3 = colors.panel,
		BorderSizePixel = 0,
	}, main)
	corner(panel, 4)

	local sidebar = new("Frame", {
		Name = "Sidebar",
		Size = UDim2.new(0, 132, 1, 0),
		BackgroundTransparency = 1,
	}, panel)

	local searchBox = new("TextBox", {
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -14, 0, 28),
		BackgroundColor3 = colors.row,
		Text = "",
		PlaceholderText = "Search...",
		PlaceholderColor3 = colors.muted,
		TextColor3 = colors.white,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		BorderSizePixel = 0,
	}, sidebar)
	corner(searchBox, 4)
	new("UIPadding", { PaddingLeft = UDim.new(0, 8) }, searchBox)

	local tabScroll = new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 1, -42),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, sidebar)

	new("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 6),
	}, tabScroll)

	new("UIListLayout", {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, tabScroll)

	new("Frame", {
		Position = UDim2.fromOffset(133, 8),
		Size = UDim2.new(0, 1, 1, -16),
		BackgroundColor3 = colors.line,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
	}, panel)

	local content = new("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(138, 0),
		Size = UDim2.new(1, -138, 1, 0),
		BackgroundTransparency = 1,
	}, panel)

	new("TextLabel", {
		Position = UDim2.new(0, 14, 1, -24),
		Size = UDim2.new(1, -60, 0, 16),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = "Hover a setting for a description",
		TextSize = 10,
		TextColor3 = colors.muted,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, main)

	local resizeHandle = new("Frame", {
		Name = "ResizeHandle",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, 0),
		Size = UDim2.fromOffset(24, 24),
		BackgroundTransparency = 1,
		ZIndex = 12,
	}, main)

	for _, info in ipairs({ { 19, 5 }, { 14, 12 }, { 9, 19 } }) do
		new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(info[1], info[1]),
			Size = UDim2.fromOffset(info[2], 1),
			Rotation = -45,
			BackgroundColor3 = colors.white,
			BackgroundTransparency = 0.15,
			BorderSizePixel = 0,
			ZIndex = 13,
		}, resizeHandle)
	end

	Window.main = main
	Window.tabScroll = tabScroll
	Window.content = content
	Window.searchBox = searchBox

	local transitionId = 0

	local function saveGeometry()
		meta.window = {
			w = main.Size.X.Offset,
			h = main.Size.Y.Offset,
			sx = main.Position.X.Scale,
			ox = main.Position.X.Offset,
			sy = main.Position.Y.Scale,
			oy = main.Position.Y.Offset,
		}
		queueSave()
	end

	local function opacityGoal()
		return (100 - S.uiOpacity) / 100
	end

	local function showApp()
		appButton.Visible = true
		tween(appButton, 0.35, { Position = appHome })
	end

	local function hideApp(id)
		tween(
			appButton,
			0.2,
			{ Position = UDim2.new(appHome.X.Scale, appHome.X.Offset, 0, -50) },
			Enum.EasingStyle.Quint,
			Enum.EasingDirection.In
		)

		task.delay(0.2, function()
			if transitionId == id then
				appButton.Visible = false
			end
		end)
	end

	function Window.show()
		transitionId += 1
		Window.open = true
		main.Visible = true
		tween(scale, 0.3, { Scale = S.uiScale / 100 })
		tween(main, 0.22, { GroupTransparency = opacityGoal() })
		tween(mainStroke, 0.22, { Transparency = 0 })
		hideApp(transitionId)
	end

	function Window.hide()
		transitionId += 1
		local id = transitionId
		Window.open = false
		Tooltip.hide()
		tween(scale, 0.18, { Scale = 0.96 * S.uiScale / 100 })
		tween(main, 0.16, { GroupTransparency = 1 })
		tween(mainStroke, 0.06, { Transparency = 1 })

		task.delay(0.18, function()
			if transitionId == id then
				main.Visible = false
			end
		end)

		showApp()
	end

	function Window.toggle()
		if Window.open then
			Window.hide()
		else
			Window.show()
		end
	end

	function Window.applyLook()
		if Window.open then
			tween(scale, 0.15, { Scale = S.uiScale / 100 })
			tween(main, 0.15, { GroupTransparency = opacityGoal() })
		end
	end

	function Window.mouseOver()
		if not Window.open or not main.Visible then
			return false
		end

		local m = UserInputService:GetMouseLocation()
		local p = main.AbsolutePosition
		local s = main.AbsoluteSize

		return m.X >= p.X and m.X <= p.X + s.X and m.Y >= p.Y and m.Y <= p.Y + s.Y
	end

	local maximized = false
	local restoreSize = main.Size
	local restorePosition = main.Position

	local function toggleMaximize()
		maximized = not maximized

		if maximized then
			restoreSize = main.Size
			restorePosition = main.Position

			local viewport = gui.AbsoluteSize
			local ratio = defaultSize.X / defaultSize.Y
			local width = math.min(1200, viewport.X - 40, (viewport.Y - 40) * ratio)

			tween(main, 0.3, {
				Size = UDim2.fromOffset(width, width / ratio),
				Position = UDim2.fromScale(0.5, 0.5),
			})
		else
			tween(main, 0.3, { Size = restoreSize, Position = restorePosition })
		end

		task.delay(0.35, saveGeometry)
	end

	minimizeControl.MouseButton1Click:Connect(Window.hide)
	maximizeControl.MouseButton1Click:Connect(toggleMaximize)
	closeControl.MouseButton1Click:Connect(function()
		gui:Destroy()
	end)

	local appDragging = false
	local appMoved = false
	local appStart
	local appOrigin

	appButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			appDragging = true
			appMoved = false
			appStart = input.Position
			appOrigin = Vector2.new(appButton.AbsolutePosition.X + appButton.AbsoluteSize.X / 2, appButton.AbsolutePosition.Y)
		end
	end)

	connect(UserInputService.InputChanged, function(input)
		if appDragging
			and (input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - appStart

			if appMoved or delta.Magnitude > 6 then
				appMoved = true

				local viewport = gui.AbsoluteSize
				local x = math.clamp(appOrigin.X + delta.X, 40, viewport.X - 40)
				local y = math.clamp(appOrigin.Y + delta.Y, 0, viewport.Y - 30)

				appHome = UDim2.fromOffset(x, y)
				appButton.Position = appHome
			end
		end
	end)

	connect(UserInputService.InputEnded, function(input)
		if appDragging
			and (input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch) then
			appDragging = false

			if appMoved then
				meta.appHome = { x = appHome.X.Offset, y = appHome.Y.Offset }
				queueSave()
			else
				Window.show()
			end
		end
	end)

	local dragging = false
	local resizing = false
	local dragStart
	local startPos
	local resizeStart
	local startSz
	local resizeStartPos

	topBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = main.Position
		end
	end)

	resizeHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			resizing = true
			resizeStart = input.Position
			startSz = main.Size
			resizeStartPos = main.Position
		end
	end)

	connect(UserInputService.InputChanged, function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		if dragging then
			local delta = input.Position - dragStart
			local viewport = gui.AbsoluteSize
			local cx = startPos.X.Scale * viewport.X + startPos.X.Offset + delta.X
			local cy = startPos.Y.Scale * viewport.Y + startPos.Y.Offset + delta.Y

			cx = math.clamp(cx, 60, math.max(viewport.X - 60, 61))
			cy = math.clamp(cy, 30, math.max(viewport.Y - 30, 31))
			main.Position = UDim2.fromOffset(cx, cy)
		elseif resizing then
			local delta = input.Position - resizeStart
			local width = math.clamp(startSz.X.Offset + delta.X, 420, 1200)
			local height = math.clamp(startSz.Y.Offset + delta.Y, 280, 800)

			main.Size = UDim2.fromOffset(width, height)
			main.Position = UDim2.new(
				resizeStartPos.X.Scale,
				resizeStartPos.X.Offset + (width - startSz.X.Offset) / 2,
				resizeStartPos.Y.Scale,
				resizeStartPos.Y.Offset + (height - startSz.Y.Offset) / 2
			)
		end
	end)

	connect(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			if dragging or resizing then
				dragging = false
				resizing = false
				saveGeometry()
			end
		end
	end)
end

local function makeColumn(parent, position, size)
	local column = new("ScrollingFrame", {
		Position = position,
		Size = size,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = colors.muted,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, parent)

	new("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 28),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	}, column)

	new("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, column)

	return column
end

function UI.select(name)
	UI.active = name

	for pageName, page in pairs(UI.pages) do
		page.Visible = pageName == name
	end

	for tabName, tab in pairs(UI.tabs) do
		local active = tabName == name
		tween(tab.button, 0.14, { BackgroundTransparency = active and 0 or 1 })
		tween(tab.label, 0.14, { TextColor3 = active and colors.white or colors.muted })
		tween(tab.bar, 0.14, { BackgroundTransparency = active and 0 or 1, BackgroundColor3 = S.accentColor })
	end
end

function UI.page(name)
	local page = new("Frame", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
	}, Window.content)

	UI.pages[name] = page
	table.insert(UI.tabOrder, name)

	local button = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = colors.row,
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		LayoutOrder = nextOrder(),
	}, Window.tabScroll)
	corner(button, 4)

	local bar = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(2, 14),
		BackgroundColor3 = S.accentColor,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, button)

	local label = makeLabel(button, name, UDim2.new(1, -16, 1, 0), UDim2.fromOffset(12, 0), 12, colors.muted)
	UI.tabs[name] = { button = button, label = label, bar = bar }

	button.MouseEnter:Connect(function()
		if UI.active ~= name then
			tween(button, 0.1, { BackgroundTransparency = 0.6 })
		end
	end)
	button.MouseLeave:Connect(function()
		if UI.active ~= name then
			tween(button, 0.1, { BackgroundTransparency = 1 })
		end
	end)
	button.MouseButton1Click:Connect(function()
		UI.select(name)
	end)

	local left = makeColumn(page, UDim2.new(0, 0, 0, 0), UDim2.new(0.5, -3, 1, 0))
	local right = makeColumn(page, UDim2.new(0.5, 3, 0, 0), UDim2.new(0.5, -3, 1, 0))
	left:SetAttribute("page", name)
	right:SetAttribute("page", name)

	return left, right
end

function UI.setTabVisible(name, visible)
	local tab = UI.tabs[name]

	if not tab then
		return
	end

	tab.button.Visible = visible

	if not visible and UI.active == name then
		for _, other in ipairs(UI.tabOrder) do
			if UI.tabs[other].button.Visible then
				UI.select(other)
				break
			end
		end
	end
end

function UI.refreshAll()
	for _, refresh in ipairs(UI.refreshers) do
		pcall(refresh)
	end

	if UI.active then
		UI.select(UI.active)
	end
end

function UI.search(query)
	query = query:lower():match("^%s*(.-)%s*$")

	local counts = {}

	for _, item in ipairs(UI.items) do
		local match = query == "" or item.text:find(query, 1, true) ~= nil
		item.frame.Visible = match

		if match then
			counts[item.page] = (counts[item.page] or 0) + 1
		end
	end

	if query ~= "" and UI.active and not counts[UI.active] then
		for _, name in ipairs(UI.tabOrder) do
			if counts[name] and UI.tabs[name].button.Visible then
				UI.select(name)
				break
			end
		end
	end
end

Window.searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	UI.search(Window.searchBox.Text)
end)

local function register(frame, text, col, tipKey)
	table.insert(UI.items, { frame = frame, text = text:lower(), page = col:GetAttribute("page") })
	Tooltip.attach(frame, TIPS[tipKey or text])
end

function UI.set(key, value)
	local control = UI.byKey[key]

	if control and control.apply then
		control.apply(value)
	else
		S[key] = value
	end
end

function UI.header(col, text)
	local label = makeLabel(col, text, UDim2.new(1, 0, 0, 14), UDim2.new(), 10, colors.muted, true)
	label.LayoutOrder = nextOrder()
	register(label, text, col)
	return label
end

function UI.note(col, text, height)
	local card = new("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = colors.row,
		BorderSizePixel = 0,
		LayoutOrder = nextOrder(),
	}, col)
	corner(card, 4)

	local label = makeLabel(card, text, UDim2.new(1, -24, 1, -16), UDim2.fromOffset(12, 8), 11, colors.muted)
	label.TextWrapped = true
	label.TextYAlignment = Enum.TextYAlignment.Top

	return label
end

function UI.switchRow(col, label, get, set, tip, dynamic)
	local row = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = colors.row,
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		LayoutOrder = nextOrder(),
	}, col)
	corner(row, 4)

	makeLabel(row, label, UDim2.new(1, -64, 1, 0), UDim2.fromOffset(12, 0), 12, colors.white)

	local track = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(34, 18),
		BackgroundColor3 = colors.off,
		BorderSizePixel = 0,
	}, row)
	corner(track, UDim.new(1, 0))

	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 9, 0.5, 0),
		Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = colors.muted,
		BorderSizePixel = 0,
	}, track)
	corner(knob, UDim.new(1, 0))

	local api = { row = row }

	function api.refresh(instant)
		local state = get()
		local trackColor = state and S.accentColor or colors.off
		local knobColor = state and colors.black or colors.muted
		local position = state and UDim2.new(1, -9, 0.5, 0) or UDim2.new(0, 9, 0.5, 0)

		if instant then
			track.BackgroundColor3 = trackColor
			knob.BackgroundColor3 = knobColor
			knob.Position = position
		else
			tween(track, 0.16, { BackgroundColor3 = trackColor })
			tween(knob, 0.16, { BackgroundColor3 = knobColor, Position = position })
		end
	end

	row.MouseButton1Click:Connect(function()
		set(not get())
		api.refresh()
	end)

	row.MouseEnter:Connect(function()
		tween(row, 0.1, { BackgroundColor3 = colors.rowHover })
	end)
	row.MouseLeave:Connect(function()
		tween(row, 0.1, { BackgroundColor3 = colors.row })
	end)

	api.refresh(true)

	if not dynamic then
		register(row, label, col, tip)
		table.insert(UI.refreshers, api.refresh)
	end

	return api
end

function UI.toggle(col, label, key, onChange, tip)
	local api

	local function set(value)
		S[key] = value

		if onChange then
			onChange(value)
		end

		queueSave()
	end

	api = UI.switchRow(col, label, function()
		return S[key] == true
	end, set, tip)

	function api.apply(value)
		set(value)
		api.refresh()
	end

	UI.byKey[key] = api
	return api
end

function UI.slider(col, label, key, minimum, maximum, suffix, onChange, gate)
	local card = new("Frame", {
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundColor3 = colors.row,
		BorderSizePixel = 0,
		LayoutOrder = nextOrder(),
	}, col)
	corner(card, 4)

	makeLabel(card, label, UDim2.new(1, -100, 0, 16), UDim2.fromOffset(12, 8), 12, colors.white)

	local valueLabel = makeLabel(card, "", UDim2.fromOffset(90, 16), UDim2.new(1, -102, 0, 8), 11, colors.muted)
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right

	local hit = new("TextButton", {
		Position = UDim2.fromOffset(12, 28),
		Size = UDim2.new(1, -24, 0, 20),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
	}, card)

	local track = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = colors.off,
		BorderSizePixel = 0,
	}, hit)
	corner(track, UDim.new(1, 0))

	local fill = new("Frame", {
		BackgroundColor3 = S.accentColor,
		BorderSizePixel = 0,
	}, track)
	corner(fill, UDim.new(1, 0))

	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = colors.white,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, track)
	corner(knob, UDim.new(1, 0))

	local api = { key = key }
	local dragging = false
	local setDragging

	local function render(value)
		local alpha = (value - minimum) / (maximum - minimum)
		fill.Size = UDim2.new(alpha, 0, 1, 0)
		fill.BackgroundColor3 = S.accentColor
		knob.Position = UDim2.new(alpha, 0, 0.5, 0)
		valueLabel.Text = tostring(value) .. suffix
	end

	function api.refresh()
		render(S[key])
	end

	function api.set(value)
		S[key] = value
		render(value)

		if onChange then
			onChange(value)
		end

		queueSave()
	end

	local function setFromX(x)
		local width = math.max(hit.AbsoluteSize.X, 1)
		local amount = math.clamp((x - hit.AbsolutePosition.X) / width, 0, 1)
		local value = math.floor(minimum + amount * (maximum - minimum) + 0.5)

		if gate and value ~= S[key] and not gate(value, api) then
			setDragging(false)
			render(S[key])
			return
		end

		S[key] = value
		fill.Size = UDim2.new(amount, 0, 1, 0)
		knob.Position = UDim2.new(amount, 0, 0.5, 0)
		valueLabel.Text = tostring(value) .. suffix

		if onChange then
			onChange(value)
		end

		queueSave()
	end

	setDragging = function(state)
		dragging = state
		tween(knob, 0.1, { Size = state and UDim2.fromOffset(15, 15) or UDim2.fromOffset(12, 12) })
	end

	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			setDragging(true)
			setFromX(input.Position.X)
		end
	end)

	connect(UserInputService.InputChanged, function(input)
		if dragging
			and (input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(input.Position.X)
		end
	end)

	connect(UserInputService.InputEnded, function(input)
		if dragging
			and (input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch) then
			setDragging(false)
		end
	end)

	api.refresh()
	register(card, label, col)
	table.insert(UI.refreshers, api.refresh)
	UI.byKey[key] = UI.byKey[key] or api

	return api
end

function UI.choice(col, label, key, options, onChange)
	local button = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = colors.row,
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		LayoutOrder = nextOrder(),
	}, col)
	corner(button, 4)

	local nameLabel = makeLabel(button, label, UDim2.new(0.5, 0, 1, 0), UDim2.fromOffset(12, 0), 12, colors.white)
	local valueLabel = makeLabel(button, "", UDim2.new(0.5, -12, 1, 0), UDim2.new(0.5, 0, 0, 0), 12, colors.muted)
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd

	local api = { key = key }

	function api.refresh()
		valueLabel.Text = tostring(S[key])
	end

	function api.apply(value)
		S[key] = value
		api.refresh()

		if onChange then
			onChange(value)
		end

		queueSave()
	end

	button.MouseButton1Click:Connect(function()
		local index = table.find(options, S[key]) or 0
		api.apply(options[index % #options + 1])
	end)

	button.MouseEnter:Connect(function()
		tween(button, 0.1, { BackgroundColor3 = colors.rowHover })
	end)
	button.MouseLeave:Connect(function()
		tween(button, 0.1, { BackgroundColor3 = colors.row })
	end)

	api.refresh()
	register(button, label, col)
	table.insert(UI.refreshers, api.refresh)
	UI.byKey[key] = api

	return api
end

function UI.field(col, label, placeholder)
	local card = new("Frame", {
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundColor3 = colors.row,
		BorderSizePixel = 0,
		LayoutOrder = nextOrder(),
	}, col)
	corner(card, 4)

	makeLabel(card, label, UDim2.new(1, -24, 0, 16), UDim2.fromOffset(12, 8), 12, colors.white)

	local box = new("TextBox", {
		Position = UDim2.fromOffset(12, 28),
		Size = UDim2.new(1, -24, 0, 22),
		BackgroundColor3 = colors.off,
		Text = "",
		PlaceholderText = placeholder or "",
		PlaceholderColor3 = colors.muted,
		TextColor3 = colors.white,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		ClearTextOnFocus = false,
		ClipsDescendants = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		BorderSizePixel = 0,
	}, card)
	corner(box, 4)
	new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, box)

	register(card, label, col)
	return box
end

function UI.input(col, label, key, onChange)
	local box = UI.field(col, label, "")
	local api = { key = key }

	function api.refresh()
		box.Text = tostring(S[key])
	end

	box.FocusLost:Connect(function()
		local d = DEF[key]
		local raw = box.Text

		if d.kind == "num" then
			raw = tonumber(raw)
		end

		S[key] = decodeValue(d, raw)
		box.Text = tostring(S[key])

		if onChange then
			onChange(S[key])
		end

		queueSave()
	end)

	api.refresh()
	table.insert(UI.refreshers, api.refresh)
	return api
end

function UI.button(col, text, callback, tip)
	local button = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = colors.row,
		Text = text,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextColor3 = colors.white,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		LayoutOrder = nextOrder(),
	}, col)
	corner(button, 4)

	button.MouseEnter:Connect(function()
		tween(button, 0.1, { BackgroundColor3 = colors.rowHover })
	end)
	button.MouseLeave:Connect(function()
		tween(button, 0.1, { BackgroundColor3 = colors.row })
	end)
	button.MouseButton1Click:Connect(callback)

	register(button, text, col, tip)
	return button
end

function UI.info(col, title)
	local row = new("Frame", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = colors.row,
		BorderSizePixel = 0,
		LayoutOrder = nextOrder(),
	}, col)
	corner(row, 4)

	makeLabel(row, title, UDim2.new(0.4, 0, 1, 0), UDim2.fromOffset(12, 0), 12, colors.muted)

	local value = makeLabel(row, "None", UDim2.new(0.6, -12, 1, 0), UDim2.new(0.4, 0, 0, 0), 12, colors.muted)
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.TextTruncate = Enum.TextTruncate.AtEnd

	register(row, title, col)

	return function(text, color)
		value.Text = text
		value.TextColor3 = color
	end
end

function UI.color(col, title, key, withAuto, onChange)
	UI.header(col, title)

	local card = new("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = colors.row,
		BorderSizePixel = 0,
		LayoutOrder = nextOrder(),
	}, col)
	corner(card, 4)

	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, card)

	new("UIPadding", {
		PaddingLeft = UDim.new(0, 7),
		PaddingRight = UDim.new(0, 7),
		PaddingTop = UDim.new(0, 7),
		PaddingBottom = UDim.new(0, 7),
	}, row)

	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}, row)

	local items = {}

	if withAuto then
		table.insert(items, { auto = true })
	end

	for _, color in ipairs(palette) do
		table.insert(items, { color = color })
	end

	local count = #items
	local outlines = {}
	local api = { key = key }

	local function selectedIndex()
		local current = S[key]

		for index, item in ipairs(items) do
			if (item.auto and current == nil) or (item.color ~= nil and item.color == current) then
				return index
			end
		end

		return nil
	end

	function api.refresh()
		local selected = selectedIndex()

		for index, outline in ipairs(outlines) do
			outline.Transparency = index == selected and 0 or 1
		end
	end

	for index, item in ipairs(items) do
		local swatch = new("TextButton", {
			Size = UDim2.new(1 / count, -4 * (count - 1) / count, 1, 0),
			BackgroundColor3 = item.color or colors.white,
			Text = "",
			AutoButtonColor = false,
			BorderSizePixel = 0,
			LayoutOrder = index,
		}, row)
		corner(swatch, 4)

		if item.auto then
			new("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, colors.player),
					ColorSequenceKeypoint.new(0.5, colors.player),
					ColorSequenceKeypoint.new(0.501, colors.npc),
					ColorSequenceKeypoint.new(1, colors.npc),
				}),
				Rotation = 45,
			}, swatch)
		end

		outlines[index] = stroke(swatch, colors.white, 1, 1.5)

		swatch.MouseButton1Click:Connect(function()
			S[key] = item.color

			for otherIndex, outline in ipairs(outlines) do
				tween(outline, 0.12, { Transparency = otherIndex == index and 0 or 1 })
			end

			if onChange then
				onChange(item.color)
			end

			queueSave()
		end)
	end

	api.refresh()
	register(card, title, col)
	table.insert(UI.refreshers, api.refresh)

	return api
end

local Bind = { listening = nil }

function UI.bind(col, label, key)
	local button = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = colors.row,
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		LayoutOrder = nextOrder(),
	}, col)
	corner(button, 4)

	makeLabel(button, label, UDim2.new(0.6, 0, 1, 0), UDim2.fromOffset(12, 0), 12, colors.white)
	local valueLabel = makeLabel(button, "", UDim2.new(0.4, -12, 1, 0), UDim2.new(0.6, 0, 0, 0), 12, colors.muted)
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right

	local api = { key = key }

	function api.refresh()
		valueLabel.Text = Bind.listening == api and "Press a key..." or S[key]
	end

	api.finish = function(name)
		Bind.listening = nil

		if name then
			S[key] = name
			queueSave()
			Toast.show(label .. " set to " .. name)
		end

		api.refresh()
	end

	button.MouseButton1Click:Connect(function()
		Bind.listening = api
		api.refresh()
	end)

	button.MouseEnter:Connect(function()
		tween(button, 0.1, { BackgroundColor3 = colors.rowHover })
	end)
	button.MouseLeave:Connect(function()
		tween(button, 0.1, { BackgroundColor3 = colors.row })
	end)

	api.refresh()
	register(button, label .. " key bind", col)
	table.insert(UI.refreshers, api.refresh)

	return api
end

local askConfirm

do
	local overlay = new("TextButton", {
		Name = "ConfirmOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = colors.black,
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 30,
	}, gui)

	local card = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(340, 156),
		BackgroundColor3 = colors.black,
		BorderSizePixel = 0,
		ZIndex = 31,
	}, overlay)
	corner(card, 4)
	stroke(card, colors.line, 0, 1)

	local cardScale = new("UIScale", { Scale = 0.94 }, card)

	local titleLabel = makeLabel(card, "", UDim2.new(1, -32, 0, 20), UDim2.fromOffset(16, 14), 14, colors.white, true)
	titleLabel.ZIndex = 32

	local messageLabel = makeLabel(card, "", UDim2.new(1, -32, 0, 52), UDim2.fromOffset(16, 42), 12, colors.muted)
	messageLabel.TextWrapped = true
	messageLabel.TextYAlignment = Enum.TextYAlignment.Top
	messageLabel.ZIndex = 32

	local onYes
	local onNo
	local closeId = 0

	local function close()
		closeId += 1
		local id = closeId

		tween(overlay, 0.15, { BackgroundTransparency = 1 })
		tween(cardScale, 0.15, { Scale = 0.94 })

		task.delay(0.16, function()
			if closeId == id then
				overlay.Visible = false
			end
		end)
	end

	local function makeChoice(text, position, filled)
		local button = new("TextButton", {
			Position = position,
			Size = UDim2.new(0.5, -22, 0, 32),
			BackgroundColor3 = filled and colors.white or colors.row,
			Text = text,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = filled and colors.black or colors.white,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			ZIndex = 32,
		}, card)
		corner(button, 4)

		local normal = button.BackgroundColor3
		local hover = filled and Color3.fromRGB(255, 255, 255) or colors.rowHover

		button.MouseEnter:Connect(function()
			tween(button, 0.1, { BackgroundColor3 = hover })
		end)
		button.MouseLeave:Connect(function()
			tween(button, 0.1, { BackgroundColor3 = normal })
		end)

		return button
	end

	local yesButton = makeChoice("Yes", UDim2.new(0, 16, 1, -48), false)
	local noButton = makeChoice("No", UDim2.new(1, -16, 1, -48), true)
	noButton.AnchorPoint = Vector2.new(1, 0)

	yesButton.MouseButton1Click:Connect(function()
		close()

		if onYes then
			onYes()
		end
	end)

	noButton.MouseButton1Click:Connect(function()
		close()

		if onNo then
			onNo()
		end
	end)

	askConfirm = function(title, message, yes, no)
		closeId += 1
		titleLabel.Text = title
		messageLabel.Text = message
		onYes = yes
		onNo = no
		overlay.Visible = true
		tween(overlay, 0.18, { BackgroundTransparency = 0.45 })
		tween(cardScale, 0.2, { Scale = 1 })
	end
end
local function opts(key)
	return DEF[key].a
end

local function announce(name)
	return function(value)
		Toast.show(name .. (value and " on" or " off"))
	end
end

local triggerLeft, triggerRight = UI.page("Trigger")
UI.header(triggerLeft, "TRIGGER")
UI.toggle(triggerLeft, "Auto Trigger", "autoEnabled", announce("Auto Trigger"))
UI.toggle(triggerLeft, "Players", "playersEnabled")
UI.toggle(triggerLeft, "NPCs", "npcsEnabled")
UI.toggle(triggerLeft, "Ignore Forcefield", "ignoreForcefield")
UI.choice(triggerLeft, "Trigger Mode", "triggerMode", opts("triggerMode"))
UI.choice(triggerLeft, "Fire Mode", "fireMode", opts("fireMode"))
UI.choice(triggerLeft, "Hit Part", "triggerPart", opts("triggerPart"))
UI.choice(triggerLeft, "Priority", "triggerPriority", PRIORITIES)
UI.input(triggerLeft, "Tool Filter", "toolFilter")
UI.header(triggerRight, "TUNING")
UI.slider(triggerRight, "Mouse FOV", "fovRadius", 12, 140, " px", function()
	Trigger.rebuild()
end)
UI.slider(triggerRight, "Max Range", "maxRange", 50, 500, " studs")
UI.slider(triggerRight, "Fire Delay", "fireDelayMs", 80, 500, " ms")
UI.slider(triggerRight, "Burst Size", "burstSize", 2, 8, "")

local assistLeft, assistRight = UI.page("Aim Assist")
UI.header(assistLeft, "AIM ASSIST")
UI.toggle(assistLeft, "Aim Assist", "assistEnabled", announce("Aim Assist"))
UI.toggle(assistLeft, "Show FOV", "assistShowFov")
UI.toggle(assistLeft, "Wall Check", "assistWall")
UI.toggle(assistLeft, "Team Check", "assistTeam")
UI.toggle(assistLeft, "Dynamic FOV", "assistDynamic")
UI.choice(assistLeft, "Aim Part", "assistPart", opts("assistPart"))
UI.choice(assistLeft, "Mode", "assistMode", opts("assistMode"))
UI.choice(assistLeft, "Curve", "assistCurve", opts("assistCurve"))
UI.choice(assistLeft, "Priority", "assistPriority", PRIORITIES)

local overdriveAsking = false
local overdrivePending = 0
local overdriveSlider

local function overdriveGate(value)
	if S.overdriveConfirmed or value == 0 then
		return true
	end

	if not overdriveAsking then
		overdriveAsking = true
		overdrivePending = value

		askConfirm(
			"Are you sure?",
			"Overdrive makes the aim assist extremely strong. It will pull hard toward targets. This question only appears once.",
			function()
				overdriveAsking = false
				S.overdriveConfirmed = true
				queueSave()

				if overdriveSlider then
					overdriveSlider.set(overdrivePending)
				end
			end,
			function()
				overdriveAsking = false
			end
		)
	end

	return false
end

UI.header(assistRight, "TUNING")
UI.slider(assistRight, "FOV", "assistFov", 10, 300, " px")
UI.slider(assistRight, "Strength", "assistStrength", 1, 100, " %")
UI.slider(assistRight, "Range", "assistRange", 50, 500, " studs")
UI.slider(assistRight, "Deadzone", "assistDeadzone", 0, 30, " px")
UI.slider(assistRight, "Lead", "assistLead", 0, 100, " %")
UI.slider(assistRight, "Bullet Speed", "assistBulletSpeed", 100, 3000, " st/s")
UI.slider(assistRight, "Sticky Time", "assistStickyMs", 0, 2000, " ms")
overdriveSlider = UI.slider(assistRight, "Overdrive", "assistOverdrive", 0, 100, " %", nil, overdriveGate)
UI.color(assistRight, "ASSIST FOV COLOR", "assistColor", false)

local espLeft, espRight = UI.page("ESP")
UI.header(espLeft, "ESP")
UI.toggle(espLeft, "Enabled", "espEnabled")
UI.toggle(espLeft, "Boxes", "espBoxes")
UI.choice(espLeft, "Box Style", "espBoxStyle", opts("espBoxStyle"))
UI.toggle(espLeft, "Names", "espNames")
UI.toggle(espLeft, "Health", "espHealth")
UI.toggle(espLeft, "Health Text", "espHealthText")
UI.toggle(espLeft, "Distance", "espDistance")
UI.toggle(espLeft, "Tool Names", "espTools")
UI.toggle(espLeft, "Head Dots", "espHeadDots")
UI.toggle(espLeft, "Off-screen Arrows", "espArrows")
UI.toggle(espLeft, "Skeletons", "espSkeleton", nil, "Skeleton")
UI.toggle(espLeft, "Chams", "espChams")
UI.toggle(espLeft, "Tracers", "espTracers")
UI.choice(espLeft, "Tracer Origin", "espTracerOrigin", opts("espTracerOrigin"))
UI.toggle(espLeft, "Team Colors", "espTeamColors")
UI.toggle(espLeft, "Distance Fade", "espFade")
UI.toggle(espLeft, "NPCs", "espNpcs", function(value)
	if value then
		Targets.ensureNpcTracking()
	end
end)
UI.toggle(espLeft, "Loot ESP", "lootEsp")
UI.header(espRight, "TUNING")
UI.slider(espRight, "Range", "espRange", 100, 2000, " studs")
UI.slider(espRight, "Max Players", "espMaxPlayers", 1, 50, "")
UI.slider(espRight, "Chams Fill", "chamsFill", 0, 100, " %")
UI.slider(espRight, "Chams Outline", "chamsOutline", 0, 100, " %")
UI.color(espRight, "ESP COLOR", "espColor", true)
UI.header(espRight, "RADAR")
UI.toggle(espRight, "Radar", "radar")
UI.slider(espRight, "Radar Size", "radarSize", 100, 300, " px")
UI.slider(espRight, "Radar Range", "radarRange", 50, 500, " studs")

local visualLeft, visualRight = UI.page("Visuals")
UI.header(visualLeft, "OVERLAY")
UI.toggle(visualLeft, "Tracer", "tracerEnabled")
UI.toggle(visualLeft, "Sight", "sightEnabled")
UI.choice(visualLeft, "Crosshair Style", "sightStyle", opts("sightStyle"))
UI.toggle(visualLeft, "Skeleton", "skeletonEnabled")
UI.toggle(visualLeft, "Hit Markers", "hitMarker")
UI.input(visualLeft, "Hit Sound ID", "hitSoundId")
UI.toggle(visualLeft, "Damage Numbers", "damageNumbers")
UI.header(visualLeft, "WORLD")
UI.toggle(visualLeft, "Camera FOV", "cameraFovOn")
UI.slider(visualLeft, "FOV Value", "cameraFov", 30, 120, "")
UI.toggle(visualLeft, "Fullbright", "fullbright", function()
	Util.syncFullbright()
end)
UI.header(visualRight, "TUNING")
UI.slider(visualRight, "Sight Size", "sightSize", 4, 40, " px")
UI.slider(visualRight, "Sight Gap", "sightGap", 0, 20, " px")
UI.slider(visualRight, "Skeleton Thickness", "skeletonThickness", 1, 5, " px")
UI.header(visualRight, "COLORS")
UI.color(visualRight, "FOV COLOR", "fovColor", false)
UI.color(visualRight, "LOCK COLOR", "lockColor", false)
UI.color(visualRight, "TRACER COLOR", "tracerColor", true)
UI.color(visualRight, "SIGHT COLOR", "sightColor", false)
UI.color(visualRight, "SKELETON COLOR", "skeletonColor", true)

local playersLeft, playersRight = UI.page("Players")
local refreshPlayerList
local queueListRefresh

UI.header(playersLeft, "PROTECTION")
UI.toggle(playersLeft, "Skip Friends", "skipFriends")
UI.toggle(playersLeft, "Protect Team", "protectTeam")
UI.toggle(playersLeft, "Protect Group", "protectGroup", function()
	Targets.resetGroup()
end)
UI.input(playersLeft, "Group ID", "protectGroupId", function()
	Targets.resetGroup()
end)
UI.slider(playersLeft, "Min Rank", "protectGroupRank", 1, 255, "")
UI.header(playersLeft, "LISTS")
UI.choice(playersLeft, "Edit List", "playerListMode", opts("playerListMode"), function()
	if refreshPlayerList then
		refreshPlayerList()
	end
end)

UI.button(playersLeft, "Import Friends To Blacklist", function()
	task.spawn(function()
		local ok, pages = pcall(function()
			return Players:GetFriendsAsync(player.UserId)
		end)

		if not ok then
			Toast.show("Could not read your friends list")
			return
		end

		local added = 0

		for _ = 1, 20 do
			for _, item in ipairs(pages:GetCurrentPage()) do
				if not S.blacklist[item.Id] then
					S.blacklist[item.Id] = item.Username
					added += 1
				end
			end

			if pages.IsFinished then
				break
			end

			if not pcall(function()
				pages:AdvanceToNextPageAsync()
			end) then
				break
			end
		end

		queueSave()

		if refreshPlayerList then
			refreshPlayerList()
		end

		Toast.show("Added " .. added .. " friends to the blacklist")
	end)
end)

UI.button(playersLeft, "Clear Blacklist", function()
	table.clear(S.blacklist)
	queueSave()
	refreshPlayerList()
end)

UI.button(playersLeft, "Clear Priority List", function()
	table.clear(S.priority)
	queueSave()
	refreshPlayerList()
end)

UI.header(playersRight, "PLAYERS")
local playerSearch = UI.field(playersRight, "Search Players", "type a name")

do
	local listRows = {}
	local listQueued = false

	refreshPlayerList = function()
		for _, row in ipairs(listRows) do
			row:Destroy()
		end

		table.clear(listRows)

		local key = S.playerListMode == "Priority" and "priority" or "blacklist"
		local query = playerSearch.Text:lower()
		local others = {}

		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= player and (query == "" or other.Name:lower():find(query, 1, true)) then
				table.insert(others, other)
			end
		end

		table.sort(others, function(a, b)
			return a.Name:lower() < b.Name:lower()
		end)

		for _, other in ipairs(others) do
			local text = other.Name

			if Targets.isFriend(other) then
				text ..= "  (friend)"
			end

			if S.protectTeam and other.Team ~= nil and other.Team == player.Team then
				text ..= "  (team)"
			end

			local api = UI.switchRow(playersRight, text, function()
				return S[key][other.UserId] ~= nil
			end, function(value)
				S[key][other.UserId] = value and other.Name or nil
				queueSave()
			end, nil, true)

			table.insert(listRows, api.row)
		end
	end

	queueListRefresh = function()
		if listQueued then
			return
		end

		listQueued = true

		task.delay(0.15, function()
			listQueued = false

			if gui.Parent then
				refreshPlayerList()
			end
		end)
	end
end

playerSearch:GetPropertyChangedSignal("Text"):Connect(function()
	refreshPlayerList()
end)

Targets.onUpdate = queueListRefresh

local utilityLeft, utilityRight = UI.page("Utility")
UI.header(utilityLeft, "MOVEMENT")
UI.toggle(utilityLeft, "Speed", "speedOn", function(value)
	Util.setSpeed(value)
	Toast.show("Speed " .. (value and "on" or "off"))
end)
UI.slider(utilityLeft, "Walk Speed", "walkSpeed", 16, 100, "")
UI.toggle(utilityLeft, "Jump", "jumpOn", function(value)
	Util.setJump(value)
end)
UI.slider(utilityLeft, "Jump Power", "jumpPower", 50, 200, "")
UI.header(utilityLeft, "SESSION")
UI.toggle(utilityLeft, "Anti-AFK", "antiAfk", function()
	Util.syncAfk()
end)
UI.toggle(utilityLeft, "Performance Mode", "perfMode")
UI.header(utilityRight, "SCRIPT")
UI.button(utilityRight, "Unload Script", function()
	gui:Destroy()
end)
UI.note(utilityRight, "Unloading removes every overlay, restores speed, camera and lighting, and saves your settings.", 62)
UI.button(utilityRight, "Load MM2 Section", function()
	if State.mm2Loaded then
		Toast.show("MM2 section is already loaded")
	else
		MM2.load()
	end
end)
UI.button(utilityRight, "Load Silent Aim", function()
	if Silent.loaded then
		Toast.show("Silent aim is already loaded")
	else
		Silent.enable()
	end
end)

local function buildSilentPage()
	local silentLeft, silentRight = UI.page("Silent Aim")
	UI.header(silentLeft, "SILENT AIM")

	if not Silent.supported then
		UI.note(
			silentLeft,
			"Silent aim needs an executor with metatable access (hookmetamethod or getrawmetatable). The controls stay inactive without it.",
			78
		)
	end

	UI.toggle(silentLeft, "Silent Aim", "silentEnabled", announce("Silent aim"))
	UI.toggle(silentLeft, "Show FOV", "silentShowFov")
	UI.toggle(silentLeft, "Wall Check", "silentWall")
	UI.toggle(silentLeft, "Team Check", "silentTeam")
	UI.toggle(silentLeft, "Sticky Target", "silentSticky")
	UI.choice(silentLeft, "Aim Part", "silentPart", opts("silentPart"))
	UI.header(silentRight, "TUNING")
	UI.slider(silentRight, "FOV", "silentFov", 10, 400, " px")
	UI.slider(silentRight, "Hit Chance", "silentHit", 1, 100, " %")
	UI.slider(silentRight, "Prediction", "silentPredict", 0, 100, " %")
	UI.slider(silentRight, "Range", "silentRange", 50, 1000, " studs")
	UI.color(silentRight, "SILENT FOV COLOR", "silentColor", false)
end

Silent.onLoaded = buildSilentPage

local interfaceLeft, interfaceRight = UI.page("Interface")
UI.header(interfaceLeft, "WINDOW")
UI.slider(interfaceLeft, "UI Scale", "uiScale", 70, 130, " %", function()
	Window.applyLook()
end)
UI.slider(interfaceLeft, "UI Opacity", "uiOpacity", 40, 100, " %", function()
	Window.applyLook()
end)
UI.toggle(interfaceLeft, "Toasts", "toasts")
UI.header(interfaceLeft, "HUD")
UI.toggle(interfaceLeft, "Module List", "hudModules")
UI.toggle(interfaceLeft, "FPS", "hudFps")
UI.toggle(interfaceLeft, "Ping", "hudPing")
UI.color(interfaceLeft, "THEME ACCENT", "accentColor", false, function()
	UI.refreshAll()
end)
UI.header(interfaceRight, "KEY BINDS")
UI.bind(interfaceRight, "Panel", "bindPanel")
UI.bind(interfaceRight, "Auto Trigger", "bindTrigger")
UI.bind(interfaceRight, "Aim Assist", "bindAssist")
UI.bind(interfaceRight, "ESP", "bindEsp")
UI.bind(interfaceRight, "Hold Key", "bindHold")
UI.bind(interfaceRight, "Switch Target", "bindSwitch")
UI.bind(interfaceRight, "Silent Aim", "bindSilent")
UI.note(interfaceRight, "Click a bind then press a key. Escape clears it. The hold key is used by the Hold Key modes.", 62)

local profilesLeft, profilesRight = UI.page("Profiles")
UI.header(profilesLeft, "PROFILES")
local profileName = UI.field(profilesLeft, "Profile Name", "name")
profileName.Text = meta.currentProfile

local function currentName()
	local name = profileName.Text:match("^%s*(.-)%s*$")

	if name == "" then
		return meta.currentProfile
	end

	return name
end

local refreshProfiles

UI.button(profilesLeft, "Save Profile", function()
	local name = currentName()
	Config.saveProfile(name)
	refreshProfiles()
	Toast.show("Saved profile " .. name)
end)

UI.button(profilesLeft, "Load Profile", function()
	local name = currentName()

	if Config.loadProfile(name) then
		refreshProfiles()
		Toast.show("Loaded profile " .. name)
	else
		Toast.show("No profile named " .. name)
	end
end)

UI.button(profilesLeft, "Delete Profile", function()
	local name = currentName()
	Config.deleteProfile(name)
	refreshProfiles()
	Toast.show("Deleted profile " .. name)
end)

UI.button(profilesLeft, "Use Profile For This Game", function()
	meta.gameProfiles[tostring(game.PlaceId)] = currentName()
	queueSave()
	Toast.show("This game will load " .. currentName())
end)

UI.button(profilesLeft, "Reset To Defaults", function()
	askConfirm("Reset settings?", "This puts every non-global setting back to its default value.", function()
		Config.reset()
		Toast.show("Settings reset")
	end)
end)

UI.header(profilesLeft, "SHARE")
local shareBox = UI.field(profilesLeft, "Export / Import Text", "paste a config here")

UI.button(profilesLeft, "Export", function()
	local text = Config.export()
	shareBox.Text = text

	if type(setclipboard) == "function" then
		setclipboard(text)
		Toast.show("Config copied to clipboard")
	else
		Toast.show("Copy the config from the box")
	end
end)

UI.button(profilesLeft, "Import", function()
	if Config.import(shareBox.Text) then
		Toast.show("Config imported")
	else
		Toast.show("That text is not a valid config")
	end
end)

UI.header(profilesRight, "SAVED PROFILES")

local profileButtons = {}

refreshProfiles = function()
	for _, button in ipairs(profileButtons) do
		button:Destroy()
	end

	table.clear(profileButtons)

	for _, name in ipairs(Config.profileNames()) do
		local text = name

		if name == meta.currentProfile then
			text ..= "  (active)"
		end

		local button = new("TextButton", {
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundColor3 = colors.row,
			Text = text,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextColor3 = colors.white,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			LayoutOrder = nextOrder(),
		}, profilesRight)
		corner(button, 4)

		button.MouseButton1Click:Connect(function()
			profileName.Text = name

			if Config.loadProfile(name) then
				refreshProfiles()
				Toast.show("Loaded profile " .. name)
			end
		end)

		table.insert(profileButtons, button)
	end
end

refreshProfiles()

UI.header(profilesRight, "ABOUT")
UI.note(profilesRight, "Paw " .. VERSION .. (canSave and "  -  settings save to " .. CONFIG_FILE or "  -  saving needs writefile support"), 44)
UI.input(profilesRight, "Update URL", "updateUrl")
UI.button(profilesRight, "Check For Updates", function()
	if S.updateUrl == "" then
		Toast.show("Set an update URL first")
		return
	end

	task.spawn(function()
		local ok, body = pcall(function()
			return game:HttpGet(S.updateUrl)
		end)

		if not ok then
			Toast.show("Update check failed")
			return
		end

		local latest = tostring(body):match("%d+%.%d+%.%d+")

		if latest and latest ~= VERSION then
			Toast.show("Version " .. latest .. " is available")
		else
			Toast.show("You are up to date")
		end
	end)
end)

local mm2Left, mm2Right = UI.page("MM2")
UI.header(mm2Left, "ROLES")
local setMurderer = UI.info(mm2Left, "Murderer")
local setSheriff = UI.info(mm2Left, "Sheriff")
UI.button(mm2Left, "Notify Roles", function()
	MM2.notify()
end)
UI.toggle(mm2Left, "Role Colors", "mm2Colors")
UI.toggle(mm2Left, "Gun Drop ESP", "mm2Gun", function()
	MM2.updateGun()
end)
UI.header(mm2Left, "COIN FARM")
UI.toggle(mm2Left, "Auto Farm Coins", "coinFarm", announce("Coin farm"))
UI.slider(mm2Left, "Fly Speed", "farmSpeed", 10, 120, " st/s")
UI.slider(mm2Left, "Collect Delay", "farmDelayMs", 50, 2000, " ms")
UI.input(mm2Left, "Coin Names", "farmNames")
UI.header(mm2Right, "COLORS")
UI.color(mm2Right, "MURDERER COLOR", "mm2MurdererColor", false)
UI.color(mm2Right, "SHERIFF COLOR", "mm2SheriffColor", false)
UI.color(mm2Right, "INNOCENT COLOR", "mm2InnocentColor", false)
UI.color(mm2Right, "GUN DROP COLOR", "mm2GunColor", false, function()
	MM2.updateGun()
end)

MM2.onLoaded = function()
	UI.setTabVisible("MM2", true)
	UI.select("MM2")
end

MM2.onChange = function()
	local murderer = Roles.murderer
	local sheriff = Roles.sheriff

	setMurderer(murderer and murderer.Name or "None", murderer and S.mm2MurdererColor or colors.muted)
	setSheriff(sheriff and sheriff.Name or "None", sheriff and S.mm2SheriffColor or colors.muted)
end

local logLeft = UI.page("Logs")
UI.header(logLeft, "ERROR LOG")

local logCard = new("Frame", {
	Size = UDim2.new(1, 0, 0, 40),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = colors.row,
	BorderSizePixel = 0,
	LayoutOrder = nextOrder(),
}, logLeft)
corner(logCard, 4)

new("UIPadding", {
	PaddingLeft = UDim.new(0, 10),
	PaddingRight = UDim.new(0, 10),
	PaddingTop = UDim.new(0, 8),
	PaddingBottom = UDim.new(0, 8),
}, logCard)

local logLabel = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	Font = Enum.Font.Code,
	Text = "No errors logged.",
	TextSize = 11,
	TextColor3 = colors.muted,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
}, logCard)

local function renderLog()
	logLabel.Text = #Log.entries > 0 and table.concat(Log.entries, "\n") or "No errors logged."
end

table.insert(Log.listeners, renderLog)

UI.button(logLeft, "Clear Log", function()
	table.clear(Log.entries)
	renderLog()
end)

UI.button(logLeft, "Copy Log", function()
	if type(setclipboard) == "function" then
		setclipboard(table.concat(Log.entries, "\n"))
		Toast.show("Log copied")
	else
		Toast.show("Clipboard is not available")
	end
end)

if UserInputService.TouchEnabled then
	local holder = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(44, 144),
		BackgroundTransparency = 1,
		ZIndex = 8,
	}, gui)

	new("UIListLayout", { Padding = UDim.new(0, 8) }, holder)

	local function touchButton(text, callback)
		local button = new("TextButton", {
			Size = UDim2.fromOffset(44, 44),
			BackgroundColor3 = colors.black,
			BackgroundTransparency = 0.15,
			Text = text,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextColor3 = colors.white,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			ZIndex = 8,
		}, holder)
		corner(button, UDim.new(1, 0))
		stroke(button, colors.line, 0, 1)
		button.MouseButton1Click:Connect(callback)
	end

	touchButton("T", function()
		UI.set("autoEnabled", not S.autoEnabled)
	end)
	touchButton("A", function()
		UI.set("assistEnabled", not S.assistEnabled)
	end)
	touchButton("P", function()
		Window.toggle()
	end)
end

table.insert(Config.hooks, function()
	Trigger.rebuild()
end)
table.insert(Config.hooks, function()
	Targets.resetGroup()
end)
table.insert(Config.hooks, function()
	Util.syncAll()
end)
table.insert(Config.hooks, function()
	UI.refreshAll()
end)
table.insert(Config.hooks, function()
	Window.applyLook()
end)
table.insert(Config.hooks, function()
	UI.setTabVisible("MM2", mm2Active())
end)
table.insert(Config.hooks, function()
	refreshPlayerList()
end)

connect(UserInputService.InputBegan, function(input, processed)
	if input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end

	if Bind.listening then
		local api = Bind.listening

		if input.KeyCode == Enum.KeyCode.Escape then
			api.finish("None")
		else
			api.finish(input.KeyCode.Name)
		end

		return
	end

	if processed then
		return
	end

	local name = input.KeyCode.Name

	if name == S.bindPanel then
		Window.toggle()
	elseif name == S.bindTrigger then
		UI.set("autoEnabled", not S.autoEnabled)
	elseif name == S.bindAssist then
		UI.set("assistEnabled", not S.assistEnabled)
	elseif name == S.bindSilent and Silent.loaded then
		UI.set("silentEnabled", not S.silentEnabled)
	elseif name == S.bindEsp then
		UI.set("espEnabled", not S.espEnabled)
	elseif name == S.bindSwitch then
		Assist.switchTarget()
		Toast.show("Switched assist target")
	end
end)

connect(Players.PlayerAdded, function(other)
	Targets.checkFriend(other)
	Targets.checkGroup(other)
	queueListRefresh()
end)

connect(Players.PlayerRemoving, function()
	queueListRefresh()
end)

for _, other in ipairs(Players:GetPlayers()) do
	Targets.checkFriend(other)
	Targets.checkGroup(other)
end

task.spawn(function()
	while gui.Parent do
		for _, other in ipairs(Players:GetPlayers()) do
			Targets.checkFriend(other)
			Targets.checkGroup(other)
		end

		task.wait(5)
	end
end)

RunService:BindToRenderStep("PawOverlay", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local mouse = UserInputService:GetMouseLocation()
	State.panelHover = Window.mouseOver()

	safe("Overlay", Overlay.update, dt, mouse)
	safe("ESP", ESP.update, dt, mouse)
	safe("Loot", Loot.update)
	safe("Radar", Radar.update)
	safe("Assist", Assist.update, dt, mouse)
	safe("Silent", Silent.update, dt, mouse)
	safe("Camera", Util.syncCamera)
	safe("HUD", HUD.update, dt)
end)

connect(RunService.Heartbeat, function(dt)
	safe("Trigger", Trigger.tick, dt)
	safe("Fx", Fx.tick, dt)
	safe("Util", Util.tick)
	safe("MM2", MM2.tick, dt)
end)

gui.Destroying:Connect(function()
	Config.save()
	RunService:UnbindFromRenderStep("PawOverlay")

	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end

	table.clear(connections)

	S.coinFarm = false
	safe("Cleanup", Farm.stop)
	safe("Cleanup", Util.restore)
	safe("Cleanup", ESP.cleanup)
	safe("Cleanup", Loot.cleanup)
	safe("Cleanup", MM2.cleanup)
	safe("Cleanup", Overlay.cleanup)

	for _, fn in ipairs(cleanups) do
		pcall(fn)
	end
end)

Util.syncAll()
refreshPlayerList()
UI.setTabVisible("MM2", mm2Active())
UI.select("Trigger")
Window.show()

local function askMM2()
	local detected = game.PlaceId == 142823291 or game.PlaceId == 335132309 or game.PlaceId == 636649648

	askConfirm(
		detected and "Murder Mystery 2 detected" or "Load the MM2 section?",
		"Load the MM2 section with role detection, role colors, gun drop ESP and the coin collector?",
		function()
			MM2.load()
		end,
		function()
			Toast.show("MM2 section not loaded")
		end
	)
end

askConfirm(
	"Load silent aim?",
	"Also load silent aim with this script? It hooks game internals, and some games can detect that.",
	function()
		Silent.enable()
		askMM2()
	end,
	function()
		Toast.show("Silent aim not loaded")
		askMM2()
	end
)
