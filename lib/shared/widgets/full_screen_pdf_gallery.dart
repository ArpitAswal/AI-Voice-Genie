import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../core/extensions/build_context_extensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/pdf_document_service.dart';
import '../../core/utils/status_message_utils.dart';
import '../../core/utils/storage_permission_helper.dart';
import '../../features/chat/domain/message_model.dart';

/// Full-screen responsive document viewer & gallery for PDF attachments.
///
/// Features:
/// - Displays all attached PDFs in an elegant, responsive modal.
/// - Adaptive layout: Mobile full-width list, Tablet centered card canvas (maxWidth 600dp).
/// - Top bar: Close button, document counter pill (`N Documents`), and "Download All" button.
/// - Per-card actions: Quick "Open" via native system viewer, "Download" to public Downloads, and "Share".
class FullScreenPdfGallery extends StatefulWidget {
  final List<PdfAttachmentInfo> pdfs;
  final int initialIndex;

  const FullScreenPdfGallery({
    super.key,
    required this.pdfs,
    this.initialIndex = 0,
  });

  /// Opens the full-screen document gallery with a smooth fade transition.
  static void open(
    BuildContext context, {
    required List<PdfAttachmentInfo> pdfs,
    int initialIndex = 0,
  }) {
    if (pdfs.isEmpty) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.88),
        pageBuilder: (_, __, ___) => FullScreenPdfGallery(
          pdfs: pdfs,
          initialIndex: initialIndex.clamp(0, pdfs.length - 1),
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<FullScreenPdfGallery> createState() => _FullScreenPdfGalleryState();
}

class _FullScreenPdfGalleryState extends State<FullScreenPdfGallery> {
  final Set<String> _downloadingIds = {};
  bool _isDownloadingAll = false;

  Future<void> _openPdf(PdfAttachmentInfo pdf) async {
    final openResult = await PdfDocumentService.instance.openPdf(pdf);
    if (openResult.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            openResult.message.isNotEmpty
                ? openResult.message
                : 'Cannot open ${pdf.name}',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _downloadPdf(PdfAttachmentInfo pdf) async {
    if (_downloadingIds.contains(pdf.name)) return;

    // 1. Storage permission check
    final hasPermission =
        await StoragePermissionHelper.requestDownloadPermission(
      context,
      isImage: false,
    );
    if (!hasPermission || !mounted) return;

    setState(() => _downloadingIds.add(pdf.name));

    // 2. Show downloading SnackBar
    context.showDownloadingSnackBar(
      context.l10n.downloadingPdfFile(pdf.name),
    );

    try {
      final bytes = await PdfDocumentService.instance.resolvePdfBytes(pdf);
      if (bytes == null || bytes.isEmpty) {
        AnalyticsService.instance.logPdfDownload(
          result: 'failure',
          fileSizeBytes: pdf.fileSizeBytes,
          failureReason: 'empty_bytes',
        );
        if (mounted) {
          context.cancelDownloadingSnackBar();
          context.showErrorToast(context.l10n.pdfSaveFailed);
        }
        return;
      }

      final saved = await PdfDocumentService.instance.savePdfToPublicDownloads(
        bytes: bytes,
        fileName: pdf.name,
      );

      AnalyticsService.instance.logPdfDownload(
        result: saved ? 'success' : 'failure',
        fileSizeBytes: bytes.length,
        failureReason: saved ? '' : 'save_failed',
      );

      if (mounted) {
        context.cancelDownloadingSnackBar();
        if (saved) {
          context.showSuccessToast(context.l10n.pdfSavedToDownloads(pdf.name));
        } else {
          context.showErrorToast(context.l10n.pdfSaveFailed);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _downloadingIds.remove(pdf.name));
      }
    }
  }

  Future<void> _downloadAll() async {
    if (_isDownloadingAll || widget.pdfs.isEmpty) return;

    // 1. Storage permission check
    final hasPermission =
        await StoragePermissionHelper.requestDownloadPermission(
      context,
      isImage: false,
    );
    if (!hasPermission || !mounted) return;

    setState(() => _isDownloadingAll = true);

    // 2. Show downloading SnackBar
    context.showDownloadingSnackBar(
      context.l10n.downloadingPdfsCount(widget.pdfs.length.toString()),
    );

    int savedCount = 0;
    try {
      for (final pdf in widget.pdfs) {
        try {
          final bytes = await PdfDocumentService.instance.resolvePdfBytes(pdf);
          if (bytes != null && bytes.isNotEmpty) {
            final saved =
                await PdfDocumentService.instance.savePdfToPublicDownloads(
              bytes: bytes,
              fileName: pdf.name,
            );
            if (saved) savedCount++;
          }
        } catch (e) {
          debugPrint('⚠️ Error downloading PDF ${pdf.name}: $e');
        }
      }

      if (mounted) {
        context.cancelDownloadingSnackBar();
        if (savedCount > 0) {
          context.showSuccessToast(
            context.l10n.pdfsSavedToDownloads(savedCount.toString()),
          );
        } else {
          context.showErrorToast(context.l10n.pdfsSaveFailed);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloadingAll = false);
      }
    }
  }

  Future<void> _sharePdf(PdfAttachmentInfo pdf) async {
    try {
      final safeName = pdf.name.endsWith('.pdf') ? pdf.name : '${pdf.name}.pdf';
      final docsDir = await getApplicationDocumentsDirectory();
      final cachedFile = File('${docsDir.path}/generated_pdfs/$safeName');
      String? localPath;

      if (await cachedFile.exists() && await cachedFile.length() > 0) {
        localPath = cachedFile.path;
      } else {
        final bytes = await PdfDocumentService.instance.resolvePdfBytes(pdf);
        if (bytes != null && bytes.isNotEmpty) {
          localPath = await PdfDocumentService.instance.savePdfLocally(
            bytes: bytes,
            fileName: safeName,
          );
        }
      }

      if (localPath != null && await File(localPath).exists()) {
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile(localPath, mimeType: 'application/pdf', name: safeName)
            ],
            subject: pdf.name,
          ),
        );
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot share ${pdf.name}: file unavailable'),
            backgroundColor: AppColors.darkError,
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Error sharing PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share PDF: $e'),
            backgroundColor: AppColors.darkError,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = context.isTablet;
    final total = widget.pdfs.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$total ${total == 1 ? 'Document' : 'Documents'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Tooltip(
                    message: 'Download all PDFs',
                    child: IconButton(
                      icon: _isDownloadingAll
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.download_rounded,
                              color: Colors.white, size: 26),
                      onPressed: _downloadAll,
                    ),
                  ),
                ],
              ),
            ),

