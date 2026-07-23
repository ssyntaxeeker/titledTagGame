# Navigation Mesh

`ReplicatedStorage.Shared.Navigation.NavigationMesh` is a standalone graph-navmesh module for static, part-built maps. It does not depend on the bot system or `PathfindingService`.

## Design

- Samples the top surfaces of actual collidable map parts instead of raycasting every world-space column.
- Supports stacked floors, interiors, slopes, thin parts, and precision-tagged surfaces.
- Rejects nodes whose agent-sized body volume overlaps map geometry.
- Uses a nested numeric 3D spatial hash for node deduplication, nearest-node queries, and edge candidates.
- Builds in caller-budgeted slices. Sampling and linking never intentionally process an entire map in one frame.
- Uses a binary-heap A* search that is also frame-budgeted, including route reconstruction and waypoint compaction.
- Generates ordinary `Walk` and collision-checked `Jump` edges.
- Accepts custom movement rules during graph generation without depending on any specific game.

## Basic Usage

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NavigationMesh = require(ReplicatedStorage.Shared.Navigation.NavigationMesh)

local buildJob = NavigationMesh.createBuildJob({
	root = workspace.Map,
	step = 4,
	maximumNodes = 12000,
	maximumJumpUp = 6,
	maximumJumpDistance = 8,
})

while not NavigationMesh.stepBuild(buildJob, 0.0015) do
	RunService.Heartbeat:Wait()
end

local mesh = buildJob.mesh
assert(mesh.ready, "Map produced no navigation nodes")

local searchJob = NavigationMesh.createSearch(mesh, startPosition, goalPosition, {
	maximumExpansions = 6000,
})

if searchJob then
	while not NavigationMesh.stepSearch(searchJob, 0.001) do
		RunService.Heartbeat:Wait()
	end

	local path = NavigationMesh.getPath(searchJob)
	if path then
		for _, waypoint in path.waypoints do
			print(waypoint.position, waypoint.kind, waypoint.metadata)
		end
	end
end
```

`buildAsync` and `findPathAsync` provide simpler yielding wrappers. Explicit jobs are preferred when a caller needs cancellation, progress UI, or strict scheduling.

## Precision Surfaces

Small surfaces automatically use `precisionStep`. Any larger part can opt in with the `NavigationPrecisionSurface` CollectionService tag, or a custom tag supplied through `precisionTag`.

Samples are distributed evenly between the usable surface boundaries. `maximumSamplesPerPart` raises the effective step on exceptionally large parts, preventing one baseplate from dominating build time or memory.

## Walk And Jump

Walk links require a clear agent-sized corridor, a supported midpoint, and an elevation change inside `maximumWalkStepUp` / `maximumWalkDropDown`. When a pair cannot be walked, the builder considers a `Jump` transition using the configured horizontal distance, elevation bounds, arc height, and an agent-sized blockcast along the arc.

These values describe the controller that will consume the route. The module does not apply movement or assume a Humanoid.

## Custom Movement Rules

Pass movement rules to the builder when a game has another way to move between nearby nodes. A rule is directional and may return no transition:

```lua
local climbRule = {
	maximumDistance = 7,
	evaluate = function(fromNode, toNode)
		local rise = toNode.floorPosition.Y - fromNode.floorPosition.Y
		if rise < 2 or rise > 6 then return nil end
		if fromNode.surface ~= toNode.surface then
			return {
				kind = "Climb",
				cost = 2.5,
				metadata = { target = toNode.surface },
			}
		end
		return nil
	end,
}

local buildJob = NavigationMesh.createBuildJob({
	root = workspace.Map,
	movementRules = { climbRule },
})
```

Rules run only for node pairs within their `maximumDistance`. Keep `evaluate` deterministic and cheap; do expensive geometry preprocessing once outside the callback. Rules own validation of their movement mechanic.

Validated or authored one-off transitions can also be added after building:

```lua
NavigationMesh.addDirectedEdge(mesh, entranceNodeId, exitNodeId, 3, "Teleport", {
	teleporterId = "BlueToRed",
})
```

Search can score or reject these edges per request:

```lua
local search = NavigationMesh.createSearch(mesh, startPosition, goalPosition, {
	edgeCost = function(edge, fromNode, toNode)
		if edge.kind == "Climb" and climbIsUnavailable then return nil end
		return edge.cost
	end,
})
```

When custom transitions can cost less than their world-space distance, lower `heuristicWeight` or set it to `0` to preserve optimality.

## Build Configuration

| Field | Default | Purpose |
| --- | ---: | --- |
| `step` | `4` | Normal surface sample spacing. |
| `precisionStep` | `1` | Sample spacing for tagged or thin surfaces. |
| `maximumNodes` | `12000` | Hard memory and build-work bound. |
| `minimumNodeSpacing` | `1.5` | Deduplicates nearly identical samples. |
| `agentHeight` / `agentRadius` | `5` / `1.25` | Occupancy and transition collision volume. |
| `maximumWalkStepUp` | `1.5` | Largest elevation increase classified as walking. |
| `maximumWalkDropDown` | `2` | Largest elevation decrease classified as walking. |
| `maximumWalkDistance` | `step * 1.5` | Candidate radius for walk links. |
| `maximumJumpUp` / `maximumJumpDown` | `6` / `8` | Vertical bounds for jump links. |
| `maximumJumpDistance` | `8` | Horizontal jump reach. |
| `jumpArcHeight` / `jumpArcSegments` | `5` / `4` | Collision-tested jump arc shape and precision. |
| `jumpCostMultiplier` | `1.15` | Makes equal-length jumps less desirable than walks. |
| `validateOccupancy` | `true` | Rejects samples without agent-sized clearance. |
| `requireAnchored` | `true` | Excludes moving parts from the static mesh. |
| `includePart` | nil | Optional application-level surface filter. |
| `movementRules` | `{}` | Directional custom transition generators. |

## API Summary

- `createBuildJob(params)` creates an incremental build and its mesh.
- `stepBuild(job, budgetSeconds)` advances that build within a CPU budget.
- `cancelBuild(job)` permanently stops it.
- `buildAsync(params, budgetSeconds?)` is the yielding convenience wrapper.
- `findNearestNode(mesh, position, radius)` performs a spatial-hash lookup.
- `addDirectedEdge(mesh, fromId, toId, cost, kind?, metadata?)` inserts authored movement.
- `createSearch(mesh, start, goal, params?)` creates an incremental A* search.
- `stepSearch(job, budgetSeconds)` advances search, reconstruction, and compaction.
- `getPath(job)` returns the completed result.
- `cancelSearch(job)` permanently stops the search.
- `findPathAsync(mesh, start, goal, params?, budgetSeconds?)` is the yielding search wrapper.

## Performance Guidance

- Start with `step = 4`; reduce it only where route accuracy requires it.
- Tag thin or route-critical geometry instead of lowering the entire map step.
- Keep build slices around `0.001` to `0.002` seconds for live clients.
- Build once per static map and share the resulting mesh between agents.
- Search does no raycasts. Dynamic obstacles should be handled by `edgeCost`, local steering, or a small edge-validity cache.
- A build remains static. Rebuild it after map geometry changes materially.

## Path Results

- `nodeIds` contains every graph node in the raw route.
- `waypoints` removes only nearly-collinear runs of `Walk` nodes. Turns, jumps, and custom transitions are always retained with their metadata.
- `reachedGoal` is false for a partial route returned after the expansion limit or an exhausted frontier.
- `cost` is the final accumulated edge cost, and `expansions` reports A* work for telemetry.
