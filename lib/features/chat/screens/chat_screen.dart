import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../listings/models/bundle_listing_model.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../services/notification_service.dart';
import '../../../services/onesignal_service.dart';
import '../../../services/database_service.dart';

class ChatScreen extends StatefulWidget {
  final BundleListing listing;
  final String vendorId;
  final String businessName;
  final String recipientNumber;

  const ChatScreen({
    Key? key,
    required this.listing,
    required this.vendorId,
    required this.businessName,
    required this.recipientNumber,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  String? chatId;
  String? activeOrderId;
  String orderStatus = 'pending';
  final TextEditingController _messageController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    final chats = FirebaseFirestore.instance.collection('chats');
    final query = await chats
        .where('buyerId', isEqualTo: user!.uid)
        .where('vendorId', isEqualTo: widget.vendorId)
        .where('bundleId', isEqualTo: widget.listing.id)
        .where('recipientNumber', isEqualTo: widget.recipientNumber)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      // Chat already exists, use its ID and activeOrderId
      final doc = query.docs.first;
      final existingActiveOrderId = doc['activeOrderId'];
      debugPrint('Found existing chat: ${doc.id}');
      debugPrint('Existing activeOrderId: $existingActiveOrderId');
      setState(() {
        chatId = doc.id;
        activeOrderId = existingActiveOrderId;
      });
    } else {
      // Create a new chat
      debugPrint('Creating new chat...');
      final doc = await chats.add({
        'bundleId': widget.listing.id,
        'buyerId': user!.uid,
        'vendorId': widget.vendorId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'recipientNumber': widget.recipientNumber,
        'activeOrderId': null,
      });
      debugPrint('Created new chat: ${doc.id}');
      setState(() {
        chatId = doc.id;
        activeOrderId = null;
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
      // Create a new transaction
      final dbService = DatabaseService();
      debugPrint('startNewPurchase: Creating transaction...');
      final transactionRef = await dbService.createTransaction(
        userId: user.uid,
        type: 'bundle_purchase',
        amount: amount * widget.listing.price,
        status: 'pending',
        bundleId: widget.listing.id,
        recipientNumber: widget.recipientNumber,
        provider: widget.listing.provider.toString().split('.').last,
      );
      debugPrint('startNewPurchase: Transaction created with ID: ${transactionRef.id}');
      // Update chat's activeOrderId
      await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
        'activeOrderId': transactionRef.id,
        'status': 'pending',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('startNewPurchase: Chat updated with activeOrderId: ${transactionRef.id}');
      setState(() {
        activeOrderId = transactionRef.id;
        orderStatus = 'pending';
      });
    } catch (e, stack) {
      debugPrint('startNewPurchase: Error creating transaction or updating chat: ${e.toString()}');
      debugPrint(stack.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start new purchase: ${e.toString()}')),
      );
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

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty && _imageFile == null) return;
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
      
      final messageText = _messageController.text.trim();
      
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'senderId': user!.uid,
        'text': messageText,
        'timestamp': FieldValue.serverTimestamp(),
        'imageUrl': imageUrl,
      });
      
      // Send notification to vendor
      if (user!.uid != widget.vendorId) {
        await NotificationService().sendChatNotification(
          recipientUserId: widget.vendorId,
          senderName: user!.displayName ?? 'Buyer',
          message: imageUrl != null ? '📷 Image' : messageText,
          chatId: chatId!,
          bundleId: widget.listing.id,
        );
      }
      
      _messageController.clear();
      setState(() => _imageFile = null);
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat with ${widget.businessName}'),
      ),
      body: chatId == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('chats').doc(chatId).snapshots(),
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
                          '${widget.listing.dataAmount}GB ${widget.listing.provider.toString().split('.').last} - GHS${widget.listing.price.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(widget.listing.description),
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
                              DropdownButton<String>(
                                    value: chatStatus,
                                items: const [
                                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                                  DropdownMenuItem(value: 'processing', child: Text('Processing')),
                                  DropdownMenuItem(value: 'data_sent', child: Text('Data Sent')),
                                      // No 'completed' option for vendor
                                ],
                                                                    onChanged: (val) async {
                                  if (val != null && chatId != null) {
                                    final batch = FirebaseFirestore.instance.batch();
                                    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
                                    final now = FieldValue.serverTimestamp();
                                    
                                    // Update chat status
                                    batch.update(chatRef, {
                                      'status': val,
                                      'updatedAt': now,
                                    });
                                    
                                    // Update transaction status if activeOrderId exists
                                    if (activeOrderId != null) {
                                      final txRef = FirebaseFirestore.instance.collection('transactions').doc(activeOrderId);
                                      batch.update(txRef, {
                                        'status': val,
                                        'updatedAt': now,
                                      });
                                    }
                                    
                                    await batch.commit();
                                  }
                                },
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
                                            debugPrint('Showing confirmation dialog');
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
                                                    child: const Text('Yes, Received'),
                                                  ),
                                                ],
                                              ),
                                            );
                                            debugPrint('Dialog result: ${confirmed.toString()}');
                                            if (confirmed == true) {
                                              debugPrint('User confirmed. Preparing batch update.');
                                              final batch = FirebaseFirestore.instance.batch();
                                              final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
                                              final txRef = FirebaseFirestore.instance.collection('transactions').doc(activeOrderId);
                                              final now = FieldValue.serverTimestamp();
                                              final userId = user!.uid;
                                              batch.update(chatRef, {
                                                'status': 'completed',
                                                'completedBy': userId,
                                                'completedAt': now,
                                                'updatedAt': now,
                                              });
                                              batch.update(txRef, {
                                                'status': 'completed',
                                                'completedBy': userId,
                                                'completedAt': now,
                                                'updatedAt': now,
                                              });
                                              await batch.commit();
                                              debugPrint('Batch update committed successfully');
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Order marked as completed!')),
                                              );
                                            } else {
                                              debugPrint('User cancelled confirmation dialog');
                                            }
                                          } catch (e, stack) {
                                            debugPrint('Error marking as completed: ${e.toString()}');
                                            debugPrint(stack.toString());
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Failed to mark as completed: ${e.toString()}')),
                                            );
                                          } finally {
                                            setState(() => _isSending = false);
                                          }
                                        }
                                      : () {
                                      title: const Text('Confirm Data Received'),
                                            content: const Text('Are you sure you have received the data bundle? This will mark the order as completed. This action cannot be undone.'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          child: const Text('Yes, Received'),
                                        ),
                                      ],
                                    ),
                                  );
                                        debugPrint('Dialog result: ${confirmed.toString()}');
                                  if (confirmed == true) {
                                          debugPrint('User confirmed. Preparing batch update.');
                                          final batch = FirebaseFirestore.instance.batch();
                                          final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
                                          final txRef = FirebaseFirestore.instance.collection('transactions').doc(activeOrderId);
                                          final now = FieldValue.serverTimestamp();
                                          final userId = user!.uid;
                                          batch.update(chatRef, {
                                            'status': 'completed',
                                            'completedBy': userId,
                                            'completedAt': now,
                                            'updatedAt': now,
                                          });
                                          batch.update(txRef, {
                                      'status': 'completed',
                                            'completedBy': userId,
                                            'completedAt': now,
                                            'updatedAt': now,
                                          });
                                          await batch.commit();
                                          debugPrint('Batch update committed successfully');
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Order marked as completed!')),
                                          );
                                        } else {
                                          debugPrint('User cancelled confirmation dialog');
                                        }
                                      } catch (e, stack) {
                                        debugPrint('Error marking as completed: ${e.toString()}');
                                        debugPrint(stack.toString());
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Failed to mark as completed: ${e.toString()}')),
                                        );
                                      } finally {
                                        setState(() => _isSending = false);
                                      }
                                    } else {
                                      debugPrint('activeOrderId or chatId is null');
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Order or chat not found.')),
                                      );
                                }
                              },
                            ),
                          ),
                        ),
                          // Message input
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
                                  onSubmitted: (_) => _sendMessage(),
                                ),
                              ),
                            IconButton(
                                icon: const Icon(Icons.send),
                              onPressed: _isSending ? null : _sendMessage,
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