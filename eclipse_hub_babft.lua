-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")

-- ─── FORCE KEY PROMPT EVERY LOAD ─────────────────────────
for _, fname in ipairs({"BaBFT_Key.txt", "BaBFT_Key"}) do
    pcall(function()
        if isfile(fname) then delfile(fname) end
    end)
end

-- Rayfield
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

-- ─── CONFIG ──────────────────────────────────────────────
local config = {
    flySpeed     = 850,
    freeFlySpeed = 80,
}

-- ─── WAYPOINTS ───────────────────────────────────────────
local waypoints = {
    Vector3.new(-45.059,   39.851,   289.557),
    Vector3.new(-52.711,   39.041,  9197.305),
    Vector3.new(-56.999, -347.374,  9476.106),
}
local waypointLabels = {
    "Waypoint 1 of 3",
    "Waypoint 2 of 3",
    "Final Destination",
}

-- ─── STATE ───────────────────────────────────────────────
local flying            = false
local freeFly           = false
local looping           = false
local noclipEnabled     = true
local flyConnection     = nil
local coordConnection   = nil
local freeFlyConnection = nil
local noclipConnection  = nil
local loopThread        = nil
local currentWaypoint   = 1
local countdown         = 0

local mobileInput = {
    forward  = false,
    backward = false,
    left     = false,
    right    = false,
    up       = false,
    down     = false,
}

-- ─── MOBILE D-PAD ────────────────────────────────────────
local mobileGui = nil

local function buildMobileControls()
    if mobileGui then mobileGui:Destroy() end

    mobileGui = Instance.new("ScreenGui")
    mobileGui.Name = "FreeFlyDpad"
    mobileGui.ResetOnSpawn = false
    mobileGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    mobileGui.Enabled = false
    mobileGui.Parent = player.PlayerGui

    local container = Instance.new("Frame")
    container.Size = UDim2.new(0, 230, 0, 230)
    container.Position = UDim2.new(0, 16, 1, -246)
    container.BackgroundTransparency = 1
    container.Parent = mobileGui

    local function makeBtn(parent, text, size, pos, onDown, onUp)
        local btn = Instance.new("TextButton")
        btn.Size = size
        btn.Position = pos
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextScaled = true
        btn.Font = Enum.Font.GothamBold
        btn.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
        btn.BackgroundTransparency = 0.25
        btn.AutoButtonColor = false
        btn.Parent = parent

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 10)
        corner.Parent = btn

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(90, 90, 220)
        stroke.Thickness = 1.5
        stroke.Parent = btn

        btn.MouseButton1Down:Connect(onDown)
        btn.MouseButton1Up:Connect(onUp)
        btn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then onDown() end
        end)
        btn.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then onUp() end
        end)

        return btn
    end

    local S = UDim2.new(0, 54, 0, 54)

    local dpad = Instance.new("Frame")
    dpad.Size = UDim2.new(0, 168, 0, 168)
    dpad.Position = UDim2.new(0, 0, 0, 30)
    dpad.BackgroundTransparency = 1
    dpad.Parent = container

    makeBtn(dpad, "▲", S, UDim2.new(0.5, -27, 0, 0),
        function() mobileInput.forward  = true  end,
        function() mobileInput.forward  = false end)
    makeBtn(dpad, "▼", S, UDim2.new(0.5, -27, 1, -54),
        function() mobileInput.backward = true  end,
        function() mobileInput.backward = false end)
    makeBtn(dpad, "◀", S, UDim2.new(0, 0, 0.5, -27),
        function() mobileInput.left     = true  end,
        function() mobileInput.left     = false end)
    makeBtn(dpad, "▶", S, UDim2.new(1, -54, 0.5, -27),
        function() mobileInput.right    = true  end,
        function() mobileInput.right    = false end)

    local vcol = Instance.new("Frame")
    vcol.Size = UDim2.new(0, 54, 0, 168)
    vcol.Position = UDim2.new(0, 174, 0, 30)
    vcol.BackgroundTransparency = 1
    vcol.Parent = container

    makeBtn(vcol, "↑", S, UDim2.new(0, 0, 0, 0),
        function() mobileInput.up   = true  end,
        function() mobileInput.up   = false end)
    makeBtn(vcol, "↓", S, UDim2.new(0, 0, 0, 58),
        function() mobileInput.down = true  end,
        function() mobileInput.down = false end)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0, 168, 0, 22)
    lbl.Position = UDim2.new(0, 0, 0, 4)
    lbl.Text = "FREE FLY"
    lbl.TextColor3 = Color3.fromRGB(160, 160, 255)
    lbl.BackgroundTransparency = 1
    lbl.TextScaled = true
    lbl.Font = Enum.Font.GothamBold
    lbl.Parent = container
