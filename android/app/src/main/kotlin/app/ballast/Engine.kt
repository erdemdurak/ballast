package app.ballast

/**
 * The same machine as Sources/BallastEngine on iOS: pure, no clocks, no platform types.
 *
 * Kept as a straight port rather than a rewrite so the two platforms cannot drift.
 * Where iOS had to work around missing signals, Android does not — but the rules about
 * when to ask are identical, and they live here.
 */

enum class Mode { SLIP, ANY }

enum class Phase { IDLE, QUIET, WAITING, ARMED, ASKING }

enum class RecordKind { SLIP, PICKUP, NUDGE, DOWN, THROUGH }

enum class Dismissal { DOWN, THROUGH }

object Constants {
    const val DEFAULT_INTERVAL_MIN = 20
    const val NUDGE_COOLDOWN = 60.0
    const val PICKUP_DEBOUNCE = 25.0
    const val REST_BEFORE_PICKUP = 12.0
    const val HOLD = 4.0
    const val STILLNESS_DELTA = 0.3

    val DURATION_STEPS = listOf(5, 10, 15, 30, 45, 60, 75, 90, 120, 150, 180, 240)

    /** A reminder that lands after the work is over is no reminder at all. */
    fun reminderInterval(intervalMin: Int, durationMin: Int) =
        maxOf(1, minOf(intervalMin, durationMin))
}

data class Config(
    val intervalMin: Int = Constants.DEFAULT_INTERVAL_MIN,
    val mode: Mode = Mode.ANY,
    val holdSeconds: Double = Constants.HOLD,
) {
    val interval: Double get() = intervalMin * 60.0
}

data class SessionState(
    val task: String = "",
    val config: Config = Config(),
    val sessionStart: Double? = null,
    val lastSlip: Double? = null,
    val lastNudge: Double? = null,
    val lastPickup: Double? = null,
    val isAsking: Boolean = false,
) {
    /** What the interval is measured from. Null means nothing is owed. */
    val anchor: Double?
        get() {
            val start = sessionStart ?: return null
            return when (config.mode) {
                Mode.SLIP -> lastSlip
                Mode.ANY -> maxOf(lastSlip ?: start, lastNudge ?: start, start)
            }
        }

    fun phase(now: Double): Phase {
        sessionStart ?: return Phase.IDLE
        if (isAsking) return Phase.ASKING
        val a = anchor ?: return Phase.QUIET
        return if (now - a >= config.interval) Phase.ARMED else Phase.WAITING
    }
}

sealed interface Event {
    data class StartSession(val task: String, val config: Config) : Event
    data object EndSession : Event
    data object Slip : Event
    data object Pickup : Event
    /** The user tapped a reminder. The question was already asked; refusing it here
     *  would leave a tap that does nothing. */
    data object AskNow : Event
    data object Tick : Event
    data class Dismiss(val how: Dismissal) : Event
}

sealed interface Effect {
    data class Record(val kind: RecordKind, val at: Double) : Effect
    data class PresentAsking(val holdSeconds: Double) : Effect
    data object PresentClosed : Effect
    data object DismissAsking : Effect
}

fun reduce(state: SessionState, event: Event, now: Double): Pair<SessionState, List<Effect>> =
    when (event) {
        is Event.StartSession -> {
            val trimmed = event.task.trim()
            if (trimmed.isEmpty()) state to emptyList()
            else SessionState(task = trimmed, config = event.config, sessionStart = now) to
                emptyList()
        }

        Event.EndSession ->
            if (state.sessionStart == null) state to emptyList()
            else state.copy(sessionStart = null, isAsking = false) to
                listOf(Effect.PresentClosed)

        Event.Slip ->
            if (state.sessionStart == null) state to emptyList()
            else state.copy(lastSlip = now) to listOf(Effect.Record(RecordKind.SLIP, now))

        Event.Pickup -> pickup(state, now)

        Event.AskNow ->
            if (state.sessionStart == null || state.isAsking) state to emptyList()
            else state.copy(
                lastNudge = now,
                lastSlip = if (state.config.mode == Mode.SLIP) null else state.lastSlip,
                isAsking = true,
            ) to listOf(
                Effect.Record(RecordKind.NUDGE, now),
                Effect.PresentAsking(state.config.holdSeconds),
            )

        Event.Tick -> state to emptyList()

        is Event.Dismiss ->
            if (!state.isAsking) state to emptyList()
            else state.copy(isAsking = false) to listOf(
                Effect.Record(
                    if (event.how == Dismissal.DOWN) RecordKind.DOWN else RecordKind.THROUGH, now),
                Effect.DismissAsking,
            )

    }

private fun pickup(state: SessionState, now: Double): Pair<SessionState, List<Effect>> {
    if (state.sessionStart == null) return state to emptyList()

    // One reach is one pick-up, and a debounced sample is not a separate event.
    state.lastPickup?.let { if (now - it < Constants.PICKUP_DEBOUNCE) return state to emptyList() }

    val moved = state.copy(lastPickup = now)
    val recorded = listOf(Effect.Record(RecordKind.PICKUP, now))

    if (moved.isAsking) return moved to recorded
    val anchor = moved.anchor ?: return moved to recorded
    if (now - anchor < moved.config.interval) return moved to recorded
    moved.lastNudge?.let { if (now - it < Constants.NUDGE_COOLDOWN) return moved to recorded }

    // Consume the slip: without this the anchor stays older than the interval for the
    // rest of the session and every pick-up past the cooldown asks again.
    return moved.copy(
        lastNudge = now,
        lastSlip = if (moved.config.mode == Mode.SLIP) null else moved.lastSlip,
        isAsking = true,
    ) to recorded + listOf(
        Effect.Record(RecordKind.NUDGE, now),
        Effect.PresentAsking(moved.config.holdSeconds),
    )
}

/** Seconds left before the dismissal becomes tappable. The friction is the product. */
fun holdRemaining(holdSeconds: Double, askedAt: Double, now: Double): Int =
    maxOf(0, Math.ceil(holdSeconds - (now - askedAt)).toInt())
