import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_markdown_latex/flutter_markdown_latex.dart';
import 'package:ecs_ai/app/theme/app_colors.dart';
import 'package:ecs_ai/shared/widgets/custom_snackbar.dart';

class IdeChatPanel extends StatefulWidget {
  const IdeChatPanel({
    super.key,
    required this.activeSessionId,
    required this.chatSessions,
    required this.onSessionSelected,
    required this.onNewChat,
    this.isGenerating = false,
    required this.chatHistory,
    required this.streamingText,
    this.currentTurnActions = const [],
    required this.onSendPrompt,
    required this.onApplyActions,
    required this.onStop,
    this.workingStatus = 'Thinking',
    this.tokenUsage = const {},
  });

  final String? activeSessionId;
  final List<Map<String, dynamic>> chatSessions;
  final bool isGenerating;
  final void Function(String) onSessionSelected;
  final VoidCallback onNewChat;

  final List<Map<String, dynamic>> chatHistory;
  final String streamingText;
  final List<Map<String, dynamic>> currentTurnActions;
  final void Function(String prompt) onSendPrompt;
  final void Function(List<Map<String, dynamic>> actions) onApplyActions;
  final VoidCallback onStop;
  final String workingStatus;
  final Map<String, int> tokenUsage;

  @override
  State<IdeChatPanel> createState() => _IdeChatPanelState();
}