end

local function showMobile()
    if mobileGui then mobileGui.Enabled = true end
end

local function hideMobile()
    if mobileGui then
        mobileGui.Enabled = false
        for k in pairs(mobileInput) do mobileInput[k] = false end
    end
end

-- ─── NOCLIP ──────────────────────────────────────────────
local function enableNoclip()
    if noclipConnection then noclipConnection:Disconnect() end
    noclipConnection = RunService.Stepped:Connect(function()
        if character then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end)
end

local function disableNoclip()
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end
    if character then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end
end

-- ─── FREE FLY ────────────────────────────────────────────
local function startFreeFly()
    if freeFly then return end
    freeFly = true
    humanoid.PlatformStand = true
    if noclipEnabled then enableNoclip() end
    showMobile()

    local bv = Instance.new("BodyVelocity")
    bv.Velocity = Vector3.new(0, 0, 0)
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.P        = 1e4
    bv.Parent   = humanoidRootPart

    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    bg.P         = 1e4
    bg.D         = 200
    bg.CFrame    = humanoidRootPart.CFrame
    bg.Parent    = humanoidRootPart

    local camera = workspace.CurrentCamera

    freeFlyConnection = RunService.Heartbeat:Connect(function()
        if not freeFly then
            bv:Destroy()
            bg:Destroy()
            humanoid.PlatformStand = false
            freeFlyConnection:Disconnect()
            return
        end

        local camCF    = camera.CFrame
        local lookVec  = camCF.LookVector
        local rightVec = camCF.RightVector
        local moveDir  = Vector3.new(0, 0, 0)

        local fwd = 0
        if UserInputService:IsKeyDown(Enum.KeyCode.W) or mobileInput.forward  then fwd =  1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) or mobileInput.backward then fwd = -1 end

        local strafe = 0
        if UserInputService:IsKeyDown(Enum.KeyCode.D) or mobileInput.right then strafe =  1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) or mobileInput.left  then strafe = -1 end

        local vert = 0
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) or mobileInput.up   then vert =  1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
            or mobileInput.down then vert = -1 end

        if fwd    ~= 0 then moveDir = moveDir + lookVec  * fwd    end
        if strafe ~= 0 then moveDir = moveDir + rightVec * strafe end
        if vert   ~= 0 then moveDir = moveDir + Vector3.new(0, vert, 0) end

        if moveDir.Magnitude > 0 then
            bv.Velocity = moveDir.Unit * config.freeFlySpeed
        else
            bv.Velocity = Vector3.new(0, 0, 0)
        end

        bg.CFrame = CFrame.new(humanoidRootPart.Position,
            humanoidRootPart.Position + lookVec)
    end)
end

local function stopFreeFly()
    if not freeFly then return end
    freeFly = false
    if noclipEnabled then disableNoclip() end
    hideMobile()
    humanoid.PlatformStand = false
end

-- ─── TREASURE FLY (multi-waypoint) ───────────────────────
local statusLabel

