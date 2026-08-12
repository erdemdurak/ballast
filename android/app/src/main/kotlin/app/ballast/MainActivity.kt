package app.ballast

import android.app.AppOpsManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.app.ActivityCompat

private val Ink = Color(0xFF16202B)
private val Ink2 = Color(0xFF3A4A57)
private val Mute = Color(0xFF78878F)
private val Paper = Color(0xFFE3E9EA)
private val Panel = Color(0xFFF2F6F6)
private val Line = Color(0xFFC3CDCF)
private val Calm = Color(0xFF47756A)
private val Slip = Color(0xFF8A5573)

class MainActivity : ComponentActivity() {

    companion object { const val EXTRA_ASK = "ask" }

    private lateinit var model: AppModel

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                Watcher.ACTION_SLIP ->
                    model.slip(intent.getStringExtra(Watcher.EXTRA_PACKAGE).orEmpty())
                Watcher.ACTION_PICKUP -> model.pickup()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        model = AppModel(applicationContext)
        if (Build.VERSION.SDK_INT >= 33) {
            ActivityCompat.requestPermissions(
                this, arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 0)
        }
        if (intent.getBooleanExtra(EXTRA_ASK, false)) model.askNow()

        registerReceiver(receiver, IntentFilter().apply {
            addAction(Watcher.ACTION_SLIP)
            addAction(Watcher.ACTION_PICKUP)
        }, Context.RECEIVER_NOT_EXPORTED)

        setContent { Root(model, ::grantUsageAccess) }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.getBooleanExtra(EXTRA_ASK, false)) model.askNow()
    }

    override fun onResume() { super.onResume(); model.refresh() }

    override fun onDestroy() { runCatching { unregisterReceiver(receiver) }; super.onDestroy() }

    /** Usage access is a settings-page grant, not a runtime dialog. All we can do is
     *  explain and deep-link — this is where installs die, so the copy matters. */
    private fun grantUsageAccess() =
        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
}

fun hasUsageAccess(context: Context): Boolean {
    val ops = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
    val mode = ops.unsafeCheckOpNoThrow(
        AppOpsManager.OPSTR_GET_USAGE_STATS,
        android.os.Process.myUid(), context.packageName)
    return mode == AppOpsManager.MODE_ALLOWED
}

@Composable
private fun Root(model: AppModel, grantUsage: () -> Unit) {
    val route by model.route
    Surface(color = if (route == Route.ASKING) Panel else Paper) {
        when (route) {
            Route.SETUP -> SetupScreen(model, grantUsage)
            Route.SESSION -> SessionScreen(model)
            Route.ASKING -> AskingScreen(model)
            Route.CLOSED -> ClosedScreen(model)
        }
    }
}

@Composable private fun Eyebrow(text: String, color: Color = Mute) =
    Text(text.uppercase(), color = color, fontSize = 11.sp,
        fontFamily = FontFamily.Monospace, letterSpacing = 2.sp)

