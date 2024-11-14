import 'package:http/http.dart' as http;

class PrinterService {
  final String rawBtUrl = 'http://localhost:port/print'; // Replace with your actual RawBT URL and port

  Future<void> printReceipt(String receiptData) async {
    try {
      final response = await http.post(
        Uri.parse(rawBtUrl),
        headers: {
          'Content-Type': 'text/plain', // RawBT usually supports plain text data
        },
        body: receiptData,
      );

      if (response.statusCode == 200) {
        print("Receipt printed successfully");
      } else {
        print("Failed to print receipt: ${response.statusCode}");
      }
    } catch (e) {
      print("Error printing receipt: $e");
    }
  }
}
