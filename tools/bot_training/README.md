# Bot Offline Training

The live bot uses deterministic movement eligibility and execution. The tiny
policy only biases route costs; it cannot authorize a vault, swing, roll, or
jump that fails the encoded game rules.

## Collect

1. Enable `Learning + Tech Exploration` in the bot workbench. This enables
   recording and bounded exploration together.
2. Train against players on a completed affordance graph. Prefer full chases,
   repeated difficult transitions, and both roles over action spam. The bot
   inspects only nearby executable affordances and tries each location-stable
   affordance at most three times per session.
3. Demonstrate player tech normally. A demonstration is recorded only when the
   observed vault, swing, jump, roll, rollboost, or slide-boost sequence ends on
   a compatible graph edge. Raw inputs and stationary attempts are ignored.
4. Independent route explorers write their successful and failed transitions
   into the same recorder. The workbench reports `Explorer`, `Bot`, and `Player`
   source counts, and every exported sample retains its source metadata.
5. Export the session. Join the numbered output chunks in order into one JSON
   file, for example `samples.json`.
6. Check the action counts shown in the workbench. Discard sessions affected by
   broken maps, severe lag, deliberate idling, invalid role state, or only one
   recorded action.

Rank and stars produce a bounded sample weight. They are evidence weighting,
not an assumption that every action from a highly ranked player is correct.

## Train

```sh
python tools/bot_training/train_policy.py samples.json \
  --out src/client/Bot/BotPolicyWeights.luau
```

PyTorch is required for the offline command. Train on a held-out set before
shipping generated weights. Compare route completion, tag time, runner survival
time, transition success, and client frame-time percentiles against the neutral
weights.

The trainer refuses one-action datasets and applies bounded inverse-frequency
weighting. This prevents routine walking from overwhelming rarer validated tech,
but it does not make a tiny or low-quality dataset trustworthy.

## In-game calibration

`Calibrate Runtime Policy + Save` performs a smaller operation than the offline
trainer. It freezes the offline-learned hidden representation, calibrates only
the 11-action output head, and spreads work across Heartbeat frames. Every fifth
sample is excluded from updates. The candidate is installed and sent to the
server only when weighted loss improves on that validation split.

Use this after collecting at least 400 mixed-action samples in the current
session. Offline PyTorch training remains the correct path when adding new maps,
large amounts of evidence, or a meaningfully different distribution of tech.
The server accepts runtime models only from the bot whitelist and validates the
exact 12-24-11 shape, action order, finite values, sample count, and loss change.

## What learns

The system has three distinct kinds of knowledge:

1. Encoded movement rules decide whether a jump, vault, swing, roll, slide boost,
   truss climb, drop, or trampoline transition is physically legal.
2. Geometry-conditioned calibration learns run-up offsets and timing arms for
   high vaults, swings, slide boosts, and roll boosts. Its keys use action,
   relative height, distance, and speed bands, so useful timing can transfer to
   similar geometry on another map.
3. Route memory and the tiny policy bias A* costs using completion time, success
   probability, goal progress, opponent progress, openness, dead-end risk, role,
   and learned reward. They cannot bypass movement eligibility.

The policy samples now use the real tactical or explorer goal. Older V2 samples
collected before this change treated each transition destination as its own goal;
replace those gradually with new ring-buffer samples before judging policy quality.

## Efficient sessions

Use independent explorers for broad transition and timing coverage, then bot vs
bot for role rewards, and finally bot vs strong players for route prediction and
cutoff evidence. Keep failed attempts: bounded failures teach risk and parameter
selection. Remove sessions only when the map, role state, or physics was broken.
The 5,000-sample ring automatically replaces its oldest entries, so leaving a
healthy session running steadily refreshes stale evidence instead of growing the
runtime workload. After a short warmup, routine Walk samples are admitted only
while they occupy less than 65% of the session buffer. This leaves capacity for
rare valid tech without deleting the walking baseline.

## Runtime memory

Successful and failed affordance outcomes, local timing estimates, dead areas,
and repeated player graph transitions are merged into the global bot DataStore.
The map model itself is rebuilt when `workspace.Map` changes because it is based
on the spawned map's world transforms. For production, a validated map model can
later be baked per map revision and loaded instead of scanned.

The checked-in weights are neutral until trained data replaces them. The bot is
therefore architecturally trainable, but it is not a trained high-level opponent
just because the new runtime is installed.
