# UTG Map Asset Test Baseplate

Parkour attributes and tags are accepted under either `workspace.Map` or `workspace.Dev`. Use `workspace.Map` for real map content and a `Folder` named `Dev` under `Workspace` for isolated fixtures that should survive independently of the currently loaded map.

For this test baseplate, put every station under `workspace.Dev`. Server validation and client probes intentionally accept that root without treating unrelated Workspace geometry as a parkour asset.

Space the stations at least 30 studs apart. Give each station a spawn pad or an obvious starting line so one mechanic cannot trigger another accidentally.

## 1. Trampoline

1. Add an anchored `Part` sized approximately `12, 1, 12`.
2. Add the CollectionService tag `Trampoline`.
3. Add a number attribute named `BounceAmount` with value `115`.
4. Stand or fall onto it.

Expected: the character leaves the ground immediately with upward velocity, the trampoline sound plays, and the same trampoline cannot retrigger until its cooldown expires.

## 2. Normal Swing Bar

1. Add an anchored horizontal `Part` sized approximately `8, 0.5, 0.5`.
2. Add a boolean attribute named `SwingBar` set to `true`.
3. Place it roughly 4 to 6 studs above the approach floor.
4. Run toward it, face it, and press jump while the aerial probe can land on its top.

Expected: the player attaches for the normal swing hold, then releases with velocity based on the player's falling speed and movement direction.

## 3. Experimental Swing Bar

Add a boolean attribute named `ExperimentalSwingbar` set to `true` to the bar part or its enclosing fixture model. `ExperimentalSwingBar` is also accepted. This attribute is sufficient by itself; adding `SwingBar = true` is supported but no longer required. Naming the part or fixture `ExperimentalSwingbar` or `ExperimentalSwingBar` is also supported.

Expected: hold jump for at least `0.15` seconds to enter the experimental looping swing. Keep holding to build loop speed, then release jump to launch. Tapping jump without holding long enough performs the normal swing release instead.

## 4. Rope Grab

Create this hierarchy:

```text
RopeTest (Model)
  Top (Part, anchored)
    TopAttachment (Attachment)
  Rope (Part, unanchored)
    RopeAttachment (Attachment)
    RopeGrab = true (may instead be placed on RopeTest)
  RopeConstraint
```

1. Parent the `RopeConstraint` anywhere inside `RopeTest`.
2. Set `Attachment0` to `TopAttachment` and `Attachment1` to `RopeAttachment`.
3. Set its `Length` to about `12` and enable it.
4. Make `Rope` narrow, such as `0.6, 5, 0.6`, with enough clearance to swing.
5. Keep `CanQuery` enabled on the physical rope part.
6. Run, jump, or fall within about 2 studs of the rope.

Expected: the player grabs automatically, movement input pumps the physical rope, and jump releases with inherited rope and player momentum.

## 5. Wallrun Surface

1. Add an anchored wall around `30, 14, 1`.
2. Add a boolean attribute named `Wallrun` set to `true`.
3. Optionally add a number attribute named `Speed`; start with `1`.
4. Jump alongside the wall while moving forward.

Expected: the wallrun starts automatically, the matching left/right animation plays, falling speed is controlled while contact remains valid, and jump releases from the wall.

## 6. Grind Rail

1. Add an anchored narrow `Part` sized approximately `40, 0.5, 1`.
2. Add a boolean attribute named `RailCollision` set to `true`.
3. Raise it enough that the character can land on its top without touching the floor.
4. Jump or fall onto it with horizontal speed.

Expected: the character attaches automatically, travels toward the endpoint selected from incoming velocity, gains rail speed, and releases at the end. Pressing jump releases upward while preserving rail direction and speed. Catching the rail inside the short jump-input window performs the faster rail fling instead of entering a normal grind.

Keep this first test rail straight. Curved or connected rail routes require multiple rail parts and should be tested only after each straight segment works independently.

## 7. Zipline

Create this hierarchy exactly:

```text
ZiplineTest (Model, Zipline = true)
  ZipPart (Part)
    TopAttachment (Attachment)
```

1. Make `ZipPart` anchored, non-collidable, and long along its local Z axis, such as `1, 1, 50`.
2. Add a boolean attribute named `Zipline` set to `true` on `ZiplineTest`.
3. Put `TopAttachment` at the beginning of `ZipPart`.
4. Set the attachment's `Axis` to local `0, 0, 1`, pointing from `TopAttachment` toward the opposite end along the part's long axis.
5. Place the start within 5 studs of the player's jump path.
6. Press jump while within 5 studs to attach. Press jump again to release with a boost.

Expected: the character hangs from the line, preserves incoming velocity, accelerates from forward input along the constrained line, releases at an endpoint, and cleans up all temporary constraints.

## 9. Windforce Volume

1. Add an anchored volume part around `12, 12, 12`.
2. Set `CanCollide` to `false`, `CanTouch` and `CanQuery` to `true`, and `Transparency` to around `0.75` while testing.
3. For world-space force, add a Vector3 attribute named `Windforce`, for example `0, 4, 0`.
4. For local-space force instead, remove `Windforce` and add `WindforceRelative`; the part's rotation controls the launch direction.

Expected: velocity is added at render priority `Input + 1` while the root touches the volume and stops immediately after leaving it. UTG scales the value by `dt * 60` and sets gravity to `75`, making `1.25` the vertical hover value. Use roughly `2` for gentle lift, `4` for strong lift, or `6` for a fast air cannon.

## 10. Breakable Window

1. Add an anchored thin part around `8, 8, 0.25`.
2. Add either `CanBeBroken = true` or `Smashable = true`.
3. Optionally add a number attribute named `ResetTime`; start with `8`.
4. Run or jump into the window with meaningful velocity.

Expected: the server validates the contact, hides the window, disables collision/query, and restores its original state after `ResetTime`. Other clients see the same break state.

## 11. NoClimb Restriction

1. Duplicate an ordinary vaultable wall.
2. Add a boolean attribute named `NoClimb` set to `true`.
3. Attempt the same vault against both walls.

Expected: the normal wall accepts the vault and the restricted wall does not. `NoClimb` is a restriction, not a separate movement asset.

## Final Isolation Checks

For every station, verify:

- Respawning during the action removes constraints, attributes, sounds, and animations.
- Changing the map during the action does not leave the player attached to destroyed geometry.
- Approaching from the wrong angle does not trigger the mechanic.
- Two players can use the station without sharing client-only state.
- Attributes use the exact spelling and value types shown above.
