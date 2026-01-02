class OneSignalConfig {
  // OneSignal App ID
  static const String appId = 'bfd12a40-5ba4-4141-a98b-26aeb15da005';
  
  // REST API Key - In production, this should be stored securely on your server
  static const String restApiKey = 'os_v2_app_x7isuqc3uraudkmle2xlcxnaawhjdb756qbu6kmdyjy6m5hjsbdbmu5gsqmzuthy7xfgu7koxfz6r2tn4k7mddwylbl5ovswldyt33a';

  // Notification settings
  static const bool requestPermissionOnInit = true;
  static const bool showNotificationWhenAppInForeground = true;
  
  // Notification channels
  static const String chatChannelId = 'chat_notifications';
  static const String orderChannelId = 'order_notifications';
  
  // Notification sounds
  static const String defaultSound = 'notification';
  static const String messageSound = 'message';
  static const String orderSound = 'order';
  
  // Notification categories
  static const String chatCategory = 'chat_messages';
  static const String orderCategory = 'order_updates';
  
  // Notification priority
  static const int highPriority = 10;
  static const int defaultPriority = 5;
  
  // Notification visibility
  static const bool publicVisibility = true;
  
  // Notification timeout (in seconds)
  static const int notificationTimeout = 10;
}