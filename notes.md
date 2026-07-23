# Titled Tag Game Development Roadmap

## Product Direction

Titled Tag Game should remain a movement-first competitive tag game. The main source of depth should be movement execution, route knowledge, prediction, adaptation, and consistency under pressure.

New systems should expand the reasons to play, compete, create maps, and improve without weakening that core. Progression and cosmetics must never provide movement or gameplay advantages.

## Design Principles

- **Movement first:** Every important mode and map should reward mastery of the movement system.
- **Deterministic competition:** Players should win through execution and decisions, not random modifiers or paid advantages.
- **Map mastery:** Strong players should be able to learn routes, counters, shortcuts, and recovery options on each map.
- **Low downtime:** Voting, intermissions, rematches, and round transitions should be short and resistant to broken states.
- **Readable gameplay:** Effects and cosmetics must not hide players, routes, tags, or important map geometry.
- **Server authority:** Tags, purchases, ratings, rewards, saves, and administrative actions must be validated by the server.
- **Faithful map mechanics:** Until UTG parity is complete, do not invent new map interactables. Add only UTG mechanics that are currently missing.
- **Easy expansion:** Modes, roles, maps, cosmetics, commands, and creator assets should be registered through focused configs and services rather than hardcoded into one round script.

## Priority 3: Crews

Crews are persistent competitive groups, not gameplay teams that grant passive bonuses.

### Crew Structure

- Owner, officer, and member permissions.
- Unique crew name and short tag.
- Invite, accept, decline, leave, promote, demote, transfer ownership, and disband flows.
- Roster limits and cooldowns to reduce rating manipulation through constant roster changes.
- Crew profile with roster, recent results, record, rating, rank, and seasonal history.

### Crew Battles

- Support fixed team sizes such as 2v2 and 3v3 after the underlying team mode is stable.
- Require valid rosters before queueing.
- Use competitive maps and symmetric round structures.
- Apply a small, bounded effect to individual ratings where appropriate.
- Keep crew ELO primarily driven by crew battle results. Member ELO may inform matchmaking confidence, but should not continuously overwrite the crew's earned rating.
- Detect repeated matches, alternate-account boosting, intentional forfeits, and suspicious roster cycling.

## Priority 4: Leaderboards And Statistics

The current in-session display should be expanded into persistent, useful competitive leaderboards.

### Leaderboards

- Individual ranked ELO.
- Crew ELO.
- Seasonal and all-time views.
- Global, friends, and crew-member filters where practical.
- Stable pagination and cached server reads to avoid excessive data-store requests.

### Tag Statistics

- Restore a visible tag counter using the existing authoritative tag data.
- Keep lifetime tags separate from ranked skill. A large tag count should not imply a higher competitive rating.
- Add session tags and match tags to the results screen.
- Only animate a tag after the server accepts it.

### Tag Feedback

- Add a brief, readable tag confirmation animation.
- Show who tagged whom and the resulting role change where the mode requires it.
- Avoid full-screen effects that obscure immediate movement after the tag.
- Handle rapid tags and cooldown rejection without displaying false confirmations.

## Priority 5: Private Servers And TAGMIN v2

Private servers should be reliable practice, tournament, and map-testing environments.

### Private Server Controls

- Change map and mode.
- Start, stop, restart, and pause a game where supported.
- Assign roles or teams.
- Set round duration and mode-specific values within validated limits.
- Move players between active play and spectating.
- Reset players or the current round.
- Enable creator-map testing.

Every command must use the same server command registry and permission checks, regardless of whether it came from chat, a menu, or TAGMIN.

### TAGMIN v2

- Provide a compact command terminal for players who cannot or do not want to use chat commands.
- Include autocomplete, command descriptions, argument hints, command history, and clear server responses.
- Keep the terminal available only to the private-server owner and explicitly authorized administrators.
- Validate all arguments on the server and log administrative actions.
- Do not let the terminal execute arbitrary Luau or bypass normal command permissions.

### Private Server Test Matrix

- Empty server and one-player server.
- Players joining or leaving during every round phase.
- Repeated map and mode changes.
- Commands issued while voting or results UI is open.
- Invalid map, mode, role, team, duration, and player arguments.
- Server owner leaving or transferring control.

## Priority 6: Creator Mode And Map Persistence

Creator mode should support building a map over multiple sessions instead of requiring players to finish in one sitting.

### Map Browser

Opening the creator map menu should show:

