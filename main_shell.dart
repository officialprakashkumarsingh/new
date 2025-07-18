import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import 'auth_and_profile_pages.dart';
import 'chat_page.dart';
import 'models.dart';
import 'saved_page.dart';
import 'auth_service.dart';
import 'characters_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  final GlobalKey<ChatPageState> _chatPageKey = GlobalKey<ChatPageState>();

  final List<Message> _bookmarkedMessages = [];
  final List<ChatSession> _chatHistory = [];

  // State for model selection
  List<String> _models = [];
  // MODIFICATION: Default model set to "claude-3-7-sonnet" as requested.
  String _selectedModel = 'claude-3-7-sonnet'; 
  bool _isLoadingModels = true;

  @override
  void initState() {
    super.initState();
    _fetchModels();
  }

  Future<void> _fetchModels() async {
    try {
      final response = await http.get(
        Uri.parse('https://api-aham-ai.officialprakashkrsingh.workers.dev/v1/chat/models'),
        headers: {'Authorization': 'Bearer ahamaibyprakash25'},
      );
      if (mounted && response.statusCode == 200) {
        final data = json.decode(response.body);
        final models = (data['data'] as List).map<String>((item) => item['id']).toList();
        setState(() {
          _models = models;
          if (!_models.contains(_selectedModel) && _models.isNotEmpty) {
            _selectedModel = _models.first;
          }
          _isLoadingModels = false;
        });
      } else {
        if (!mounted) return;
        setState(() => _isLoadingModels = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching models: ${response.reasonPhrase}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingModels = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch models: $e')),
      );
    }
  }

  void _showModelSelectionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFF7F7F7),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Select a Model', style: Theme.of(context).textTheme.titleLarge),
              ),
              const Divider(height: 1),
              LimitedBox(
                maxHeight: 300,
                child: _isLoadingModels
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        shrinkWrap: true,
                        children: _models.map((model) => ListTile(
                          title: Text(model),
                          trailing: _selectedModel == model ? Icon(Icons.check_circle, color: Theme.of(context).primaryColor) : null,
                          onTap: () {
                            setState(() => _selectedModel = model);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(duration: const Duration(seconds: 2), content: Text('$model selected')),
                            );
                          },
                        )).toList(),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _bookmarkMessage(Message botMessage) {
    setState(() {
      if (!_bookmarkedMessages.any((m) => m.text == botMessage.text)) {
        _bookmarkedMessages.insert(0, botMessage);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(duration: Duration(seconds: 2), content: Text('AI response saved!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(duration: Duration(seconds: 2), content: Text('This response is already saved.')),
        );
      }
    });
  }

  void _saveAndStartNewChat() {
    final currentMessages = _chatPageKey.currentState?.getMessages();
    if (currentMessages != null && currentMessages.length > 1) {
      final lastUserMessage = currentMessages.lastWhere((m) => m.sender == Sender.user, orElse: () => Message.user(''));

      if (lastUserMessage.text.isNotEmpty) {
        final title = lastUserMessage.text.length <= 20
            ? lastUserMessage.text
            : '${lastUserMessage.text.substring(0, 20)}...';
        
        final session = ChatSession(
          title: title,
          messages: List.from(currentMessages),
        );
        setState(() {
          _chatHistory.insert(0, session);
        });
      }
    }

    _chatPageKey.currentState?.startNewChat();
    if (_selectedIndex != 0) {
      setState(() {
        _selectedIndex = 0;
      });
    }
  }
  
  void _loadChat(ChatSession session) {
    _chatPageKey.currentState?.loadChatSession(session.messages);
    setState(() {
      _selectedIndex = 0;
    });
  }

  Widget _buildAnimatedIcon(IconData activeIcon, IconData inactiveIcon, int itemIndex) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
      child: Icon(
        _selectedIndex == itemIndex ? activeIcon : inactiveIcon,
        key: ValueKey<int>(_selectedIndex == itemIndex ? 1 : 0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      ChatPage(key: _chatPageKey, onBookmark: _bookmarkMessage, selectedModel: _selectedModel),
      const PlaceholderPage(title: 'Discover'),
      CharactersPage(selectedModel: _selectedModel),
      SavedPage(
        bookmarkedMessages: _bookmarkedMessages,
        chatHistory: _chatHistory,
        onLoadChat: _loadChat,
      ),
    ];

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: GestureDetector(
          onTap: _showModelSelectionSheet,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'AhamAI',
                style: GoogleFonts.pacifico(
                  fontSize: 22,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.expand_more_rounded, color: Colors.black54),
            ],
          ),
        ),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: ValueListenableBuilder<User?>(
            valueListenable: AuthService().currentUser,
            builder: (context, user, child) {
              return IconButton(
                icon: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: user != null ? NetworkImage(user.avatarUrl) : null,
                  child: user == null ? const Icon(Icons.person, size: 20) : null,
                ),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage()));
                },
              );
            },
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.add_comment_outlined), onPressed: _saveAndStartNewChat),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          colorScheme: Theme.of(context).colorScheme.copyWith(
                surfaceTint: Colors.transparent,
              ),
        ),
        child: BottomNavigationBar(
          backgroundColor: const Color(0xFFF7F7F7),
          elevation: 0,
          items: <BottomNavigationBarItem>[
            BottomNavigationBarItem(icon: _buildAnimatedIcon(Icons.home_filled, Icons.home_outlined, 0), label: 'Home'),
            BottomNavigationBarItem(icon: _buildAnimatedIcon(Icons.explore, Icons.explore_outlined, 1), label: 'Discover'),
            BottomNavigationBarItem(icon: _buildAnimatedIcon(Icons.theater_comedy, Icons.theater_comedy_outlined, 2), label: 'Characters'),
            BottomNavigationBarItem(icon: _buildAnimatedIcon(Icons.bookmark, Icons.bookmark_border, 3), label: 'Saved'),
          ],
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.black87,
          unselectedItemColor: Colors.grey.shade600,
          showSelectedLabels: false,
          showUnselectedLabels: false,
        ),
      ),
    );
  }
}

/* ----------------------------------------------------------
   PLACEHOLDER PAGE for other tabs
---------------------------------------------------------- */
class PlaceholderPage extends StatelessWidget {
  final String title;
  const PlaceholderPage({super.key, required this.title});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '$title Page',
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.grey),
      ),
    );
  }
}