@Composable
private fun Filled(label: String, enabled: Boolean = true, onClick: () -> Unit) =
    Button(onClick = onClick, enabled = enabled,
        modifier = Modifier.fillMaxWidth().height(52.dp),
        shape = MaterialTheme.shapes.extraSmall,
        colors = ButtonDefaults.buttonColors(containerColor = Ink, contentColor = Panel)) {
        Text(label, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
    }

@Composable
private fun Outline(label: String, color: Color = Ink, enabled: Boolean = true,
                    onClick: () -> Unit) =
    OutlinedButton(onClick = onClick, enabled = enabled,
        modifier = Modifier.fillMaxWidth().height(52.dp),
        shape = MaterialTheme.shapes.extraSmall,
        colors = ButtonDefaults.outlinedButtonColors(contentColor = color)) {
        Text(label, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
    }

@Composable
private fun SetupScreen(model: AppModel, grantUsage: () -> Unit) {
    val context = LocalContextCompat()
    var task by remember { mutableStateOf(model.store.prefs.task) }
    var duration by remember { mutableStateOf(model.store.prefs.durationMin) }
    val watched by model.watched
    var picking by remember { mutableStateOf(false) }

    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(24.dp)) {
        Eyebrow(stringRes(R.string.app_name), Ink)
        Text(stringRes(R.string.setup_title), fontSize = 34.sp,
            fontWeight = FontWeight.Bold, color = Ink)
        Text(stringRes(R.string.setup_sub), fontSize = 15.sp, color = Ink2)

        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Eyebrow(stringRes(R.string.setup_task_label))
            BasicTextField(
                value = task, onValueChange = { task = it.replace("\n", " ") },
                singleLine = true,
                textStyle = TextStyle(fontSize = 24.sp, fontWeight = FontWeight.SemiBold,
                    color = Ink),
                modifier = Modifier.fillMaxWidth())
            Box(Modifier.fillMaxWidth().height(2.dp).background(Ink))
        }

        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Eyebrow(stringRes(R.string.setup_duration))
                Text(humanDuration(duration), fontSize = 13.sp,
                    fontFamily = FontFamily.Monospace, color = Ink)
            }
            val steps = Constants.DURATION_STEPS
            Slider(
                value = steps.indexOf(duration).coerceAtLeast(0).toFloat(),
                onValueChange = { duration = steps[it.toInt().coerceIn(steps.indices)] },
                valueRange = 0f..(steps.size - 1).toFloat(),
                steps = steps.size - 2,
                colors = SliderDefaults.colors(thumbColor = Ink, activeTrackColor = Ink))
        }

        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Eyebrow(stringRes(R.string.setup_feeds))
                Text("${watched.size}", fontSize = 13.sp,
                    fontFamily = FontFamily.Monospace,
                    color = if (watched.isEmpty()) Mute else Calm)
            }
            Outline(stringRes(R.string.setup_feeds_pick)) { picking = true }
            if (!hasUsageAccess(context)) {
                Text(stringRes(R.string.perm_usage_body), fontSize = 13.sp, color = Mute)
                Outline(stringRes(R.string.perm_usage_open), Slip) { grantUsage() }
            }
        }

        Filled(stringRes(R.string.setup_start), enabled = task.isNotBlank()) {
            model.start(task.trim(), duration)
        }

        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Eyebrow(stringRes(R.string.setup_recent))
            model.store.sessions.take(3).forEach { s ->
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(s.task, fontSize = 15.sp, color = Ink, modifier = Modifier.weight(1f))
                    Text(if (s.completed) stringRes(R.string.recent_done)
                         else stringRes(R.string.recent_unfinished),
                        fontSize = 13.sp, fontFamily = FontFamily.Monospace,
                        color = if (s.completed) Calm else Slip)
                }
                Box(Modifier.fillMaxWidth().height(1.dp).background(Line))
            }
            if (model.store.sessions.isNotEmpty()) {
                TextButton(onClick = { model.wipe() }) {
                    Text(stringRes(R.string.setup_wipe), color = Slip, fontSize = 14.sp)
                }
            }
        }
    }

    if (picking) AppPicker(model) { picking = false }
}

@Composable
private fun AppPicker(model: AppModel, done: () -> Unit) {
    val watched by model.watched
    AlertDialog(
        onDismissRequest = done,
        confirmButton = { TextButton(onClick = done) { Text("OK") } },
        title = { Text(stringRes(R.string.setup_feeds)) },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState())) {
                model.installedCandidates().forEach { (pkg, label) ->
                    Row(Modifier.fillMaxWidth().padding(vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically) {
                        Checkbox(checked = pkg in watched,
                            onCheckedChange = { model.toggleWatched(pkg) })
                        Text(label, fontSize = 15.sp, color = Ink)
                    }
                }
            }
        })
}

