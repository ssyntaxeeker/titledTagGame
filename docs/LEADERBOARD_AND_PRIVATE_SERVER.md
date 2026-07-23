# Leaderboard And Private-Server Administration

## All-Time Individual ELO

The server mirrors each loaded player's numeric `ELO` attribute into the `IndividualELO` ordered leaderboard. The initial category uses `Leaderboard_IndividualELO_AllTime_V1` and is configured in `src/shared/Configs/Leaderboards.luau`.

Client UI can request a page through the `GetAllTimeLeaderboard` Net remote function:

```lua
local entries = GetAllTimeLeaderboard:InvokeServer("IndividualELO", 50)
```

Each entry has this shape:

```lua
{
    userId = 3693744006,
    score = 200,
}
```

Reads are cached and request counts are normalized to 10, 25, 50, or 100. Writes are serialized per player and retried up to three times. Adding crew ELO later requires a new category config and a producer that calls `OrderedLeaderboardService.setScore`.

Studio must have **Enable Studio Access to API Services** enabled to exercise the real ordered data store. Use a separate test version of the data-store name if production leaderboard data must remain untouched.

## Private-Server Permission Commands

The private-server owner can delegate command access for the lifetime of the current server:

- `/psgrant player` grants access.
- `/psrevoke player` revokes access.
- `/psperms` lists current delegates.

Delegates satisfy the existing `PrivateServerOwner` permission checks and can use private-server commands such as map, mode, time, role, bring, and goto. They cannot grant or revoke other delegates. Grants are held only in server memory and disappear when that private-server instance closes.

In Studio, users in the static `Admin` whitelist act as the owner so this flow can be tested locally. In a published private server, only `game.PrivateServerOwnerId` can grant or revoke access.
