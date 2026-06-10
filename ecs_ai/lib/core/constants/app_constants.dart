/// global constants for the eda canvas and layout
abstract final class AppConstants {
  // -- canvas grid & elements --
  static const double gridSize = 20.0;
  static const double snapThreshold = 10.0;
  static const double dotRadius = 1.0;
  static const double componentStrokeWidth = 2.0;
  static const double pinDotRadius = 2.5;
  static const double selectionPadding = 8.0;

  // -- zoom limits --
  static const double minZoom = 0.1;
  static const double maxZoom = 5.0;
  static const double defaultZoom = 1.0;
  static const double zoomStep = 0.1;

  // -- canvas defaults --
  static const double canvasWidth = 4000.0;
  static const double canvasHeight = 3000.0;

  // -- layout --
  static const double sidebarWidth = 220.0;
  static const double toolbarHeight = 44.0;
  static const double bottomBarHeight = 180.0;
  static const double panelHeaderHeight = 36.0;

  // -- animation --
  static const Duration panelAnimDuration = Duration(milliseconds: 200);
}

/// global configuration for api connections
abstract final class ApiConstants {
  // IMPORTANT: For local development, use localhost.
  static const String baseUrl = 'http://127.0.0.1:8000';
  static const String wsUrl = 'ws://127.0.0.1:8000';

  // static const String baseUrl = 'https://ecs-rapid-agent-hackathon-609652852189.africa-south1.run.app';
  // static const String wsUrl = 'wss://ecs-rapid-agent-hackathon-609652852189.africa-south1.run.app';

  // static const String baseUrl = 'https://ecs-ai-9ywk.onrender.com';
  // static const String wsUrl = 'wss://ecs-ai-9ywk.onrender.com';
}
