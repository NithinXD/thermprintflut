import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/database_service.dart'; // Assuming this is your database service file
import 'ZonesScreen.dart';
import 'orders_Screen.dart';

class ReportScreen extends StatefulWidget {
  @override
  _ReportScreenState createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final TextEditingController _dateController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic> _reportData = {};
  final DatabaseService _databaseService = DatabaseService();
  String? _shopId;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    _dateController.text = _getTodayDate(); // Set default date to today
    _shopId = await _databaseService.getShopId(); // Fetch shopId from database
    if (_shopId != null) {
      _fetchReport(_dateController.text); // Fetch report for today's date
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Shop ID not found.')),
      );
    }
  }

  String _getTodayDate() {
    final now = DateTime.now();
    return "${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}";
  }

  Future<void> _fetchReport(String date) async {
  if (_shopId == null) {
    print("Error: Shop ID is null.");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Error: Shop ID is null.')),
    );
    return;
  }

  print("Fetching report for date: $date");
  setState(() {
    _isLoading = true;
  });

  try {
    final Uri apiUrl = Uri.parse(
      'https://www.takeawayordering.com/appserver/appserver.php?tag=getreport&shop_id=$_shopId&report_date=$date',
    );

    print("API URL: $apiUrl");
    final response = await http.get(apiUrl);
    print("Raw API Response: ${response.body}");

    if (response.statusCode == 200) {
      // Clean the response by removing unexpected characters
      String cleanedResponse = response.body.trim();
      if (cleanedResponse.startsWith(RegExp(r'\d'))) {
        cleanedResponse = cleanedResponse.replaceFirst(RegExp(r'^\d+'), '');
      }

      print("Cleaned API Response: $cleanedResponse");

      final Map<String, dynamic> data = json.decode(cleanedResponse);
      print("Parsed JSON Data: $data");

      if (data['success'] == 1 || data['success'] == -4) {
        final Map<String, dynamic> reportDetails = data['reportdetails'] ?? {};
        print("Report details: $reportDetails");
        setState(() {
          _reportData = {
            'cashOrders': data['cashorder'] ?? 0,
            'cardOrders': data['cardorder'] ?? 0,
            'collectionOrders': data['collection'] ?? 0,
            'deliveryOrders': data['delivery'] ?? 0,
            'totalOrders': data['totalorders'] ?? 0,
            'cashBusiness': data['cashbusiness'] ?? 0.0,
            'cardBusiness': data['cardbusiness'] ?? 0.0,
            'totalBusiness': data['totalbusiness'] ?? 0.0,
            'cashDeliveryCharge': data['cashdeliverycharge'] ?? 0.0,
            'cardDeliveryCharge': data['carddeliverycharge'] ?? 0.0,
            'totalDeliveryCharge': data['totaldeliverycharge'] ?? 0.0,
            'reportDetails': reportDetails,
          };
        });
      } else {
        print("No report data available for the date.");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No report data available for this date.')),
        );
      }
    } else {
      print("Failed to fetch report. Status code: ${response.statusCode}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch report. Status code: ${response.statusCode}')),
      );
    }
  } catch (e) {
    print("Error fetching report: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error fetching report: $e')),
    );
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

  void _onFooterItemTapped(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ReportScreen()),
        );
        break;
      case 1:
        Navigator.pushReplacement(
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopSection(),
            const SizedBox(height: 16),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _reportData.isNotEmpty
                    ? _buildReportSummary()
                    : const Center(child: Text('No data available')),
          ],
        ),
      ),
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
            icon: Icon(Icons.person),
            label: 'Orders',
          ),
        ],
        currentIndex: 0, // Sets 'Report' as the selected item
        onTap: _onFooterItemTapped,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
      ),
    );
  }

  Widget _buildTopSection() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _dateController,
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Select Date',
              suffixIcon: IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () async {
                  final DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (pickedDate != null) {
                    final formattedDate =
                        "${pickedDate.day.toString().padLeft(2, '0')}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.year}";
                    _dateController.text = formattedDate;
                    _fetchReport(formattedDate);
                  }
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () => _fetchReport(_dateController.text),
          child: const Text('Get Report'),
        ),
      ],
    );
  }

  Widget _buildReportSummary() {
    final reportDetails = _reportData['reportDetails'] as Map<String, dynamic>? ?? {};
    
    return Expanded(
      child: ListView(
        children: [
          _buildSectionCard(
            'Order Details',
            {
              'Number of Cash Orders': _reportData['cashOrders'],
              'Number of Card Orders': _reportData['cardOrders'],
              'Number of Collection Orders': _reportData['collectionOrders'],
              'Number of Delivery Orders': _reportData['deliveryOrders'],
              'Total Number of Orders': _reportData['totalOrders'],
            },
          ),
          _buildSectionCard(
            'Business Summary',
            {
              'Total Cash Business': "€${_reportData['cashBusiness']}",
              'Total Card Business': "€${_reportData['cardBusiness']}",
              'Total Business': "€${_reportData['totalBusiness']}",
            },
          ),
          _buildSectionCard(
            'Delivery Charges Summary',
            {
              'Total Cash Delivery Charge': "€${_reportData['cashDeliveryCharge']}",
              'Total Card Delivery Charge': "€${_reportData['cardDeliveryCharge']}",
              'Total Delivery Charge': "€${_reportData['totalDeliveryCharge']}",
            },
          ),
          if (reportDetails.isNotEmpty) _buildOrderDetailsList(reportDetails),
        ],
      ),
    );
  }

  Widget _buildOrderDetailsList(Map<String, dynamic> reportDetails) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Details Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ...reportDetails.entries.map((entry) {
              final orderId = entry.key;
              final details = entry.value as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Order ID: $orderId"),
                    Text("Total: €${details['od_total']}"),
                    Text("Delivery Charge: €${details['od_delivery_charge']}"),
                    Text("Payment Type: ${details['od_payment_type']}"),
                    const Divider(),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(String title, Map<String, dynamic> details) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ...details.entries.map((entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key),
                      Text(entry.value.toString()),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
