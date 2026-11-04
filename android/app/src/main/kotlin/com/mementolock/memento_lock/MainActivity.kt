package com.mementolock.memento_lock

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.*
import android.os.Build
import android.widget.RemoteViews
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.text.DecimalFormat
import java.text.SimpleDateFormat
import java.util.*
import kotlin.math.max
import kotlin.math.min

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.mementolock.memento_lock/widgets"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidgets" -> {
                    val args = call.arguments as? Map<*, *>
                    if (args != null) {
                        val quote = args["quote"] as? String
                        if (!quote.isNullOrBlank()) {
                            val prefs = applicationContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                            prefs.edit().putString("flutter.lastQuote", quote).apply()
                        }
                    }
                    MementoWidgetRenderer.updateAllWidgets(applicationContext)
                    result.success(true)
                }
                "requestPinWidget" -> {
                    val kind = call.argument<String>("kind") ?: "lock"
                    val ok = requestPinAppWidget(kind)
                    result.success(ok)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun requestPinAppWidget(kind: String): Boolean {
        MementoWidgetRenderer.updateAllWidgets(applicationContext)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val mgr = getSystemService(AppWidgetManager::class.java) ?: return false
            if (mgr.isRequestPinAppWidgetSupported) {
                val provider = if (kind == "home4x1") {
                    ComponentName(this, MementoHome4x1WidgetProvider::class.java)
                } else {
                    ComponentName(this, MementoLockWidgetProvider::class.java)
                }
                return mgr.requestPinAppWidget(provider, null, null)
            }
        }
        return false
    }
}

class MementoLockWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) {
            MementoWidgetRenderer.updateWidget(context, appWidgetManager, id, isLockStyle = true)
        }
    }
}

class MementoHome4x1WidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) {
            MementoWidgetRenderer.updateWidget(context, appWidgetManager, id, isLockStyle = false)
        }
    }
}

object MementoWidgetRenderer {
    fun updateAllWidgets(context: Context) {
        val mgr = AppWidgetManager.getInstance(context)
        val lockIds = mgr.getAppWidgetIds(ComponentName(context, MementoLockWidgetProvider::class.java))
        for (id in lockIds) {
            updateWidget(context, mgr, id, isLockStyle = true)
        }
        val homeIds = mgr.getAppWidgetIds(ComponentName(context, MementoHome4x1WidgetProvider::class.java))
        for (id in homeIds) {
            updateWidget(context, mgr, id, isLockStyle = false)
        }
    }

    fun updateWidget(context: Context, mgr: AppWidgetManager, appWidgetId: Int, isLockStyle: Boolean) {
        val views = RemoteViews(context.packageName, R.layout.memento_widget_layout)
        val bmp = if (isLockStyle) renderLockBitmap(context) else renderHome4x1Bitmap(context)
        views.setImageViewBitmap(R.id.memento_widget_image, bmp)

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getActivity(context, appWidgetId, launchIntent, flags)
        views.setOnClickPendingIntent(R.id.memento_widget_image, pendingIntent)

        mgr.updateAppWidget(appWidgetId, views)
    }

    private data class WidgetData(
        val percent: Double,
        val age: Int,
        val livedLabel: String,
        val remDays: String,
        val remWeekends: String,
        val yearPct: Double,
        val todayPct: Double,
        val quote: String,
        val g1Title: String,
        val g1Dday: String,
        val g1Progress: Float,
        val g2Title: String,
        val g2Dday: String,
        val opacity: Float,
        val boxColor: Int,
        val textColor: Int,
        val accentColor: Int,
        val home4x1Mode: Int
    )

