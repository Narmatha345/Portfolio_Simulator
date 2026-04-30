import 'package:flutter/material.dart';

class HelpProvider with ChangeNotifier {
  bool _isOpen = false;
  String? _currentTopic;

  bool get isOpen => _isOpen;
  String? get currentTopic => _currentTopic;

  void openHelp(String topic) {
    _currentTopic = topic;
    _isOpen = true;
    // trackHelp(topic); // Analytics tracking
    notifyListeners();
  }

  void closeHelp() {
    _isOpen = false;
    notifyListeners();
  }
}