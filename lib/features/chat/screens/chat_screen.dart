import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../listings/models/bundle_listing_model.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

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
    // Find or create chat document for this buyer, vendor, and bundle
    final chats = FirebaseFirestore.instance.collection('chats');
    final query = await chats
        .where('bundleId', isEqualTo: widget.listing.id)
        .where('buyerId', isEqualTo: user!.uid)
        .where('vendorId', isEqualTo: widget.vendorId)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      final docData = query.docs.first.data();
      // If recipientNumber is not set, update it
      if ((docData['recipientNumber'] ?? '').isEmpty && widget.recipientNumber.isNotEmpty) {
        await chats.doc(query.docs.first.id).update({
          'recipientNumber': widget.recipientNumber,
        });
      }
      setState(() {
        chatId = query.docs.first.id;
        orderStatus = query.docs.first['status'] ?? 'pending';
      });
    } else {
      final doc = await chats.add({
        'bundleId': widget.listing.id,
        'buyerId': user!.uid,
        'vendorId': widget.vendorId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'recipientNumber': widget.recipientNumber,
      });
      setState(() {
        chatId = doc.id;
        orderStatus = 'pending';
      });
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
          .doc(chatId)
          .collection('messages')
          .add({
        'senderId': user!.uid,
        'text': _messageController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'imageUrl': imageUrl,
      });
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
          : Column(
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
                                color: _statusColor(orderStatus),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                orderStatus.replaceAll('_', ' ').toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (user!.uid == widget.vendorId)
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
                // Message input
                SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (orderStatus == 'data_sent' && user!.uid != widget.vendorId)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.check_circle, color: Colors.white),
                              label: const Text('Data Received'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                textStyle: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              onPressed: () async {
                                if (chatId != null) {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Confirm Data Received'),
                                      content: const Text('Are you sure you have received the data bundle? This will mark the order as completed.'),
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
                                  if (confirmed == true) {
                                    await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
                                      'status': 'completed',
                                      'updatedAt': FieldValue.serverTimestamp(),
                                      'vendorNotifiedCompleted': false,
                                    });
                                    // Create transaction if not exists
                                    final txQuery = await FirebaseFirestore.instance
                                        .collection('transactions')
                                        .where('chatId', isEqualTo: chatId)
                                        .limit(1)
                                        .get();
                                    if (txQuery.docs.isEmpty) {
                                      // Fetch chat and bundle info
                                      final chatDoc = await FirebaseFirestore.instance.collection('chats').doc(chatId).get();
                                      final chatData = chatDoc.data() ?? {};
                                      final bundleId = chatData['bundleId'] ?? widget.listing.id;
                                      final userId = chatData['buyerId'] ?? user!.uid;
                                      final vendorId = chatData['vendorId'] ?? widget.vendorId;
                                      final recipientNumber = chatData['recipientNumber'] ?? '';
                                      final bundleSnap = await FirebaseFirestore.instance.collection('listings').doc(bundleId).get();
                                      final bundleData = bundleSnap.data() ?? {};
                                      await FirebaseFirestore.instance.collection('transactions').add({
                                        'chatId': chatId,
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
                                    setState(() {
                                      orderStatus = 'completed';
                                    });
                                  }
                                }
                              },
                            ),
                          ),
                        ),
                      Padding(
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
                    ],
                  ),
                ),
              ],
            ),
    );
  }
} 