# Route Trainer

The route trainer is available only to user IDs in `BotAccess.userIds`.

## Studio setup

1. Open `docs/ROUTE_TRAINER_UI_COMMAND_BAR.luau`.
2. Paste its contents into the Studio Command Bar and run it once.
3. Keep the generated `StarterGui.RouteTrainerUI` hierarchy. Its layout and styling can be edited, but the named controls are the runtime contract.
4. Restart the play session so StarterGui clones the new hierarchy into PlayerGui.

## Authoring workflow

1. Open **Route Trainer** from the whitelisted launcher.
2. Enter a route title.
3. Press **Start Attempt**, perform the route, then mark it as a success or failure.
4. Click any attempt to replay it through the world ghost.
5. Select exactly three successful attempts as **BEST**.
6. Publish the route.

Failed attempts contribute to the displayed success rate but cannot be selected for planner use. The server independently checks selected attempts for movement, speed, duration, and valid action data.

If the route overlaps an existing directed corridor, the trainer opens the similarity prompt. Preview the existing route, then either merge the demonstrations or publish a distinct route.

## Ratings and analysis

Select a published route and rate it from 1 to 5. A route with at least two ratings and an average below `2.75` is excluded from analysis recommendations. Unrated routes remain `PROMISING`; ratings and repeated evidence can promote them to `GOOD` or `PROVEN`.

Analysis loads the best three demonstrations as authored candidate lines. It can recommend a complete authored route or use its trusted transitions while generating a new line that combines observed and authored movement.
