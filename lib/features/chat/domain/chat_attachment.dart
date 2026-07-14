import 'dart:typed_data';

enum ChatAttachmentType {
  image,
  pdf,
}

class ChatAttachment {
  final ChatAttachmentType type;
  final String name;
  final Uint8List bytes;
  final String? path;
  final String? mimeType;
  final int? fileSizeBytes;

  const ChatAttachment({
    required this.type,
    required this.name,
    required this.bytes,
    this.path,
    this.mimeType,
    this.fileSizeBytes,
  });

  bool get isImage => type == ChatAttachmentType.image;
  bool get isPdf => type == ChatAttachmentType.pdf;

  String get fileSizeLabel {
    final size = fileSizeBytes ?? bytes.lengthInBytes;
    if (size >= 1000 * 1000) {
      return '${(size / (1000 * 1000)).toStringAsFixed(1)} MB';
    }
    return '${(size / 1000).toStringAsFixed(0)} KB';
  }
}
