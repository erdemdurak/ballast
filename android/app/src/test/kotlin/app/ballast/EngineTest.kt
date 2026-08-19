package app.ballast

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** The same table as the iOS suite, so the two ports cannot drift apart. */
class EngineTest {
    private val t0 = 1_754_900_000.0
    private val min = 60.0

    private fun run(script: List<Pair<Event, Double>>): SessionState {
        var s = SessionState()
        script.forEach { (e, t) -> s = reduce(s, e, t).first }
        return s
    }

    private fun start(mode: Mode) =
        Event.StartSession("Finish the chemistry lab write-up", Config(mode = mode)) to t0

    private fun asks(fx: List<Effect>) = fx.any { it is Effect.PresentAsking }

    @Test fun pickupDecisionTable() {
        data class Row(val name: String, val script: List<Pair<Event, Double>>,
                       val at: Double, val question: Boolean)
        listOf(
            Row("quiet, no slip", listOf(start(Mode.SLIP)), t0 + 30 * min, false),
            Row("waiting 19m", listOf(start(Mode.SLIP), Event.Slip to t0), t0 + 19 * min, false),
            Row("waiting 20m", listOf(start(Mode.SLIP), Event.Slip to t0), t0 + 20 * min, true),
            Row("any mode, no slip", listOf(start(Mode.ANY)), t0 + 20 * min, true),
            Row("slip mode, never slipped", listOf(start(Mode.SLIP)), t0 + 90 * min, false),
            Row("dismissed, cooldown expired",
                listOf(start(Mode.SLIP), Event.Slip to t0, Event.Pickup to t0 + 20 * min,
                       Event.Dismiss(Dismissal.THROUGH) to t0 + 20 * min + 2),
                t0 + 21 * min + 5, false),
        ).forEach { row ->
            val (_, fx) = reduce(run(row.script), Event.Pickup, row.at)
            assertEquals(row.name, row.question, asks(fx))
        }
    }

    @Test fun askNowAlwaysOpensTheQuestion() {
        val (s, fx) = reduce(run(listOf(start(Mode.ANY))), Event.AskNow, t0 + 5)
        assertTrue(asks(fx))
        assertEquals(Phase.ASKING, s.phase(t0 + 5))
    }

    @Test fun askNowNeedsASession() {
        assertTrue(reduce(SessionState(), Event.AskNow, t0).second.isEmpty())
    }

    @Test fun slipModeGoesQuietAfterAQuestion() {
        val asked = run(listOf(start(Mode.SLIP), Event.Slip to t0, Event.Pickup to t0 + 20 * min))
        val (dismissed, _) = reduce(asked, Event.Dismiss(Dismissal.DOWN), t0 + 20 * min + 2)
        assertEquals(Phase.QUIET, dismissed.phase(t0 + 20 * min + 2))
    }

    @Test fun anyModeNeverGoesQuiet() {
        var s = run(listOf(start(Mode.ANY), Event.Pickup to t0 + 20 * min))
        s = reduce(s, Event.Dismiss(Dismissal.THROUGH), t0 + 20 * min + 2).first
        assertEquals(Phase.WAITING, s.phase(t0 + 20 * min + 2))
        assertEquals(Phase.ARMED, s.phase(t0 + 40 * min))
    }

    @Test fun debouncedPickupIsDropped() {
        val s = run(listOf(start(Mode.SLIP), Event.Slip to t0, Event.Pickup to t0 + 20 * min))
        assertTrue(reduce(s, Event.Pickup, t0 + 20 * min + 24).second.isEmpty())
    }

    @Test fun blankTaskStartsNothing() {
        val (s, fx) = reduce(SessionState(), Event.StartSession("   ", Config()), t0)
        assertEquals(Phase.IDLE, s.phase(t0))
        assertTrue(fx.isEmpty())
    }

    @Test fun theHoldCountsDown() {
        assertEquals(4, holdRemaining(4.0, t0, t0))
        assertEquals(3, holdRemaining(4.0, t0, t0 + 1))
        assertEquals(1, holdRemaining(4.0, t0, t0 + 3.9))
        assertEquals(0, holdRemaining(4.0, t0, t0 + 4))
        assertEquals(0, holdRemaining(0.0, t0, t0))
    }

    @Test fun shortWorkIsAskedWithinItsOwnLength() {
        assertEquals(5, Constants.reminderInterval(20, 5))
        assertEquals(20, Constants.reminderInterval(20, 60))
        assertEquals(1, Constants.reminderInterval(20, 0))
    }
}