    private fun parseFlutterStringList(raw: String?): List<String> {
        if (raw.isNullOrBlank()) return emptyList()
        val cleaned = if (raw.startsWith("VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu")) {
            raw.removePrefix("VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu").removePrefix("!")
        } else {
            raw
        }
        return try {
            val arr = JSONArray(cleaned)
            val list = mutableListOf<String>()
            for (i in 0 until arr.length()) {
                list.add(arr.getString(i))
            }
            list
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun loadData(context: Context): WidgetData {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val birthStr = prefs.getString("flutter.birth", null)
        val nowCal = Calendar.getInstance()
        val birthCal = Calendar.getInstance()
        if (!birthStr.isNullOrBlank()) {
            try {
                val clean = birthStr.take(10)
                val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.US)
                sdf.parse(clean)?.let { birthCal.time = it }
            } catch (_: Exception) {
                birthCal.set(1995, Calendar.MAY, 15)
            }
        } else {
            birthCal.set(1995, Calendar.MAY, 15)
        }

        val endCal = (birthCal.clone() as Calendar).apply { add(Calendar.YEAR, 80) }
        val totalDays = max(1L, (endCal.timeInMillis - birthCal.timeInMillis) / 86400000L)
        val livedDays = max(0L, (nowCal.timeInMillis - birthCal.timeInMillis) / 86400000L)
        val remLifeDays = max(0L, (endCal.timeInMillis - nowCal.timeInMillis) / 86400000L)
        val pct = min(100.0, max(0.0, livedDays.toDouble() / totalDays.toDouble() * 100.0))
        val age = (livedDays / 365.25).toInt()
        val df = DecimalFormat("#,###")
        val livedLabel = "D+${df.format(livedDays)}"
        val remDaysStr = "${df.format(remLifeDays)}일"
        val remWeekendsStr = "${df.format(remLifeDays / 7L)}회"

        val startYear = Calendar.getInstance().apply { set(nowCal.get(Calendar.YEAR), Calendar.JANUARY, 1, 0, 0, 0) }
        val endYear = Calendar.getInstance().apply { set(nowCal.get(Calendar.YEAR) + 1, Calendar.JANUARY, 1, 0, 0, 0) }
        val yearPct = ((nowCal.timeInMillis - startYear.timeInMillis).toDouble() /
                max(1L, endYear.timeInMillis - startYear.timeInMillis).toDouble() * 100.0).coerceIn(0.0, 100.0)
        val secToday = nowCal.get(Calendar.HOUR_OF_DAY) * 3600 + nowCal.get(Calendar.MINUTE) * 60 + nowCal.get(Calendar.SECOND)
        val todayPct = (secToday / 86400.0 * 100.0).coerceIn(0.0, 100.0)

        var opacity = 0.75f
        var boxColor = 0xFF0A0A0A.toInt()
        var textColor = 0xFFFFFFFF.toInt()
        var accentColor = 0xFFD8C3A5.toInt()
        var home4x1Mode = 0

        val rawStyle = prefs.getString("flutter.widgetStyle", null)
        if (!rawStyle.isNullOrBlank()) {
            try {
                val obj = JSONObject(rawStyle)
                opacity = obj.optDouble("opacity", 0.75).toFloat().coerceIn(0f, 1f)
                boxColor = obj.optLong("boxColor", 0xFF0A0A0AL).toInt()
                textColor = obj.optLong("textColor", 0xFFFFFFFFL).toInt()
                accentColor = obj.optLong("accentColor", 0xFFD8C3A5L).toInt()
                home4x1Mode = obj.optInt("home4x1Mode", 0).coerceIn(0, 2)
            } catch (_: Exception) {}
        }

        val rawGoals = parseFlutterStringList(prefs.getString("flutter.goals", null))
        val parsedGoals = mutableListOf<Triple<String, String, Float>>()
        val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        for (gStr in rawGoals) {
            try {
                val gObj = JSONObject(gStr)
                val title = gObj.optString("title", "나의 목표")
                val dateIso = gObj.optString("date", "").take(10)
                val dt = sdf.parse(dateIso)
                if (dt != null) {
                    val diff = ((dt.time - nowCal.timeInMillis) / 86400000L).toInt()
                    val dday = when {
                        diff > 0 -> "D-$diff"
                        diff == 0 -> "D-DAY"
                        else -> "D+${-diff}"
                    }
                    val prog = if (diff <= 0) 1f else ((365f - diff.coerceIn(0, 365)) / 365f).coerceIn(0.08f, 1f)
                    parsedGoals.add(Triple(title, dday, prog))
                }
            } catch (_: Exception) {}
        }

        val g1 = parsedGoals.getOrNull(0) ?: Triple("D-Day 1 미설정", "—", 0.1f)
        val g2 = parsedGoals.getOrNull(1) ?: Triple("D-Day 2 추가", "—", 0.1f)

        val quote = prefs.getString("flutter.lastQuote", null)
            ?: "기억하라, 너는 언젠가 죽는다. — Memento Mori"

        return WidgetData(
            percent = pct,
            age = age,
            livedLabel = livedLabel,
            remDays = remDaysStr,
            remWeekends = remWeekendsStr,
            yearPct = yearPct,
            todayPct = todayPct,
            quote = quote,
            g1Title = g1.first,
            g1Dday = g1.second,
            g1Progress = g1.third,
            g2Title = g2.first,
            g2Dday = g2.second,
            opacity = opacity,
            boxColor = boxColor,
            textColor = textColor,
            accentColor = accentColor,
            home4x1Mode = home4x1Mode
        )
    }

    private fun withAlpha(color: Int, alphaFraction: Float): Int {
        val a = (alphaFraction.coerceIn(0f, 1f) * 255f).toInt()
        return (color and 0x00FFFFFF) or (a shl 24)
    }

    private fun renderLockBitmap(context: Context): Bitmap {
        val d = loadData(context)
        val w = 960
        val h = 420
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)

        val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = withAlpha(d.boxColor, d.opacity)
            style = Paint.Style.FILL
        }
        val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = withAlpha(d.accentColor, (d.opacity * 0.5f).coerceIn(0.2f, 0.7f))
            style = Paint.Style.STROKE
            strokeWidth = 3f
        }
        val rect = RectF(6f, 6f, w - 6f, h - 6f)
        c.drawRoundRect(rect, 44f, 44f, bgPaint)
        c.drawRoundRect(rect, 44f, 44f, borderPaint)

        val tp = Paint(Paint.ANTI_ALIAS_FLAG)

        // Header
        tp.color = d.textColor
        tp.textSize = 28f
        tp.typeface = Typeface.create(Typeface.DEFAULT, Typeface.NORMAL)
        c.drawText("MEMENTO LOCK", 48f, 64f, tp)

        tp.color = d.accentColor
        tp.textAlign = Paint.Align.RIGHT
        c.drawText("LIFE ${d.livedLabel} · ${d.age}/80세", w - 48f, 64f, tp)
        tp.textAlign = Paint.Align.LEFT

        // Big Percent
        tp.color = d.textColor
        tp.textSize = 96f
        tp.typeface = Typeface.create("sans-serif-light", Typeface.NORMAL)
        val pctStr = String.format(Locale.US, "%.1f", d.percent)
        c.drawText(pctStr, 48f, 196f, tp)
        val pctW = tp.measureText(pctStr)

        tp.color = d.accentColor
        tp.textSize = 38f
        c.drawText("%", 54f + pctW, 192f, tp)

        // Divider
        val divPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = withAlpha(d.textColor, 0.22f)
            strokeWidth = 2f
        }
        c.drawLine(340f, 110f, 340f, 210f, divPaint)

        // Goal 1 & Goal 2
        tp.color = withAlpha(d.textColor, 0.92f)
        tp.textSize = 28f
        c.drawText(d.g1Title.take(10), 375f, 138f, tp)
        c.drawText(d.g2Title.take(10), 665f, 138f, tp)

        tp.color = d.accentColor
        tp.textSize = 52f
        tp.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        c.drawText(d.g1Dday, 375f, 200f, tp)
        c.drawText(d.g2Dday, 665f, 200f, tp)

        // Progress Bar
        val barBg = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = withAlpha(d.textColor, 0.18f) }
        val barFg = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = d.accentColor }
        val barLeft = 48f
        val barRight = w - 48f
        val barTop = 252f
        val barBottom = 266f
        c.drawRoundRect(RectF(barLeft, barTop, barRight, barBottom), 8f, 8f, barBg)
        val fillRight = barLeft + (barRight - barLeft) * (d.percent.toFloat() / 100f)
        c.drawRoundRect(RectF(barLeft, barTop, fillRight, barBottom), 8f, 8f, barFg)

        // Quote at bottom
        tp.color = d.textColor
        tp.textSize = 30f
        tp.typeface = Typeface.create("sans-serif-light", Typeface.NORMAL)
        val q = d.quote
        if (q.length <= 34) {
            c.drawText(q, 48f, 336f, tp)
        } else {
            c.drawText(q.take(34), 48f, 322f, tp)
            c.drawText(q.drop(34).take(36), 48f, 366f, tp)
        }

        return bmp
    }

    private fun renderHome4x1Bitmap(context: Context): Bitmap {
        val d = loadData(context)
        val w = 960
        val h = 230
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)

        val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = withAlpha(d.boxColor, d.opacity)
            style = Paint.Style.FILL
        }
        val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = withAlpha(d.accentColor, (d.opacity * 0.5f).coerceIn(0.2f, 0.7f))
            style = Paint.Style.STROKE
            strokeWidth = 3f
        }
        val rect = RectF(6f, 6f, w - 6f, h - 6f)
        c.drawRoundRect(rect, 44f, 44f, bgPaint)
        c.drawRoundRect(rect, 44f, 44f, borderPaint)

        val tp = Paint(Paint.ANTI_ALIAS_FLAG)

        // Left column: Life % + Bar + LIFE D+
        tp.color = d.textColor
        tp.textSize = 62f
        tp.typeface = Typeface.create("sans-serif-light", Typeface.NORMAL)
        val pctStr = String.format(Locale.US, "%.1f", d.percent)
        c.drawText(pctStr, 42f, 102f, tp)
        val pctW = tp.measureText(pctStr)
        tp.color = d.accentColor
        tp.textSize = 28f
        c.drawText("%", 46f + pctW, 98f, tp)

        val barBg = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = withAlpha(d.textColor, 0.18f) }
        val barFg = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = d.accentColor }
        c.drawRoundRect(RectF(42f, 122f, 270f, 134f), 6f, 6f, barBg)
        c.drawRoundRect(RectF(42f, 122f, 42f + 228f * (d.percent.toFloat() / 100f), 134f), 6f, 6f, barFg)

        tp.color = d.accentColor
        tp.textSize = 26f
        tp.typeface = Typeface.create(Typeface.DEFAULT, Typeface.NORMAL)
        c.drawText("LIFE ${d.livedLabel}", 42f, 178f, tp)

        // Divider
        val divPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = withAlpha(d.textColor, 0.22f)
            strokeWidth = 2f
        }
        c.drawLine(305f, 45f, 305f, h - 45f, divPaint)

        // Center column based on home4x1Mode
        when (d.home4x1Mode) {
            1 -> {
                tp.color = withAlpha(d.textColor, 0.6f)
                tp.textSize = 23f
                c.drawText("REMAINING (80세)", 335f, 75f, tp)
                c.drawText("남은 날", 335f, 120f, tp)
                c.drawText("남은 주말", 510f, 120f, tp)
                tp.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                tp.textSize = 32f
                tp.color = d.textColor
                c.drawText(d.remDays, 335f, 166f, tp)
                tp.color = d.accentColor
                c.drawText(d.remWeekends, 510f, 166f, tp)
            }
            2 -> {
                tp.color = d.textColor
                tp.textSize = 28f
                tp.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                c.drawText("TARGET · ${d.g1Title.take(10)}", 335f, 82f, tp)
                c.drawRoundRect(RectF(335f, 106f, 680f, 120f), 6f, 6f, barBg)
                c.drawRoundRect(RectF(335f, 106f, 335f + 345f * d.g1Progress, 120f), 6f, 6f, barFg)
                tp.color = withAlpha(d.textColor, 0.65f)
                tp.textSize = 25f
                tp.typeface = Typeface.create(Typeface.DEFAULT, Typeface.NORMAL)
                c.drawText("NEXT · ${d.g2Title.take(10)} (${d.g2Dday})", 335f, 168f, tp)
            }
            else -> {
                tp.color = withAlpha(d.textColor, 0.65f)
                tp.textSize = 24f
                c.drawText("${Calendar.getInstance().get(Calendar.YEAR)} YEAR", 335f, 74f, tp)
                tp.color = d.textColor
                c.drawText(String.format(Locale.US, "%.1f%%", d.yearPct), 610f, 74f, tp)
                c.drawRoundRect(RectF(335f, 88f, 680f, 100f), 5f, 5f, barBg)
                c.drawRoundRect(RectF(335f, 88f, 335f + 345f * (d.yearPct.toFloat() / 100f), 100f), 5f, 5f, barFg)

                tp.color = withAlpha(d.textColor, 0.65f)
                c.drawText("TODAY", 335f, 148f, tp)
                tp.color = d.accentColor
                c.drawText(String.format(Locale.US, "%.1f%%", d.todayPct), 610f, 148f, tp)
                val todayFg = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = withAlpha(d.textColor, 0.85f) }
                c.drawRoundRect(RectF(335f, 162f, 680f, 174f), 5f, 5f, barBg)
                c.drawRoundRect(RectF(335f, 162f, 335f + 345f * (d.todayPct.toFloat() / 100f), 174f), 5f, 5f, todayFg)
            }
        }

        // Right column: Featured D-Day
        tp.textAlign = Paint.Align.RIGHT
        tp.color = withAlpha(d.textColor, 0.65f)
        tp.textSize = 26f
        tp.typeface = Typeface.create(Typeface.DEFAULT, Typeface.NORMAL)
        c.drawText(d.g1Title.take(8), w - 42f, 94f, tp)

        tp.color = d.accentColor
        tp.textSize = 56f
        tp.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        c.drawText(d.g1Dday, w - 42f, 162f, tp)

        return bmp
    }
}
