import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'models.dart';
import 'character_service.dart';
import 'file_upload_widget.dart';

/* ----------------------------------------------------------
   CHAT PAGE
---------------------------------------------------------- */
class ChatPage extends StatefulWidget {
  final void Function(Message botMessage) onBookmark;
  final String selectedModel;
  const ChatPage({super.key, required this.onBookmark, required this.selectedModel});

  @override
  State<ChatPage> createState() => ChatPageState();
}

class ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <Message>[
    Message.bot('Hi, I’m AhamAI. Ask me anything!'),
  ];
  bool _awaitingReply = false;
  String? _editingMessageId;

  StreamSubscription? _streamSubscription;
  http.Client? _httpClient;
  final CharacterService _characterService = CharacterService();

  final _prompts = ['Explain quantum computing', 'Write a Python snippet', 'Draft an email to my boss', 'Ideas for weekend trip'];
  
  // MODIFICATION: Robust function to fix server-side encoding errors (mojibake).
  // This is the core fix for rendering emojis and special characters correctly.
  String _fixServerEncoding(String text) {
    try {
      // This function corrects text that was encoded in UTF-8 but mistakenly interpreted as Latin-1.
      // 1. We take the garbled string and encode it back into bytes using Latin-1.
      //    This recovers the original, correct UTF-8 byte sequence.
      final originalBytes = latin1.encode(text);
      // 2. We then decode these bytes using the correct UTF-8 format.
      //    `allowMalformed: true` makes this more robust against potential errors.
      return utf8.decode(originalBytes, allowMalformed: true);
    } catch (e) {
      // If anything goes wrong, return the original text to prevent the app from crashing.
      return text;
    }
  }

  @override
  void initState() {
    super.initState();
    _characterService.addListener(_onCharacterChanged);
    _updateGreetingForCharacter();
  }

  @override
  void dispose() {
    _characterService.removeListener(_onCharacterChanged);
    _controller.dispose();
    _scroll.dispose();
    _streamSubscription?.cancel();
    _httpClient?.close();
    super.dispose();
  }

  List<Message> getMessages() => _messages;

  void loadChatSession(List<Message> messages) {
    setState(() {
      _awaitingReply = false;
      _streamSubscription?.cancel();
      _httpClient?.close();
      _messages.clear();
      _messages.addAll(messages);
    });
  }

  void _onCharacterChanged() {
    if (mounted) {
      _updateGreetingForCharacter();
    }
  }

  void _updateGreetingForCharacter() {
    final selectedCharacter = _characterService.selectedCharacter;
    setState(() {
      if (_messages.isNotEmpty && _messages.first.sender == Sender.bot && _messages.length == 1) {
        if (selectedCharacter != null) {
          _messages.first = Message.bot('Hello! I\'m ${selectedCharacter.name}. ${selectedCharacter.description}. How can I help you today?');
        } else {
          _messages.first = Message.bot('Hi, I\'m AhamAI. Ask me anything!');
        }
      }
    });
  }

  void _startEditing(Message message) {
    setState(() {
      _editingMessageId = message.id;
      _controller.text = message.text;
      _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
    });
  }
  
  void _cancelEditing() {
    setState(() {
      _editingMessageId = null;
      _controller.clear();
    });
  }

  void _showUserMessageOptions(BuildContext context, Message message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFF7F7F7),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.copy_all_rounded),
              title: const Text('Copy'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.text));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(duration: Duration(seconds: 2), content: Text('Copied to clipboard')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Edit & Resend'),
              onTap: () {
                Navigator.pop(context);
                _startEditing(message);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _generateResponse(String prompt) async {
    if (widget.selectedModel.isEmpty) {
      setState(() => _messages.add(Message.bot('Error: No model has been selected.')));
      return;
    }

    final completer = Completer<void>();
    _streamSubscription?.cancel();
    _httpClient?.close();
    _httpClient = http.Client();

    setState(() {
      _awaitingReply = true;
      _messages.add(Message.bot('', isStreaming: true));
    });
    _scrollDown();
    
    try {
      const apiKey = 'ahamaibyprakash25';
      final url = Uri.parse('https://api-aham-ai.officialprakashkrsingh.workers.dev/v1/chat/completions');
      
      // Build messages with character system prompt if available
      final messages = <Map<String, String>>[];
      final selectedCharacter = _characterService.selectedCharacter;
      if (selectedCharacter != null) {
        messages.add({'role': 'system', 'content': selectedCharacter.systemPrompt});
      }
      messages.add({'role': 'user', 'content': prompt});
      
      final body = json.encode({
        'model': widget.selectedModel,
        'messages': messages,
        'stream': true,
      });

      final request = http.Request('POST', url)
        ..headers.addAll({
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $apiKey',
        })
        ..bodyBytes = utf8.encode(body);

      final streamedResponse = await _httpClient!.send(request);

      if (streamedResponse.statusCode == 200) {
        final buffer = StringBuffer();
        _streamSubscription = streamedResponse.stream.transform(utf8.decoder).transform(const LineSplitter()).listen(
          (line) {
            if (line.startsWith('data: ')) {
              final data = line.substring(6);
              if (data.trim() == '[DONE]') return;
              
              try {
                final jsonResponse = json.decode(data);
                final content = jsonResponse['choices'][0]['delta']['content'];
                if (content != null) {
                  // MODIFICATION: Apply the robust encoding fix to the incoming text.
                  final correctedContent = _fixServerEncoding(content);
                  buffer.write(correctedContent);
                  if (mounted) {
                    setState(() => _messages.last = Message.bot(buffer.toString(), isStreaming: true));
                    _scrollDown();
                  }
                }
              } catch (e) {
                 // Ignore errors from incomplete JSON chunks
              }
            }
          },
          onDone: () {
            if (mounted) {
              setState(() {
                _messages.last = Message.bot(_messages.last.text, isStreaming: false);
                _awaitingReply = false;
              });
              _httpClient?.close();
              completer.complete();
            }
          },
          onError: (e) {
            if (mounted) {
              setState(() {
                _messages.last = Message.bot('An error occurred during streaming: $e');
                _awaitingReply = false;
              });
              _httpClient?.close();
              completer.complete();
            }
          },
          cancelOnError: true,
        );
      } else {
        final errorBody = await streamedResponse.stream.transform(utf8.decoder).join();
        final errorDetails = errorBody.isNotEmpty ? _fixServerEncoding(errorBody) : streamedResponse.reasonPhrase;
         if (mounted) {
            setState(() {
              _messages.last = Message.bot('API Error (${streamedResponse.statusCode}): $errorDetails');
              _awaitingReply = false;
            });
            _httpClient?.close();
            completer.complete();
         }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.last = Message.bot('Failed to send request: $e');
          _awaitingReply = false;
        });
        _httpClient?.close();
        completer.complete();
      }
    }
    return completer.future;
  }

  void _regenerateResponse(int botMessageIndex) {
    int userMessageIndex = botMessageIndex - 1;
    if (userMessageIndex >= 0 && _messages[userMessageIndex].sender == Sender.user) {
      String lastUserPrompt = _messages[userMessageIndex].text;
      setState(() => _messages.removeAt(botMessageIndex));
      _generateResponse(lastUserPrompt);
    }
  }
  
  void _stopGeneration() {
    _streamSubscription?.cancel();
    _httpClient?.close();
    if(mounted) {
      setState(() {
        if (_awaitingReply && _messages.isNotEmpty && _messages.last.isStreaming) {
           _messages.last = Message.bot(_messages.last.text, isStreaming: false);
        }
        _awaitingReply = false;
      });
    }
  }

  void startNewChat() {
    setState(() {
      _awaitingReply = false;
      _editingMessageId = null;
      _streamSubscription?.cancel();
      _httpClient?.close();
      _messages.clear();
      final selectedCharacter = _characterService.selectedCharacter;
      if (selectedCharacter != null) {
        _messages.add(Message.bot('Fresh chat started with ${selectedCharacter.name}. How can I help?'));
      } else {
        _messages.add(Message.bot('Fresh chat started. How can I help?'));
      }
    });
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic);
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _awaitingReply) return;

    final isEditing = _editingMessageId != null;
    if (isEditing) {
      final messageIndex = _messages.indexWhere((m) => m.id == _editingMessageId);
      if (messageIndex != -1) {
        setState(() {
          _messages.removeRange(messageIndex, _messages.length);
        });
      }
    }
    
    _controller.clear();
    setState(() {
      _messages.add(Message.user(text));
      _editingMessageId = null;
    });

    _scrollDown();
    HapticFeedback.lightImpact();
    await _generateResponse(text);
  }

  @override
  Widget build(BuildContext context) {
    final emptyChat = _messages.length <= 1;
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            itemCount: _messages.length,
            itemBuilder: (_, index) {
              final message = _messages[index];
              return _MessageBubble(
                message: message,
                onRegenerate: () => _regenerateResponse(index),
                onBookmark: () => widget.onBookmark(message),
                onUserMessageTap: () => _showUserMessageOptions(context, message),
              );
            },
          ),
        ),
        if (emptyChat && _editingMessageId == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _prompts.map((p) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(p),
                            selected: false,
                            onSelected: (_) {
                              _controller.text = p;
                              _send();
                            },
                            side: BorderSide.none,
                            backgroundColor: Colors.white,
                            labelStyle: const TextStyle(fontSize: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 1,
                          ),
                        )).toList(),
              ),
            ),
          ),
        SafeArea(
          top: false,
          left: false,
          right: false,
          child: _InputBar(
            controller: _controller,
            onSend: _send,
            onStop: _stopGeneration,
            awaitingReply: _awaitingReply,
            isEditing: _editingMessageId != null,
            onCancelEdit: _cancelEditing,
            onFilesUploaded: (content) {
              _controller.text = content;
              _send();
            },
          ),
        ),
      ],
    );
  }
}

