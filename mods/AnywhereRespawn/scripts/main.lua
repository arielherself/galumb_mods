local UEHelpers = require("UEHelpers")

print("[AnywhereRespawn] loaded\n")

local savedLocation = nil
local savedRotation = nil

--------------------------------------------------
-- Player
--------------------------------------------------

local function getPlayerController()
    local pc = UEHelpers:GetPlayerController()

    if pc == nil or not pc:IsValid() then
        return nil
    end

    return pc
end

local function getPawn()
    local pc = getPlayerController()

    if pc == nil then
        return nil
    end

    local pawn = pc.Pawn

    if pawn == nil or not pawn:IsValid() then
        return nil
    end

    return pawn
end


--------------------------------------------------
-- HUD
--------------------------------------------------

local hudRoot = nil
local hudText = nil
local hudCounter = 0
local notificationId = 0


local function construct(classPath, outer, name)
    local class = StaticFindObject(classPath)

    if class == nil or not class:IsValid() then
        error("Cannot find class: " .. classPath)
    end

    return StaticConstructObject(
        class,
        outer,
        FName(name)
    )
end


local function setTextColor(r, g, b, a)
    if hudText == nil or not hudText:IsValid() then
        return
    end

    -- 不同 UE/UE4SS 版本对 FSlateColor 的 Lua 转换
    -- 可能略有区别，所以失败也不影响 Mod 本体。
    pcall(function()
        hudText:SetColorAndOpacity({
            SpecifiedColor = {
                R = r,
                G = g,
                B = b,
                A = a
            },
            ColorUseRule = 0
        })
    end)
end


local function destroyHUD()
    if hudRoot ~= nil and hudRoot:IsValid() then
        pcall(function()
            hudRoot:RemoveFromParent()
        end)

        pcall(function()
            hudRoot:RemoveFromViewport()
        end)
    end

    hudRoot = nil
    hudText = nil
end


local function createHUD()
    if hudRoot ~= nil
       and hudRoot:IsValid()
       and hudText ~= nil
       and hudText:IsValid() then
        return true
    end

    local outer = UEHelpers:GetGameInstance()

    if outer == nil or not outer:IsValid() then
        outer = getPlayerController()
    end

    if outer == nil or not outer:IsValid() then
        return false
    end

    hudCounter = hudCounter + 1
    local suffix = tostring(hudCounter)

    local hud = construct(
        "/Script/UMG.UserWidget",
        outer,
        "AnywhereRespawn_HUD_" .. suffix
    )

    local tree = construct(
        "/Script/UMG.WidgetTree",
        hud,
        "AnywhereRespawn_Tree_" .. suffix
    )

    hud.WidgetTree = tree

    local canvas = construct(
        "/Script/UMG.CanvasPanel",
        tree,
        "AnywhereRespawn_Canvas_" .. suffix
    )

    tree.RootWidget = canvas

    local border = construct(
        "/Script/UMG.Border",
        canvas,
        "AnywhereRespawn_Background_" .. suffix
    )

    -- 黑色半透明底
    pcall(function()
        border:SetBrushColor({
            R = 0.0,
            G = 0.0,
            B = 0.0,
            A = 0.55
        })
    end)

    pcall(function()
        border:SetPadding({
            Left = 12,
            Top = 7,
            Right = 12,
            Bottom = 7
        })
    end)

    local text = construct(
        "/Script/UMG.TextBlock",
        border,
        "AnywhereRespawn_Text_" .. suffix
    )

    text:SetText(FText("Anywhere Respawn"))

    pcall(function()
        text.Font.Size = 17
    end)

    border:SetContent(text)

    local slot = canvas:AddChildToCanvas(border)

    if slot ~= nil then
        pcall(function()
            slot:SetAutoSize(true)

            -- 左上角
            slot:SetAnchors({
                Minimum = { X = 0.02, Y = 0.04 },
                Maximum = { X = 0.02, Y = 0.04 }
            })

            slot:SetOffsets({
                Left = 0,
                Top = 0,
                Right = 0,
                Bottom = 0
            })

            slot:SetAlignment({
                X = 0,
                Y = 0
            })
        end)
    end

    hud:AddToViewport(9999)

    hudRoot = hud
    hudText = text

    return true
end


local function showNormalHUD()
    if not createHUD() then
        return
    end

    if savedLocation ~= nil then
        hudText:SetText(
            FText("● RESPAWN SET   R3 Save  ·  L3 Return")
        )

        -- 淡绿色
        setTextColor(0.65, 1.0, 0.65, 1.0)
    else
        hudText:SetText(
            FText("○ NO RESPAWN   R3 Save")
        )

        -- 白色
        setTextColor(1.0, 1.0, 1.0, 1.0)
    end
end


local function showNotification(text, r, g, b, duration)
    if not createHUD() then
        return
    end

    notificationId = notificationId + 1
    local thisId = notificationId

    hudText:SetText(FText(text))
    setTextColor(r, g, b, 1.0)

    ExecuteWithDelay(duration, function()
        ExecuteInGameThread(function()

            -- 如果期间又弹出了新的提示，
            -- 老 timer 不覆盖新的提示。
            if thisId ~= notificationId then
                return
            end

            showNormalHUD()
        end)
    end)
