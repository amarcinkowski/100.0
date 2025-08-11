package com.example.appwidget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import java.util.*

class ClockWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_layout)

            val now = Calendar.getInstance()

            val startToday = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 6)
                set(Calendar.MINUTE, 15)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }

            if (now.before(startToday)) {
                startToday.add(Calendar.DATE, -1)
            }

            val diffMillis = now.timeInMillis - startToday.timeInMillis
            val minutesElapsed = (diffMillis / 60000).toInt()

            val maxMinutes = 1000
            val displayMinutes = if (minutesElapsed in 0..maxMinutes) {
                minutesElapsed
            } else {
                startToday.add(Calendar.DATE, 1)
                val diffNext = startToday.timeInMillis - now.timeInMillis
                val remaining = (diffNext / 60000).toInt()
                if (remaining < 0) 0 else remaining
            }

            views.setTextViewText(R.id.textViewMinutes, String.format("%03d", displayMinutes))
            val progress = if (displayMinutes > maxMinutes) maxMinutes else displayMinutes
            views.setProgressBar(R.id.progressBar, maxMinutes, progress, false)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
