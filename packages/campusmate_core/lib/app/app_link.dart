import 'package:flutter/foundation.dart';

class AppLink {
  AppLink._();

  static final ValueNotifier<String?> todoToOpen = ValueNotifier<String?>(null);
  static final ValueNotifier<int?> tabToOpen = ValueNotifier<int?>(null);

  static void openTodo(String todoId) {
    todoToOpen.value = todoId;
  }

  static void clearTodo() {
    todoToOpen.value = null;
  }

  static void openTab(int tabIndex) {
    tabToOpen.value = tabIndex;
  }

  static void clearTab() {
    tabToOpen.value = null;
  }
}