/* ----------------------------------------------------------
   MESSAGE BUBBLE & ACTION BUTTONS
---------------------------------------------------------- */
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    this.onRegenerate,
    this.onBookmark,
    this.onUserMessageTap,
  });
  final Message message;
  final VoidCallback? onRegenerate;
  final VoidCallback? onBookmark;
  final VoidCallback? onUserMessageTap;

  @override
  Widget build(BuildContext context) {
    final isBot = message.sender == Sender.bot;
    final isUser = message.sender == Sender.user;
    final showActions = isBot && !message.isStreaming && message.text.isNotEmpty && onRegenerate != null;
    final isBookmarkable = isBot && !message.isStreaming && message.text.isNotEmpty;

    Widget bubbleContent = Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: isBot ? EdgeInsets.zero : const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      constraints: const BoxConstraints(maxWidth: 640),
      decoration: isBot ? null : BoxDecoration(
        color: const Color(0xFFE5E5E5),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 1))],
      ),
      child: isBot
          ? MarkdownBody(
              data: message.text,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(fontSize: 15, height: 1.45, color: Colors.black87),
                code: const TextStyle(backgroundColor: Color(0xFFF1F1F1), fontFamily: 'monospace'),
              ),
            )
          : Text(message.text, style: const TextStyle(fontSize: 15, height: 1.45, color: Colors.black87)),
    );

    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Column(
        crossAxisAlignment: isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          if (isUser)
            InkWell(
              onTap: onUserMessageTap,
              borderRadius: BorderRadius.circular(20),
              child: bubbleContent,
            )
          else
            bubbleContent,
          if (showActions)
            Padding(
              padding: const EdgeInsets.only(left: 8.0, top: 4, bottom: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionButton(
                    icon: Icons.copy_all_outlined,
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: message.text));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(duration: Duration(seconds: 2), content: Text('Copied to clipboard')));
                    },
                  ),
                  const SizedBox(width: 4),
                  _ActionButton(icon: Icons.refresh_rounded, onTap: onRegenerate!),
                  if (isBookmarkable && onBookmark != null) ...[
                    const SizedBox(width: 4),
                    _ActionButton(icon: Icons.bookmark_add_outlined, onTap: onBookmark!),
                  ],
                ],
              ),
            )
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(16),
        child: Padding(padding: const EdgeInsets.all(6.0), child: Icon(icon, color: Colors.grey.shade600, size: 20)),
      ),
    );
  }
}

