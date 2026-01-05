import 'package:flutter/material.dart';
import '../../../services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _chatNotifications = true;
  bool _orderNotifications = true;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreferences();
  }

  Future<void> _loadNotificationPreferences() async {
    try {
      final preferences = await NotificationService().getNotificationPreferences();
      setState(() {
        _chatNotifications = preferences['chatNotifications'] ?? true;
        _orderNotifications = preferences['orderNotifications'] ?? true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load notification preferences: $e')),
        );
      }
    }
  }

  Future<void> _saveNotificationPreferences() async {
    setState(() {
      _isSaving = true;
    });

    try {
      await NotificationService().updateNotificationPreferences(
        chatNotifications: _chatNotifications,
        orderNotifications: _orderNotifications,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification preferences saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save notification preferences: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Push Notifications',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose which notifications you want to receive',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Chat Notifications
                  Card(
                    elevation: 2,
                    child: SwitchListTile(
                      title: const Text(
                        'Chat Messages',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: const Text(
                        'Get notified when you receive new messages from vendors or buyers',
                        style: TextStyle(fontSize: 14),
                      ),
                      value: _chatNotifications,
                      onChanged: (value) {
                        setState(() {
                          _chatNotifications = value;
                        });
                        _saveNotificationPreferences();
                      },
                      secondary: const Icon(
                        Icons.chat_bubble_outline,
                        color: Colors.green,
                        size: 28,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Order Notifications
                  Card(
                    elevation: 2,
                    child: SwitchListTile(
                      title: const Text(
                        'Order Updates',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: const Text(
                        'Get notified about order status changes and updates',
                        style: TextStyle(fontSize: 14),
                      ),
                      value: _orderNotifications,
                      onChanged: (value) {
                        setState(() {
                          _orderNotifications = value;
                        });
                        _saveNotificationPreferences();
                      },
                      secondary: const Icon(
                        Icons.shopping_bag_outlined,
                        color: Colors.blue,
                        size: 28,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Information Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Notification Information',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '• Chat notifications will alert you when you receive new messages\n'
                          '• Order notifications will keep you updated on your bundle orders\n'
                          '• You can change these settings at any time\n'
                          '• Notifications work even when the app is closed',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Save Button
                  if (_isSaving)
                    const Center(
                      child: CircularProgressIndicator(),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveNotificationPreferences,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Save Preferences',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
} 