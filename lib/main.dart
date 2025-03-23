import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'billing_screen.dart';
import 'package:provider/provider.dart';
import 'providers/bill_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(BillingApp());
}

class BillingApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => BillProvider()), // Shared state for billing
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Billing App',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: BillingScreen(),
      ),
    );
  }
}
