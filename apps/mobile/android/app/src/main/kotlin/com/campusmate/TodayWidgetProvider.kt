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
    private fun navIntent(context: Context, target: String) =
        HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("campusmate://nav/tab?target=$target")
        )

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.today_widget_layout)

            val localeCode = widgetData.getString("widget_locale_code", "ko") ?: "ko"
            val isEnglish = localeCode.startsWith("en", ignoreCase = true)
            val date = widgetData.getString("widget_date", null)?.takeIf { it.isNotBlank() }
                ?: if (isEnglish) "Today" else "오늘"
            val todoCount = widgetData.getInt("widget_todo_count", 0)
            val todoLinesRaw = widgetData.getString("widget_todo_lines", "") ?: ""
            val todoLines = todoLinesRaw.ifBlank {
                if (isEnglish) "- No urgent todos" else "- 급한 할 일이 없습니다"
            }
            val primaryTodoId = widgetData.getString("widget_todo_primary_id", "") ?: ""
            val primaryTodoTitle = widgetData.getString("widget_todo_primary_title", "") ?: ""
            val icsCount = widgetData.getInt("widget_ics_count", 0)
            val timetableCount = widgetData.getInt("widget_timetable_count", 0)
            val timetableLinesRaw = widgetData.getString("widget_timetable_lines", "") ?: ""
            val timetableLines = timetableLinesRaw.ifBlank {
                if (isEnglish) "- No courses yet" else "- 등록된 강의가 없습니다"
            }

            val openAppIntent = navIntent(context, "home")
            views.setOnClickPendingIntent(R.id.widget_root, openAppIntent)
            views.setOnClickPendingIntent(R.id.widget_todo_section, navIntent(context, "todo"))
            views.setOnClickPendingIntent(R.id.widget_timetable_section, navIntent(context, "timetable"))
            views.setOnClickPendingIntent(R.id.widget_ics_count, navIntent(context, "calendar"))

            views.setTextViewText(R.id.widget_date, date)
            views.setTextViewText(
                R.id.widget_todo_count,
                "${if (isEnglish) "TODO" else "할 일"} $todoCount"
            )
            views.setTextViewText(R.id.widget_todo_lines, todoLines)
            views.setTextViewText(
                R.id.widget_timetable_count,
                "${if (isEnglish) "TIMETABLE" else "시간표"} $timetableCount"
            )
            views.setTextViewText(R.id.widget_timetable_lines, timetableLines)
            views.setTextViewText(
                R.id.widget_ics_count,
                "${if (isEnglish) "School events" else "학교 일정"} $icsCount"
            )

            if (primaryTodoId.isNotBlank()) {
                val title = if (primaryTodoTitle.isBlank()) {
                    if (isEnglish) "Top task" else "가장 급한 할 일"
                } else primaryTodoTitle
                val shortTitle = if (title.length > 18) "${title.take(18)}..." else title
                views.setTextViewText(
                    R.id.widget_complete_action,
                    if (isEnglish) "Complete: $shortTitle" else "완료: $shortTitle"
                )
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


