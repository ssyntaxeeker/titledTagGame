# Project Guidelines

Guidelines for working in this pure Luau Roblox game project.

## Module Basics

- Every Luau module should start with `--!strict`.
- New modules should include a header comment with `Sol (3693744006)`, an `Updated: YY/MM/DD` date, and a short overview.

```lua
--!strict
--[[
    Script (Run context)
    ==============
    Author: Sol (3693744006)
    Updated: YY/MM/DD

    Overview here.
]]
```

## Architecture

- The project follows a service-based architecture: services provide domain capabilities, while handlers compose those capabilities into orchestrated gameplay behavior.
- Client-only orchestration lives in `src/client`.
- Server-only orchestration lives in `src/server`.
- Config modules hold tuning data and should return frozen data when practical.
- Type modules should stay inert: export types, stable state names, and frozen lookup tables, but do not own runtime behavior.
- Command modules should be small command table modules that validate input, call services, and reply.

## Lifecycle

- Main client/server bootstraps modules.

## Coding Practices

- Use `const` for immutable data, for example `const x = 10`. Use `local` only for mutable values or forward declarations.
- Prefer clear domain names over abbreviations. Common terms like `fsm`, `bin`, `dt`, `ui`, `vfx`, `uid`, and `ctx` are fine when they are established by context.
- Prefer guard clauses over deeply nested conditionals.
- Use Luau `if else` expressions instead of `and`/`or` ternary logic.

```lua
const x: number? = if y then z else nil
```

- Prefer existing libraries in `Vendor` and existing services in `src/shared/Utils` before writing new utility behavior.

### Table Naming: `info` vs `params`

- Do not name table-shaped argument or type aliases `Options`. Use either `params` or `info`.
- Use `info` for descriptive data or state. An `info` table tells what something is: object data, player/session data, save data, marketplace asset data, or authored asset metadata.
- Use `info` for creation/register tables when the table describes the initial state of the object being created.
- Use `params` for action configuration. A `params` table tells an engine system, service method, or operation how to execute: filters, target slots, counts, lock states, teleport/raycast/overlap configuration, or other call-time behavior.
- Type aliases should follow the same rule: `type AddParams = InventoryTypes.AddParams`, not `AddOptions`.
- Variable names should follow the same rule: `insertParams`, `raycastParams`, `playerInfo`, `assetInfo`.

```lua
type PlayerInfo = {
    username: string,
    level: number,
    isPremium: boolean,
}

const playerInfo: PlayerInfo = {
    username = "RobloxDev",
    level = 50,
    isPremium = true,
}

const function populateProfileCard(info: PlayerInfo)
    usernameLabel.Text = info.username
    levelLabel.Text = `LVL {info.level}`
end
```

```lua
type InsertParams = {
    count: number?,
    slot: number?,
}

const hitscanParams = RaycastParams.new()
hitscanParams.FilterType = Enum.RaycastFilterType.Exclude
hitscanParams.FilterDescendantsInstances = { player.Character }

const result = workspace:Raycast(origin, direction, hitscanParams)
```

### Type Naming

- Prefix exported record/data table types with `R`, for example `RInventory`, `RSlot`, or `RPlayerInventory`. A record describes state or data fields.
- Prefix exported interface/contract table types with `I`, for example `IInventoryStore` or `IInteractable`. An interface describes behavior a value must provide.
- Do not add `R` or `I` to params/info tables. Keep action configuration as `Params` and descriptive metadata as `Info`.
- Primitive aliases, string unions, ids, enum-like unions, and scalar domain aliases should keep clear domain names without `R` or `I`.
- Avoid adding `Record` or `Interface` suffixes when the prefix already communicates the category.

## Offensive Programming

- Assert aggressively at service boundaries, lifecycle entry points, and invariant checks so failures are loud and close to the cause.
- Do not silently return on invalid state, missing required instances, malformed config, failed ownership checks, or impossible branches.
- Silent `return` is only allowed when it is a documented, valid return path that satisfies the function contract, such as returning `nil` from a lookup or ignoring an idempotent no-op.
- If a caller violates the contract, use `assert` or `error` with a message that names the service/function and the broken assumption.
- Only soften a failure into `warn`/`return` when explicitly requested or when the function contract says best-effort behavior is valid.

```lua
const character = player.Character
assert(character, `[PlayerManagerService] {player.Name} has no character`)

const state = PlayerManagerService.getState(player)
assert(state, `[PlayerManagerService] {player.Name} has no replicated state`)
```

## Flat Code

