import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_markdown_latex/flutter_markdown_latex.dart';
import 'package:ecs_ai/app/theme/app_colors.dart';

import 'package:flutter/services.dart';
import 'package:ecs_ai/shared/widgets/custom_snackbar.dart';

class AiChatPanel extends StatefulWidget {
  const AiChatPanel({
    super.key,
    required this.chatHistory,
    required this.onSendPrompt,
    required this.onApplyFix,
  });

  final List<Map<String, String>> chatHistory;
  final void Function(String prompt) onSendPrompt;
  final void Function(String jsonString) onApplyFix;

  @override
  State<AiChatPanel> createState() => _AiChatPanelState();
}

class _AiChatPanelState extends State<AiChatPanel> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(AiChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.chatHistory.length != oldWidget.chatHistory.length) {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 50), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSendPrompt(text);
      _controller.clear();
      _scrollToBottom();
    }
  }

  String? _extractJsonBlock(String text) {
    final regex = RegExp(r'```json\s*(\{.*?\})\s*```', dotAll: true);
    final matches = regex.allMatches(text);
    if (matches.isNotEmpty) {
      return matches.last.group(1);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(8.0),
            itemCount: widget.chatHistory.length,
            itemBuilder: (context, index) {
              final msg = widget.chatHistory[index];
              final isUser = msg['role'] == 'user';
              final content = msg['content'] ?? '';
              final jsonPayload = !isUser ? _extractJsonBlock(content) : null;
              
              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8.0),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isUser
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isUser
                          ? AppColors.primary.withValues(alpha: 0.2)
                          : AppColors.surfaceVariant,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      MarkdownBody(
                        data: content,
                        selectable: true,
                        builders: {
                          'latex': LatexElementBuilder(
                            textStyle: TextStyle(
                              color: isUser ? AppColors.primary : AppColors.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                        },
                        extensionSet: md.ExtensionSet(
                          [LatexBlockSyntax()],
                          [LatexInlineSyntax()],
                        ),
                        styleSheet: MarkdownStyleSheet(
                          p: TextStyle(
                            fontSize: 12,
                            color: isUser ? AppColors.primary : AppColors.textPrimary,
                          ),
                          code: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            backgroundColor: AppColors.surface,
                          ),
                          codeblockDecoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.surfaceVariant),
                          ),
                        ),
                      ),
                      if (!isUser && content.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: content));
                                  CustomSnackBar.show(
                                    context,
                                    message: 'Copied to clipboard',
                                  );
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(4.0),
                                  child: Icon(
                                    Icons.copy_rounded,
                                    size: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              if (jsonPayload != null) ...[
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  onPressed: () => widget.onApplyFix(jsonPayload),
                                  icon: const Icon(Icons.build_circle, size: 16),
                                  label: const Text('Apply Circuit Fix'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: AppColors.surface,
                                    textStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Container(
          padding: const EdgeInsets.all(8.0),
          color: AppColors.surface,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Ask the AI...',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: AppColors.surfaceVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: AppColors.surfaceVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                  onSubmitted: (_) => _handleSend(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _handleSend,
                icon: const Icon(Icons.send_rounded, size: 16),
                color: AppColors.primary,
                splashRadius: 16,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
