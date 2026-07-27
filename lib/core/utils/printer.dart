import 'package:printing/printing.dart';

class PrinterService {
  static Future<void> printPdf(String filePath) async {
    await Printing.layoutPdf(onLayout: (_) => File(filePath).readAsBytes());
  }
}
