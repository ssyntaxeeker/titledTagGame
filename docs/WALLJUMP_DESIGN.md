# Walljump Design

## Purpose

Walljump is an airborne movement technique performed with the player's back close to a wall while the player faces away from it. It converts vertical speed into a mostly horizontal launch away from the wall.

It should fill a different role from vaulting:

- Vaulting converts a reachable ledge into vertical access.
- Wallrunning converts a valid side wall into sustained traversal.
- Walljump converts a brief, deliberately aligned rear-wall contact into horizontal repositioning.

Walljump must not become a free second jump, a reliable replacement for vaulting, or a way to climb one wall indefinitely.

## Input

Use the existing jump/vault input. Evaluate Walljump only when:

1. No active swing, rope, rail, wallrun release, or zipline action consumed the input.
2. The normal forward vault/swing probe did not find a valid action.
3. The Humanoid is airborne.
4. The input is a new press, not a held input repeatedly evaluated every frame.

If the rear probe fails, the input does nothing while airborne. It must not apply a partial impulse.

## Rear-Wall Probe

Run the probe only when jump is pressed, so the technique has no permanent per-frame cost.

- Origin: `HumanoidRootPart.Position`, raised by approximately `0.3` studs.
- Direction: `-HumanoidRootPart.CFrame.LookVector`.
- Initial maximum distance: `3.5` studs.
- Valid practical contact range: approximately `0.6-3.5` studs.
- Exclude the character and debug geometry.
- Respect collision and reject `NoWalljump` geometry.
- Require a nearly vertical face: `abs(hit.Normal.Y) <= 0.15`.
- Require the player to face generally away from the face: `hit.Normal:Dot(root.LookVector) >= 0.7`, roughly 43º.

Use the raycast normal as the authoritative launch direction. Do not use only `LookVector`, because that allows players to manufacture sideways velocity that is unrelated to the wall they touched.

An optional short clearance ray should run from the root in the intended launch direction. Reject the action if the character would immediately launch into another solid wall.

## Proposed Velocity Model

The technique should use the absolute incoming vertical speed while keeping vertical output below a normal vault's reliable vertical output.

These are starting values, not final balance values. With the current movement model:

- Normal vault vertical velocity begins at approximately `30`.
- Walljump should usually produce `25.2-36.4` vertical velocity after the current `1.4x` launch multiplier.
- Outward launch velocity receives an additional `1.3x` emphasis, for `1.82x` the original baseline.
- Walljump should produce substantially more outward velocity than vertical velocity.
- Existing tangential speed should be preserved partially, allowing skilled diagonal lines without creating speed from nothing.

Using `abs(velocity.Y)` rewards both fast falls and intentional rising contact. The hard caps are necessary because uncapped fall velocity would turn large drops into extreme map-crossing launches.
Incoming vertical speed stops improving the complete launch at `65y`, so the model explicitly caps its effective circumstance at `65y`.

## Skill Expression

### 1. Facing accuracy

The player must deliberately turn away from the wall before pressing jump. A player looking sideways or into the wall should fail the probe.

This distinguishes Walljump from simply pressing jump after colliding with geometry.

### 2. Timing against vertical speed

The player chooses when to convert vertical speed. Waiting longer during a fall produces a stronger launch, but also increases the chance of landing, missing the wall, or passing beyond the valid contact range.

### 3. Approach quality

Tangential velocity is partially preserved. A clean diagonal approach therefore creates a better exit line than dropping vertically against a wall.

### 4. Exit aiming

The raycast normal supplies most of the outward launch, but a small aim contribution may be added later if testing shows that fixed normals feel too rigid. Any aim contribution should be clamped inside the valid facing cone.

## Anti-Spam And Exploit Rules

### Same-wall lock

Store the hit part and approximate face normal after success. The same face cannot be used again until one of these occurs:

- The player lands.

A cooldown alone is insufficient because a player could repeatedly climb a tall wall after waiting in the air.

### Grounded activation

Walljump does NOT require an actual airborne setup and CAN become a faster default jump.

### No automatic contact activation

Touching the wall never launches the player. Only a valid jump press during the contact opportunity does.

### No velocity stacking from repeated requests

Set the cooldown and wall lock before assigning velocity. This prevents duplicate input callbacks from applying the impulse twice.

### Moving walls

Inherit bounded wall assembly velocity. This keeps moving platforms coherent without allowing an unbounded physics object to fling the player. A production implementation should clamp inherited horizontal wall velocity.

## Interaction Priority

Recommended jump-request order:

1. Release swing, rope, rail, wallrun, or other active state.
2. Toggle or release zipline where applicable.
3. Attempt forward swing or vault.
4. Attempt side Wallrun.
5. Attempt rear Walljump.
6. Fall through to an ordinary grounded jump.

This order prevents Walljump from stealing intentional vaults and prevents a rear wall from interfering with active parkour states.

## Feedback

On accepted input:

- Play a short backward wall-kick animation. (Animations.Parkour.Walljump)
- Play a distinct wall impact sound from the hit position.
- Apply a restrained camera impulse aligned with the launch.
- Set a short `Walljumping` character attribute for animation and debugging.

On rejected input, do not play the animation or sound. Feedback must represent an action that really happened.

Useful debug output:

- Rear-wall distance.
- Facing dot product.
- Incoming vertical speed.
- Calculated vertical and outward speed.
- Rejection reason.
- Same-wall-lock state.

## Architecture

Keep the implementation separated into:

- `WalljumpConfig`: frozen tuning, angle, distance, cooldown, and speed limits.
- `WalljumpModel`: pure probe eligibility and velocity calculation.
- `WalljumpTech`: player state, cooldown, animation, sound, and velocity application.
- `AerialInputs`: input priority and invocation only.

The pure model should accept position, orientation, velocity, raycast parameters, and a hit result without reading local-player state. This allows future bots and test tooling to use exactly the same legality and physics rules as players.

## Balance Acceptance Tests

Walljump is ready for normal play when all of these hold:

1. A standing player cannot use it as a stronger normal jump, but a moving one can.
2. Its maximum vertical gain remains below a normal valid vault.
3. A player cannot gain unlimited height by repeating it on one or multiple walls.
4. A deliberate fall or initial jump velocity produces a noticeably stronger horizontal launch than a low-speed contact.
5. Diagonal approaches preserve useful route speed without exceeding the configured cap.
6. Forward vaults, swings, wallruns, slides, and ordinary jumps retain their existing behavior.
7. Invalid input never plays successful Walljump feedback.
8. The probe runs only on input and has no measurable idle-frame cost.

The first tuning pass should measure route completion time, maximum height gained, horizontal distance, accidental activation rate, and repeated-wall abuse. Adjust the facing cone and same-wall reset distance before increasing velocity; permissive eligibility is usually more damaging to skill expression than slightly conservative launch power.
