package com.example.mobile

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class TodayWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.today_widget_layout)

            val date = widgetData.getString("widget_date", "Today") ?: "Today"
            val todoCount = widgetData.getInt("widget_todo_count", 0)
            val todoLines = widgetData.getString("widget_todo_lines", "- No urgent todos")
                ?: "- No urgent todos"
            val icsCount = widgetData.getInt("widget_ics_count", 0)

            views.setTextViewText(R.id.widget_date, date)
            views.setTextViewText(R.id.widget_todo_count, "TODO $todoCount")
            views.setTextViewText(R.id.widget_todo_lines, todoLines)
            views.setTextViewText(R.id.widget_ics_count, "School events $icsCount")

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