local function runFlyRoute(onComplete)
    if flying then return end
    flying = true
    currentWaypoint = 1
    if noclipEnabled then enableNoclip() end

    local bv = Instance.new("BodyVelocity")
    bv.Velocity = Vector3.new(0, 0, 0)
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.Parent   = humanoidRootPart

    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(4000, 4000, 4000)
    bg.P         = 10000
    bg.CFrame    = humanoidRootPart.CFrame
    bg.Parent    = humanoidRootPart

    humanoid.PlatformStand = true

    if statusLabel then
        statusLabel:Set("Status: Flying → " .. waypointLabels[currentWaypoint])
    end

    flyConnection = RunService.Heartbeat:Connect(function()
        if not flying then
            bv:Destroy()
            bg:Destroy()
            humanoid.PlatformStand = false
            flyConnection:Disconnect()
            return
        end

        local target     = waypoints[currentWaypoint]
        local currentPos = humanoidRootPart.Position
        local direction  = target - currentPos
        local distance   = direction.Magnitude

        if distance < 8 then
            if currentWaypoint < #waypoints then
                currentWaypoint = currentWaypoint + 1
                Rayfield:Notify({
                    Title    = "Waypoint Reached",
                    Content  = "Now flying to " .. waypointLabels[currentWaypoint],
                    Duration = 3,
                    Image    = "navigation",
                })
                if statusLabel then
                    statusLabel:Set("Status: Flying → " .. waypointLabels[currentWaypoint])
                end
            else
                flying = false
                bv:Destroy()
                bg:Destroy()
                humanoid.PlatformStand = false
                flyConnection:Disconnect()
                if noclipEnabled then disableNoclip() end
                if statusLabel then
                    statusLabel:Set("Status: Route complete. Waiting 15s...")
                end
                Rayfield:Notify({
                    Title    = "Route Complete",
                    Content  = "Treasure reached. Restarting in 15 seconds.",
                    Duration = 6,
                    Image    = "check",
                })
                if onComplete then onComplete() end
            end
            return
        end

        bv.Velocity = direction.Unit * config.flySpeed
        bg.CFrame   = CFrame.lookAt(currentPos, target)
    end)
end

-- ─── LOOP LOGIC ──────────────────────────────────────────
local function stopLoop()
    looping = false
    if loopThread then
        task.cancel(loopThread)
        loopThread = nil
    end
    flying = false
    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end
    if noclipEnabled then disableNoclip() end
    humanoid.PlatformStand = false
    countdown = 0
    if statusLabel then statusLabel:Set("Status: Stopped.") end
end

local function startLoop()
    if looping then return end
    looping = true

    loopThread = task.spawn(function()
        while looping do
            local routeDone = false
            runFlyRoute(function()
                routeDone = true
            end)

            while not routeDone and looping do
                task.wait(0.1)
            end

            if not looping then break end

            for i = 15, 1, -1 do
                if not looping then break end
                countdown = i
                if statusLabel then
                    statusLabel:Set(string.format("Status: Restarting in %ds...", i))
                end
                task.wait(1)
            end

            if not looping then break end

            if statusLabel then statusLabel:Set("Status: Restarting route...") end
            task.wait(0.2)
        end
    end)
end

-- ─── RAYFIELD WINDOW ─────────────────────────────────────
local Window = Rayfield:CreateWindow({
    Name = "Eclipse Hub Babft",
    LoadingTitle = "Verifying Key...",
    LoadingSubtitle = "by DOCTOR BOB",
    ConfigurationSaving = { Enabled = false },
    Discord = { Enabled = false },
    KeySystem = true,
    KeySettings = {
        Title           = "Eclipse Hub Babft",
        Subtitle        = "Key Required",
        Note            = "Enter your access key to continue.",
        FileName        = "BaBFT_Key",
        SaveKey         = false,
        GrabKeyFromSite = false,
        Key             = {"DoctorBob123"},
    },
})

-- ─── TABS ────────────────────────────────────────────────
local MainTab   = Window:CreateTab("Main",        "navigation")
local MiscTab   = Window:CreateTab("Misc",        "wind")
local CoordsTab = Window:CreateTab("Coordinates", "map-pin")

-- ─── MAIN TAB ────────────────────────────────────────────
MainTab:CreateSection("Treasure Auto-Fly")
statusLabel = MainTab:CreateLabel("Status: Idle")
MainTab:CreateLabel("Route: WP1 → WP2 → Treasure → 15s → repeat")

MainTab:CreateButton({
    Name = "Start Autofarm",
    Callback = function()
        stopFreeFly()
        startLoop()
    end,
})

MainTab:CreateButton({
    Name = "Stop Autofarm",
    Callback = function()
        stopLoop()
    end,
})

