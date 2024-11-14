import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/order.dart';
import '../services/database_service.dart';

class ApiService {
  static const String baseUrl = 'https://www.takeawayordering.com/appserver/appserver.php';
  final _databaseService = DatabaseService();

  Future<String?> _getEmployeePhone() async => await _databaseService.getEmployeePhone();
  Future<String?> _getEmployeePin() async => await _databaseService.getEmployeePin();
  Future<String?> _getShopId() async => await _databaseService.getShopId();

  void _logRequest(String endpoint, Map<String, String?> params) {
    print('\nAPI Request to $endpoint:');
    print('Parameters:');
    params.forEach((key, value) => print('$key: $value'));
  }

  void _logResponse(String endpoint, http.Response response) {
    print('\nAPI Response from $endpoint:');
    print('Status Code: ${response.statusCode}');
    print('Body: ${response.body}');
  }

  void _logError(String operation, dynamic error) {
    print('\nError in $operation:');
    print('Error details: $error');
    print('Stack trace: ${StackTrace.current}');
  }

  Future<OrderResponse> fetchOrders() async {
    try {
      final shopId = await _getShopId();
      final employeePhone = await _getEmployeePhone();
      final employeePin = await _getEmployeePin();

      final params = {
        'tag': 'todaysorders',
        'employee_phone': employeePhone,
        'employee_pin': employeePin,
        'shop_id': shopId,
      };

      _logRequest('fetchOrders', params);

      final url = '$baseUrl?tag=todaysorders&employee_phone=$employeePhone&employee_pin=$employeePin&shop_id=$shopId';
      final response = await http.get(Uri.parse(url));
      print('Bodyyyyyyy: ${response.body}');

      _logResponse('fetchOrders', response);
      final jsonResponse = jsonDecode(response.body);
        jsonResponse['tabledetails']?.forEach((orderId, orderDetails) {
          print('Order ID: $orderId');
          orderDetails.forEach((key, value) {
            print('$key: $value');
          });
        });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return OrderResponse.fromJson(data);
      } else {
        throw Exception('Failed to load orders: ${response.statusCode}');
      }
    } catch (e) {
      _logError('fetchOrders', e);
      return OrderResponse(
        orders: {},
        success: false,
        message: 'Error fetching orders: $e',
      );
    }
  }

  Future<OrderDetailsResponse> fetchOrderDetails(String orderId) async {
    try {
      final shopId = await _getShopId();
      final employeePhone = await _getEmployeePhone();
      final employeePin = await _getEmployeePin();

      final params = {
        'tag': 'todaysorders',
        'employee_phone': employeePhone,
        'employee_pin': employeePin,
        'shop_id': shopId,
        'order_id': orderId,
      };

      _logRequest('fetchOrderDetails', params);

      final url = '$baseUrl?tag=tableitemdetails&employee_phone=$employeePhone&employee_pin=$employeePin&shop_id=$shopId&order_id=$orderId';
      final response = await http.get(Uri.parse(url));

      _logResponse('fetchOrderDetails', response);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return OrderDetailsResponse.fromJson(data);
      } else {
        throw Exception('Failed to load order details: ${response.statusCode}');
      }
    } catch (e) {
      _logError('fetchOrderDetails', e);
      return OrderDetailsResponse(
        items: {},
        success: false,
        message: 'Error fetching order details: $e',
      );
    }
  }
}