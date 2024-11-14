import 'package:flutter/material.dart';
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
  final PrinterService _printerService = PrinterService();
  final ApiService _apiService = ApiService();

  List<OrderDetail>? _orderDetails; // List to store fetched order details
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

  void _printReceipt() async {
  // Retrieve the shop ID
  final shopId = await DatabaseService().getShopId();

  // Define URL for updating print status
  final url = 'https://www.takeawayordering.com/appserver/appserver.php?'
              'tag=updateprintstatus&'
              'employee_phone=wingsbox&'
              'employee_pin=2go2hell&'
              'shop_id=$shopId&'
              'order_id=${widget.order.orderId}';

  try {
    // Send request to update print status
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      print('Print status updated successfully.');
    } else {
      print('Failed to update print status. Status code: ${response.statusCode}');
    }
  } catch (e) {
    print('Error updating print status: $e');
  }

  // Check if order details exist
  if (_orderDetails == null) return;

  // Format and print the receipt
  String receiptData = _formatReceipt(widget.order);
  await _printerService.printReceipt(receiptData);
}


  String _formatReceipt(Order order) {
    String receipt = '';
    receipt += 'Order #${order.orderId}\n';
    receipt += 'Date: ${order.orderTime}\n';
    receipt += 'Customer: ${order.customerName}\n';
    receipt += 'Phone: ${order.customerPhone}\n';
    receipt += 'Address: ${order.customerAddress}\n';
    receipt += '--------------------------------\n';
    receipt += 'Order Items:\n';

    for (var item in _orderDetails ?? []) {
      receipt += '${item.quantity}x ${item.itemName} - €${(item.price * item.quantity).toStringAsFixed(2)}\n';
      if (item.extras.isNotEmpty) {
        for (var extra in item.extras) {
          receipt += '  + $extra\n';
        }
      }
      if (item.notes.isNotEmpty) {
        receipt += '  Note: ${item.notes}\n';
      }
      receipt += '\n';
    }

    receipt += '--------------------------------\n';
    receipt += 'Total: €${order.total.toStringAsFixed(2)}\n';
    receipt += 'Thank You!\n';
    return receipt;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${widget.order.orderId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _printReceipt,
          ),
        ],
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
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Heading for Order Details
          Text(
            'Order Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8), // Add some spacing below the heading

          // Display shop details
          Text('Shop ID: ${widget.order.shopId}'),
          Text('Shop Address: ${widget.order.shopAddress}'),
Text('Phone: ${widget.order.shopTelephone.replaceFirst(RegExp(r'^0'), '')}', // Removes the leading 0 if it exists
 ),          const Divider(),

          // Display customer details
          Text(
            '${widget.order.customerName}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text('${widget.order.customerAddress}'),
          const Divider(),
          Text('Order Type: ${widget.order.orderType}'),
          Text('Payment: ${widget.order.paymentType}'),
        ],
      ),
    ),
  );
}



  Widget _buildOrderItems() {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ITEMS', style: TextStyle(fontWeight: FontWeight.bold)),
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
                        maxLines: 2, // Allowing two lines for long item names
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
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Order Total:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                '€${(widget.order.total + widget.order.deliveryFee).toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Thank you for your custom.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    ),
  );
}

}