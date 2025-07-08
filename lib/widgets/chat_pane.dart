import 'package:flutter/material.dart';

const kCream = Color(0xFFFEF1D6);

class ChatPane extends StatelessWidget {
  const ChatPane({
    super.key,
    required this.messages,
    required this.controller,
    required this.onSend,
    required this.isProcessing,
  });

  final List<Msg> messages;              // assume newest at index 0
  final TextEditingController controller;
  final ValueChanged<String> onSend;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        // ── bubbles ──────────────────────────────────────────────
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: kCream,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(12),
            child: ListView.builder(
              reverse: true,                      // <-- key line
              itemCount: messages.length,
              itemBuilder: (_, i) {
                final m = messages[i];
                return Align(
                  alignment:
                      m.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    constraints:
                        const BoxConstraints(maxWidth: 240, minWidth: 60),
                    decoration: BoxDecoration(
                      color: m.isUser
                          ? cs.primary.withOpacity(.15)
                          : cs.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(m.text),
                  ),
                );
              },
            ),
          ),
        ),

        // ── “Typing…” Indicator ───────────────────────────────────
        if (isProcessing) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              const Text(
                'Plant is thinking…',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 8),

        // ── input ────────────────────────────────────────────────
        TextField(
          controller: controller,
          onSubmitted: (text) {
            if (text.trim().isNotEmpty && !isProcessing) {
              onSend(text);
            }
          },
          decoration: InputDecoration(
            hintText: 'Say something…',
            filled: true,
            fillColor: kCream,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: IconButton(
              icon: const Icon(Icons.send),
              onPressed: () {
                final txt = controller.text.trim();
                if (txt.isNotEmpty && !isProcessing) {
                  onSend(txt);
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

class Msg {
  Msg(this.text, this.isUser);
  final String text;
  final bool isUser;
}
