package com.campusmate

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
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
            val primaryTodoId = widgetData.getString("widget_todo_primary_id", "") ?: ""
            val primaryTodoTitle = widgetData.getString("widget_todo_primary_title", "") ?: ""
            val icsCount = widgetData.getInt("widget_ics_count", 0)
            val timetableCount = widgetData.getInt("widget_timetable_count", 0)
            val timetableLines = widgetData.getString("widget_timetable_lines", "- No courses yet")
                ?: "- No courses yet"

            val openAppIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java
            )
            views.setOnClickPendingIntent(R.id.widget_root, openAppIntent)

            views.setTextViewText(R.id.widget_date, date)
            views.setTextViewText(R.id.widget_todo_count, "TODO $todoCount")
            views.setTextViewText(R.id.widget_todo_lines, todoLines)
            views.setTextViewText(R.id.widget_timetable_count, "TIMETABLE $timetableCount")
            views.setTextViewText(R.id.widget_timetable_lines, timetableLines)
            views.setTextViewText(R.id.widget_ics_count, "School events $icsCount")

            if (primaryTodoId.isNotBlank()) {
                val title = if (primaryTodoTitle.isBlank()) "Top task" else primaryTodoTitle
                val shortTitle = if (title.length > 18) "${title.take(18)}..." else title
                views.setTextViewText(R.id.widget_complete_action, "Complete: $shortTitle")
                views.setViewVisibility(R.id.widget_complete_action, View.VISIBLE)

                val actionUri = Uri.parse(
                    "campusmate://todo/complete?id=${Uri.encode(primaryTodoId)}"
                )
                val completeIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    actionUri
                )
                views.setOnClickPendingIntent(R.id.widget_complete_action, completeIntent)
            } else {
                views.setViewVisibility(R.id.widget_complete_action, View.GONE)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}