- Saved map slots.
- Map name, last edited time, schema version, and thumbnail where feasible.
- Search and sorting for the player's own maps.
- Create, save, save as, load, rename, duplicate, test, and delete actions.
- Clear confirmation for destructive actions.

### Creating A Map

1. Open the creator map browser from the menu.
2. Select **Create Map**.
3. Enter a valid map name and choose a base template.
4. Load a baseplate and creator tools.
5. Save the initial map immediately so the slot exists before editing begins.

### Saving

- Support manual save and periodic autosave.
- Serialize only allowlisted instances, properties, attributes, and asset types.
- Never save scripts or arbitrary executable content from a player-authored map.
- Use a versioned schema so old maps can be migrated.
- Enforce limits for part count, total size, map bounds, string lengths, and serialized data size.
- Keep a previous valid revision so an interrupted or malformed save does not destroy the map.

### Loading

- Validate the full saved document before replacing the current creator map.
- Load into a temporary model, validate it, then swap it into the workspace.
- Report unsupported assets or migrated fields clearly.
- Do not partially load a corrupted map into an active session.

### Creator Asset Palette

The palette should contain ordinary building geometry plus only the UTG movement assets listed in this document:

- Trampoline.
- Swing bar.
- Experimental swing bar.
- Rope grab.
- Wallrun surface.
- Grind rail.
- Zipline.
- Truss or ladder.
- Windforce or air cannon.
- Breakable or smashable window.
- `NoClimb` surface restriction.

Do not add unrelated mechanical assets simply to make the palette larger. Each available asset must work in normal play, map testing, private servers, and round cleanup before it is exposed to creators.

### Map Validation

- Require valid spawn locations and playable bounds.
- Reject movement assets with missing required parts or invalid attributes.
- Warn about unreachable spawns, out-of-bounds geometry, excessive part density, and unsupported instances.
- Provide a test mode that uses real movement and round rules without publishing the map.

## Priority 7: Cosmetic Shop

The shop should fund and personalize the game without changing competitive outcomes.

### Initial Scope

- Outfits.
- Trails.
- Inventory, preview, purchase, equip, and unequip flows.
- Clear ownership and equipped-state indicators.

### Rules

- No cosmetic may change hitboxes, speed, jump behavior, visibility rules, or tag range.
- Trails must remain readable and may need reduced intensity in ranked play.
- Purchases and currency writes must be server-authoritative and idempotent.
- Owned items should survive item removal or shop rotation without corrupting player data.
- Reuse the existing outfit-loading system rather than creating a second character appearance pipeline.

## Competitive Mode Direction

Classic and Infinite Classic should remain the baseline used to judge movement changes. Additional modes should still test tagging, routing, teamwork, or survival rather than random power-ups.

- **Freeze:** Team coordination, rescues, and route control.
- **Bounty:** Target selection and pursuit under pressure.
- **Team Tag:** Structured team positioning and coordinated tags.
- **Bomb:** Hot-potato pressure with server-safe elimination and no-runner edge-case handling.
- **Checkpoint Escape:** Movement consistency and route execution against pursuit.

Modes should be registered through shared definitions with mode-owned rules and cleanup. The core game lifecycle should not contain a growing set of mode-name conditionals.

## Technical Quality Gates

A feature is not complete until it satisfies the following:

- No stale UI, timer, task, connection, character state, or map state after cancellation.
- Server validation exists for every persistent or competitive action.
- Character movement feels identical outside the feature being changed.
- The feature survives death, respawn, map replacement, mode replacement, and players leaving.
- Client boot and normal play do not load development-only or inactive systems unnecessarily.
- Expensive map and UI work is incremental where it could cause a visible frame spike.
- Data writes are bounded, retried safely, and protected against duplicate application.
- Studio diagnostics explain invalid configuration close to its source.

## Suggested Delivery Order

1. Finish UTG movement and map-asset parity.
2. Stabilize the shared game, voting, timer, map-change, and cleanup lifecycle.
3. Rebuild Ranked on top of that lifecycle.
4. Restore tag feedback and persistent leaderboards.
5. Finish private-server controls and TAGMIN v2.
6. Add creator map persistence and validated UTG asset templates.
7. Add crews and crew battles after team competition is reliable.
8. Add the cosmetic shop after inventory and purchase persistence are proven.

This order keeps the movement game authoritative. Competitive and social systems should build on a stable version of the game rather than forcing movement or round behavior to work around unfinished infrastructure.
