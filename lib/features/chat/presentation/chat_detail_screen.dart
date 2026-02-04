import 'dart:io';
import 'package:intellitaxi/core/permissions/permissions_service.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/chat/logic/chat_provider.dart';
import 'package:intellitaxi/features/chat/widgets/build_message_bubble_widget.dart';
import 'package:intellitaxi/features/chat/widgets/user_avatar_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';



class ChatDetailScreen extends StatefulWidget {
  final String userName;
  final String userImage;
  final int userId;
  final int activationId;
  final int activationIdCurrentUser;
  final String activCompanyUserId;

  const ChatDetailScreen({
    super.key,
    required this.userName,
    required this.userImage,
    required this.userId,
    required this.activationId,
    required this.activationIdCurrentUser,
    required this.activCompanyUserId,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  ChatProvider? _chatProvider;
  final PermissionsService _permissionsService = PermissionsService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _chatProvider = Provider.of<ChatProvider>(context, listen: false);

      await _chatProvider!.loadMessages(
        widget.userId,
        widget.activationId,
        widget.activationIdCurrentUser,
      );
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _chatProvider?.disconnectPusher();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<File?> pickImage() async {
    final granted = await _permissionsService.requestStoragePermission();
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Se necesita permiso de galería")),
      );
      return null;
    }

    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile != null) {
      return File(pickedFile.path);
    }
    return null;
  }

  void _showProfileImage() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: widget.userImage.isNotEmpty
                      ? Image.network(
                          widget.userImage,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.person,
                                size: 100,
                                color: Colors.grey[600],
                              ),
                            );
                          },
                        )
                      : Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.person,
                            size: 100,
                            color: Colors.grey[600],
                          ),
                        ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void sendMessage({List<File>? archivos}) async {
    final text = _controller.text.trim();
    if (text.isEmpty && (archivos == null || archivos.isEmpty)) return;

    _controller.clear();

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    await chatProvider.sendMessage(
      widget.userId,
      widget.activationId,
      text,
      archivos: archivos,
    );
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (chatProvider.newMessageArrived) {
            _listKey.currentState?.insertItem(chatProvider.messages.length - 1);
            _scrollToBottom();
            chatProvider.resetNewMessageFlag();
          }
        });

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            // backgroundColor: Colors.white,
            elevation: 0,
            title: Row(
              children: [
                GestureDetector(
                  onTap: _showProfileImage,
                  child: UserAvatar(
                    imageUrl: widget.userImage,
                    userName: widget.userName,
                    radius: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.userName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        // color: Colors.black,
                      ),
                    ),
                    const Text(
                      "En línea",
                      style: TextStyle(fontSize: 12, color: Colors.green),
                    ),
                  ],
                ),
              ],
            ),
          ),
          body: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: const AssetImage("assets/images/erp_logo.png"),
                fit: BoxFit.contain,
                alignment: Alignment.center,
                scale: 3.3,
                colorFilter: ColorFilter.mode(
                  Colors.white.withOpacity(0.3), //
                  BlendMode.modulate,
                ),
              ),
            ),

            child: Column(
              children: [
                Expanded(
                  child: chatProvider.loadingMessages
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.orange.shade400,
                                      Colors.deepOrange.shade500,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.orange.shade200,
                                      blurRadius: 15,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Cargando mensajes...',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : AnimatedList(
                          key: _listKey,
                          controller: _scrollController,
                          padding: EdgeInsets.only(
                            left: 14,
                            right: 14,
                            top: kToolbarHeight + 20,
                            bottom:
                                MediaQuery.of(context).viewInsets.bottom + 70,
                          ),
                          initialItemCount: chatProvider.messages.length,
                          itemBuilder: (context, index, animation) {
                            final msg = chatProvider.messages[index];
                            final isMe =
                                msg.idActivationCompanyUser ==
                                int.parse(widget.activCompanyUserId);

                            return SizeTransition(
                              sizeFactor: animation,
                              axisAlignment: 0.0,
                              child: buildMessageBubble(msg, isMe),
                            );
                          },
                        ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.attach_file,
                            color: Colors.grey,
                          ),
                          onPressed: () async {
                            final file = await pickImage();
                            if (file != null) {
                              sendMessage(archivos: [file]);
                            }
                          },
                        ),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: AppColors.white.withOpacity(0.04),
                              border: Border.all(
                                color: Colors.black.withOpacity(0.2),
                                width: 1, // grosor del borde
                              ),
                            ),
                            child: TextField(
                              controller: _controller,
                              decoration: const InputDecoration(
                                hintText: "Escribe un mensaje...",
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                              onSubmitted: (_) => sendMessage(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Colors.orange.shade400,
                                Colors.deepOrange.shade500,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.shade200,
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: IconButton(
                            onPressed: sendMessage,
                            icon: const Icon(Icons.send, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}