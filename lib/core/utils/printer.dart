import 'dart:io';
import 'package:printing/printing.dart';

class PrinterService {
  static Future<void> printPdf(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await Printing.layoutPdf(onLayout: (_) => file.readAsBytes());
    }
  }
}
