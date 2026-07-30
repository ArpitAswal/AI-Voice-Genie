/// Represents a paginated slice of chat data (conversations or messages).
class ChatPage<T> {
  /// The list of items in this page.
  final List<T> items;

  /// The cursor to use to fetch the next page.
  /// If null, there is no more data.
  final Object? nextCursor;

  /// True if there are more items to load after this page.
  final bool hasMore;

  const ChatPage({
    required this.items,
    this.nextCursor,
    required this.hasMore,
  });

  /// An empty page representing no data.
  factory ChatPage.empty() => const ChatPage(
        items: [],
        nextCursor: null,
        hasMore: false,
      );
}
