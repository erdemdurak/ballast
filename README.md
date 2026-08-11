# Hold Focus

**A focus reminder. It never blocks anything.**

You name the one thing you are working on and how long it should take. Then you put the
phone down. When you pick it up again the task is already on the Lock Screen with the time
left on it, and at intervals it asks you one question.

Every question has a way through, and taking it costs four seconds and nothing else. There
is no streak to lose, no score, and no red.

## What it does

- **One task, one sentence.** Not a list.
- **Lock Screen, Dynamic Island, Home Screen** — the task and the time left, wherever you
  happen to look.
- **Reminders that arrive with the app closed**, and that reach you through Focus modes.
- **Optional Screen Time** — choose which apps count as a distraction and Hold Focus will
  notice when you have been in one, then count what actually broke the work.
- **A Shortcuts action**, so an automation can remind you the moment a chosen app opens.

## Privacy

Nothing leaves the phone. No account, no server, no analytics, no ads, no third-party
SDKs. See [PRIVACY.md](PRIVACY.md).

## Support

Open an issue: https://github.com/erdemdurak/ballast/issues

## Building

```bash
swift test                      # the nudge engine, 16 tests, no device needed
open Ballast.xcodeproj          # the app
```

The engine is a pure `reduce(state, event, now) -> (state, effects)` in
`Sources/BallastEngine`, deliberately free of platform types so it can be tested without a
device and ported without rewriting.

## Design notes

- `BALLAST.md` — the design specification and the reasoning behind it
- `IMPLEMENTATION.md` — how it is built
- `FAMILY-CONTROLS-REQUEST.md` — the Screen Time entitlement request text

Named Ballast during design; the shipping name is Hold Focus. Bundle identifiers still say
`app.ballast`, and changing them would mean redoing every capability registration for
something no user sees.
