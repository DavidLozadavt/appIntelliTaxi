import 'package:intellitaxi/features/chat/widgets/build_user_list_widget.dart';
import 'package:intellitaxi/shared/loading_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intellitaxi/features/chat/logic/chat_provider.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUsers();
    });
  }

  Future<void> _loadUsers() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    await chatProvider.loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            title: const Text(
              "Chats",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
            ],
          ),
          body: Column(
            children: [
              // 🔍 Buscador moderno tipo WhatsApp
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: chatProvider.searchUsers,
                  decoration: InputDecoration(
                    hintText: "Buscar chats o usuarios...",
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    // fillColor: Colors.grey.shade200,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              chatProvider.clearSearch();
                            },
                          )
                        : null,
                  ),
                ),
              ),

              Expanded(
                child: chatProvider.isLoading
                    ? const LoadingScreen(message: 'Cargando usuarios...')
                    : buildUserList(chatProvider.users, chatProvider.isLoading),
              ),
            ],
          ),

          //   // ✉️ Botón para nuevo chat
          //   floatingActionButton: FloatingActionButton(
          //     onPressed: () {},
          //     child: const Icon(Icons.chat),
          //   ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
