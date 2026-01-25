import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../listings/models/bundle_listing_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:quick_bundles_flutter/services/fcm_v1_service.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../services/notification_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/app_theme.dart';
import '../../reviews/widgets/add_review_dialog.dart';

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
 // Track last notified message
  bool _isReporting = false;

  @override
  void initState() {
    super.initState();
    chatId = widget.chatId;
    _fetchBundleAndChat().then((_) {
      if (chatId == null || chatId!.isEmpty) {
        _initChat();
      } else {
        _loadExistingChat();
      }
    });
    
    // Add a listener to scroll to bottom when new messages arrive
    _scrollController.addListener(() {});
    
    // Mark messages as read when chat is opened
    _markMessagesAsRead();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Mark messages as read when the screen is focused
    _markMessagesAsRead();
  }

  Future<void> _fetchBundleAndChat() async {
    if (!mounted) return;
    
    setState(() => _loading = true);
    try {
      // Fetch bundle
      final bundleSnap = await FirebaseFirestore.instance.collection('listings').doc(widget.bundleId).get();
      
      if (mounted) {
        setState(() {
          if (bundleSnap.exists) {
            _bundle = BundleListing.fromFirestore(bundleSnap);
          } else {
            _bundle = BundleListing(
              id: widget.bundleId,
              vendorId: widget.vendorId,
              provider: NetworkProvider.MTN,
              dataAmount: 0,
              price: 0,
              title: 'Bundle Not Found',
              description: 'The requested bundle could not be found',
              estimatedDeliveryTime: 0,
              availableStock: 0,
              status: ListingStatus.INACTIVE,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              paymentMethods: {},
              minOrder: 1.0,
              maxOrder: 0.0,
              network: 'MTN',
              bundleSize: '0GB',
              validity: 'N/A',
              discountPercentage: 0.0,
            );
          }
        });
      }
      
      // Initialize or load chat
      if (widget.chatId == null || widget.chatId!.isEmpty) {
        await _initChat();
      } else {
        await _loadExistingChat();
      }
    } catch (e) {
      debugPrint('Error in _fetchBundleAndChat: $e');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading bundle details. Please try again.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    try {
      if (!mounted) return;
      
      final chats = FirebaseFirestore.instance.collection('chats');
      debugPrint('Creating new chat for new purchase...');
      
      // Get buyer name from user profile
      String buyerName = 'Buyer';
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          buyerName = userData?['name'] ?? userData?['businessName'] ?? 'Buyer';
        }
      } catch (e) {
        debugPrint('Error getting buyer name: $e');
      }
      
      // Create a transaction ID for this chat
      final txId = FirebaseFirestore.instance.collection('transactions').doc().id;
      final now = FieldValue.serverTimestamp();
      
      // Create chat document reference
      final chatRef = chats.doc();
      
      // Prepare the system message with all required fields
      final systemMessage = {
        'senderId': 'system',
        'text': 'New order started for ${_bundle?.dataAmount ?? 'N/A'}GB ${_bundle?.provider.toString().split('.').last ?? 'bundle'} for ${widget.recipientNumber}',
        'timestamp': now,
        'isSystem': true,
        'isRead': false, // Required by Firestore rules for message updates
        'createdAt': now, // Add timestamp for sorting
      };
      
      // Build chat data with required fields
      final chatData = {
        'bundleId': widget.bundleId,
        'buyerId': user!.uid,
        'buyerName': buyerName,
        'vendorId': widget.vendorId,
        'status': 'pending',
        'createdAt': now,
        'updatedAt': now,
        'lastMessage': systemMessage['text'],
        'lastMessageTime': now,
        'recipientNumber': widget.recipientNumber,
        'activeOrderId': txId,
        'lastMessageSenderId': 'system',
        'unreadCount_${user!.uid}': 0,
        'unreadCount_${widget.vendorId}': 1, // Vendor has one unread message
      };
      
      // 1) Create the chat document first so rules for messages can see participants
      await chatRef.set(chatData);
      
      // 2) Then add the initial system message
      await chatRef.collection('messages').add(systemMessage);
      
      debugPrint('Created new chat: ${chatRef.id} with transaction ID: $txId');

      // Notify vendor about the new order
      try {
        final vendorDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.vendorId)
            .get();
        final vendorToken = vendorDoc.data()?['fcmToken'];
        final bundleName = _bundle?.description ?? '${_bundle?.dataAmount ?? 0}GB ${_bundle?.provider.toString().split('.').last}';
        if (vendorToken is String && vendorToken.isNotEmpty) {
          await FCMV1Service().sendMessage(
            token: vendorToken,
            title: 'New order from $buyerName',
            body: '$bundleName for ${widget.recipientNumber}',
            sound: 'default',
            category: 'ORDER_CATEGORY',
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
            data: {
              'type': 'order_update',
              'orderStatus': 'pending',
              'chatId': chatRef.id,
              'bundleId': widget.bundleId,
              'buyerId': user!.uid,
            },
          );
          debugPrint('Notified vendor of new order via FCM');
        } else {
          debugPrint('Vendor FCM token not found; skipping new order notification');
        }
      } catch (e) {
        debugPrint('Failed to send new order notification: $e');
      }
      
      if (mounted) {
        setState(() {
          chatId = chatRef.id;
          activeOrderId = txId;
          _loading = false; // Set loading to false after successful creation
        });
        
        // Scroll to bottom to show the new message
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollToBottom();
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Error initializing chat: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _loading = false); // Ensure loading is false on error
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to initialize chat. Please try again.')),
        );
      }
    }
  }

  Future<void> _loadExistingChat() async {
    if (widget.chatId == null || widget.chatId!.isEmpty) {
      debugPrint('No chat ID provided for loading existing chat');
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }
    
    try {
      final doc = await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).get();
      
      if (doc.exists) {
        final data = doc.data();
        if (mounted) {
          setState(() {
            chatId = doc.id;
            activeOrderId = data?['activeOrderId'];
            orderStatus = data?['status'] ?? 'pending';
            _loading = false; // Set loading to false after loading
          });
          
          // Mark messages as read
          _markMessagesAsRead();
          
          // Scroll to bottom to show latest messages
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _scrollToBottom();
          });
        }
      } else {
        debugPrint('Chat document ${widget.chatId} does not exist');
        // If chat doesn't exist, create a new one
        await _initChat();
      }
    } catch (e, stackTrace) {
      debugPrint('Error loading chat: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _loading = false); // Ensure loading is false on error
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading chat. Please try again.')),
        );
      }
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

      // Get buyer name from user profile
      String buyerName = 'Buyer';
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          buyerName = userData?['name'] ?? userData?['businessName'] ?? 'Buyer';
        }
      } catch (e) {
        debugPrint('Error getting buyer name: $e');
      }

      // Create the transaction
      batch.set(txRef, {
        'id': txId,
        'userId': user.uid,
        'buyerId': user.uid,
        'buyerName': buyerName,  // Add buyer's name to transaction
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
      case 'completed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // Helper method to build message text with clickable phone numbers
  Widget _buildMessageText(String text, {Color? color}) {
    final textColor = color ?? AppTheme.textPrimary;
    // Regular expression to match phone numbers in various formats
    final phoneRegex = RegExp(
      r'\b(?:\+?233|0)?[ -]?\(?(\d{3})\)?[ -]?(\d{3})[ -]?(\d{4})\b',
      caseSensitive: false,
    );
    
    final matches = phoneRegex.allMatches(text);
    if (matches.isEmpty) {
      return Text(
        text,
        style: GoogleFonts.poppins(fontSize: 15, color: textColor),
        softWrap: true,
      );
    }

    final textSpans = <TextSpan>[];
    int currentIndex = 0;
    
    for (final match in matches) {
      // Add text before the match
      if (match.start > currentIndex) {
        textSpans.add(TextSpan(
          text: text.substring(currentIndex, match.start),
          style: GoogleFonts.poppins(fontSize: 15, color: textColor),
        ));
      }
      
      // Add the matched phone number as clickable
      final phoneNumber = match.group(0)!;
      textSpans.add(TextSpan(
        text: phoneNumber,
        style: GoogleFonts.poppins(
          fontSize: 15,
          color: color != null ? Colors.white : Colors.blue, // White if on colored background, blue otherwise
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.w600,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            // Copy to clipboard
            await Clipboard.setData(ClipboardData(text: phoneNumber));
            
            // Show feedback
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Copied to clipboard: $phoneNumber'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
      ));
      
      currentIndex = match.end;
    }
    
    // Add remaining text after last match
    if (currentIndex < text.length) {
      textSpans.add(TextSpan(
        text: text.substring(currentIndex),
        style: GoogleFonts.poppins(fontSize: 15, color: textColor),
      ));
    }
    
    return RichText(
      text: TextSpan(children: textSpans),
      softWrap: true,
    );
  }

  Future<void> _sendMessage(String message, {bool isSystem = false}) async {
    if (message.trim().isEmpty && _imageFile == null) return;
    setState(() => _isSending = true);
    try {
      // Capture UI state and clear immediately for better UX (mirror vendor side)
      final messageText = message.trim();
      final imageToSend = _imageFile;
      _messageController.clear();
      setState(() => _imageFile = null);

      String? imageUrl;
      if (imageToSend != null) {
        // Upload image to Firebase Storage
        final fileName = 'chat_images/${DateTime.now().millisecondsSinceEpoch}_${user!.uid}.jpg';
        final ref = FirebaseStorage.instance.ref().child(fileName);
        await ref.putFile(imageToSend);
        imageUrl = await ref.getDownloadURL();
      }
      
      final messageData = {
        'senderId': isSystem ? 'system' : user!.uid,
        'text': messageText,
        'timestamp': FieldValue.serverTimestamp(),
        'imageUrl': imageUrl,
        'isSystem': isSystem,
        'isRead': false,
      };
      
      // Add message to subcollection
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(messageData);
      
      // Update chat document with last message info (only for non-system messages)
      if (!isSystem) {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
          final chatDoc = await transaction.get(chatRef);
          if (!chatDoc.exists) return;
          transaction.update(chatRef, {
            'lastMessage': imageUrl != null ? '📷 Image' : messageText,
            'lastMessageTime': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'lastMessageSenderId': user!.uid,
            // increment vendor's unread counter since buyer is sending
            'unreadCount_${widget.vendorId}': FieldValue.increment(1),
          });
        });
      }
      
      // Only send notifications if the recipient is different from current user
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
              body: messageText.isNotEmpty ? messageText : '📷 Image',
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
          // Also try OneSignal via NotificationService for better reliability
          await NotificationService().sendChatNotification(
            recipientUserId: widget.vendorId,
            senderName: user?.displayName ?? 'Buyer',
            message: imageUrl != null ? '📷 Image' : messageText,
            chatId: chatId!,
            bundleId: _bundle?.id,
          );
        } catch (e, stack) {
          debugPrint('Error sending FCM notification: $e');
          debugPrint('Stack trace: $stack');
        }
      }
      
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
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 70,
      );
      if (picked != null) {
        final file = File(picked.path);
        // Additional size check (2MB)
        final size = await file.length();
        if (size > 2 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Image is too large. Please select a smaller one.')),
            );
          }
          return;
        }
        setState(() => _imageFile = file);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  void _showFullScreenImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                },
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.white, size: 50),
              ),
            ),
          ),
        ),
      ),
    );
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
    if (chatId == null || user?.uid == null) return;
    
    // Mark messages as read
    final messagesRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .where('senderId', isNotEqualTo: user!.uid);
        
    final snapshot = await messagesRef.get();
    
    if (snapshot.docs.isNotEmpty) {
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      
      // Update the unread count in the chat document
      final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
      batch.update(chatRef, {
        'unreadCount_${user!.uid}': 0,
        'lastMessageRead_${user!.uid}': FieldValue.serverTimestamp(),
      });
      
      await batch.commit();
    }
  }

  Future<void> _showReportDialog() async {
    final reportReasons = [
      'Inappropriate behavior',
      'Fraudulent activity',
      'Spam or harassment',
      'Technical issues',
      'Payment problems',
      'Data not received',
      'Other',
    ];

    return showDialog(
      context: context,
      builder: (context) {
        // Move state variables to the dialog builder scope
        String? selectedReason;
        final TextEditingController descriptionController = TextEditingController();
        
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Report Issue'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedReason,
                    decoration: const InputDecoration(
                      labelText: 'Reason for report',
                      border: OutlineInputBorder(),
                    ),
                    items: reportReasons
                        .map((reason) => DropdownMenuItem(
                              value: reason,
                              child: Text(reason),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedReason = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                      hintText: 'Please provide more details',
                    ),
                    maxLines: 3,
                    onChanged: (value) {
                      // Update the state when text changes
                      setState(() {});
                    },
                    // Add autofocus to ensure the keyboard appears
                    autofocus: true,
                    // Ensure proper text input action
                    textInputAction: TextInputAction.done,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedReason == null || descriptionController.text.trim().isEmpty
                      ? null
                      : () async {
                          Navigator.pop(context);
                          await _submitReport(selectedReason!, descriptionController.text.trim());
                        },
                  child: const Text('Submit Report'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitReport(String reason, String description) async {
    if (chatId == null || user == null) return;

    
    setState(() => _isReporting = true);
    try {
      // Get chat details
      final chatDoc = await FirebaseFirestore.instance.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) throw Exception('Chat not found');
      
      final chatData = chatDoc.data() as Map<String, dynamic>;
      
      // Get recent messages for context
      final messagesQuery = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();
      
      final recentMessages = messagesQuery.docs.map((doc) {
        final data = doc.data();
        return {
          'text': data['text'] ?? '',
          'senderId': data['senderId'] ?? '',
          'timestamp': data['timestamp'],
          'isSystem': data['isSystem'] ?? false,
        };
      }).toList();
      
      // Create report document
      final reportData = {
        'chatId': chatId,
        'bundleId': widget.bundleId,
        'vendorId': widget.vendorId,
        'buyerId': user!.uid,
        'reporterId': user!.uid,
        'reporterType': user!.uid == widget.vendorId ? 'vendor' : 'buyer',
        'reason': reason,
        'description': description,
        'chatStatus': chatData['status'] ?? 'unknown',
        'bundleDetails': {
          'dataAmount': _bundle?.dataAmount ?? 0,
          'provider': _bundle?.provider.toString().split('.').last ?? 'unknown',
          'price': _bundle?.price ?? 0,
        },
        'recentMessages': recentMessages,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'adminNotes': '',
      };
      
      await FirebaseFirestore.instance.collection('reports').add(reportData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted successfully. We will review it shortly.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isReporting = false);
    }
  }

  void _showReviewDialog() async {
    // Only allow reviewing if user is NOT the vendor
    if (user?.uid == widget.vendorId) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AddReviewDialog(
        vendorId: widget.vendorId,
        vendorName: widget.businessName,
        bundleId: widget.bundleId,
      ),
    );
    
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thank you using Quick Bundles!')),
      );
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
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(widget.vendorId).get(),
          builder: (context, snapshot) {
            String displayedName = widget.businessName;
            if (snapshot.hasData && snapshot.data!.exists) {
              final userData = snapshot.data!.data() as Map<String, dynamic>?;
              displayedName = userData?['businessName'] ?? userData?['name'] ?? widget.businessName;
            }
            return Text(
              displayedName,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.white),
            );
          },
        ),
        actions: [
          IconButton(
            icon: _isReporting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.report_problem, color: Colors.white),
            onPressed: _isReporting ? null : _showReportDialog,
            tooltip: 'Report Issue',
          ),
          // Only show review button if user is NOT the vendor
          if (user?.uid != widget.vendorId)
            IconButton(
              icon: const Icon(Icons.star_rate_rounded, color: Colors.amber),
              onPressed: _showReviewDialog,
              tooltip: 'Rate Vendor',
            ),
        ],
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_bundle!.dataAmount}GB ${_bundle!.provider.toString().split('.').last}',
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  Text(
                                    'GHS ${_bundle!.price.toStringAsFixed(2)}',
                                    style: GoogleFonts.poppins(color: AppTheme.primary, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _statusColor(chatStatus).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: _statusColor(chatStatus).withOpacity(0.2)),
                                ),
                                child: Text(
                                  chatStatus.replaceAll('_', ' ').toUpperCase(),
                                  style: GoogleFonts.poppins(
                                    color: _statusColor(chatStatus),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (user!.uid == widget.vendorId) ...[
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.phone_android, size: 16, color: AppTheme.textSecondary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.recipientNumber,
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
                                  ),
                                ),
                                IconButton(
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                  icon: Icon(Icons.copy, size: 18, color: AppTheme.primary),
                                  onPressed: () async {
                                    await Clipboard.setData(ClipboardData(text: widget.recipientNumber));
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Recipient number copied')),
                                      );
                                    }
                                  },
                                ),
                              ],
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
                            .doc(chatId)
                            .collection('messages')
                            .orderBy('timestamp')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                             _markMessagesAsRead(); // Keep existing logic
                          }
                          if (!snapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final messages = snapshot.data!.docs;
                          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                          
                          return ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final msg = messages[index].data() as Map<String, dynamic>;
                              final isMe = msg['senderId'] == user!.uid;
                              final timestamp = msg['timestamp'] != null ? (msg['timestamp'] as Timestamp).toDate() : null;
                              final timeString = timestamp != null ? TimeOfDay.fromDateTime(timestamp).format(context) : '';
                              
                              return Align(
                                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: isMe ? const LinearGradient(colors: [AppTheme.primary, AppTheme.secondary]) : null,
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
                                      if (msg['imageUrl'] != null)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 8),
                                          child: GestureDetector(
                                            onTap: () => _showFullScreenImage(msg['imageUrl']),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: Hero(
                                                tag: msg['imageUrl'],
                                                child: Image.network(
                                                  msg['imageUrl'],
                                                  width: 200,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (c, e, s) => const Icon(Icons.broken_image, color: Colors.white70),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      if ((msg['text'] ?? '').isNotEmpty)
                                        _buildMessageText(
                                          msg['text'], 
                                          color: isMe ? Colors.white : AppTheme.textPrimary
                                        ),
                                      const SizedBox(height: 4),
                                      if (timeString.isNotEmpty)
                                        Text(
                                          timeString,
                                          style: GoogleFonts.poppins(
                                            fontSize: 10, 
                                            color: isMe ? Colors.white.withOpacity(0.7) : AppTheme.textSecondary
                                          ),
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

                    // Input Area
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
                      child: SafeArea( // Ensure safety inside container
                        top: false,
                        child: Column(
                          children: [
                            // Data Received Button (if applicable)
                             if (chatStatus == 'data_sent' && user!.uid != widget.vendorId)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: Builder(
                                    builder: (context) {
                                      final canMarkReceived = chatId != null && activeOrderId != null;
                                      return ElevatedButton.icon(
                                        icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                                        label: _isSending
                                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                            : Text('Confirm Data Received', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.success,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          elevation: 0,
                                        ),
                                        onPressed: !_isSending && canMarkReceived
                                            ? () async {
                                                // Existing confirmation logic 
                                                // ... (We need to replicate the logic here or extracted method would be better, but reusing inline for now as in original)
                                                // Note: duplicating logic is risky, let's try to keep it inline as original or simplify.
                                                // Given the complexity of the original logic, I should have extracted it.
                                                // I will assume the user wants me to rewrite the inline logic or call reference.
                                                // Since I am replacing the method, I must include the logic.
                                                
                                                setState(() => _isSending = true);
                                                try {
                                                  final confirmed = await showDialog<bool>(
                                                    context: context,
                                                    builder: (context) => AlertDialog(
                                                      title: const Text('Confirm Data Received'),
                                                      content: const Text('Are you sure you have received the bundle? This will complete the order.'),
                                                      actions: [
                                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                                        ElevatedButton(
                                                          onPressed: () => Navigator.pop(context, true),
                                                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, foregroundColor: Colors.white),
                                                          child: const Text('Yes, Received'),
                                                        ),
                                                      ],
                                                    ),
                                                  );

                                                  if (confirmed == true && activeOrderId != null) {
                                                     final batch = FirebaseFirestore.instance.batch();
                                                     final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
                                                     final txRef = FirebaseFirestore.instance.collection('transactions').doc(activeOrderId);
                                                     final now = FieldValue.serverTimestamp();
                                                     
                                                     batch.set(txRef, {
                                                       'id': activeOrderId,
                                                       'userId': user!.uid,
                                                       'buyerId': user!.uid,
                                                       'vendorId': widget.vendorId,
                                                       'type': 'bundle_purchase',
                                                       'amount': _bundle!.price,
                                                       'status': 'completed',
                                                       'bundleId': _bundle!.id,
                                                       'provider': _bundle!.provider.toString().split('.').last,
                                                       'dataAmount': _bundle!.dataAmount,
                                                       'recipientNumber': widget.recipientNumber,
                                                       'createdAt': now,
                                                       'updatedAt': now,
                                                       'completedBy': user!.uid,
                                                       'completedAt': now,
                                                       'timestamp': now,
                                                     });
                                                     
                                                     batch.update(chatRef, {
                                                       'status': 'completed',
                                                       'completedBy': user!.uid,
                                                       'updatedAt': now,
                                                     });
                                                     
                                                     await batch.commit();
                                                     setState(() => orderStatus = 'completed');
                                                     if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order completed!')));
                                                  }
                                                } catch (e) {
                                                   if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                                } finally {
                                                   if (mounted) setState(() => _isSending = false);
                                                }
                                              }
                                            : null,
                                      );
                                    }
                                  ),
                                ),
                              ),

                              if (_imageFile != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.file(
                                          _imageFile!,
                                          height: 150,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: GestureDetector(
                                          onTap: () => setState(() => _imageFile = null),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.close, color: Colors.white, size: 20),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                            // Input Field
                            Row(
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
                                      border: Border.all(color: Colors.transparent),
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
                                      onSubmitted: (message) => _sendMessage(message),
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
                                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                                    onPressed: _isSending ? null : () => _sendMessage(_messageController.text),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
} 