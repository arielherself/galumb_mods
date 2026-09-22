local UEHelpers = require("UEHelpers")

print("[FreeTeleport] loaded - safe movement version\n")

-- ============================================================
-- Config
-- ============================================================

local TOGGLE_KEY = Key.F7

local FLY_SPEED = 1600.0
local BOOST_SPEED = 4000.0
local DEADZONE = 0.15

-- ============================================================
-- State
-- ============================================================

local active = false

local startLocation = nil
local startRotation = nil

local savedMaxFlySpeed = nil

local previousA = false
local previousB = false

-- ============================================================
-- Keys
-- ============================================================

local function FKey(name)
    return {
        KeyName = FName(name)
    }
end

-- keyboard
local KEY_W     = FKey("W")
local KEY_A     = FKey("A")
local KEY_S     = FKey("S")
local KEY_D     = FKey("D")
local KEY_Q     = FKey("Q")
local KEY_E     = FKey("E")
local KEY_SHIFT = FKey("LeftShift")

-- gamepad
local PAD_LX = FKey("Gamepad_LeftX")
local PAD_LY = FKey("Gamepad_LeftY")
local PAD_LT = FKey("Gamepad_LeftTriggerAxis")
local PAD_RT = FKey("Gamepad_RightTriggerAxis")

local PAD_A  = FKey("Gamepad_FaceButton_Bottom")
local PAD_B  = FKey("Gamepad_FaceButton_Right")
local PAD_LB = FKey("Gamepad_LeftShoulder")

-- ============================================================
-- Helpers
-- ============================================================

local function isValid(obj)
    if obj == nil then
        return false
    end

    local ok, result = pcall(function()
        return obj:IsValid()
    end)

    return ok and result
end

local function getPlayer()
    local ok, controller = pcall(function()
        return UEHelpers:GetPlayerController()
    end)

    if not ok or not isValid(controller) then
        return nil, nil, nil
    end

    local pawn = nil

    pcall(function()
        pawn = controller.Pawn
    end)

    if not isValid(pawn) then
        return controller, nil, nil
    end

    local movement = nil

    pcall(function()
        movement = pawn.CharacterMovement
    end)

    if not isValid(movement) then
        movement = nil
    end

    return controller, pawn, movement
end

local function keyDown(controller, key)
    if not isValid(controller) then
        return false
    end

    local ok, result = pcall(function()
        return controller:IsInputKeyDown(key)
    end)

    return ok and result == true
end

local function analog(controller, key)
    if not isValid(controller) then
        return 0.0
    end

    local ok, result = pcall(function()
        return controller:GetInputAnalogKeyState(key)
    end)

    if not ok or result == nil then
        return 0.0
    end

    if math.abs(result) < DEADZONE then
        return 0.0
    end

    return result
end

local function copyVector(v)
    return {
        X = v.X,
        Y = v.Y,
        Z = v.Z
    }
end

local function copyRotator(r)
    return {
        Pitch = r.Pitch,
        Yaw   = r.Yaw,
        Roll  = r.Roll
    }
end

local function teleportOnce(pawn, location, rotation)
    if not isValid(pawn) then
        return
    end

    pcall(function()
        pawn:K2_TeleportTo(location, rotation)
    end)
end

-- ============================================================
-- Enter
-- ============================================================

local function enterFreeMode()
    if active then
        return
    end

    local controller, pawn, movement = getPlayer()

    if not isValid(controller)
        or not isValid(pawn)
        or not isValid(movement) then

        print("[FreeTeleport] player/CharacterMovement not found\n")
        return
    end

    local okLoc, loc = pcall(function()
        return pawn:K2_GetActorLocation()
    end)

    local okRot, rot = pcall(function()
        return pawn:K2_GetActorRotation()
    end)

    if not okLoc or not okRot then
        print("[FreeTeleport] unable to get transform\n")
        return
    end

    startLocation = copyVector(loc)
    startRotation = copyRotator(rot)

    pcall(function()
        savedMaxFlySpeed = movement.MaxFlySpeed
    end)

    -- Disable Galumb's normal movement input.
    -- Our AddMovementInput(..., true) ignores this flag.
    pcall(function()
        controller:SetIgnoreMoveInput(true)
    end)

    -- No collisions during free selection.
    pcall(function()
        pawn:SetActorEnableCollision(false)
    end)

    -- MOVE_Flying = 5
    pcall(function()
        movement:SetMovementMode(5, 0)
    end)

    pcall(function()
        movement.MaxFlySpeed = FLY_SPEED
    end)

    previousA = keyDown(controller, PAD_A)
    previousB = keyDown(controller, PAD_B)

    active = true

    print("[FreeTeleport] FREE MODE ON\n")
end

-- ============================================================
-- Restore
-- ============================================================

