import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../listings/models/bundle_listing_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:quick_bundles_flutter/services/fcm_v1_service.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../services/notification_service.dart';
import '../../../services/database_service.dart';

class ChatScreen extends StatefulWidget {
  final String? chatId;
  final String vendorId;
  final String bundleId;
  final String businessName;
  final String recipientNumber;

  const ChatScreen({
    Key? key,
    this.chatId,
    required this.vendorId,
    required this.bundleId,
    required this.businessName,
    required this.recipientNumber,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  BundleListing? _bundle;
  bool _loading = true;
  String? chatId;
  String? activeOrderId;
  String orderStatus = 'pending';
  final TextEditingController _messageController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  String? _lastNotifiedMessageId; // Track last notified message

  @override
  void initState() {
    super.initState();
      chatId = widget.chatId;
    _fetchBundleAndChat();
    if (chatId == null || chatId!.isEmpty) {
      _initChat();
    } else {
      _loadExistingChat();
    }
  }

  Future<void> _fetchBundleAndChat() async {
    setState(() => _loading = true);
    try {
      // Fetch bundle
      final bundleSnap = await FirebaseFirestore.instance.collection('listings').doc(widget.bundleId).get();
      if (bundleSnap.exists) {
        _bundle = BundleListing.fromFirestore(bundleSnap);
      } else {
        _bundle = BundleListing(
          id: widget.bundleId,
          vendorId: widget.vendorId,
          provider: NetworkProvider.MTN,
          dataAmount: 0,
          price: 0,
          description: 'Bundle not found',
          estimatedDeliveryTime: 0,
          availableStock: 0,
          status: ListingStatus.INACTIVE,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          paymentMethods: {},
          minOrder: 0,
          maxOrder: 0,
        );
      }
      // Optionally fetch chat details if needed
      // ...
    } catch (e) {
      debugPrint('Error fetching bundle in ChatScreen: $e');
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    final chats = FirebaseFirestore.instance.collection('chats');
    debugPrint('Creating new chat for new purchase...');
    
    // Get buyer name from user profile
    String buyerName = 'Buyer';
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>?;
        buyerName = userData?['name'] ?? userData?['businessName'] ?? 'Buyer';
      }
    } catch (e) {
      debugPrint('Error getting buyer name: $e');
    }
    
    // Create a transaction ID for this chat (transaction will be created when data is received)
    final txId = FirebaseFirestore.instance.collection('transactions').doc().id;
    
    // Create chat with the transaction ID (transaction doesn't exist yet but we have the ID)
    final doc = await chats.add({
      'bundleId': widget.bundleId,
      'buyerId': user!.uid,
      'buyerName': buyerName,
      'vendorId': widget.vendorId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'recipientNumber': widget.recipientNumber,
      'activeOrderId': txId, // Set the transaction ID but don't create the transaction yet
    });
    
    debugPrint('Created new chat: ${doc.id} with transaction ID: $txId');
    
    setState(() {
      chatId = doc.id;
      activeOrderId = txId;
    });
    
    // Send system message about the new order
    if (mounted) {
      await _sendMessage(
        'New order started for ${_bundle?.dataAmount ?? 'N/A'}GB ${_bundle?.provider.toString().split('.').last ?? 'bundle'} for ${widget.recipientNumber}',
        isSystem: true,
      );
    }
  }

  Future<void> _loadExistingChat() async {
    final doc = await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      setState(() {
        chatId = doc.id;
        activeOrderId = data.containsKey('activeOrderId') ? data['activeOrderId'] : null;
      });
    }
  }