MainTab:CreateButton({
    Name = "Teleport to Treasure",
    Callback = function()
        stopLoop()
        stopFreeFly()
        humanoidRootPart.CFrame = CFrame.new(waypoints[#waypoints])
        statusLabel:Set("Status: Teleported to final destination.")
        Rayfield:Notify({
            Title    = "Teleported",
            Content  = "Dropped at final treasure coordinates.",
            Duration = 4,
            Image    = "map-pin",
        })
    end,
})

MainTab:CreateSlider({
    Name = "Autofarm Fly Speed",
    Range = {1, 1000},
    Increment = 1,
    Suffix = "studs/s",
    CurrentValue = config.flySpeed,
    Flag = "FlySpeed",
    Callback = function(value)
        config.flySpeed = value
    end,
})

-- ─── MISC TAB ────────────────────────────────────────────
MiscTab:CreateSection("Free Fly")
MiscTab:CreateLabel("▲▼◀▶  —  Move direction")
MiscTab:CreateLabel("↑↓    —  Ascend / Descend")
MiscTab:CreateLabel("WASD + Space / LCtrl on desktop")

MiscTab:CreateToggle({
    Name = "Enable Free Fly",
    CurrentValue = false,
    Flag = "FreeFlyToggle",
    Callback = function(state)
        if state then
            stopLoop()
            startFreeFly()
        else
            stopFreeFly()
        end
    end,
})

MiscTab:CreateSlider({
    Name = "Free Fly Speed",
    Range = {10, 300},
    Increment = 5,
    Suffix = "studs/s",
    CurrentValue = config.freeFlySpeed,
    Flag = "FreeFlySpeed",
    Callback = function(value)
        config.freeFlySpeed = value
    end,
})

MiscTab:CreateToggle({
    Name = "Noclip",
    CurrentValue = true,
    Flag = "NoclipToggle",
    Callback = function(state)
        noclipEnabled = state
        if state then
            if flying or freeFly then enableNoclip() end
        else
            disableNoclip()
        end
    end,
})

-- ─── COORDINATES TAB ─────────────────────────────────────
CoordsTab:CreateSection("Live Position")
local coordX    = CoordsTab:CreateLabel("X:  0.000")
local coordY    = CoordsTab:CreateLabel("Y:  0.000")
local coordZ    = CoordsTab:CreateLabel("Z:  0.000")

CoordsTab:CreateSection("Distance to Next Waypoint")
local distLabel = CoordsTab:CreateLabel("Distance:  calculating...")

CoordsTab:CreateSection("Actions")
CoordsTab:CreateButton({
    Name = "Copy Coordinates to Clipboard",
    Callback = function()
        local pos = humanoidRootPart.Position
        local str = string.format("Vector3.new(%.3f, %.3f, %.3f)", pos.X, pos.Y, pos.Z)
        setclipboard(str)
        Rayfield:Notify({
            Title    = "Copied",
            Content  = str,
            Duration = 4,
            Image    = "clipboard",
        })
    end,
})

local function startCoordLoop()
    if coordConnection then coordConnection:Disconnect() end
    coordConnection = RunService.Heartbeat:Connect(function()
        local ok, pos = pcall(function() return humanoidRootPart.Position end)
        if not ok then return end
        local idx    = math.clamp(currentWaypoint, 1, #waypoints)
        local target = waypoints[idx]
        local dist   = (pos - target).Magnitude
        coordX:Set(string.format("X:  %.3f", pos.X))
        coordY:Set(string.format("Y:  %.3f", pos.Y))
        coordZ:Set(string.format("Z:  %.3f", pos.Z))
        distLabel:Set(string.format("Distance to %s:  %.1f studs",
            waypointLabels[idx], dist))
    end)
end

startCoordLoop()

-- ─── RESPAWN HANDLING ────────────────────────────────────
player.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoidRootPart = newChar:WaitForChild("HumanoidRootPart")
    humanoid = newChar:WaitForChild("Humanoid")
    flying  = false
    freeFly = false
    currentWaypoint = 1
    for k in pairs(mobileInput) do mobileInput[k] = false end
    statusLabel:Set("Status: Respawned. Ready.")
    startCoordLoop()
end)

-- ─── BUILD D-PAD + BOOT ──────────────────────────────────
buildMobileControls()

Rayfield:Notify({
    Title    = "Eclipse Hub Babft Loaded",
    Content  = "Key verified. Press Start Autofarm to begin.",
    Duration = 5,
    Image    = "anchor",
})
