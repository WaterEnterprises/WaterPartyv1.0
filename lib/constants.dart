class AppConstants {
  static const String host = "waterparty.onrender.com";
  static const String apiBase = "https://$host";
  static const String wsBase = "wss://$host/ws";

  // Debugging with local server:
  // static const String host = "localhost:5432";
  // static const String apiBase = "http://$host";
  // static const String wsBase = "ws://$host/ws";

  static String assetUrl(String hash) => "$apiBase/assets/$hash";
}
