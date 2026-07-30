/// Cursor for paginating chat conversations.
class ConversationPageCursor {
  final DateTime lastMessageAt;
  final String conversationId;

  const ConversationPageCursor({
    required this.lastMessageAt,
    required this.conversationId,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConversationPageCursor &&
        other.lastMessageAt == lastMessageAt &&
        other.conversationId == conversationId;
  }

  @override
  int get hashCode => lastMessageAt.hashCode ^ conversationId.hashCode;
}
