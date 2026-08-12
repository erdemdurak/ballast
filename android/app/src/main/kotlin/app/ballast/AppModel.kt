package app.ballast

import android.content.Context
import android.content.pm.ApplicationInfo
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.platform.LocalContext
import androidx.compose.runtime.Composable
import androidx.compose.ui.res.stringResource
import android.os.Handler
import android.os.Looper

enum class Route { SETUP, SESSION, ASKING, CLOSED }

@Composable fun stringRes(id: Int): String = stringResource(id)
@Composable fun stringRes(id: Int, vararg args: Any): String = stringResource(id, *args)
@Composable fun LocalContextCompat(): Context = LocalContext.current

/** Drives the engine and everything around it. The rules themselves live in Engine.kt. */
class AppModel(private val context: Context) {

    val store = Store(context)
    val route: MutableState<Route> = mutableStateOf(Route.SETUP)
    val now: MutableState<Double> = mutableStateOf(seconds())
    val watched: MutableState<Set<String>> = mutableStateOf(store.prefs.watched.toSet())

    var askedAt = 0.0
        private set
    var closed: SessionRecord? = null
        private set
    private var slipLabel: String? = null

    private var state = SessionState()
    private val ticker = Handler(Looper.getMainLooper())

    init {
        store.open?.let { open ->
            // A session whose deadline has passed should not still be running.
            val deadline = open.startedAt + open.durationMin * 60.0
            if (seconds() > deadline) {
                closed = store.end(deadline)
                Watcher.stop(context)
                route.value = Route.CLOSED
            } else {
                state = rebuild(open)
                route.value = if (state.isAsking) Route.ASKING else Route.SESSION
                Watcher.start(context)
                tick()
            }
        }
    }

    private fun seconds() = System.currentTimeMillis() / 1000.0

    private fun config() = Config(
        intervalMin = Constants.reminderInterval(
            store.prefs.intervalMin, store.prefs.durationMin),
        holdSeconds = store.prefs.holdSeconds)

    private fun rebuild(record: SessionRecord): SessionState {
        var s = SessionState(task = record.task, config = config(),
            sessionStart = record.startedAt)
        record.events.forEach { e ->
            s = when (e.type) {
                RecordKind.SLIP -> s.copy(lastSlip = e.t)
                RecordKind.PICKUP -> s.copy(lastPickup = e.t)
                RecordKind.NUDGE -> s.copy(lastNudge = e.t, isAsking = true)
                RecordKind.DOWN, RecordKind.THROUGH -> s.copy(isAsking = false)
            }
        }
        return s
    }

    fun refresh() {
        watched.value = store.prefs.watched.toSet()
        now.value = seconds()
    }

    // MARK: - Intent

    fun start(task: String, durationMin: Int) {
        val prefs = store.prefs.apply {
            this.task = task
            this.durationMin = durationMin
        }
        store.savePrefs(prefs)
        val t = seconds()
        store.begin(task, durationMin, t)
        send(Event.StartSession(task, config()), t)
        route.value = Route.SESSION
        Watcher.start(context)
        tick()
    }

    fun end() {
        val t = seconds()
        send(Event.EndSession, t)
        closed = store.end(t)
        Watcher.stop(context)
        ticker.removeCallbacksAndMessages(null)
        route.value = Route.CLOSED
    }

    fun slip(packageName: String) {
        if (packageName.isNotEmpty()) {
            store.recordInterruption(packageName)
            slipLabel = label(packageName)
        }
        send(Event.Slip, seconds())
    }

    fun pickup() = send(Event.Pickup, seconds())

    /** The reminder already asked; opening it must never be refused. */
    fun askNow() = send(Event.AskNow, seconds())

    fun dismiss(how: Dismissal) = send(Event.Dismiss(how), seconds())

    fun markDone() {
        closed?.let { store.markCompleted(it.id); closed = store.sessions.firstOrNull { s -> s.id == it.id } }
        route.value = Route.CLOSED
    }

    fun newSession() { closed = null; slipLabel = null; route.value = Route.SETUP }

    fun wipe() { store.wipe(); route.value = Route.SETUP }

    fun toggleWatched(packageName: String) {
        val prefs = store.prefs
        if (!prefs.watched.remove(packageName)) prefs.watched.add(packageName)
        store.savePrefs(prefs)
        watched.value = prefs.watched.toSet()
    }

    // MARK: - Derived

    fun armedIn(atNow: Double): Double? {
        val anchor = state.anchor ?: return null
        val left = state.config.interval - (atNow - anchor)
        return if (left > 0) left else null
    }

    fun askBody(): String {
        val label = slipLabel
        return if (label != null)
            context.getString(R.string.ask_body_slip, label, state.task)
        else {
            val anchor = state.anchor ?: state.sessionStart ?: askedAt
            context.getString(R.string.ask_body, humanDuration(((askedAt - anchor) / 60).toInt()))
        }
    }

    fun label(packageName: String): String = runCatching {
        val pm = context.packageManager
        pm.getApplicationLabel(pm.getApplicationInfo(packageName, 0)).toString()
    }.getOrDefault(packageName)

    /** Only the packages declared in <queries> are visible, which is the point. */
    fun installedCandidates(): List<Pair<String, String>> {
        val pm = context.packageManager
        return CANDIDATES.mapNotNull { pkg ->
            runCatching {
                val info: ApplicationInfo = pm.getApplicationInfo(pkg, 0)
                pkg to pm.getApplicationLabel(info).toString()
            }.getOrNull()
        }.sortedBy { it.second }
    }

    // MARK: - Engine

    private fun send(event: Event, at: Double) {
        val (next, effects) = reduce(state, event, at)
        state = next
        effects.forEach { effect ->
            when (effect) {
                is Effect.Record -> store.append(effect.kind, effect.at)
                is Effect.PresentAsking -> { askedAt = at; now.value = at; route.value = Route.ASKING }
                Effect.PresentClosed -> route.value = Route.CLOSED
                Effect.DismissAsking -> { slipLabel = null; route.value = Route.SESSION }
            }
        }
    }

    private fun tick() {
        ticker.removeCallbacksAndMessages(null)
        ticker.postDelayed(object : Runnable {
            override fun run() {
                now.value = seconds()
                ticker.postDelayed(this, 500)
            }
        }, 500)
    }

    companion object {
        /** Mirrors the <queries> block; the manifest is the source of truth. */
        val CANDIDATES = listOf(
            "com.instagram.android", "com.zhiliaoapp.musically", "com.twitter.android",
            "com.x.android", "com.facebook.katana", "com.google.android.youtube",
            "com.reddit.frontpage", "com.linkedin.android", "com.snapchat.android",
            "com.whatsapp", "org.telegram.messenger", "com.pinterest",
            "com.netflix.mediaclient", "tv.twitch.android.app")
    }
}
