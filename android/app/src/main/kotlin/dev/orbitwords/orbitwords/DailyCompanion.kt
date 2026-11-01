package dev.orbitwords.orbitwords

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime

/** No XP is awarded here. The durable Flutter snapshot is a read-only projection
 * of the event ledger. Calendar-dependent values are evaluated on the device,
 * even when Flutter is not running. Only one inexact study alarm is scheduled. */
object DailyCompanion {
    const val OPEN_COURSE = "kvesmos_course"
    const val STUDY = "dev.orbitwords.orbitwords.STUDY"
    const val MIDNIGHT = "dev.orbitwords.orbitwords.MIDNIGHT"
    private const val NOTIFICATION = 1110
    private fun prefs(c: Context) = c.getSharedPreferences("kvesmos_companion_v1", Context.MODE_PRIVATE)
    fun snapshot(c: Context): JSONObject? = try {
        JSONObject(prefs(c).getString("snapshot", "")!!).takeIf { it.optInt("version") == 1 }
    } catch (_: Exception) { null }
    fun course(id: String?) = id?.takeIf { it in listOf("ru-en", "ru-es", "ru-de") } ?: "ru-en"
    fun sync(c: Context, raw: String) {
        val json = JSONObject(raw)
        require(json.optInt("version") == 1)
        prefs(c).edit().putString("snapshot", raw).commit()
        updateWidgets(c)
        schedule(c)
        val reminders = json.optJSONObject("reminders") ?: JSONObject()
        val id = course(reminders.optString("courseId"))
        val xp = daily(json, id).optInt(LocalDate.now().toString())
        if (!reminders.optBoolean("enabled") || xp >= json.optInt("goal", 50)) {
            (c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(NOTIFICATION)
        }
    }
    private fun daily(j: JSONObject, id: String) =
        j.optJSONObject("courses")?.optJSONObject(id)?.optJSONObject("dailyXp") ?: JSONObject()
    private fun quiet(p: JSONObject, minute: Int): Boolean {
        if (!p.optBoolean("quiet", true)) return false
        val start = p.optInt("quietStart", 1320); val end = p.optInt("quietEnd", 480)
        return if (start == end) true else if (start < end) minute >= start && minute < end else minute >= start || minute < end
    }
    private fun eligible(j: JSONObject, date: LocalDate): Boolean {
        val p = j.optJSONObject("reminders") ?: return false
        if (!p.optBoolean("enabled")) return false
        val weekdays = p.optJSONArray("weekdays") ?: return false
        if ((0 until weekdays.length()).none { weekdays.optInt(it) == date.dayOfWeek.value }) return false
        if (quiet(p, p.optInt("minute", 1140))) return false
        val paused = p.optString("pausedUntil", "")
        if (paused != "null" && paused.isNotEmpty() && date.toString() < paused) return false
        return daily(j, course(p.optString("courseId"))).optInt(date.toString()) < j.optInt("goal", 50)
    }
    private fun alarm(c: Context, action: String, request: Int) = PendingIntent.getBroadcast(c, request,
        Intent(c, CompanionReceiver::class.java).setAction(action), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    fun schedule(c: Context) {
        val manager = c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val study = alarm(c, STUDY, 1101)
        manager.cancel(study)
        val now = ZonedDateTime.now()
        snapshot(c)?.let { j ->
            val minute = j.optJSONObject("reminders")?.optInt("minute", 1140) ?: 1140
            if (minute in 0..1439) for (i in 0..370) {
                val date = now.toLocalDate().plusDays(i.toLong())
                val at = date.atTime(minute / 60, minute % 60).atZone(ZoneId.systemDefault())
                if (at.isAfter(now) && eligible(j, date) && prefs(c).getString("lastSent", "") != date.toString()) {
                    manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at.toInstant().toEpochMilli(), study)
                    break
                }
            }
        }
        val midnight = alarm(c, MIDNIGHT, 1102)
        manager.cancel(midnight)
        val ids = AppWidgetManager.getInstance(c).getAppWidgetIds(ComponentName(c, StreakWidget::class.java))
        if (ids.isNotEmpty()) {
            val nextDay = now.toLocalDate().plusDays(1).atStartOfDay(ZoneId.systemDefault())
            manager.set(AlarmManager.RTC, nextDay.toInstant().toEpochMilli(), midnight)
        }
    }
    fun deliver(c: Context) {
        val j = snapshot(c) ?: return
        val now = ZonedDateTime.now(); val date = now.toLocalDate()
        val p = j.optJSONObject("reminders") ?: return
        val minute = now.hour * 60 + now.minute
        // Delayed Doze alarms cannot arrive in quiet hours or another day's
        // morning. A consumed alarm cannot duplicate after a clock change.
        if (eligible(j, date) && minute >= p.optInt("minute", 1140) && !quiet(p, minute) && prefs(c).getString("lastSent", "") != date.toString()) {
            val manager = c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val allowed = if (Build.VERSION.SDK_INT >= 24) manager.areNotificationsEnabled() else true
            if (allowed) {
                if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel("kvesmos_study_v1", "Напоминания Орби", NotificationManager.IMPORTANCE_DEFAULT))
                val id = course(p.optString("courseId"))
                val name = j.optJSONObject("courses")?.optJSONObject(id)?.optString("name") ?: "Учёба"
                val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(c, "kvesmos_study_v1") else Notification.Builder(c)
                val notification = builder.setSmallIcon(R.drawable.ic_notification)
                    .setContentTitle("Орби · $name").setContentText("Пять минут для новых слов сегодня?")
                    .setContentIntent(open(c, id, 1110)).setAutoCancel(true).setOnlyAlertOnce(true).build()
                try {
                    manager.notify(NOTIFICATION, notification)
                    prefs(c).edit().putString("lastSent", date.toString()).commit()
                } catch (_: SecurityException) { /* Revoked permission: no delivery. */ }
            }
        }
        schedule(c)
    }
    private fun open(c: Context, id: String, request: Int) = PendingIntent.getActivity(c, request,
        Intent(c, MainActivity::class.java).putExtra(OPEN_COURSE, course(id))
            .setFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    fun updateWidgets(c: Context) {
        val manager = AppWidgetManager.getInstance(c)
        for (id in manager.getAppWidgetIds(ComponentName(c, StreakWidget::class.java))) render(c, manager, id)
    }
    fun render(c: Context, manager: AppWidgetManager, widget: Int) {
        val j = snapshot(c); val id = course(j?.optString("selectedCourse"))
        val today = LocalDate.now(); val history = if (j != null) daily(j, id) else JSONObject()
        val xp = history.optInt(today.toString()); val goal = (j?.optInt("goal", 50) ?: 50).coerceAtLeast(1)
        var cursor = if (history.optInt(today.toString()) > 0) today else today.minusDays(1)
        var streak = 0
        while (history.optInt(cursor.toString()) > 0) { streak++; cursor = cursor.minusDays(1) }
        val info = j?.optJSONObject("courses")?.optJSONObject(id)
        val views = RemoteViews(c.packageName, R.layout.streak_widget)
        val width = manager.getAppWidgetOptions(widget).getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
        val wide = width >= 240
        val compact = width < 180
        views.setTextViewText(R.id.widget_language, if (info == null) "KVESMOS" else "${info.optString("flag")} ${info.optString("name")}")
        views.setTextViewText(R.id.widget_streak, if (j == null) "Начнём?" else "$streak дн. подряд")
        views.setTextViewText(R.id.widget_goal, when { j == null -> "Откройте KVESMOS для обновления"; compact && xp >= goal -> "$xp XP · цель ✓"; compact -> "Сегодня $xp / $goal XP"; xp >= goal -> "Цель достигнута · $xp XP"; streak == 0 && xp == 0 -> "Первый шаг · 0 / $goal XP"; else -> "$xp / $goal XP сегодня" })
        views.setTextViewText(R.id.widget_cta, if (xp >= goal) "Ещё немного?" else "Продолжить урок")
        views.setTextViewTextSize(R.id.widget_streak, android.util.TypedValue.COMPLEX_UNIT_SP, if (wide) 29f else if (compact) 18f else 22f)
        val padding = ((if (compact) 10 else 14) * c.resources.displayMetrics.density).toInt()
        views.setViewPadding(R.id.widget_root, padding, padding, padding, padding)
        views.setProgressBar(R.id.widget_progress, goal, xp.coerceAtMost(goal), false)
        views.setViewVisibility(R.id.widget_progress, if (j == null) View.GONE else View.VISIBLE)
        views.setOnClickPendingIntent(R.id.widget_root, open(c, id, widget))
        views.setOnClickPendingIntent(R.id.widget_cta, open(c, id, widget))
        manager.updateAppWidget(widget, views)
    }
    fun pin(c: Context): Boolean {
        val manager = AppWidgetManager.getInstance(c)
        return Build.VERSION.SDK_INT >= 26 && manager.isRequestPinAppWidgetSupported &&
            manager.requestPinAppWidget(ComponentName(c, StreakWidget::class.java), null, null)
    }
}

class CompanionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == DailyCompanion.STUDY) DailyCompanion.deliver(context)
        else { DailyCompanion.updateWidgets(context); DailyCompanion.schedule(context) }
    }
}

class StreakWidget : AppWidgetProvider() {
    override fun onUpdate(c: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) DailyCompanion.render(c, manager, id)
        DailyCompanion.schedule(c)
    }
    override fun onAppWidgetOptionsChanged(c: Context, manager: AppWidgetManager, id: Int, options: Bundle) {
        DailyCompanion.render(c, manager, id)
    }
    override fun onDisabled(c: Context) { DailyCompanion.schedule(c) }
}
