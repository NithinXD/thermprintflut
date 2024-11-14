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
  Timer? _timer;
  List<Order> _orders = [];
  bool _isLoading = true;
  String? _error;
  String? _shopId;
  String? _employeePhone;
  String? _employeePin;
  final Map<String, bool> _printStatus = {};

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _initCredentials();
    _startPeriodicFetch();
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

  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiService.fetchOrders();

      if (!mounted) return;

      final newOrders = response.orders.values.toList();

      // Trigger notification and sound for each unprinted order
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
  }

  @override
  void dispose() {
    _timer?.cancel();
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
        title: Text(_employeePin != null ? 'Orders - $_employeePin' : 'Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

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
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              side: BorderSide(
                color: isPrinted ? Colors.white : Colors.red,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              leading: isPrinted
                  ? null
                  : Icon(Icons.circle, color: Colors.red, size: 12),
              title: Text('Order #${order.orderId}'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status: ${order.status}'),
                  Text('Time: ${order.orderTime}'),
                  Text('Customer: ${order.customerName}'),
                  Text('Total: \$${order.total.toStringAsFixed(2)}'),
                ],
              ),
              isThreeLine: true,
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/order-details',
                  arguments: order,
                );
              },
            ),
          );
        },
       ),
     );
    }
   } 