import 'package:flutter/material.dart';
import '../services/printer_service.dart';
import '../models/order.dart';

class OrderDetailsScreen extends StatefulWidget {
  final Order order;

  const OrderDetailsScreen({Key? key, required this.order}) : super(key: key);

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final PrinterService _printerService = PrinterService();

  void _printReceipt() async {
    // Format receipt data specific to this application
    String receiptData = _formatReceipt(widget.order);
    await _printerService.printReceipt(receiptData);
  }

  String _formatReceipt(Order order) {
    // Construct the receipt content
    String receipt = '';
    receipt += 'Order #${order.orderId}\n';
    receipt += 'Date: ${order.orderTime}\n';
    receipt += 'Customer: ${order.customerName}\n';
    receipt += 'Phone: ${order.customerPhone}\n';
    receipt += 'Address: ${order.customerAddress}\n';
    receipt += '--------------------------------\n';
    receipt += 'Order Items:\n';

    for (var item in order.items) {
      receipt += '${item.quantity}x ${item.itemName} - \$${(item.price * item.quantity).toStringAsFixed(2)}\n';
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
    receipt += 'Total: \$${order.total.toStringAsFixed(2)}\n';
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Display the order details and items list
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
            Text('Order Information', style: Theme.of(context).textTheme.titleLarge),
            Text('Status: ${widget.order.status}'),
            Text('Time: ${widget.order.orderTime}'),
            Text('Customer: ${widget.order.customerName}'),
            Text('Phone: ${widget.order.customerPhone}'),
            Text('Address: ${widget.order.customerAddress}'),
            Text('Total: \$${widget.order.total.toStringAsFixed(2)}'),
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
            Text('Order Items', style: Theme.of(context).textTheme.titleLarge),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.order.items.length,
              itemBuilder: (context, index) {
                final item = widget.order.items[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${item.quantity}x ${item.itemName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (item.extras.isNotEmpty)
                        ...item.extras.map((extra) => Padding(
                              padding: const EdgeInsets.only(left: 16),
                              child: Text('+ $extra'),
                            )),
                      if (item.notes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Text('Note: ${item.notes}'),
                        ),
                      Text('Price: \$${(item.price * item.quantity).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
