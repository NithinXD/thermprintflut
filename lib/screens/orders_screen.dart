import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/order.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import 'ReportScreen.dart'; 
import 'ZonesScreen.dart';  
import '../services/printer_service.dart'; // Import PrinterService
import 'package:http/http.dart' as http;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

class OrdersScreen extends StatefulWidget {
  final String? shopId;
  final String? employeePhone;
  final String? employeePin;

  const OrdersScreen({
    Key? key,
    this.shopId,
    this.employeePhone,
    this.employeePin,
  }) : super(key: key);

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final ApiService _apiService = ApiService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final DatabaseService _databaseService = DatabaseService();
  final PrinterService _printerService = PrinterService(); // PrinterService instance
  Timer? _continuousNotificationTimer;
  Timer? _timer;
  List<Order> _orders = [];
  bool _isLoading = true;
  String? _error;
  String? _shopId;
  String? _employeePhone;
  String? _employeePin;
  final Map<String, bool> _printStatus = {};
  final Set<String> _notifiedOrders = {};

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _initCredentials();
    _startPeriodicFetch();
    _startContinuousNotifications();
  }
  
  Future<void> _printOrder(Order order) async {
    try {
      setState(() {
        _printStatus[order.orderId] = true; // Mark as printed optimistically
      });

      await _printerService.fetchAndPrintReceipt(order);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order #${order.orderId} sent to printer.')),
      );
    } catch (e) {
      setState(() {
        _printStatus[order.orderId] = false; // Revert status on failure
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to print order #${order.orderId}: $e')),
      );
    }
  }

  Future<void> _initNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings = InitializationSettings(android: androidSettings);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _initCredentials() async {
    try {
      _shopId = widget.shopId;
      _employeePhone = widget.employeePhone;
      _employeePin = widget.employeePin;

      if (_shopId == null || _employeePhone == null || _employeePin == null) {
        final savedId = await _databaseService.getShopId();
        final savedPhone = await _databaseService.getEmployeePhone();
        final savedPin = await _databaseService.getEmployeePin();

        if (savedId == null || savedId.isEmpty) {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/');
            return;
          }
        }
        _shopId = savedId;
        _employeePhone = savedPhone;
        _employeePin = savedPin;
      }

      await _fetchOrders();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error initializing: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _startPeriodicFetch() {
    _timer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _fetchOrders();
    });
  }

  Future<void> _playNotificationSound() async {
    try {
      final byteData = await rootBundle.load('assets/sounds/beep.mp3');
      final audioBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/notification.mp3');
      await tempFile.writeAsBytes(audioBytes, flush: true);

      await _audioPlayer.setFilePath(tempFile.path);
      _audioPlayer.play();
    } catch (e) {
      print("Error loading or playing sound: $e");
    }
  }

  void _startContinuousNotifications() {
    _continuousNotificationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      for (var order in _orders) {
        final isPrinted = _printStatus[order.orderId] ?? false;
        if (!isPrinted) {
          _playNotificationSound();
          _showOrderNotification(order, isPrinted);
        }
      }
    });
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiService.fetchOrders();

      if (!mounted) return;

      final newOrders = response.orders.values.toList();

      for (var order in newOrders) {
        final isPrinted = order.orderPrinted != "0";
        _printStatus[order.orderId] = isPrinted;

        if (!isPrinted) {
          await _playNotificationSound();
          _showOrderNotification(order, isPrinted);
        }
      }

      setState(() {
        _orders = newOrders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to fetch orders: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _showOrderNotification(Order order, bool isPrinted) async {
    if (_notifiedOrders.contains(order.orderId)) return;

    final notificationTitle = isPrinted
        ? 'New Order'
        : 'Unprinted Order #${order.orderId} is ready.';

    await flutterLocalNotificationsPlugin.show(
      order.orderId.hashCode,
      notificationTitle,
      'Order #${order.orderId} is ready.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'order_channel',
          'Order Notifications',
          channelDescription: 'Notifications for new orders',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );

    _notifiedOrders.add(order.orderId);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _continuousNotificationTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    try {
      await _databaseService.saveShopId('');
      await _databaseService.saveEmployeePhone('');
      await _databaseService.saveEmployeePin('');

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error logging out: $e')),
      );
    }
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text(_employeePin != null ? 'Order Pad - $_employeePin' : 'Order Pad'),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _fetchOrders,
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: _logout,
        ),
      ],
    ),
    body: _buildBody(),
    bottomNavigationBar: BottomNavigationBar(
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.analytics),
          label: 'Report',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.map),
          label: 'Zones',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt),
          label: 'Orders',
        ),
      ],
      onTap: (int index) {
        switch (index) {
          case 0:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ReportScreen()),
            );
            break;
          case 1:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ZonesScreen()),
            );
            break;
          case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OrdersScreen(
              shopId: _shopId,
              employeePhone: "wingsbox",
              employeePin: "2go2hell",
            ),
          ),
        );
        break;
    }
      },
      selectedItemColor: Colors.grey,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
    ),
  );
}



  @override
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchOrders,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_orders.isEmpty) {
      return const Center(
        child: Text('No orders found'),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchOrders,
      child: ListView.builder(
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final order = _orders[index];
          final isPrinted = _printStatus[order.orderId] ?? false;

          return Card(
  color: isPrinted ? const Color(0xFF88C3CF) : Colors.orange[100], // Card color remains the same
  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  shape: RoundedRectangleBorder(
    side: BorderSide(
      color: isPrinted ? Colors.blue : Colors.red,
      width: 2,
    ),
    borderRadius: BorderRadius.circular(8),
  ),
  child: InkWell(
    onTap: () {
      Navigator.pushNamed(
        context,
        '/order-details',
        arguments: order,
      );
    },
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.customerPhone,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    order.customerName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    order.email,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Total: €${order.total.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Address: ${order.customerAddress}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Delivery Charge: €${order.deliveryFee.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 14),
              ),
              Text(
                order.paymentType, // Delivery type
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8), // Add spacing between rows
          Row(
            children: [
              Text(
                'Order Type: ${order.orderType}', // Assuming 'deliveryOption' holds "Delivery" or "Collection"
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
                    const SizedBox(height: 16), // Add spacing before the button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // Align items to opposite ends
            children: [
              Text(
                'Order ID: ${order.orderId}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPrinted ? Colors.green : Colors.red,
                ),
                onPressed: () async {
                  try {
                    // Print the receipt
                    await _printOrder(order);

                    // Fetch saved credentials from the local database
                    final savedId = await _databaseService.getShopId();
                    final savedPhone = await _databaseService.getEmployeePhone();
                    final savedPin = await _databaseService.getEmployeePin();
                    final orderId = order.orderId; // Current order ID

                    // Construct the API URL
                    final apiUrl =
                        'https://www.takeawayordering.com/appserver/appserver.php?tag=updateprintstatus'
                        '&employee_phone=$savedPhone&employee_pin=$savedPin&shop_id=$savedId&order_id=$orderId';

                    // Make the API call to update the print status
                    final response = await http.get(Uri.parse(apiUrl));

                    if (response.statusCode == 200) {
                      // Success: Print status updated
                      print('Print status updated successfully: ${response.body}');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Print status updated successfully!')),
                      );
                      setState(() {
                        _printStatus[order.orderId] = true; // Mark order as printed
                      });
                    } else {
                      // Failure: Handle API failure
                      print('Failed to update print status: ${response.body}');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to update print status.')),
                      );
                    }
                  } catch (e) {
                    // Error: Handle network or API errors
                    print('Error occurred while updating print status: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('An error occurred: $e')),
                    );
                  }
                },
                child: const Text('Print Receipt'),
              ),
            ],
          ),
        ],
      ),
    ),
  ),
);

        },
      ),
    );
  }
}


