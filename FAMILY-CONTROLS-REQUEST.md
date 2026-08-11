# Family Controls (Distribution) — request text

Submitted through Apple's web form, not Xcode:
`developer.apple.com/contact/request/family-controls-distribution`

Team ID: `Y829B2QFT9`

**One request per bundle ID.** Approving the container app does not approve its
extensions, and an extension left on the development entitlement fails distribution
signing outright. `app.ballast.widget` needs nothing here — it does not use Family
Controls.

| Bundle ID | Needs the entitlement | Status |
|---|---|---|
| `app.ballast` | Yes — `FamilyActivityPicker`, `DeviceActivityCenter` | Development only |
| `app.ballast.monitor` | Yes — `DeviceActivityMonitor` extension | Development only |
| `app.ballast.widget` | No | — |

Every claim below is true of the code as written. `ManagedSettingsStore` is never
imported, authorization is `.individual`, and the extension really does only write a
timestamp and schedule one notification. If a reviewer asks for source, nothing here
needs walking back.

---

## For `app.ballast`

Paperweight is a personal focus reminder for the person using the device. The user writes
down the one task they are working on and how long it should take. While that session
runs, Paperweight reminds them of that task — on the Lock Screen and through notifications
— so they are not pulled away from it without noticing.

We request Family Controls to use DeviceActivity for a single purpose: to know when the
user's own chosen apps have been in use, so a reminder can arrive shortly afterwards
instead of on a blind timer. The user selects those apps themselves through
FamilyActivityPicker. Because Apple returns opaque tokens, Paperweight never learns which
apps were selected, and it stores no record of them.

Paperweight never blocks, restricts, hides or delays access to anything. ManagedSettingsStore
and shield configurations are not used anywhere in the app, and we do not intend to use
them. Every reminder can be dismissed immediately, and dismissing it is worded neutrally
— the design deliberately avoids making the user feel they have failed.

Authorization is requested for `.individual` only. There is no parental mode, no employer
or team mode, no remote configuration, and no reporting to any third party. Paperweight
cannot be pointed at another person's device.

No usage or activity data leaves the device. There is no account, no server, no sync and
no analytics containing usage data. All session history is stored locally and can be
erased by the user at any time.

---

## For `app.ballast.monitor`

This extension belongs to Paperweight, a personal focus reminder. It is the
DeviceActivityMonitor extension for the container app `app.ballast`, submitted separately
as required.

Its only job is to receive `eventDidReachThreshold` when the user's own selected apps
have accumulated about a minute of use, write a timestamp into the shared App Group
container, and schedule one local notification reminding the user of the task they named.
It performs no other work, stores nothing else, and makes no network requests.

The extension does not block or restrict anything. It does not use ManagedSettingsStore
or shields. It has no access to which apps the user selected, since the tokens are opaque.

Authorization is `.individual` only. Paperweight is a tool a person points at themselves; it
has no parental, employer or third-party monitoring capability of any kind.

---

## After approval

The capability changes from Family Controls (Development) to (Distribution). Provisioning
profiles have to be regenerated before the change takes effect — a build with
`-allowProvisioningUpdates` picks it up.

Turnaround runs from days to weeks, and requests have been reported going unanswered.
Nothing breaks while waiting: the development entitlement keeps working on registered
devices. Only TestFlight and the App Store are closed until then.
