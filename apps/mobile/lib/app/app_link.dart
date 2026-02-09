import 'package:flutter/foundation.dart';

class AppLink {
  AppLink._();

  static final ValueNotifier<String?> todoToOpen = ValueNotifier<String?>(null);

  static void openTodo(String todoId) {
    todoToOpen.value = todoId;
  }

  static void clearTodo() {
    todoToOpen.value = null;
  }
}
