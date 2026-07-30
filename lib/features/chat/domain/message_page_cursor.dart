/// Cursor for paginating chat messages.
class MessagePageCursor {
  final DateTime timestamp;
  final String messageId;

  const MessagePageCursor({
    required this.timestamp,
    required this.messageId,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessagePageCursor &&
        other.timestamp == timestamp &&
        other.messageId == messageId;
  }

  @override
  int get hashCode => timestamp.hashCode ^ messageId.hashCode;
}
