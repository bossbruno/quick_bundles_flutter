import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:quick_bundles_flutter/services/fcm_v1_service.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import '../../../services/notification_service.dart';
import '../../../../core/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

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
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Chat with ${widget.buyerName}',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
      ),
      body: Column(
        children: [
          // Order Info Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (bundleInfo != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${bundleInfo!['dataAmount']}GB ${bundleInfo!['provider'] ?? ''}',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              'GHS ${bundleInfo!['price']?.toStringAsFixed(2) ?? ''}',
                              style: GoogleFonts.poppins(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildStatusBadge(orderStatus),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('chats').doc(widget.chatId).snapshots(),
                    builder: (context, chatSnap) {
                      if (!chatSnap.hasData || !chatSnap.data!.exists) return const SizedBox();
                      final data = chatSnap.data!.data() as Map<String, dynamic>?;
                      final recipient = data?['recipientNumber'] ?? '';
                      final currentStatus = data?['status'] ?? 'pending';
                      
                      return Column(
                        children: [
                          if (recipient.isNotEmpty)
                            Row(
                              children: [
                                Icon(Icons.phone_android, size: 16, color: AppTheme.textSecondary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    recipient,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                  icon: Icon(Icons.copy, size: 18, color: AppTheme.primary),
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
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                'Update Status: ',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: currentStatus == 'completed'
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'ORDER COMPLETED',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.grey.shade200),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: currentStatus,
                                            isExpanded: true,
                                            icon: Icon(Icons.arrow_drop_down, color: AppTheme.primary),
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              color: AppTheme.textPrimary,
                                            ),
                                            items: const [
                                              DropdownMenuItem(value: 'pending', child: Text('Pending')),
                                              DropdownMenuItem(value: 'processing', child: Text('Processing')),
                                              DropdownMenuItem(value: 'data_sent', child: Text('Data Sent')),
                                            ],
                                            onChanged: (val) => _handleStatusUpdate(val),
                                          ),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ],
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
                    );
                  },
                );
              },
            ),
          ),
          
          // Message input
          Container(
            padding: EdgeInsets.only(
              left: 16, 
              right: 16, 
              top: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                )
              ],
            ),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.image_outlined, color: AppTheme.primary),
                    onPressed: _pickImage,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _messageController,
                      style: GoogleFonts.poppins(),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    onPressed: _isSending ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _statusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _statusColor(status).withOpacity(0.2)),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: GoogleFonts.poppins(
          color: _statusColor(status),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Future<void> _handleStatusUpdate(String? val) async {
    if (val != null && user != null) {
      try {
        final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
        final batch = FirebaseFirestore.instance.batch();
        final now = FieldValue.serverTimestamp();
          
        batch.update(chatRef, {
          'status': val,
          'updatedAt': now,
        });
        
        if (activeOrderId != null && activeOrderId!.isNotEmpty) {
          final txRef = FirebaseFirestore.instance.collection('transactions').doc(activeOrderId);
          batch.update(txRef, {
            'status': val,
            'updatedAt': now,
          });
        }
        
        await batch.commit();
        if (mounted) {
          setState(() {
            orderStatus = val;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Status updated to ${val.replaceAll('_', ' ')}')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating status: $e')),
          );
        }
      }
    }
  }
}

class _VendorChatMessageBubble extends StatelessWidget {
  const _VendorChatMessageBubble({
    super.key,
    required this.isMe,
    required this.text,
    required this.imageUrl,
    required this.timeString,
  });

  final bool isMe;
  final String text;
  final String? imageUrl;
  final String timeString;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          gradient: isMe ? const LinearGradient(
            colors: [AppTheme.primary, AppTheme.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ) : null,
          color: isMe ? null : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl!,
                    width: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => const Icon(Icons.broken_image, color: Colors.white70),
                  ),
                ),
              ),
            if (text.isNotEmpty)
              Text(
                text,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: isMe ? Colors.white : AppTheme.textPrimary,
                ),
                softWrap: true,
              ),
            const SizedBox(height: 4),
            if (timeString.isNotEmpty)
              Text(
                timeString,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: isMe ? Colors.white.withOpacity(0.7) : AppTheme.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}