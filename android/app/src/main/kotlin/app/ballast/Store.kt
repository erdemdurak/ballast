package app.ballast

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/** Local only. No account, no sync, no server. */
data class Ev(val t: Double, val type: RecordKind)

data class SessionRecord(
    val id: String = java.util.UUID.randomUUID().toString(),
    val task: String = "",
    val startedAt: Double = 0.0,
    val durationMin: Int = 60,
    var endedAt: Double? = null,
    val events: MutableList<Ev> = mutableListOf(),
    /** Only the user can say the work got done. Time running out is not the same thing. */
    var completed: Boolean = false,
    /** Package names that interrupted this session, in the order they were seen. */
    val interruptions: MutableList<String> = mutableListOf(),
) {
    val lengthSeconds: Double get() = (endedAt ?: startedAt) - startedAt
    fun count(kind: RecordKind) = events.count { it.type == kind }
    fun interruptionCounts(): List<Pair<String, Int>> =
        interruptions.groupingBy { it }.eachCount()
            .toList().sortedWith(compareByDescending<Pair<String, Int>> { it.second }.thenBy { it.first })
}

data class Prefs(
    var task: String = "",
    var durationMin: Int = 60,
    var intervalMin: Int = Constants.DEFAULT_INTERVAL_MIN,
    var holdSeconds: Double = Constants.HOLD,
    var watched: MutableSet<String> = mutableSetOf(),
)

class Store(context: Context) {
    private val file = File(context.filesDir, "store.json")

    var prefs = Prefs()
        private set
    var sessions = mutableListOf<SessionRecord>()
        private set
    var open: SessionRecord? = null
        private set

    init { load() }

    fun savePrefs(p: Prefs) { prefs = p; persist() }

    fun begin(task: String, durationMin: Int, at: Double) {
        open = SessionRecord(task = task, startedAt = at, durationMin = durationMin)
        persist()
    }

    fun append(kind: RecordKind, at: Double) {
        open?.events?.add(Ev(at, kind)); persist()
    }

    fun recordInterruption(packageName: String) {
        open?.interruptions?.add(packageName); persist()
    }

    fun end(at: Double): SessionRecord? {
        val record = open ?: return null
        record.endedAt = at
        sessions.add(0, record)
        open = null
        prune()
        persist()
        return record
    }

    fun markCompleted(id: String) {
        sessions.firstOrNull { it.id == id }?.completed = true
        persist()
    }

    fun wipe() { sessions.clear(); open = null; persist() }

    /** 30 days, then the event streams go. */
    private fun prune() {
        val cutoff = System.currentTimeMillis() / 1000.0 - 30 * 24 * 60 * 60
        sessions.removeAll { it.startedAt < cutoff }
    }

    private fun load() {
        if (!file.exists()) return
        runCatching {
            val root = JSONObject(file.readText())
            root.optJSONObject("prefs")?.let { p ->
                prefs = Prefs(
                    task = p.optString("task"),
                    durationMin = p.optInt("durationMin", 60),
                    intervalMin = p.optInt("intervalMin", Constants.DEFAULT_INTERVAL_MIN),
                    holdSeconds = p.optDouble("holdSeconds", Constants.HOLD),
                    watched = p.optJSONArray("watched").toStringList().toMutableSet(),
                )
            }
            sessions = root.optJSONArray("sessions").toRecords().toMutableList()
            open = root.optJSONObject("open")?.let { record(it) }
        }.onFailure {
            // Not swallowed: a store that cannot be read is a session that cannot be
            // ended, and reminders that cannot be stopped.
            android.util.Log.e("HoldFocus", "could not read store", it)
        }
    }

    private fun persist() {
        runCatching {
            val root = JSONObject()
            root.put("prefs", JSONObject().apply {
                put("task", prefs.task); put("durationMin", prefs.durationMin)
                put("intervalMin", prefs.intervalMin); put("holdSeconds", prefs.holdSeconds)
                put("watched", JSONArray(prefs.watched.toList()))
            })
            root.put("sessions", JSONArray(sessions.map { json(it) }))
            open?.let { root.put("open", json(it)) }
            file.writeText(root.toString())
        }.onFailure { android.util.Log.e("HoldFocus", "could not persist", it) }
    }

    private fun json(r: SessionRecord) = JSONObject().apply {
        put("id", r.id); put("task", r.task); put("startedAt", r.startedAt)
        put("durationMin", r.durationMin); r.endedAt?.let { put("endedAt", it) }
        put("completed", r.completed)
        put("interruptions", JSONArray(r.interruptions))
        put("events", JSONArray(r.events.map {
            JSONObject().put("t", it.t).put("type", it.type.name)
        }))
    }

    private fun record(o: JSONObject) = SessionRecord(
        id = o.optString("id", java.util.UUID.randomUUID().toString()),
        task = o.optString("task"),
        startedAt = o.optDouble("startedAt", 0.0),
        durationMin = o.optInt("durationMin", 60),
        endedAt = if (o.has("endedAt")) o.optDouble("endedAt") else null,
        events = (0 until (o.optJSONArray("events")?.length() ?: 0)).mapNotNull { i ->
            val e = o.getJSONArray("events").getJSONObject(i)
            runCatching { Ev(e.getDouble("t"), RecordKind.valueOf(e.getString("type"))) }.getOrNull()
        }.toMutableList(),
        completed = o.optBoolean("completed", false),
        interruptions = o.optJSONArray("interruptions").toStringList().toMutableList(),
    )

    private fun JSONArray?.toStringList(): List<String> =
        if (this == null) emptyList() else (0 until length()).map { getString(it) }

    private fun JSONArray?.toRecords(): List<SessionRecord> =
        if (this == null) emptyList() else (0 until length()).map { record(getJSONObject(it)) }
}
