import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';

class ExportHelper {
  // ── Export CSV ───────────────────────────────────────────
  static Future<void> exportCsv(
      BuildContext context, Uint8List bytes) async {
    try {
      if (kIsWeb) {
        // Web — browser download
        final blob = html.Blob([bytes], 'text/csv');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', 'patients_report.csv')
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        // Windows/Android — save to Downloads folder
        final dir = await _getDownloadDir();
        final file = File('${dir.path}/patients_report.csv');
        await file.writeAsBytes(bytes);
        if (context.mounted) {
          _showSuccessSnackbar(
              context, 'CSV saved to: ${file.path}');
        }
        return;
      }
      if (context.mounted) {
        _showSuccessSnackbar(context, 'CSV downloaded successfully!');
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorSnackbar(context, 'Failed to export CSV');
      }
    }
  }

  // ── Export PDF ───────────────────────────────────────────
  static Future<void> exportPdf(
      BuildContext context, Uint8List bytes,
      String patientName) async {
    try {
      final filename =
          '${patientName.replaceAll(' ', '_')}_report.pdf';

      if (kIsWeb) {
        final blob = html.Blob([bytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', filename)
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        final dir = await _getDownloadDir();
        final file = File('${dir.path}/$filename');
        await file.writeAsBytes(bytes);
        if (context.mounted) {
          _showSuccessSnackbar(
              context, 'PDF saved to: ${file.path}');
        }
        return;
      }
      if (context.mounted) {
        _showSuccessSnackbar(context, 'PDF downloaded successfully!');
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorSnackbar(context, 'Failed to export PDF');
      }
    }
  }

  // ── Get download directory ───────────────────────────────
  static Future<Directory> _getDownloadDir() async {
    if (Platform.isWindows) {
      final home = Platform.environment['USERPROFILE'] ?? '';
      final downloads = Directory('$home\\Downloads');
      if (await downloads.exists()) return downloads;
      return await getApplicationDocumentsDirectory();
    } else if (Platform.isAndroid) {
      return Directory('/storage/emulated/0/Download');
    } else {
      return await getApplicationDocumentsDirectory();
    }
  }

  static void _showSuccessSnackbar(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  static void _showErrorSnackbar(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
    ));
  }
}