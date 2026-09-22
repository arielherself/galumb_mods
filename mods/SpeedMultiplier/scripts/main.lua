local UEHelpers = require("UEHelpers")

local STEP = 1.1

local function scaleVector(v, factor)
    v.X = v.X * factor
    v.Y = v.Y * factor
    v.Z = v.Z * factor
end

local function scalePlayerSpeed(factor)
    local player = UEHelpers.GetPlayer()

    if not player:IsValid() then
        print("[Speed] player invalid\n")
        return
    end

    scaleVector(player.WalkSpeeds, factor)
    scaleVector(player.RunSpeeds, factor)
    scaleVector(player.SprintSpeeds, factor)
    scaleVector(player.CrouchSpeeds, factor)

    local run = player.RunSpeeds

    print(string.format(
        "[Speed] factor %.6f | RunSpeeds = %.3f, %.3f, %.3f\n",
        factor,
        run.X,
        run.Y,
        run.Z
    ))
end

-- F8: ×1.1
RegisterKeyBind(Key.F8, function()
    ExecuteInGameThread(function()
        scalePlayerSpeed(STEP)
    end)
end)

-- F9: ÷1.1
RegisterKeyBind(Key.F9, function()
    ExecuteInGameThread(function()
        scalePlayerSpeed(1.0 / STEP)
    end)
end)
