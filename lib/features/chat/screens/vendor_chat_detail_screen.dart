import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:quick_bundles_flutter/services/fcm_v1_service.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../services/notification_service.dart';

class VendorChatDetailScreen extends StatefulWidget {
  final String chatId;
  final String buyerId;
  final String buyerName;
  final String bundleId;

  const VendorChatDetailScreen({
    Key? key,
    required this.chatId,
    required this.buyerId,
    required this.buyerName,
    required this.bundleId,
  }) : super(key: key);

  @override
  State<VendorChatDetailScreen> createState() => _VendorChatDetailScreenState();
}

class _VendorChatDetailScreenState extends State<VendorChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;
  String orderStatus = 'pending';
  Map<String, dynamic>? bundleInfo;
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  String? activeOrderId;
  String? _lastNotifiedMessageId; // Track last notified message

  @override
  void initState() {
    super.initState();
    _loadChatAndBundle();
    _markMessagesAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadChatAndBundle() async {
    final chatDoc = await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).get();
    if (chatDoc.exists) {
      setState(() {
        orderStatus = chatDoc['status'] ?? 'pending';
        activeOrderId = chatDoc['activeOrderId'];
      });
      // Load bundle info
      final bundleId = chatDoc['bundleId'];
      if (bundleId != null) {
        final bundleSnap = await FirebaseFirestore.instance.collection('listings').doc(bundleId).get();
        if (bundleSnap.exists) {
          setState(() {
            bundleInfo = bundleSnap.data();
          });
        }
      }
    }
  }

  Future<void> _markMessagesAsRead() async {
    final unread = await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .where('senderId', isEqualTo: widget.buyerId)
        .get();
    for (var doc in unread.docs) {
      doc.reference.update({'isRead': true});
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'data_sent':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    if ((_messageController.text.trim().isEmpty && _imageFile == null) || _isSending) return;
    
    setState(() => _isSending = true);
    
    // Get message data before clearing the controller
    final messageText = _messageController.text.trim();
    final imageToSend = _imageFile;
    
    // Clear UI immediately for better UX
    _messageController.clear();
    setState(() => _imageFile = null);
    
    try {
      String? imageUrl;
      
      if (imageToSend != null) {
        // Upload image to Firebase Storage
        final fileName = 'chat_images/${DateTime.now().millisecondsSinceEpoch}_${user!.uid}.jpg';
        final ref = FirebaseStorage.instance.ref().child(fileName);
        await ref.putFile(imageToSend);
        imageUrl = await ref.getDownloadURL();
      }
      
      // Add message to subcollection
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
        'senderId': user!.uid,
        'text': messageText,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'imageUrl': imageUrl,
      });
      
      // Update chat document with last message info
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .update({
        'lastMessage': imageUrl != null ? '📷 Image' : messageText,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Send notification to buyer if not sending to self
      if (user!.uid != widget.buyerId) {
        try {
          // Get buyer's FCM token from Firestore
          final buyerDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.buyerId)
              .get();
              
          final buyerFcmToken = buyerDoc.data()?['fcmToken'];
          final buyerName = buyerDoc.data()?['name'] ?? 'Buyer';
          final bundleName = bundleInfo?['description'] ?? 'Bundle';
          
          if (buyerFcmToken != null && buyerFcmToken is String) {
            // Send enhanced FCM v1 push notification with sound and category
            await FCMV1Service().sendMessage(
              token: buyerFcmToken,
              title: 'New message from ${user!.displayName ?? 'Vendor'}' ,
              body: imageUrl != null ? '📷 Image' : messageText,
              sound: 'default',
              category: 'MESSAGE_CATEGORY',
              clickAction: 'FLUTTER_NOTIFICATION_CLICK',
              data: {
                'type': 'chat',
                'chatId': widget.chatId,
                'bundleId': widget.bundleId,
                'senderId': user!.uid,
                'senderName': user!.displayName ?? 'Vendor',
                'bundleName': bundleName,
                'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              },
            );
            debugPrint('FCM notification sent to buyer');
            
            // Also show local notification for in-app notification
            if (mounted) {
              await NotificationService().showLocalChatNotification(
                title: 'New message from ${user!.displayName ?? 'Vendor'}' ,
                body: imageUrl != null ? '📷 Image' : messageText,
                payload: 'chat_${widget.chatId}_${widget.bundleId}',
              );
            }
          } else {
            debugPrint('Buyer FCM token not found');
          }
        } catch (e, stack) {
          debugPrint('Error sending FCM notification: $e');
          debugPrint('Stack trace: $stack');
          // Don't fail the message send if notification fails
        }
      }
      
      // Scroll to bottom after sending
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
      _scrollToBottom();
        }
      });
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message. Please try again.')),
      );
      }
    } finally {
      if (mounted) {
      setState(() => _isSending = false);
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked != null) {
        setState(() => _imageFile = File(picked.path));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  Future<void> _updateStatus(String status) async {
    if (activeOrderId == null) return;
    
    final batch = FirebaseFirestore.instance.batch();
    final now = FieldValue.serverTimestamp();
    
    // Update transaction status
    final txRef = FirebaseFirestore.instance.collection('transactions').doc(activeOrderId);
    batch.update(txRef, {
      'status': status,
      'updatedAt': now,
    });
    
    // Update chat status
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
    batch.update(chatRef, {
      'status': status,
      'updatedAt': now,
    });
    
    try {
      await batch.commit();
    setState(() {
      orderStatus = status;
    });
    } catch (e) {
      debugPrint('Error updating status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update status. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat with ${widget.buyerName}'),
      ),
      body: Column(
        children: [
          // Bundle info and order status (from chat document)
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (bundleInfo != null) ...[
                    Text(
                      '${bundleInfo!['dataAmount']}GB ${bundleInfo!['provider'] ?? ''} - GHS${bundleInfo!['price']?.toStringAsFixed(2) ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(bundleInfo!['description'] ?? ''),
                    const SizedBox(height: 4),
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('chats').doc(widget.chatId).get(),
                      builder: (context, chatSnap) {
                        if (!chatSnap.hasData || !chatSnap.data!.exists) return const SizedBox();
                        final data = chatSnap.data!.data() as Map<String, dynamic>?;
                        final recipient = data?['recipientNumber'] ?? '';
                        return recipient.isNotEmpty
                          ? Text('Recipient: $recipient', style: const TextStyle(fontWeight: FontWeight.bold))
                          : const SizedBox();
                      },
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Order status from chat document
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('chats').doc(widget.chatId).snapshots(),
                    builder: (context, chatSnap) {
                      if (!chatSnap.hasData || !chatSnap.data!.exists) {
                        return const SizedBox();
                      }
                      final chatData = chatSnap.data!.data() as Map<String, dynamic>?;
                      String chatStatus = chatData?['status'] ?? 'pending';
                      return Row(
                    children: [
                      const Text('Order Status: '),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                              color: _statusColor(chatStatus),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                              chatStatus.replaceAll('_', ' ').toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                            value: chatStatus,
                        items: const [
                          DropdownMenuItem(value: 'pending', child: Text('Pending')),
                          DropdownMenuItem(value: 'processing', child: Text('Processing')),
                          DropdownMenuItem(value: 'data_sent', child: Text('Data Sent')),
                              // No 'completed' option for vendor
                        ],
                            onChanged: (val) async {
                              if (val != null) {
                                try {
                                final batch = FirebaseFirestore.instance.batch();
                                final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
                                final now = FieldValue.serverTimestamp();
                                  final chatDoc = await chatRef.get();
                                  final chatData = chatDoc.data() as Map<String, dynamic>?;
                                
                                // Update chat status
                                batch.update(chatRef, {
                                  'status': val,
                                  'updatedAt': now,
                                });
                                
                                  // Only create/update transaction when marking as completed
                                  if (val == 'completed' && chatData != null) {
                                    final txRef = FirebaseFirestore.instance.collection('transactions').doc();
                                    final txId = txRef.id;
                                    
                                    // Create the transaction document
                                    batch.set(txRef, {
                                      'id': txId,
                                      'userId': widget.buyerId,
                                      'vendorId': user!.uid,
                                      'type': 'bundle_purchase',
                                      'amount': bundleInfo?['price'] ?? 0,
                                      'status': 'completed',
                                      'bundleId': widget.bundleId,
                                      'provider': bundleInfo?['provider']?.toString().split('.').last ?? 'unknown',
                                      'dataAmount': bundleInfo?['dataAmount'] ?? 0,
                                      'recipientNumber': chatData['recipientNumber'] ?? '',
                                      'createdAt': now,
                                    'updatedAt': now,
                                      'completedBy': user!.uid,
                                      'completedAt': now,
                                    });
                                    
                                    // Update chat with the new transaction ID
                                    batch.update(chatRef, {
                                      'activeOrderId': txId,
                                    });
                                    
                                    // Update local state
                                    if (mounted) {
                                      setState(() {
                                        activeOrderId = txId;
                                      });
                                    }
                                }
                                
                                await batch.commit();
                                  
                                  // Update local state
                                  if (mounted) {
                                    setState(() {
                                      orderStatus = val;
                                    });
                                  }
                                } catch (e) {
                                  debugPrint('Error updating status: $e');
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Failed to update status. Please try again.')),
                                    );
                                  }
                                }
                              }
                        },
                      ),
                    ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          // Chat messages
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  _markMessagesAsRead();
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data!.docs;
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                // Note: Push notifications are now handled by FCM service
                // Local notifications removed to prevent duplicates
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index].data() as Map<String, dynamic>;
                    final isMe = msg['senderId'] == user!.uid;
                    final timestamp = msg['timestamp'] != null ? (msg['timestamp'] as Timestamp).toDate() : null;
                    final timeString = timestamp != null ? TimeOfDay.fromDateTime(timestamp).format(context) : '';
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.green[100] : Colors.grey[200],
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isMe ? 16 : 4),
                            bottomRight: Radius.circular(isMe ? 4 : 16),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (msg['imageUrl'] != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    msg['imageUrl'],
                                    width: 180,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => const Icon(Icons.broken_image),
                                  ),
                                ),
                              ),
                            if ((msg['text'] ?? '').isNotEmpty)
                              Text(
                                msg['text'],
                                style: const TextStyle(fontSize: 15),
                                softWrap: true,
                              ),
                            const SizedBox(height: 4),
                            if (timeString.isNotEmpty)
                              Text(
                                timeString,
                                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Message input
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message... 😊',
                        border: OutlineInputBorder(),
                      ),
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      keyboardType: TextInputType.multiline,
                      enableSuggestions: true,
                    ),
                  ),
                  if (_imageFile != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Stack(
                        alignment: Alignment.topRight,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(_imageFile!, width: 48, height: 48, fit: BoxFit.cover),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _imageFile = null),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.attach_file),
                    onPressed: _pickImage,
                  ),
                  IconButton(
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    onPressed: _isSending ? null : _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 