end


--------------------------------------------------
-- Checkpoint
--------------------------------------------------

local function saveCheckpoint()
    local pawn = getPawn()

    if pawn == nil then
        print("[AnywhereRespawn] No player pawn\n")
        return
    end

    local loc = pawn:K2_GetActorLocation()
    local rot = pawn:K2_GetActorRotation()

    savedLocation = {
        X = loc.X,
        Y = loc.Y,
        Z = loc.Z
    }

    savedRotation = {
        Pitch = rot.Pitch,
        Yaw = rot.Yaw,
        Roll = rot.Roll
    }

    print(string.format(
        "[AnywhereRespawn] checkpoint = %.1f %.1f %.1f\n",
        loc.X,
        loc.Y,
        loc.Z
    ))

    showNotification(
        "✓ CHECKPOINT SAVED",
        0.35, 1.0, 0.35,
        1500
    )
end


local function teleportBack(showMessage)
    if savedLocation == nil then
        print("[AnywhereRespawn] No checkpoint\n")

        showNotification(
            "NO CHECKPOINT",
            1.0, 0.6, 0.3,
            1200
        )

        return
    end

    local pawn = getPawn()

    if pawn == nil then
        print("[AnywhereRespawn] Pawn not ready\n")
        return
    end

    local result = pawn:K2_TeleportTo(
        savedLocation,
        savedRotation
    )

    print(
        "[AnywhereRespawn] teleport = "
        .. tostring(result)
        .. "\n"
    )

    if showMessage then
        showNotification(
            "↩ RETURNED TO CHECKPOINT",
            0.5, 0.8, 1.0,
            1000
        )
    else
        showNormalHUD()
    end
end


local function clearCheckpoint()
    savedLocation = nil
    savedRotation = nil

    print("[AnywhereRespawn] checkpoint cleared\n")

    showNotification(
        "CHECKPOINT CLEARED",
        1.0, 0.7, 0.4,
        1200
    )
end


--------------------------------------------------
-- Keyboard fallback
--------------------------------------------------

-- F5 = Save
RegisterKeyBind(Key.F5, function()
    ExecuteInGameThread(function()
        saveCheckpoint()
    end)
end)

-- F6 = Return
RegisterKeyBind(Key.F6, function()
    ExecuteInGameThread(function()
        teleportBack(true)
    end)
end)

-- F7 = Clear
RegisterKeyBind(Key.F7, function()
    ExecuteInGameThread(function()
        clearCheckpoint()
    end)
end)


--------------------------------------------------
-- Controller
--
-- R3 = Save
-- L3 = Return
--------------------------------------------------

local R3_KEY = {
    KeyName = FName("Gamepad_RightThumbstick")
}

local L3_KEY = {
    KeyName = FName("Gamepad_LeftThumbstick")
}


local r3WasDown = false
local l3WasDown = false


local function inputDown(pc, key)
    local ok, result = pcall(function()
        return pc:IsInputKeyDown(key)
    end)

    if ok then
        return result == true or result == 1
    end

    -- fallback
    ok, result = pcall(function()
        return pc:IsInputKeyDown(key.KeyName)
    end)

    if ok then
        return result == true or result == 1
    end

    return false
end


local function pollGamepad()
    local pc = getPlayerController()

    if pc == nil then
        r3WasDown = false
        l3WasDown = false
        return
    end

    local r3Down = inputDown(pc, R3_KEY)
    local l3Down = inputDown(pc, L3_KEY)

    -- R3 新按下：保存位置
    if r3Down and not r3WasDown then
        saveCheckpoint()
    end

    -- L3 新按下：传送
    if l3Down and not l3WasDown then
        teleportBack(true)
    end

    r3WasDown = r3Down
    l3WasDown = l3Down
end


-- 20 Hz 检查手柄
if LoopInGameThreadWithDelay ~= nil then

    LoopInGameThreadWithDelay(50, function()
        pollGamepad()
    end)

else

    LoopAsync(50, function()

        ExecuteInGameThread(function()
            pollGamepad()
        end)

        return false
    end)

end


--------------------------------------------------
-- Automatic respawn
--------------------------------------------------

RegisterHook(
    "/Script/Engine.PlayerController:ClientRestart",

    function(Context, NewPawn)
        -- pre hook
    end,

    function(Context, NewPawn)

        destroyHUD()

        ExecuteWithDelay(300, function()

            ExecuteInGameThread(function()

                createHUD()

                if savedLocation ~= nil then

                    -- 死亡重生不弹 RETURNED，
                    -- 直接恢复常驻提示。
                    teleportBack(false)

                else
                    showNormalHUD()
                end

            end)
        end)
    end
)


--------------------------------------------------
-- Initial HUD
--------------------------------------------------

ExecuteWithDelay(1000, function()
    ExecuteInGameThread(function()
        showNormalHUD()
    end)
end)


print(
    "[AnywhereRespawn] "
    .. "R3=save | L3=return | "
    .. "F5=save | F6=return | F7=clear\n"
)