/* ----------------------------------------------------------
   INPUT BAR – Now with Editing State
---------------------------------------------------------- */
class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.onStop,
    required this.awaitingReply,
    required this.isEditing,
    required this.onCancelEdit,
    this.onFilesUploaded,
  });
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final bool awaitingReply;
  final bool isEditing;
  final VoidCallback onCancelEdit;
  final void Function(String)? onFilesUploaded;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Column(
        children: [
          if (isEditing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              margin: const EdgeInsets.only(left: 20, right: 20, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Expanded(child: Text("Editing message...", style: TextStyle(color: Colors.black87))),
                  IconButton(icon: const Icon(Icons.close), onPressed: onCancelEdit, iconSize: 20),
                ],
              ),
            ),
          Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 4))],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (onFilesUploaded != null)
                  FileUploadWidget(onFilesUploaded: onFilesUploaded),
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: !awaitingReply,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    cursorColor: Colors.blue,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    decoration: InputDecoration(
                      hintText: awaitingReply ? 'AhamAI is responding...' : 'Message AhamAI…',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    ),
                  ),
                ),
                IconButton(
                  padding: const EdgeInsets.all(12),
                  onPressed: awaitingReply ? onStop : onSend,
                  icon: Icon(awaitingReply ? Icons.stop_circle : Icons.arrow_outward, color: awaitingReply ? Colors.red : Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}