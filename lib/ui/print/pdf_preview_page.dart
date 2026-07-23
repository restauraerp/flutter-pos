import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../theme.dart';

/// In-app PDF preview with a guaranteed way back.
///
/// Printing used to hand off directly to the platform print flow, which on the
/// desktop targets could leave the operator on a preview with no obvious way to
/// return. Hosting [PdfPreview] inside a [Scaffold] gives every platform the
/// same AppBar back button, while the preview's own toolbar keeps the Print and
/// Share actions.
class PdfPreviewPage extends StatelessWidget {
  const PdfPreviewPage({
    super.key,
    required this.title,
    required this.documentName,
    required this.buildDocument,
  });

  /// Shown in the AppBar, e.g. `Receipt · #1024`.
  final String title;

  /// File name used when printing or sharing the document.
  final String documentName;

  /// Produces the PDF bytes for the requested page format.
  final FutureOr<Uint8List> Function(PdfPageFormat format) buildDocument;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      body: PdfPreview(
        build: buildDocument,
        pdfFileName: documentName,
        // The layout is fixed to the thermal roll, so hide the controls that
        // would let the operator change it.
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        loadingWidget: const CircularProgressIndicator(),
        previewPageMargin: const EdgeInsets.all(12),
        onError: (context, error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not render the document.\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ),
      ),
    );
  }
}
