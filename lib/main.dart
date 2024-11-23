import 'package:flutter/material.dart';
import 'package:sale/dasboard.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() async {


  // Initialize the timezone database
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('America/New_York'));

  runApp(SalesToolApp());
}

class SalesToolApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sales Tool',
      theme: ThemeData.dark(),
      home: SalesDashboard(),
    );
  }
}