  Future<void> startNewPurchase(double amount) async {
    if (chatId == null) {
      debugPrint('startNewPurchase: chatId is null');
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('startNewPurchase: user is null');
      return;
    }
    try {
      setState(() => _isSending = true);
      
      // First check if we already have an active order
      if (activeOrderId != null) {
        debugPrint('startNewPurchase: Using existing order $activeOrderId');
        return;
      }

      debugPrint('startNewPurchase: Creating new transaction...');
      final batch = FirebaseFirestore.instance.batch();
      final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
      final txRef = FirebaseFirestore.instance.collection('transactions').doc();
      final now = FieldValue.serverTimestamp();
      final txId = txRef.id;

      // Create the transaction
      batch.set(txRef, {
        'id': txId,
        'userId': user.uid,
        'vendorId': widget.vendorId,
        'type': 'bundle_purchase',
        'amount': _bundle!.price,
        'status': 'pending',
        'bundleId': _bundle!.id,
        'provider': _bundle!.provider.toString().split('.').last,
        'dataAmount': _bundle!.dataAmount,
        'recipientNumber': widget.recipientNumber,
        'createdAt': now,
        'updatedAt': now,
        'timestamp': now,
      });

      // Update the chat with the new transaction ID
      batch.update(chatRef, {
        'activeOrderId': txId,
        'status': 'pending',
        'updatedAt': now,
      });

      // Commit the batch
      await batch.commit();
      
      debugPrint('startNewPurchase: Transaction created with ID: $txId');
      
      // Update local state
      if (mounted) {
        setState(() {
          activeOrderId = txId;
          orderStatus = 'pending';
        });
      }
      
      // Send a system message about the new order
      await _sendMessage(
        'New order started for ${_bundle!.dataAmount}GB ${_bundle!.provider.toString().split('.').last} bundle for {${widget.recipientNumber}}',
        isSystem: true,
      );
      
    } catch (e, stack) {
      debugPrint('startNewPurchase: Error creating transaction or updating chat: $e');
      debugPrint(stack.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start new order: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<String> _getActiveOrderStatus() async {
    if (activeOrderId == null) return 'pending';
    final txDoc = await FirebaseFirestore.instance.collection('transactions').doc(activeOrderId).get();
    if (txDoc.exists) {
      final data = txDoc.data() as Map<String, dynamic>;
      return data['status'] ?? 'pending';
    }
    return 'pending';
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

  Future<void> _sendMessage(String message, {bool isSystem = false}) async {
    if (message.trim().isEmpty && _imageFile == null) return;
    setState(() => _isSending = true);
    try {
      String? imageUrl;
      if (_imageFile != null) {
        // Upload image to Firebase Storage
        final fileName = 'chat_images/${DateTime.now().millisecondsSinceEpoch}_${user!.uid}.jpg';
        final ref = FirebaseStorage.instance.ref().child(fileName);
        await ref.putFile(_imageFile!);
        imageUrl = await ref.getDownloadURL();
      }
      
      final messageData = {
        'senderId': isSystem ? 'system' : user!.uid,
        'text': message,
        'timestamp': FieldValue.serverTimestamp(),
        'imageUrl': imageUrl,
        'isSystem': isSystem,
      };
      
      // Add message to subcollection
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(messageData);
      
      // Update chat document with last message info (only for non-system messages)
      if (!isSystem) {
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .update({
          'lastMessage': imageUrl != null ? '📷 Image' : message,
          'lastMessageTime': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      // Only send notifications if the message isn't from the current user
      if (user!.uid != widget.vendorId) {
        try {
          // Get vendor's FCM token from Firestore
          final vendorDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.vendorId)
              .get();
              
          final vendorFcmToken = vendorDoc.data()?['fcmToken'];
          final vendorName = vendorDoc.data()?['name'] ?? 'Vendor';
          
          if (vendorFcmToken != null && vendorFcmToken is String) {
            // Send enhanced FCM v1 push notification with sound and category
            await FCMV1Service().sendMessage(
              token: vendorFcmToken,
              title: 'New message from ${user?.displayName ?? 'Buyer'}',
              body: message.isNotEmpty ? message : '📷 Image',
              sound: 'default',
              category: 'MESSAGE_CATEGORY',
              clickAction: 'FLUTTER_NOTIFICATION_CLICK',
              data: {
                'type': 'chat',
                'chatId': chatId!,
                'bundleId': _bundle?.id ?? '',
                'senderId': user!.uid,
                'senderName': user?.displayName ?? 'Buyer',
                'bundleName': _bundle?.description ?? 'Bundle',
                'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              },
            );
            debugPrint('FCM notification sent to vendor');
            // Note: removed local self-notification to prevent duplicate/self notifications
          } else {
            debugPrint('Vendor FCM token not found');
          }
        } catch (e, stack) {
          debugPrint('Error sending FCM notification: $e');
          debugPrint('Stack trace: $stack');
        }
      }
      
      _messageController.clear();
      setState(() => _imageFile = null);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message')),
      );
      }
    } finally {
      setState(() => _isSending = false);
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

  void _updateStatus(String status) async {
    if (chatId == null) return;
    await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    setState(() {
      orderStatus = status;
    });
  }

  Future<void> _markMessagesAsRead() async {
    if (chatId == null) return;
    final unread = await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .where('senderId', isEqualTo: widget.vendorId)
        .get();
    for (var doc in unread.docs) {
      doc.reference.update({'isRead': true});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _bundle == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(widget.vendorId).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.exists) {
              final userData = snapshot.data!.data() as Map<String, dynamic>?;
              final vendorName = userData?['businessName'] ?? userData?['name'] ?? 'Vendor';
              return Text('Chat with $vendorName');
            }
            return Text('Chat with ${widget.businessName}');
          },
        ),
      ),
      body: chatId == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<DocumentSnapshot>(
            stream: chatId != null && chatId!.isNotEmpty
                ? FirebaseFirestore.instance.collection('chats').doc(chatId).snapshots()
                : const Stream.empty(),
              builder: (context, chatSnap) {
                if (!chatSnap.hasData || !chatSnap.data!.exists) {
                  return const Center(child: CircularProgressIndicator());
                }
                final chatData = chatSnap.data!.data() as Map<String, dynamic>?;
                String chatStatus = chatData?['status'] ?? 'pending';
                return Column(
              children: [
                // Bundle info and status
                Card(
                  margin: const EdgeInsets.all(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_bundle!.dataAmount}GB ${_bundle!.provider.toString().split('.').last} - GHS${_bundle!.price.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(_bundle!.description),
                        const SizedBox(height: 8),
                        Row(
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
                            if (user!.uid == widget.vendorId)
                              (
                                chatStatus == 'completed'
                                    ? Chip(
                                        label: const Text('COMPLETED'),
                                        backgroundColor: Colors.green,
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
                                          if (val != null && chatId != null) {
                                            try {
                                              final now = FieldValue.serverTimestamp();
                                              final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
                                              await chatRef.update({
                                                'status': val,
                                                'updatedAt': now,
                                              });
                                              setState(() {
                                                orderStatus = val;
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
                                        },
                                      )
                              ),
                          ],
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
                        .doc(chatId)
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
                    // Message input & Confirm Data Received button
                SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                          if (chatStatus == 'data_sent' && user!.uid != widget.vendorId)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                          child: SizedBox(
                            width: double.infinity,
                            child: Builder(
                              builder: (context) {
                                final canMarkReceived = chatId != null && activeOrderId != null;
                                if (!canMarkReceived) {
                                  debugPrint('Data Received button hidden/disabled. chatId: '
                                      ' ${chatId}, activeOrderId:  ${activeOrderId}');
                                }
                                return ElevatedButton.icon(
                                  icon: const Icon(Icons.check_circle, color: Colors.white),
                                  label: _isSending
                                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                                      : const Text('Data Received'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: canMarkReceived ? Colors.green : Colors.grey,
                                    foregroundColor: Colors.white,
                                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: !_isSending && canMarkReceived
                                      ? () async {
                                          debugPrint('Data Received button pressed');
                                          debugPrint('chatId: $chatId, activeOrderId: $activeOrderId');
                                          setState(() => _isSending = true);
                                          try {
                                            final confirmed = await showDialog<bool>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text('Confirm Data Received'),
                                                content: const Text('Are you sure you have received the data bundle? This will mark the order as completed. This action cannot be undone.'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(context, false),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () => Navigator.pop(context, true),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.amber,
                                                      foregroundColor: Colors.black,
                                                    ),
                                                    child: const Text('Yes, Received'),
                                                  ),
                                                ],
                                              ),
                                            );

                                            if (confirmed == true) {
                                              try {
                                                if (activeOrderId == null) {
                                                  throw Exception('No active order ID found for this chat');
                                                }
                                                
                                                final batch = FirebaseFirestore.instance.batch();
                                                final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
                                                final txRef = FirebaseFirestore.instance.collection('transactions').doc(activeOrderId);
                                                final now = FieldValue.serverTimestamp();
                                                final userId = user!.uid;

                                                // Create the transaction with the pre-allocated ID
                                                batch.set(txRef, {
                                                  'id': activeOrderId,
                                                  'userId': userId,
                                                  'vendorId': widget.vendorId,
                                                  'type': 'bundle_purchase',
                                                  'amount': _bundle!.price,
                                                  'status': 'completed',
                                                  'bundleId': _bundle!.id,
                                                  'provider': _bundle!.provider.toString().split('.').last,
                                                  'dataAmount': _bundle!.dataAmount,
                                                  'recipientNumber': widget.recipientNumber,
                                                  'createdAt': now, // Set created time when actually creating the transaction
                                                  'updatedAt': now,
                                                  'completedBy': userId,
                                                  'completedAt': now,
                                                  'timestamp': now,
                                                });

                                                // Update chat document to mark as completed
                                                batch.update(chatRef, {
                                                  'status': 'completed',
                                                  'completedBy': userId,
                                                  'completedAt': now,
                                                  'updatedAt': now,
                                                });

                                                // Commit all changes atomically
                                                await batch.commit();

                                                // Update local state
                                                setState(() {
                                                  orderStatus = 'completed';
                                                });

                                                if (mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Order marked as completed!')),
                                                  );
                                                }
                                              } catch (e, stack) {
                                                debugPrint('Error in transaction processing: $e');
                                                debugPrint('Stack trace: $stack');

                                                String errorMessage = 'Failed to complete the transaction';
                                                if (e is FirebaseException) {
                                                  errorMessage = 'Firebase error: ${e.message}';
                                                } else if (e is StateError) {
                                                  errorMessage = 'State error: ${e.message}';
                                                }

                                                if (mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text(errorMessage),
                                                      duration: const Duration(seconds: 5),
                                                    ),
                                                  );
                                                }
                                                rethrow;
                                              }
                                            }
                                          } catch (e) {
                                            debugPrint('Error in confirmation dialog: $e');
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('An error occurred while processing your request')),
                                              );
                                            }
                                          } finally {
                                            if (mounted) {
                                              setState(() => _isSending = false);
                                            }
                                          }
                                        }
                                      : () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Order or chat not found. Please wait or try again.')),
                                          );
                                        },
                                  );
                              }, // <-- close Builder.builder
                            ), // <-- close Builder
                          ), // <-- close SizedBox
                        ), // <-- close Padding
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.image),
                                onPressed: _pickImage,
                              ),
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                decoration: const InputDecoration(
                                    hintText: 'Type a message...',
                                  ),
                                  onSubmitted: (message) => _sendMessage(message),
                                ),
                              ),
                            IconButton(
                                icon: const Icon(Icons.send),
                              onPressed: _isSending ? null : () => _sendMessage(_messageController.text),
                            ),
                          ],
                      ),
                    ],
                  ),
                ),
              ],
                );
              },
            ),
    );
  }
} 