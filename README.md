# Galumb UE4SS Mods

My own UE4SS Lua mods for *Galumb* (`IQ_Galumb.exe`).

## Layout

```
mods/
├── AnywhereRespawn/scripts/main.lua
├── FreeTeleport/scripts/main.lua
└── SpeedMultiplier/scripts/main.lua
```

## Mods

### AnywhereRespawn
Save your position anywhere and respawn there after dying.

| Key | Action |
| --- | --- |
| R3 / F5 | Save current position as checkpoint |
| L3 / F6 | Teleport back to checkpoint |
| F7 | Clear checkpoint |

A small HUD in the top-left corner shows whether a checkpoint is set, and a notification pops up on save/teleport/clear. Respawn after death is automatic — the mod hooks `PlayerController:ClientRestart` and sends you back to the checkpoint without any input.

### FreeTeleport
Free-fly debug teleport, "safe movement" variant: it moves via `CharacterMovement` flying mode plus `AddMovementInput(..., true)` instead of teleporting every frame. Collision is disabled and normal movement input is ignored on entry; both are restored on confirm/cancel.

| Key | Action |
| --- | --- |
| F7 | Enter / confirm and leave free-fly |
| WASD / left stick | Horizontal movement (camera-relative) |
| Q / E / LT / RT | Vertical movement |
| Shift / LB | Speed boost (1600 → 4000) |
| Gamepad A (bottom face button) | Confirm current position |
| Gamepad B (right face button) | Cancel, return to pre-entry position |

### SpeedMultiplier
Scales player movement speed by ×1.1 or ÷1.1 per press.

| Key | Action |
| --- | --- |
| F8 | Speed ×1.1 |
| F9 | Speed ÷1.1 |

It scales `WalkSpeeds`, `RunSpeeds`, `SprintSpeeds` and `CrouchSpeeds` together, and prints the current factor to the UE4SS log.

## Known Issues

- **F7 conflict**: `AnywhereRespawn` binds F7 to "clear checkpoint" and `FreeTeleport` binds F7 to "toggle free-fly". With both mods enabled, pressing F7 triggers both. Either rebind one of the `RegisterKeyBind(Key.F7, ...)` calls or use the gamepad buttons (R3/L3 and A/B) while in free-fly.
- `SpeedMultiplier` uses `UEHelpers.GetPlayer()`, so it depends on `shared/UEHelpers`. The `mods/` folder here does not ship the shared library — keep the existing `shared/` folder in your game's UE4SS `Mods` directory when installing.

## Installation

Copy the mod folders into the game's UE4SS `Mods` directory:

```bash
cp -r mods/* "$GAME/IQ_Galumb/Binaries/Win64/ue4ss/Mods/"
```

Then enable them in `Mods/mods.txt` — append after the built-in mods and keep `Keybinds` first:

```
; Built-in keybinds, do not move up!
Keybinds : 1
AnywhereRespawn : 1
FreeTeleport : 1
SpeedMultiplier : 1
```

Mods missing from `mods.txt` are not loaded, so make sure all three lines are present before launching the game.
