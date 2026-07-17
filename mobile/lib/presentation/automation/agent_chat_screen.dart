import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/automation.model.dart';
import '../../data/repositories/automation.repository.dart';
import '../../controllers/dashboard.controller.dart';
import '../../core/utils/extensions.dart';

const Color _primary = Color(0xFF06457F);
const Color _secondary = Color(0xFF06457F);
const Color _darkBg = Color(0xFF33343B);
const Color _cardDark = Color(0xFF06457F);
const Color _darkTextPrimary = Color(0xFFFFFFFF);
const Color _darkTextSecondary = Color(0xFFFFFFFF);
const Color _lightTextPrimary = Color(0xFF06457F);
const Color _lightTextSecondary = Color(0xFF06457F);
const Color _borderDark = Color(0xFF06457F);
const Color _borderLight = Color(0xFF06457F);

final _chatHistoryProvider = StateProvider<List<ChatMessage>>((ref) => []);

class AgentChatScreen extends ConsumerStatefulWidget {
  const AgentChatScreen({super.key});

  @override
  ConsumerState<AgentChatScreen> createState() => _AgentChatScreenState();
}

class _AgentChatScreenState extends ConsumerState<AgentChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final history = ref.read(_chatHistoryProvider);
      if (history.isEmpty) {
        ref.read(_chatHistoryProvider.notifier).state = [
          ChatMessage(
            id: const Uuid().v4(),
            role: 'assistant',
            content:
                'Hello! I\'m your Neuro Touch AI assistant. I can help you control your devices, create automations, and answer questions about your smart home. What would you like to do?',
            timestamp: DateTime.now(),
          ),
        ];
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isTyping) return;

    _textController.clear();

    final userMsg = ChatMessage(
      id: const Uuid().v4(),
      role: 'user',
      content: text,
      timestamp: DateTime.now(),
    );

    ref.read(_chatHistoryProvider.notifier).state = [
      ...ref.read(_chatHistoryProvider),
      userMsg,
    ];

    setState(() => _isTyping = true);
    _scrollToBottom();

    try {
      final homeId = ref.read(homeIdProvider);
      final history = ref.read(_chatHistoryProvider);
      final response = await ref.read(automationRepositoryProvider).sendChatMessage(
            homeId ?? '',
            text,
            history,
          );

      if (!mounted) return;

      final assistantMsg = ChatMessage(
        id: const Uuid().v4(),
        role: 'assistant',
        content: response,
        timestamp: DateTime.now(),
      );

      ref.read(_chatHistoryProvider.notifier).state = [
        ...ref.read(_chatHistoryProvider),
        assistantMsg,
      ];
    } catch (e) {
      if (!mounted) return;
      final errMsg = ChatMessage(
        id: const Uuid().v4(),
        role: 'assistant',
        content: 'Sorry, I encountered an error. Please try again.',
        timestamp: DateTime.now(),
      );
      ref.read(_chatHistoryProvider.notifier).state = [
        ...ref.read(_chatHistoryProvider),
        errMsg,
      ];
    } finally {
      if (mounted) setState(() => _isTyping = false);
      _scrollToBottom();
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

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final messages = ref.watch(_chatHistoryProvider);
    final bgColor = isDark ? _darkBg : const Color(0xFFF2F3F5);
    final appBarColor = isDark ? _darkBg : const Color(0xFF194B85);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AI Assistant',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white)),
            Text(
              'Powered by local LLM',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  color: isDark ? _darkTextSecondary : Colors.white70),
            ),
          ],
        ),
        backgroundColor: appBarColor,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
      ),
      body: Column(
        children: [
          // Message list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (_, index) {
                if (index == messages.length && _isTyping) {
                  return const _TypingIndicator();
                }
                return _ChatBubble(
                  message: messages[index],
                  isDark: isDark,
                );
              },
            ),
          ),

          // Input bar
          Container(
            padding: EdgeInsets.fromLTRB(
              12, 8, 12, MediaQuery.paddingOf(context).bottom + 8),
            decoration: BoxDecoration(
              color: isDark ? _cardDark : const Color(0xFF194B85),
              border: Border(
                top: BorderSide(
                  color: isDark ? _borderDark : _borderLight,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: GoogleFonts.inter(fontSize: 15, color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      hintText: 'Ask me anything about your home...',
                      hintStyle: GoogleFonts.inter(
                        color: isDark ? _darkTextSecondary : Colors.black54,
                        fontSize: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: isDark ? _darkBg : Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    maxLines: null,
                    minLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_primary, _secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
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

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isDark;

  const _ChatBubble({required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final bubbleBg = isUser
        ? _primary
        : (isDark ? _cardDark : const Color(0xFF194B85));
    final textColor = isUser
        ? Colors.white
        : (isDark ? _darkTextPrimary : Colors.white);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_primary, _secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.smart_toy_outlined,
                  color: Colors.white, size: 18),
            ),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.72),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bubbleBg,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: Text(
                message.content,
                style: GoogleFonts.inter(color: textColor, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_primary, _secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.smart_toy_outlined,
              color: Colors.white, size: 18),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF45484D),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
              bottomLeft: Radius.circular(4),
            ),
          ),
          child: FadeTransition(
            opacity: _anim,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dot(),
                const SizedBox(width: 4),
                _Dot(delay: 150),
                const SizedBox(width: 4),
                _Dot(delay: 300),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final int delay;
  const _Dot({this.delay = 0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: _darkTextSecondary,
        shape: BoxShape.circle,
      ),
    );
  }
}
