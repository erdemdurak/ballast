package app.ballast

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorManager
import android.hardware.TriggerEvent
import android.hardware.TriggerEventListener
import android.media.AudioAttributes
import android.net.Uri
import android.os.Handler
import android.os.IBinder
import android.os.Looper

/**
 * Everything iOS could not do.
 *
 * `UsageStatsManager` reports MOVE_TO_FOREGROUND the moment an app is opened — not a
 * minute of accumulated use later, and not whenever the system feels like delivering
 * it. So on Android the alarm really can fire as the user opens Instagram, which is
 * what the product was always meant to do.
 *
 * `TYPE_SIGNIFICANT_MOTION` is a hardware trigger that wakes the process while it is
 * in the background, so the physical pick-up is detectable too.
 */
class Watcher : Service() {

    companion object {
        const val CHANNEL_ALERT = "holdfocus.alerts"
        const val CHANNEL_SERVICE = "holdfocus.session"
        const val ACTION_SLIP = "app.ballast.SLIP"
        const val ACTION_PICKUP = "app.ballast.PICKUP"
        const val EXTRA_PACKAGE = "package"

        fun start(context: Context) =
            context.startForegroundService(Intent(context, Watcher::class.java))

        fun stop(context: Context) = context.stopService(Intent(context, Watcher::class.java))
    }

    private lateinit var store: Store
    private lateinit var usage: UsageStatsManager
    private lateinit var sensors: SensorManager
    private val handler = Handler(Looper.getMainLooper())
    private var lastQuery = 0L
    private var lastPickup = 0.0
    private var lastAlerted = mutableMapOf<String, Long>()

    private val poll = object : Runnable {
        override fun run() {
            checkForegroundApp()
            // Two seconds is the difference between "you just opened Instagram" and a
            // warning that arrives once you have already put it down.
            handler.postDelayed(this, 2_000)
        }
    }

    private val motion = object : TriggerEventListener() {
        override fun onTrigger(event: TriggerEvent) {
            val now = System.currentTimeMillis() / 1000.0
            if (now - lastPickup > Constants.PICKUP_DEBOUNCE) {
                lastPickup = now
                sendBroadcast(Intent(ACTION_PICKUP).setPackage(packageName))
            }
            // One-shot sensor: it has to be re-armed after every trigger.
            sensors.getDefaultSensor(Sensor.TYPE_SIGNIFICANT_MOTION)
                ?.let { sensors.requestTriggerSensor(this, it) }
        }
    }

    override fun onCreate() {
        super.onCreate()
        store = Store(this)
        usage = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        sensors = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        channels()
        startForeground(1, runningNotification())
        lastQuery = System.currentTimeMillis() - 10_000
        handler.post(poll)
        sensors.getDefaultSensor(Sensor.TYPE_SIGNIFICANT_MOTION)
            ?.let { sensors.requestTriggerSensor(motion, it) }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int) = START_STICKY

    override fun onDestroy() {
        handler.removeCallbacks(poll)
        sensors.cancelTriggerSensor(motion,
            sensors.getDefaultSensor(Sensor.TYPE_SIGNIFICANT_MOTION))
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    /** The whole point: catch the open as it happens. */
    private fun checkForegroundApp() {
        val store = Store(this)
        val session = store.open ?: return
        val watched = store.prefs.watched
        if (watched.isEmpty()) return

        val now = System.currentTimeMillis()
        val events = usage.queryEvents(lastQuery, now)
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType != UsageEvents.Event.MOVE_TO_FOREGROUND) continue
            val pkg = event.packageName ?: continue
            if (pkg !in watched) continue
            // One alert per app per minute: switching back and forth is one slip.
            if (now - (lastAlerted[pkg] ?: 0) < 60_000) continue
            lastAlerted[pkg] = now
            alert(pkg, session.task)
            sendBroadcast(
                Intent(ACTION_SLIP).setPackage(packageName).putExtra(EXTRA_PACKAGE, pkg))
        }
        lastQuery = now
    }

    private fun alert(pkg: String, task: String) {
        val label = appLabel(pkg)
        val open = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                .putExtra(MainActivity.EXTRA_ASK, true),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        val notification = Notification.Builder(this, CHANNEL_ALERT)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle(getString(R.string.ask_title))
            .setContentText(getString(R.string.notif_slip_now, label, task))
            .setStyle(Notification.BigTextStyle()
                .bigText(getString(R.string.notif_slip_now, label, task)))
            .setContentIntent(open)
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_ALARM)
            .setFullScreenIntent(open, true)
            .build()
        manager().notify(pkg.hashCode(), notification)
    }

    private fun appLabel(pkg: String): String = runCatching {
        packageManager.getApplicationLabel(packageManager.getApplicationInfo(pkg, 0)).toString()
    }.getOrDefault(pkg)

    private fun runningNotification(): Notification {
        val task = Store(this).open?.task.orEmpty()
        return Notification.Builder(this, CHANNEL_SERVICE)
            .setSmallIcon(android.R.drawable.ic_menu_view)
            .setContentTitle(getString(R.string.notif_running, task))
            .setContentIntent(PendingIntent.getActivity(
                this, 1, Intent(this, MainActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            .setOngoing(true)
            .build()
    }

    private fun channels() {
        val alarm = Uri.parse("android.resource://$packageName/${R.raw.alarm}")
        val alerts = NotificationChannel(
            CHANNEL_ALERT, getString(R.string.notif_channel),
            NotificationManager.IMPORTANCE_HIGH).apply {
            setSound(alarm, AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build())
            enableVibration(true)
        }
        val session = NotificationChannel(
            CHANNEL_SERVICE, getString(R.string.notif_service_channel),
            NotificationManager.IMPORTANCE_LOW)
        manager().createNotificationChannel(alerts)
        manager().createNotificationChannel(session)
    }

    private fun manager() =
        getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
}
