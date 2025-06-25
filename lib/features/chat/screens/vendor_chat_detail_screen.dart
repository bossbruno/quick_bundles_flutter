import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

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
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
        'senderId': user!.uid,
        'text': _messageController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'imageUrl': imageUrl,
      });
      _messageController.clear();
      setState(() => _imageFile = null);
      _scrollToBottom();
      await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
        'updatedAt': FieldValue.serverTimestamp(),
      });
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
    await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    setState(() {
      orderStatus = status;
    });
    if (status == 'completed' && mounted) {
      // Check if transaction already exists for this chat
      final txQuery = await FirebaseFirestore.instance
          .collection('transactions')
          .where('chatId', isEqualTo: widget.chatId)
          .limit(1)
          .get();
      if (txQuery.docs.isEmpty) {
        // Fetch chat and bundle info
        final chatDoc = await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).get();
        final chatData = chatDoc.data() ?? {};
        final bundleId = chatData['bundleId'] ?? widget.bundleId;
        final userId = chatData['buyerId'] ?? widget.buyerId;
        final vendorId = chatData['vendorId'] ?? user?.uid;
        final recipientNumber = chatData['recipientNumber'] ?? '';
        final bundleSnap = await FirebaseFirestore.instance.collection('listings').doc(bundleId).get();
        final bundleData = bundleSnap.data() ?? {};
        await FirebaseFirestore.instance.collection('transactions').add({
          'chatId': widget.chatId,
          'bundleId': bundleId,
          'bundleName': bundleData['description'] ?? '',
          'dataAmount': bundleData['dataAmount'] ?? '',
          'amount': bundleData['price'] ?? 0.0,
          'recipientNumber': recipientNumber,
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'bundle_purchase',
          'userId': userId,
          'vendorId': vendorId,
          'provider': bundleData['provider'] ?? '',
          'status': 'completed',
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order marked as completed!')),
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
          // Bundle info and status
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
                  Row(
                    children: [
                      const Text('Order Status: '),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor(orderStatus),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          orderStatus.replaceAll('_', ' ').toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: orderStatus,
                        items: const [
                          DropdownMenuItem(value: 'pending', child: Text('Pending')),
                          DropdownMenuItem(value: 'processing', child: Text('Processing')),
                          DropdownMenuItem(value: 'data_sent', child: Text('Data Sent')),
                        ],
                        onChanged: (val) {
                          if (val != null) _updateStatus(val);
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
                    icon: const Icon(Icons.attach_file, color: Colors.blueGrey),
                    onPressed: _isSending ? null : _pickImage,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: _isSending
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send, color: Colors.green),
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