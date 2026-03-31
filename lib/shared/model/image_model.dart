import 'dart:typed_data';

enum AppImageSource {
  asset,
  network,
  file,
  memory,
}

class ImageViewData {
  final AppImageSource source;
  final String? path;           // asset / network / file
  final Uint8List? bytes;       // memory
  final Map<String, String>? headers;

  const ImageViewData.asset(this.path)
      : source = AppImageSource.asset,
        bytes = null,
        headers = null;

  const ImageViewData.network(this.path, {this.headers})
      : source = AppImageSource.network,
        bytes = null;

  const ImageViewData.file(this.path)
      : source = AppImageSource.file,
        bytes = null,
        headers = null;

  const ImageViewData.memory(this.bytes)
      : source = AppImageSource.memory,
        path = null,
        headers = null;
}