- Generate the flattest code that still reads clearly.
- Do not introduce helper functions for one-line table lookups, simple predicates, direct property checks, or aliases around existing APIs.
- Avoid rabbit holes of single-use helpers; they break code reading flow by forcing readers to jump away from the logic they are trying to understand.
- Prefer descriptive variables or direct inline logic when the expression is local, obvious, and used once.
- Add a helper only when it removes real duplication, isolates meaningful complexity, captures a non-obvious contract, owns lifecycle/cleanup, or is explicitly requested.
- Extra abstraction is a design choice for the project owner, not a default code-generation habit.

Avoid:

```lua
const function getArchetype(buildingId: string): BuildingArchetype?
    return (BuildingConfig.buildings :: { [string]: BuildingArchetype })[buildingId]
end

const function isScriptContainer(instance: Instance): boolean
    return instance:IsA("Script") or instance:IsA("LocalScript") or instance:IsA("ModuleScript")
end

const function isVerticalSnapLayer(layer: string): boolean
    return VERTICAL_SNAP_LAYERS[layer] == true
end

const archetype = getArchetype(buildingId)
if not archetype or isScriptContainer(descendant) or not isVerticalSnapLayer(layer) then
    return
end
```

Prefer:

```lua
const buildings = BuildingConfig.buildings :: { [string]: BuildingArchetype }
const archetype = buildings[buildingId]
const isScriptContainer =
    descendant:IsA("Script")
    or descendant:IsA("LocalScript")
    or descendant:IsA("ModuleScript")
const isVerticalLayer = VERTICAL_SNAP_LAYERS[layer] == true

if not archetype or isScriptContainer or not isVerticalLayer then
    return
end
```

## Function Documentation

- Document exported service APIs, lifecycle entry points, and helpers whose contract is not obvious from the name and type signature.
- Private helper docs should explain the reason the helper exists: the engine quirk, lifecycle hazard, state invariant, race condition, or caller contract that would be easy to miss.
- Do not write comments that only restate what the code does. Prefer better names and types for that.
- Include parameter and return notes only when they clarify ownership, mutation, replication, cleanup, yielding, or a non-obvious valid range.
- If a function creates connections, tasks, observers, animations, springs, or temporary state, document who owns cleanup when that ownership is not local and obvious.
- Use Moonwave-compatible tags. Prefer `@server` and `@client` for runtime-specific APIs; use `@tag Shared` only when a shared API would otherwise be ambiguous.
- Useful `@tag` labels for this project: `Authoritative`, `Replica`, `Attribute`, `ValueObject`, and `Cleanup`.
- Use `@yields`, `@error`, `@deprecated`, `@private`, and `@ignore` only when the function truly has that behavior.
- Put realm and behavior tags at the top of the block before the function title. If present, `@server` or `@client` must be first, followed by `@tag` lines and behavior tags like `@yields` or `@private`.
- Separate tag groups with blank lines: top tags, title/prose, params/returns, then errors.
- The title line is only the function name. Do not include parameters there; parameters belong in `@param` tags and the Luau signature.
- Do not add `@param` or `@return` just to repeat Luau types; add them when the parameter or return value needs contract detail.
- Do not use `@function` for normal function definitions. Moonwave detects real functions automatically; reserve `@function` or `@method` for generated or missing definitions.

```lua
--[=[
    @server
    @tag Authoritative
    @tag Cleanup
    @yields

    functionName
    ============

    Explain the non-obvious contract: why this function exists, what invariant
    it protects, what engine behavior it works around, or what lifecycle rule
    callers must respect.

    @param owner -- Include only when ownership, mutation, yielding, cleanup,
        replication, or valid range is not obvious from the Luau type.
    @param shouldStart -- Explain caller-visible behavior, not syntax.
    @return () -> () -- Cleanup function; caller owns teardown.

    @error "MissingOwner" -- Raised when the required owner state is absent.
]=]
const function functionName(owner: Player, shouldStart: boolean): () -> ()
    -- ...
end
```

## Reactivity And Cleanup

- Use `Janitor` for connection cleanup, scoped bins, character lifecycle, and reactive helpers.
- Any connection, task, observer, spring, animation, or temporary state created for a lifecycle should have an owning cleanup bin or explicit cleanup function.

## State And Replication

- Do not force simple stat math, config lookup, validation, or pure transforms into state machines.
- Prefer attributes or ValueObjects for automatically replicated primitive state.
- Use `Net` for client/server requests, `Signal` to script signals, and invocations. Server code owns authoritative writes and validation.

## Don'ts

- Do not use metatable-based OOP.
- Do not wrap functions or properties in new functions that add no logic. Call the source directly.
- Do not add alias helpers that only rename an existing service method or property.
- Do not split obvious one-line logic into helpers just to give it a name.

```lua
const uidService = require(path.to.service)

local function generateUID()
    return uidService.uid
end
```