            // Document List
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isTablet ? 600.0 : double.infinity,
                  ),
                  child: ListView.separated(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 24.0 : 16.0,
                      vertical: 12.0,
                    ),
                    itemCount: total,
                    separatorBuilder: (_, __) => const SizedBox(height: 12.0),
                    itemBuilder: (context, index) {
                      final pdf = widget.pdfs[index];
                      final isDownloading = _downloadingIds.contains(pdf.name);

                      return Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _openPdf(pdf),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: AppColors.darkError
                                              .withValues(alpha: 0.25),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.picture_as_pdf_rounded,
                                          size: 26,
                                          color: AppColors.lightError,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              pdf.name,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              pdf.fileSizeLabel.isNotEmpty
                                                  ? '${pdf.fileSizeLabel} • PDF'
                                                  : 'PDF Document',
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withValues(alpha: 0.65),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.white,
                                            side: BorderSide(
                                              color: Colors.white
                                                  .withValues(alpha: 0.25),
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 10),
                                          ),
                                          icon: const Icon(
                                              Icons.visibility_outlined,
                                              size: 18),
                                          label: const Text('Open'),
                                          onPressed: () => _openPdf(pdf),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton.outlined(
                                        style: IconButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          side: BorderSide(
                                            color: Colors.white
                                                .withValues(alpha: 0.25),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        icon: isDownloading
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Icon(Icons.download_rounded,
                                                size: 20),
                                        tooltip: 'Download',
                                        onPressed: () => _downloadPdf(pdf),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton.outlined(
                                        style: IconButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          side: BorderSide(
                                            color: Colors.white
                                                .withValues(alpha: 0.25),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        icon: const Icon(Icons.share_outlined,
                                            size: 20),
                                        tooltip: 'Share',
                                        onPressed: () => _sharePdf(pdf),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
