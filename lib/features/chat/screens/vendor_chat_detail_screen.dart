import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:quick_bundles_flutter/services/fcm_v1_service.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
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
    final currentUserId = user?.uid;
    if (currentUserId == null) return;

    final messagesQuery = await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .where('senderId', isEqualTo: widget.buyerId) // unread messages from buyer
        .get();

    if (messagesQuery.docs.isEmpty) {
      // Still ensure unread counter is zeroed in case it was left stale
      await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
        'unreadCount_${currentUserId}': 0,
        'lastMessageRead_${currentUserId}': FieldValue.serverTimestamp(),
      });
      return;
    }

    final batch = FirebaseFirestore.instance.batch();
    for (var doc in messagesQuery.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
    batch.update(chatRef, {
      'unreadCount_${currentUserId}': 0,
      'lastMessageRead_${currentUserId}': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'data_sent':
        return Colors.green;
      case 'completed':
        return Colors.grey;
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
      
      // Update chat document with last message info and increment unread count for buyer
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
        final chatDoc = await transaction.get(chatRef);
        
        if (!chatDoc.exists) return;
        
        final currentUnread = chatDoc.data()?['unreadCount_${widget.buyerId}'] ?? 0;
        
        transaction.update(chatRef, {
          'lastMessage': imageUrl != null ? '📷 Image' : messageText,
          'lastMessageTime': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'unreadCount_${widget.buyerId}': FieldValue.increment(1), // Increment buyer's unread count
          'lastMessageSenderId': user!.uid, // Track who sent the last message
        });
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
          // Also try OneSignal via NotificationService for better reliability
          await NotificationService().sendChatNotification(
            recipientUserId: widget.buyerId,
            senderName: user!.displayName ?? 'Vendor',
            message: imageUrl != null ? '📷 Image' : messageText,
            chatId: widget.chatId,
            bundleId: widget.bundleId,
          );
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
                          ? Row(
                              children: [
                                const Icon(Icons.phone_iphone, size: 16, color: Colors.blueGrey),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Recipient: $recipient',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Copy number',
                                  icon: const Icon(Icons.copy, size: 18),
                                  onPressed: () async {
                                    await Clipboard.setData(ClipboardData(text: recipient));
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Recipient number copied')),
                                      );
                                    }
                                  },
                                ),
                              ],
                            )
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
                      final vendorId = chatData?['vendorId'] as String?;
                      final isVendor = user != null && vendorId != null && user!.uid == vendorId;
                      
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
                      // Only show dropdown if user is the vendor, otherwise show read-only status
                      if (isVendor)
                        (chatStatus == 'completed'
                          ? Chip(
                              label: const Text('COMPLETED'),
                              backgroundColor: Colors.grey,
                              labelStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : DropdownButton<String>(
                            value: chatStatus,
                        items: const [
                          DropdownMenuItem(value: 'pending', child: Text('Pending')),
                          DropdownMenuItem(value: 'processing', child: Text('Processing')),
                          DropdownMenuItem(value: 'data_sent', child: Text('Data Sent')),
                        ],
                            onChanged: (val) async {
                              if (val != null && user != null) {
                                try {
                                  // Verify user is still the vendor
                                  final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
                                  final chatDoc = await chatRef.get();
                                  
                                  if (!chatDoc.exists) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Chat document not found.')),
                                      );
                                    }
                                    return;
                                  }
                                  
                                  final currentChatData = chatDoc.data() as Map<String, dynamic>?;
                                  final currentVendorId = currentChatData?['vendorId'];
                                  final currentBuyerId = currentChatData?['buyerId'];
                                  
                                  debugPrint('Chat Status Update - Chat ID: ${widget.chatId}');
                                  debugPrint('Current User UID: ${user!.uid}');
                                  debugPrint('Chat vendorId: $currentVendorId (type: ${currentVendorId.runtimeType})');
                                  debugPrint('Chat buyerId: $currentBuyerId (type: ${currentBuyerId.runtimeType})');
                                  
                                  // Check if vendorId is a valid string and matches
                                  if (currentVendorId == null || currentVendorId.toString().isEmpty) {
                                    debugPrint('ERROR: vendorId is null or empty in chat document');
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Chat is missing vendor information. Cannot update status.')),
                                      );
                                    }
                                    return;
                                  }
                                  
                                  if (currentVendorId.toString() != user!.uid) {
                                    debugPrint('ERROR: vendorId mismatch - Chat vendorId: $currentVendorId, Current user: ${user!.uid}');
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('You are not authorized to update this chat status.')),
                                      );
                                    }
                                    return;
                                  }
                                  
                                  debugPrint('Vendor verification passed. Proceeding with status update...');
                                  
                                  final batch = FirebaseFirestore.instance.batch();
                                  final now = FieldValue.serverTimestamp();
                                    
                                  // Update chat status (pending, processing, or data_sent)
                                  batch.update(chatRef, {
                                    'status': val,
                                    'updatedAt': now,
                                  });
                                  
                                  // If transaction exists, also update transaction status
                                  if (activeOrderId != null && activeOrderId!.isNotEmpty) {
                                    try {
                                      final txRef = FirebaseFirestore.instance.collection('transactions').doc(activeOrderId);
                                      final txDoc = await txRef.get();
                                      if (txDoc.exists) {
                                        batch.update(txRef, {
                                          'status': val,
                                          'updatedAt': now,
                                        });
                                      }
                                    } catch (e) {
                                      debugPrint('Error checking transaction: $e');
                                      // Continue with chat update even if transaction check fails
                                    }
                                  }
                                
                                await batch.commit();
                                  
                                  // Update local state
                                  if (mounted) {
                                    setState(() {
                                      orderStatus = val;
                                    });
                                  }
                                } catch (e, stackTrace) {
                                  debugPrint('Error updating status: $e');
                                  debugPrint('Stack trace: $stackTrace');
                                  String errorMessage = 'Failed to update status. Please try again.';
                                  
                                  final errorStr = e.toString().toLowerCase();
                                  if (errorStr.contains('permission_denied') || errorStr.contains('permission-denied')) {
                                    errorMessage = 'Permission denied. Verify you are the vendor for this chat.\n'
                                        'Chat ID: ${widget.chatId}\n'
                                        'Your UID: ${user!.uid}';
                                    debugPrint('PERMISSION DENIED - Chat vendorId may not match current user UID');
                                  } else if (errorStr.contains('not-found')) {
                                    errorMessage = 'Chat or transaction document not found.';
                                  } else {
                                    errorMessage = 'Error: ${e.toString()}';
                                  }
                                  
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(errorMessage),
                                        duration: const Duration(seconds: 5),
                                      ),
                                    );
                                  }
                                }
                              }
                        },
                      )),
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
                final maxBubbleWidth = MediaQuery.sizeOf(context).width * 0.75;
                // Note: Push notifications are now handled by FCM service
                // Local notifications removed to prevent duplicates
                return ListView.builder(
                  key: PageStorageKey<String>('vendor_chat_messages_${widget.chatId}'),
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index].data() as Map<String, dynamic>;
                    final isMe = msg['senderId'] == user!.uid;
                    final timestamp = msg['timestamp'] != null ? (msg['timestamp'] as Timestamp).toDate() : null;
                    final timeString = timestamp != null ? TimeOfDay.fromDateTime(timestamp).format(context) : '';
                    return _VendorChatMessageBubble(
                      key: ValueKey(messages[index].id),
                      isMe: isMe,
                      text: (msg['text'] ?? '').toString(),
                      imageUrl: msg['imageUrl']?.toString(),
                      timeString: timeString,
                      maxBubbleWidth: maxBubbleWidth,
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

class _VendorChatMessageBubble extends StatelessWidget {
  const _VendorChatMessageBubble({
    super.key,
    required this.isMe,
    required this.text,
    required this.imageUrl,
    required this.timeString,
    required this.maxBubbleWidth,
  });

  static const EdgeInsets _margin = EdgeInsets.symmetric(vertical: 4, horizontal: 2);
  static const EdgeInsets _padding = EdgeInsets.symmetric(horizontal: 14, vertical: 10);
  static const EdgeInsets _imagePadding = EdgeInsets.only(bottom: 6);
  static const double _imageWidth = 180;

  final bool isMe;
  final String text;
  final String? imageUrl;
  final String timeString;
  final double maxBubbleWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: _margin,
        padding: _padding,
        constraints: BoxConstraints(maxWidth: maxBubbleWidth),
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
            if (imageUrl != null)
              Padding(
                padding: _imagePadding,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl!,
                    width: _imageWidth,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => const Icon(Icons.broken_image),
                  ),
                ),
              ),
            if (text.isNotEmpty)
              Text(
                text,
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
  }
}