local function restoreNormal()
    local controller, pawn, movement = getPlayer()

    if isValid(controller) then
        pcall(function()
            controller:SetIgnoreMoveInput(false)
        end)
    end

    if isValid(pawn) then
        pcall(function()
            pawn:SetActorEnableCollision(true)
        end)
    end

    if isValid(movement) then
        if savedMaxFlySpeed ~= nil then
            pcall(function()
                movement.MaxFlySpeed = savedMaxFlySpeed
            end)
        end

        -- MOVE_Falling = 3
        -- Safer than forcing Walking while possibly in mid-air.
        pcall(function()
            movement:SetMovementMode(3, 0)
        end)
    end
end

local function confirm()
    if not active then
        return
    end

    restoreNormal()

    active = false
    startLocation = nil
    startRotation = nil
    savedMaxFlySpeed = nil

    print("[FreeTeleport] position confirmed\n")
end

local function cancel()
    if not active then
        return
    end

    local _, pawn, _ = getPlayer()

    if isValid(pawn)
        and startLocation ~= nil
        and startRotation ~= nil then

        teleportOnce(
            pawn,
            startLocation,
            startRotation
        )
    end

    restoreNormal()

    active = false
    startLocation = nil
    startRotation = nil
    savedMaxFlySpeed = nil

    print("[FreeTeleport] cancelled\n")
end

-- ============================================================
-- Movement
-- ============================================================

local function update()
    if not active then
        return
    end

    -- Important:
    -- reacquire these every update instead of keeping UObject
    -- references around indefinitely.
    local controller, pawn, movement = getPlayer()

    if not isValid(controller)
        or not isValid(pawn)
        or not isValid(movement) then

        active = false
        print("[FreeTeleport] player became invalid\n")
        return
    end

    -- ========================================================
    -- Confirm / Cancel
    -- ========================================================

    local aDown = keyDown(controller, PAD_A)
    local bDown = keyDown(controller, PAD_B)

    if aDown and not previousA then
        previousA = aDown
        confirm()
        return
    end

    if bDown and not previousB then
        previousB = bDown
        cancel()
        return
    end

    previousA = aDown
    previousB = bDown

    -- ========================================================
    -- Input
    -- ========================================================

    local x = analog(controller, PAD_LX)
    local y = analog(controller, PAD_LY)

    if keyDown(controller, KEY_D) then
        x = x + 1.0
    end

    if keyDown(controller, KEY_A) then
        x = x - 1.0
    end

    if keyDown(controller, KEY_W) then
        y = y + 1.0
    end

    if keyDown(controller, KEY_S) then
        y = y - 1.0
    end

    local vertical =
        analog(controller, PAD_RT)
        - analog(controller, PAD_LT)

    if keyDown(controller, KEY_E) then
        vertical = vertical + 1.0
    end

    if keyDown(controller, KEY_Q) then
        vertical = vertical - 1.0
    end

    -- ========================================================
    -- Speed boost
    -- ========================================================

    local boosting =
        keyDown(controller, PAD_LB)
        or keyDown(controller, KEY_SHIFT)

    pcall(function()
        movement.MaxFlySpeed =
            boosting and BOOST_SPEED or FLY_SPEED
    end)

    -- ========================================================
    -- Camera-relative directions
    -- ========================================================

    local okRot, rotation = pcall(function()
        return controller:GetControlRotation()
    end)

    if not okRot then
        return
    end

    local yaw = math.rad(rotation.Yaw)

    local forward = {
        X = math.cos(yaw),
        Y = math.sin(yaw),
        Z = 0.0
    }

    local right = {
        X = -math.sin(yaw),
        Y =  math.cos(yaw),
        Z = 0.0
    }

    local up = {
        X = 0.0,
        Y = 0.0,
        Z = 1.0
    }

    -- ========================================================
    -- Let CharacterMovement perform the actual movement.
    --
    -- bForce=true bypasses SetIgnoreMoveInput(true).
    -- No teleporting here.
    -- ========================================================

    if math.abs(y) > 0.001 then
        pcall(function()
            pawn:AddMovementInput(
                forward,
                y,
                true
            )
        end)
    end

    if math.abs(x) > 0.001 then
        pcall(function()
            pawn:AddMovementInput(
                right,
                x,
                true
            )
        end)
    end

    if math.abs(vertical) > 0.001 then
        pcall(function()
            pawn:AddMovementInput(
                up,
                vertical,
                true
            )
        end)
    end
end

-- ============================================================
-- F7
-- ============================================================

RegisterKeyBind(TOGGLE_KEY, function()
    ExecuteInGameThread(function()
        if active then
            confirm()
        else
            enterFreeMode()
        end
    end)
end)

-- ============================================================
-- SAFE GAME-THREAD LOOP
-- ============================================================

LoopInGameThreadWithDelay(16, function()
    update()
end)
