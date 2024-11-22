import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/printer_service.dart';
import '../models/order.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import 'package:http/http.dart' as http;

class OrderDetailsScreen extends StatefulWidget {
  final Order order;

  const OrderDetailsScreen({Key? key, required this.order}) : super(key: key);

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final ApiService _apiService = ApiService();
  final DatabaseService _databaseService = DatabaseService();

  List<OrderDetail>? _orderDetails;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchOrderDetails();
  }

  Future<void> _fetchOrderDetails() async {
    try {
      final response = await _apiService.fetchOrderDetails(widget.order.orderId);
      setState(() {
        _orderDetails = response.items.values.toList();
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to fetch order details: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _printReceipt() async {
    const MethodChannel platform = MethodChannel('rawbt.intent.channel');

    if (_orderDetails == null) return;

    String receiptData = _formatReceipt(widget.order, _orderDetails!);

    try {
      await platform.invokeMethod('sendToRawBT', <String, dynamic>{
        'text': receiptData,
        'type': 'text/plain',
      });
      print('Print sent to RawBT');
    } on PlatformException catch (e) {
      print('Failed to print: ${e.message}');
    }
  }

 String _formatReceipt(Order order, List<OrderDetail> orderDetails) {
  String receipt = '';

  // Shop Details
  receipt += '--------------------------------\n';
  receipt += 'Shop ID: ${order.shopId}\n';
  receipt += 'Shop Address: ${order.shopAddress}\n';
  receipt += 'Phone: ${order.shopTelephone}\n';
  receipt += '--------------------------------\n';

  // Order Details
  receipt += 'Order #${order.orderId}\n';
  receipt += 'Date: ${order.orderTime}\n';
  receipt += 'Customer: ${order.customerName}\n';
  receipt += 'Phone: ${order.customerPhone}\n';
  receipt += 'Address: ${order.customerAddress}\n';
  receipt += '--------------------------------\n';

  // ESC/POS commands
  const String normalStyle = '\x1B\x21\x00'; // Normal text
  const String heightStyle = '\x1B\x21\x10'; // Double height only
  const int totalWidth = 48; // Total receipt width
  const int priceWidth = 10; // Width reserved for price
  const int itemNameWidth = totalWidth - priceWidth - 1; // Remaining width for item name

  // Order Items
  receipt += 'Order Items:\n';

  for (var item in orderDetails) {
    String itemName = '${item.quantity}x ${item.itemName}';
    String price = '€${(item.price * item.quantity).toStringAsFixed(2)}';

    // Apply double height style for items
    receipt += heightStyle;

    // Wrap item name
    List<String> wrappedLines = _wrapText(itemName, itemNameWidth);

    // Add the first line with the price aligned to the right
    receipt += wrappedLines[0].padRight(itemNameWidth) + price.padLeft(priceWidth) + '\n';

    // Add remaining lines for the item name
    for (int i = 1; i < wrappedLines.length; i++) {
      receipt += wrappedLines[i] + '\n';
    }

    // Add extras or notes
    if (item.extras.isNotEmpty) {
      for (var extra in item.extras) {
        receipt += '  + $extra\n';
      }
    }
    if (item.notes.isNotEmpty) {
      receipt += '  Note: ${item.notes}\n';
    }

    // Reset style to normal after each item
    receipt += normalStyle;
  }

  // Order Summary
  receipt += '--------------------------------\n';
  receipt += 'Sub Total:'.padRight(itemNameWidth) +
      '€${order.total.toStringAsFixed(2)}'.padLeft(priceWidth) +
      '\n';

  receipt += 'Discount:'.padRight(itemNameWidth) +
      '-€${order.discount.toStringAsFixed(2)}'.padLeft(priceWidth) +
      '\n';

  receipt += 'Delivery Charge:'.padRight(itemNameWidth) +
      '€${order.deliveryFee.toStringAsFixed(2)}'.padLeft(priceWidth) +
      '\n';

  // Final Total
  double finalTotal = order.total + order.deliveryFee - order.discount;
  receipt += 'Order Total:'.padRight(itemNameWidth) +
      '€${finalTotal.toStringAsFixed(2)}'.padLeft(priceWidth) +
      '\n';

  // Footer
  receipt += '--------------------------------\n';
  receipt += 'Payment Type: ${order.paymentType}\n';
  receipt += 'Thank You for Your Customs!\n';

  return receipt;
}

  /// Helper to wrap text into multiple lines
  List<String> _wrapText(String text, int width) {
    List<String> lines = [];
    StringBuffer currentLine = StringBuffer();

    for (String word in text.split(' ')) {
      if ((currentLine.length + word.length + 1) > width) {
        lines.add(currentLine.toString());
        currentLine.clear();
      }
      if (currentLine.isNotEmpty) {
        currentLine.write(' ');
      }
      currentLine.write(word);
    }

    if (currentLine.isNotEmpty) {
      lines.add(currentLine.toString());
    }

    return lines;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${widget.order.orderId}'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOrderInfo(),
          const SizedBox(height: 24),
          _buildOrderItems(),
        ],
      ),
    );
  }

  Widget _buildOrderInfo() {
    String formattedPhone = widget.order.customerPhone;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Order ID: ${widget.order.orderId}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            Text('Shop ID: ${widget.order.shopId}'),
            const SizedBox(height: 8),
            Text(
              '${widget.order.customerName}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(formattedPhone),
            Text('${widget.order.customerAddress}'),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Order Type:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(widget.order.orderType),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Payment:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(widget.order.paymentType),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItems() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _orderDetails?.length ?? 0,
              itemBuilder: (context, index) {
                final item = _orderDetails![index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          '${item.quantity} x ${item.itemName}',
                          softWrap: true,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text('€${(item.price * item.quantity).toStringAsFixed(2)}'),
                    ],
                  ),
                );
              },
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Sub Total:'),
                Text('€${widget.order.total.toStringAsFixed(2)}'),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Delivery Charge:'),
                Text('€${widget.order.deliveryFee.toStringAsFixed(2)}'),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Discount:'),
                Text('€${widget.order.discount.toStringAsFixed(2)}'),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Order Total:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  '€${(widget.order.total + widget.order.deliveryFee - widget.order.discount).toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  Text(
                    'Thank you for your custom.',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      await _printReceipt();
                      // Fetch values from the local database
                      final savedId = await _databaseService.getShopId();
                      final savedPhone = await _databaseService.getEmployeePhone();
                      final savedPin = await _databaseService.getEmployeePin();
                      final orderId = widget.order.orderId; // Current order ID

                      // Construct the API URL
                      final apiUrl =
                          'https://www.takeawayordering.com/appserver/appserver.php?tag=updateprintstatus'
                          '&employee_phone=$savedPhone&employee_pin=$savedPin&shop_id=$savedId&order_id=$orderId';

                      try {
                        // Make the API call
                        final response = await http.get(Uri.parse(apiUrl));

                        if (response.statusCode == 200) {
                          // Handle success
                          print('Print successful: ${response.body}');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Print status updated successfully!')),
                          );
                        } else {
                          // Handle failure
                          print('Failed to update print status: ${response.body}');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to update print status.')),
                          );
                        }
                      } catch (e) {
                        // Handle error
                        print('Error occurred while updating print status: $e');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('An error occurred: $e')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
    backgroundColor: Colors.green, // Change button background color to green
    foregroundColor: Colors.white, // Change text color to white
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
  ),

                    child: const Text('Print Receipt'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
