import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';

import 'screens/shop_id_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/order_details_screen.dart';
import 'models/order.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService(); // Initialize background service
  runApp(const MyApp());
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: true,

    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );

  service.startService();
}

bool onIosBackground(ServiceInstance service) {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}

void onStart(ServiceInstance service) {
  if (service is AndroidServiceInstance) {
    service.on('stopService').listen((event) {
      service.stopSelf();
    });
  }

  service.on('update').listen((event) {
    print("Background service is running...");
  });
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Bill',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 2,
        ),
        cardTheme: const CardTheme(
          elevation: 2,
          margin: EdgeInsets.symmetric(vertical: 8),
        ),
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
              builder: (context) => const ShopIdScreen(),
            );
          case '/orders':
            if (settings.arguments is Map) {
              final args = settings.arguments as Map;
              return MaterialPageRoute(
                builder: (context) => OrdersScreen(
                  shopId: args['shopId']?.toString(),
                  employeePhone: args['employeePhone']?.toString(),
                  employeePin: args['employeePin']?.toString(),
                ),
              );
            }
            return MaterialPageRoute(
              builder: (context) => const ShopIdScreen(),
            );
          case '/order-details':
            if (settings.arguments is Order) {
              return MaterialPageRoute(
                builder: (context) => OrderDetailsScreen(
                  order: settings.arguments as Order,
                ),
              );
            }
            return MaterialPageRoute(
              builder: (context) => const ShopIdScreen(),
            );
          default:
            return MaterialPageRoute(
              builder: (context) => const ShopIdScreen(),
            );
        }
      },
    );
  }
}
