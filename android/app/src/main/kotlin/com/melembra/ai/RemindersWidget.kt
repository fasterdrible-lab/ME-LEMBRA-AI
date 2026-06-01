package com.melembra.ai

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class RemindersWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            update(context, appWidgetManager, id)
        }
    }

    companion object {

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, RemindersWidget::class.java)
            )
            if (ids.isEmpty()) return
            for (id in ids) update(context, manager, id)
        }

        fun update(context: Context, manager: AppWidgetManager, widgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.widget_reminders)

            // Data formatada em pt-BR
            val sdf = SimpleDateFormat("EEE, d MMM", Locale("pt", "BR"))
            views.setTextViewText(R.id.wgt_date, sdf.format(Date()))

            // Toque no widget abre o app
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context, 0, launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.wgt_container, pendingIntent)

            // Lê lembretes do SharedPreferences (escritos pelo Flutter)
            val prefs = context.getSharedPreferences(
                "FlutterSharedPreferences", Context.MODE_PRIVATE
            )
            val json = prefs.getString("flutter.widget_reminders", null)
            val reminders = parseReminders(json)

            // IDs das linhas
            val rowIds    = intArrayOf(R.id.wgt_row1,   R.id.wgt_row2,   R.id.wgt_row3)
            val titleIds  = intArrayOf(R.id.wgt_title1, R.id.wgt_title2, R.id.wgt_title3)
            val timeIds   = intArrayOf(R.id.wgt_time1,  R.id.wgt_time2,  R.id.wgt_time3)
            val dotIds    = intArrayOf(R.id.wgt_dot1,   R.id.wgt_dot2,   R.id.wgt_dot3)

            for (i in rowIds.indices) {
                if (i < reminders.size) {
                    val r = reminders[i]
                    views.setViewVisibility(rowIds[i], View.VISIBLE)
                    views.setTextViewText(titleIds[i], r.title)
                    views.setTextViewText(timeIds[i], r.time)

                    val titleColor = if (r.confirmed) Color.parseColor("#2E7D32")
                                     else Color.parseColor("#1C1C1E")
                    val dotColor   = if (r.confirmed) Color.parseColor("#50C878")
                                     else Color.parseColor("#7B5EA7")
                    views.setTextColor(titleIds[i], titleColor)
                    views.setTextColor(dotIds[i],   dotColor)
                } else {
                    views.setViewVisibility(rowIds[i], View.GONE)
                }
            }

            // "+N mais" quando há mais de 3 lembretes
            val extra = reminders.size - 3
            if (extra > 0) {
                views.setViewVisibility(R.id.wgt_more, View.VISIBLE)
                views.setTextViewText(R.id.wgt_more, "+ $extra mais")
            } else {
                views.setViewVisibility(R.id.wgt_more, View.GONE)
            }

            // Estado vazio
            views.setViewVisibility(
                R.id.wgt_empty,
                if (reminders.isEmpty()) View.VISIBLE else View.GONE
            )

            manager.updateAppWidget(widgetId, views)
        }

        // -------------------------------------------------------

        private data class ReminderItem(
            val title: String,
            val time: String,
            val confirmed: Boolean
        )

        private fun parseReminders(json: String?): List<ReminderItem> {
            if (json.isNullOrBlank()) return emptyList()
            return try {
                val arr = JSONArray(json)
                List(arr.length()) { i ->
                    val obj = arr.getJSONObject(i)
                    ReminderItem(
                        title     = obj.optString("title", ""),
                        time      = obj.optString("time", ""),
                        confirmed = obj.optBoolean("confirmed", false)
                    )
                }
            } catch (_: Exception) {
                emptyList()
            }
        }
    }
}