class _IdeChatPanelState extends State<IdeChatPanel> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(IdeChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.chatHistory.length != oldWidget.chatHistory.length ||
        widget.streamingText != oldWidget.streamingText) {
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

  // String _cleanContent(String content) {
  //   // Remove completed JSON tool-call blocks
  //   var cleaned = content.replaceAll(RegExp(r'```json\s*.*?(?:```|$)', dotAll: true), '');
  //   // If there's an unclosed block without the closing ```, remove it too
  //   final unclosedIndex = cleaned.lastIndexOf('```json');
  //   if (unclosedIndex != -1) {
  //     cleaned = cleaned.substring(0, unclosedIndex);
  //   }
  //   return cleaned.trim();
  // }

  List<Map<String, dynamic>> _extractActions(String content) {
    final regex = RegExp(r'```json\s*(.*?)\s*```', dotAll: true);
    final match = regex.firstMatch(content);
    if (match != null) {
      final jsonBlock = match.group(1);
      if (jsonBlock != null) {
        final List<Map<String, dynamic>> actions = [];
        final lines = jsonBlock.split('\n');
        for (final line in lines) {
          if (line.trim().isEmpty) continue;
          try {
            final parsed = jsonDecode(line.trim());
            if (parsed is Map<String, dynamic> && parsed.containsKey('action_type')) {
              actions.add(parsed);
            }
          } catch (e) {
            // ignore malformed lines
          }
        }
        return actions;
      }
    }
    return [];
  }

  Widget _buildMarkdown(String data, bool isUser) {
    return MarkdownBody(
      data: data,
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
        blockquoteDecoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: const Border(left: BorderSide(color: AppColors.error, width: 4)),
        ),
        blockquote: const TextStyle(color: AppColors.error),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rawHistory = List<Map<String, dynamic>>.from(widget.chatHistory);
    if (widget.streamingText.isNotEmpty || widget.currentTurnActions.isNotEmpty) {
      rawHistory.add({
        'role': 'assistant', 
        'content': widget.streamingText,
        'actions': widget.currentTurnActions,
      });
    }

    final displayHistory = <Map<String, dynamic>>[];
    for (final msg in rawHistory) {
      final role = msg['role'];
      final content = msg['content']?.toString() ?? '';
      
      if (role == 'user' && content.startsWith('System Action Result:')) {
        continue;
      }
      
      final isModel = role == 'model' || role == 'assistant';
      
      if (isModel && displayHistory.isNotEmpty) {
        final lastMsg = displayHistory.last;
        final lastRole = lastMsg['role'];
        if (lastRole == 'model' || lastRole == 'assistant') {
          final lastContent = lastMsg['content']?.toString() ?? '';
          
          final lastActionsRaw = lastMsg['actions'];
          final newActionsRaw = msg['actions'];
          
          dynamic mergedActions;
          if (lastActionsRaw == null && newActionsRaw == null) {
            mergedActions = null;
          } else {
            final l = lastActionsRaw != null ? List<Map<String, dynamic>>.from(lastActionsRaw) : <Map<String, dynamic>>[];
            final n = newActionsRaw != null ? List<Map<String, dynamic>>.from(newActionsRaw) : <Map<String, dynamic>>[];
            final combined = [...l, ...n];
            mergedActions = combined.isEmpty ? null : combined;
          }
          
          displayHistory.last = {
            'role': 'assistant',
            'content': '$lastContent\n\n$content'.trim(),
            'actions': mergedActions,
          };
          continue;
        }
      }
      
      displayHistory.add(Map<String, dynamic>.from(msg));
    }

    return Column(
      children: [
        // --- Header for Chat Sessions ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.divider)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.activeSessionId == null
                      ? 'New Conversation'
                      : (widget.chatSessions.firstWhere((s) => s['id'] == widget.activeSessionId, orElse: () => {'title': 'Conversation'})['title'] as String? ?? 'Conversation'),
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.history, size: 16, color: AppColors.textSecondary),
                tooltip: 'Chat History',
                color: AppColors.surface,
                offset: const Offset(0, 30),
                padding: EdgeInsets.zero,
                itemBuilder: (context) {
                  if (widget.chatSessions.isEmpty) {
                    return [
                      const PopupMenuItem<String>(
                        enabled: false,
                        child: Text(
                          'No previous sessions',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ),
                    ];
                  }
                  return widget.chatSessions.map((session) {
                    return PopupMenuItem<String>(
                      value: session['id'] as String?,
                      child: Text(
                        session['title'] as String? ?? 'Conversation',
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList();
                },
                onSelected: widget.onSessionSelected,
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.add, size: 18, color: AppColors.textPrimary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'New Chat',
                onPressed: widget.onNewChat,
              ),
            ],
          ),
        ),
        Expanded(
          child: Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                final dampened = event.scrollDelta.dy * 0.3;
                _scrollController.jumpTo(
                  (_scrollController.offset + dampened).clamp(
                    0.0,
                    _scrollController.position.maxScrollExtent,
                  ),
                );
              }
            },
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                thickness: 4,
                radius: const Radius.circular(2),
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(8.0),
                  itemCount: displayHistory.length,
                  itemBuilder: (context, index) {
              final msg = displayHistory[index];
              final isUser = msg['role'] == 'user';
              final rawContent = msg['content'] ?? '';
              final msgActionsRaw = msg['actions'];
              final actions = msgActionsRaw != null ? List<Map<String, dynamic>>.from(msgActionsRaw) : (!isUser ? _extractActions(rawContent) : <Map<String, dynamic>>[]);
              
              String thoughtText = '';
              String summaryText = '';
              
              if (!isUser) {
                 final regex = RegExp(r'```json\s*.*?(?:```|$)', dotAll: true);
                 final matches = regex.allMatches(rawContent);
                 if (matches.isNotEmpty) {
                    thoughtText = rawContent.substring(0, matches.first.start).trim();
                    summaryText = rawContent.substring(matches.last.end).trim();
                 } else {
                    if (widget.isGenerating && rawContent == widget.streamingText) {
                        thoughtText = rawContent.trim();
                    } else {
                        summaryText = rawContent.trim();
                    }
                 }
              } else {
                 summaryText = rawContent.trim();
              }

              if (thoughtText.isEmpty && summaryText.isEmpty && actions.isEmpty) return const SizedBox.shrink();

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
                      if (thoughtText.isNotEmpty)
                        Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            initiallyExpanded: widget.isGenerating && index == displayHistory.length - 1,
                            tilePadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 0.0),
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            collapsedShape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: const BorderSide(color: AppColors.surfaceVariant),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: const BorderSide(color: AppColors.primary),
                            ),
                            backgroundColor: AppColors.surface,
                            collapsedBackgroundColor: AppColors.surface,
                            leading: const Icon(Icons.psychology, size: 16, color: AppColors.textSecondary),
                            title: const Text(
                              '> Thought',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 12.0, right: 12.0, bottom: 12.0),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: _buildMarkdown(thoughtText, isUser),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (!isUser && widget.isGenerating && widget.streamingText == rawContent)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              '...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.workingStatus,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),

                      if (!isUser && actions.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 0.0),
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              collapsedShape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                                side: const BorderSide(color: AppColors.surfaceVariant),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                                side: const BorderSide(color: AppColors.primary),
                              ),
                              backgroundColor: AppColors.surface,
                              collapsedBackgroundColor: AppColors.surface,
                              leading: const Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
                              title: Text(
                                '> Executed ${actions.length} workspace action${actions.length > 1 ? 's' : ''}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 12.0, right: 12.0, bottom: 12.0),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Wrap(
                                      spacing: 16.0,
                                      runSpacing: 8.0,
                                      children: () {
                                        final counts = <String, Map<String, dynamic>>{};
                                        for (final action in actions) {
                                          final actionType = action['action_type'] as String? ?? 'unknown_action';
                                          IconData iconData = Icons.build_circle_outlined;
                                          String label = actionType;
                                          if (actionType == 'inspect_canvas') {
                                            iconData = Icons.search_rounded;
                                            label = 'Inspected Canvas';
                                          } else if (actionType == 'add_component') {
                                            iconData = Icons.add_circle_outline;
                                            label = 'Added Component';
                                          } else if (actionType == 'update_component') {
                                            iconData = Icons.edit_rounded;
                                            label = 'Updated Component';
                                          } else if (actionType == 'delete_element') {
                                            iconData = Icons.delete_outline;
                                            label = 'Deleted Element';
                                          } else if (actionType == 'add_wire') {
                                            iconData = Icons.timeline_rounded;
                                            label = 'Added Wire';
                                          }
                                          if (!counts.containsKey(label)) {
                                            counts[label] = {'count': 0, 'icon': iconData};
                                          }
                                          counts[label]!['count'] = (counts[label]!['count'] as int) + 1;
                                        }
                                        return counts.entries.map((entry) {
                                          final label = entry.key;
                                          final count = entry.value['count'] as int;
                                          final iconData = entry.value['icon'] as IconData;
                                          return Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(iconData, size: 14, color: AppColors.textSecondary),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${count}x $label',
                                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                              ),
                                            ],
                                          );
                                        }).toList();
                                      }(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (summaryText.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: (thoughtText.isNotEmpty || actions.isNotEmpty) && !isUser ? 8.0 : 0.0),
                          child: _buildMarkdown(summaryText, isUser),
                        ),
                      if (!isUser && (thoughtText.isNotEmpty || summaryText.isNotEmpty))
                        Align(
                          alignment: Alignment.centerRight,
                          child: InkWell(
                            onTap: () {
                              final textToCopy = [thoughtText, summaryText].where((t) => t.isNotEmpty).join('\n\n');
                              Clipboard.setData(ClipboardData(text: textToCopy));
                              CustomSnackBar.show(
                                context,
                                message: 'Copied to clipboard',
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.only(top: 8.0, left: 4.0, right: 4.0, bottom: 4.0),
                              child: Icon(
                                Icons.copy_rounded,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
            ),
          ),
        ),
        const Divider(height: 1),
        if (widget.tokenUsage.isNotEmpty && (widget.tokenUsage['input']! > 0 || widget.tokenUsage['output']! > 0))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.memory, size: 12, color: AppColors.textSecondary.withValues(alpha: 0.7)),
                const SizedBox(width: 4),
                Text(
                  'Input: ${widget.tokenUsage['input']} | Output: ${widget.tokenUsage['output']}',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
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
                    hintText: 'Ask the IDE Agent...',
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
                  onSubmitted: widget.isGenerating ? null : (_) => _handleSend(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: widget.isGenerating ? widget.onStop : _handleSend,
                icon: Icon(
                  widget.isGenerating ? Icons.stop_rounded : Icons.send_rounded, 
                  size: 16
                ),
                color: widget.isGenerating ? AppColors.textPrimary : AppColors.primary,
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