@Composable
private fun SessionScreen(model: AppModel) {
    val now by model.now
    val session = model.store.open
    Column(Modifier.fillMaxSize().padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp)) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Eyebrow(stringRes(R.string.session_in))
            TextButton(onClick = { model.end() }) {
                Text(stringRes(R.string.session_end), color = Ink)
            }
        }
        Eyebrow(stringRes(R.string.session_anchor))
        Text(session?.task.orEmpty(), fontSize = 30.sp,
            fontWeight = FontWeight.SemiBold, color = Ink)

        Box(Modifier.fillMaxWidth().height(1.dp).background(Line))
        val counts = session?.interruptionCounts().orEmpty()
        if (counts.isEmpty()) Eyebrow(stringRes(R.string.session_no_interruptions), Calm)
        else {
            Eyebrow(stringRes(R.string.session_interrupted, counts.sumOf { it.second }), Slip)
            counts.take(4).forEach { (pkg, count) ->
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(model.label(pkg), fontSize = 15.sp, color = Ink)
                    Text("${count}×", fontSize = 13.sp,
                        fontFamily = FontFamily.Monospace, color = Slip)
                }
            }
        }
        Box(Modifier.fillMaxWidth().height(1.dp).background(Line))

        val left = model.armedIn(now)
        if (left != null) {
            Eyebrow(stringRes(R.string.session_armed_in))
            Text(clock(left), fontSize = 40.sp, fontFamily = FontFamily.Monospace, color = Ink)
        } else Eyebrow(stringRes(R.string.session_armed), Slip)

        Spacer(Modifier.weight(1f))
        Eyebrow(stringRes(R.string.session_watching, model.watched.value.size), Calm)
    }
}

@Composable
private fun AskingScreen(model: AppModel) {
    val now by model.now
    val held = holdRemaining(model.store.prefs.holdSeconds, model.askedAt, now)
    Column(Modifier.fillMaxSize().padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp)) {
        Spacer(Modifier.weight(1f))
        Eyebrow(stringRes(R.string.ask_eyebrow), Slip)
        Text(stringRes(R.string.ask_title), fontSize = 40.sp,
            fontWeight = FontWeight.Bold, color = Ink)
        Box(Modifier.fillMaxWidth().height(1.dp).background(Line))
        Eyebrow(stringRes(R.string.ask_list))
        Text(model.store.open?.task.orEmpty(), fontSize = 26.sp,
            fontWeight = FontWeight.SemiBold, color = Ink)
        Box(Modifier.fillMaxWidth().height(1.dp).background(Line))
        Text(model.askBody(), fontSize = 17.sp, color = Ink2)
        Spacer(Modifier.weight(1f))
        Filled(stringRes(R.string.ask_down)) { model.dismiss(Dismissal.DOWN) }
        Outline(
            if (held > 0) stringRes(R.string.ask_through_held, held)
            else stringRes(R.string.ask_through),
            enabled = held == 0) { model.dismiss(Dismissal.THROUGH) }
    }
}

@Composable
private fun ClosedScreen(model: AppModel) {
    val record = model.closed
    Column(Modifier.fillMaxSize().padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp)) {
        Spacer(Modifier.weight(1f))
        Eyebrow(stringRes(R.string.closed_title))
        Text(record?.task.orEmpty(), fontSize = 30.sp,
            fontWeight = FontWeight.SemiBold, color = Ink)
        Text(stringRes(R.string.closed_length) + " · " + clock(record?.lengthSeconds ?: 0.0),
            fontSize = 15.sp, color = Ink2)

        record?.interruptionCounts()?.take(4)?.let { counts ->
            if (counts.isNotEmpty()) {
                Eyebrow(stringRes(R.string.closed_interrupted_by), Slip)
                counts.forEach { (pkg, count) ->
                    Row(Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(model.label(pkg), fontSize = 15.sp, color = Ink)
                        Text("${count}×", fontSize = 13.sp,
                            fontFamily = FontFamily.Monospace, color = Slip)
                    }
                }
            }
        }
        Spacer(Modifier.weight(1f))
        if (record != null && !record.completed) {
            Filled(stringRes(R.string.closed_mark_done)) { model.markDone() }
        } else Eyebrow(stringRes(R.string.recent_done), Calm)
        Outline(stringRes(R.string.closed_next)) { model.newSession() }
    }
}

fun clock(seconds: Double): String {
    val total = maxOf(0, seconds.toInt())
    return "%02d:%02d".format(total / 60, total % 60)
}

fun humanDuration(minutes: Int): String =
    if (minutes < 60) "$minutes min"
    else if (minutes % 60 == 0) "${minutes / 60} hr"
    else "${minutes / 60} hr ${minutes % 60} min"
