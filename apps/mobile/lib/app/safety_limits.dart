class SafetyLimits {
  SafetyLimits._();

  // Prevent unbounded growth of active due todos for one day.
  static const int maxActiveTodosPerDay = 120;
  static const int maxTodoTitleChars = 180;
  static const int maxCourseNameChars = 80;
  static const int maxCourses = 500;
  static const int maxMaterialsPerCourse = 300;

  // Keep calendar rendering stable even with large feeds.
  static const int maxCalendarItemsPerDay = 200;
  static const int maxCalendarMarkerItemsPerDay = 8;

  // Guardrails for remote ICS payloads.
  static const int maxIcsPayloadBytes = 4 * 1024 * 1024;
  static const int maxIcsEvents = 6000;

  // File import/export safety.
  static const int maxTimetableImageBytes = 12 * 1024 * 1024;
  static const int maxCoursePdfBytes = 40 * 1024 * 1024;
  static const int maxUndoPdfBytes = 8 * 1024 * 1024;
  static const int maxBackupFileBytes = 80 * 1024 * 1024;
  static const int maxBackupMaterialFileBytes = 32 * 1024 * 1024;

  // Restore safety to avoid pathological payloads.
  static const int maxBackupTodos = 20000;
  static const int maxBackupCourses = 4000;
  static const int maxBackupMaterials = 5000;
  static const int maxBackupHistoryEntries = 20000;

  // PDF memo safety.
  static const int maxPageMemosPerMaterial = 5000;
  static const int maxPageMemoTextChars = 4000;
  static const int maxPageMemoTagChars = 48;
  static const int maxPageMemoPayloadChars = 2 * 1024 * 1024;
  static const int maxOverallNoteChars = 20000;
  static const int maxTagsPerPageMemo = 20;
}
