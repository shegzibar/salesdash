import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

class SalesDashboard extends StatefulWidget {
  @override
  _SalesDashboardState createState() => _SalesDashboardState();
}

class _SalesDashboardState extends State<SalesDashboard> {
  List<Customer> customers = [];
  Timer? notificationTimer;
  Timer? clockTimer;
  Customer? currentNotification;
  String currentEasternTime = '';

  @override
  void initState() {
    super.initState();
    _updateEasternTime();
    _loadCustomers();
    notificationTimer = Timer.periodic(
        Duration(seconds: 1), (timer) => _checkForNotifications());
    clockTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _updateEasternTime();
    });
  }

  void _updateEasternTime() {
    final now = tz.TZDateTime.now(tz.getLocation('America/New_York'));
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';

    setState(() {
      currentEasternTime = "$hour:$minute:$second $period";
    });
  }

  Future<void> _loadCustomers() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('customers');
    if (data != null) {
      final List<dynamic> customerList = jsonDecode(data);
      setState(() {
        customers = customerList.map((e) => Customer.fromJson(e)).toList();
      });
    }
  }

  Future<void> _saveCustomers() async {
    final prefs = await SharedPreferences.getInstance();
    final data = customers.map((e) => e.toJson()).toList();
    prefs.setString('customers', jsonEncode(data));
  }

  void _checkForNotifications() {
    final now = tz.TZDateTime.now(tz.getLocation('America/New_York'));
    for (var customer in customers) {
      final callbackTime = tz.TZDateTime.fromMillisecondsSinceEpoch(
        tz.getLocation('America/New_York'),
        customer.callbackTime,
      );
      if (callbackTime.isBefore(now) &&
          (currentNotification == null || currentNotification != customer)) {
        setState(() {
          currentNotification = customer;
        });
        print("Notification triggered for customer: ${customer.name}");
        break;
      }
    }
  }

  @override
  void dispose() {
    notificationTimer?.cancel();
    clockTimer?.cancel();
    super.dispose();
  }
  void _showAddCustomerDialog() {
    final infoController = TextEditingController();
    String urgency = 'Urgent'; // Default value for the dropdown

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New Customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: infoController,
              decoration: InputDecoration(
                labelText: 'Customer Info (Name, Phone, Email)',
                hintText: 'Enter or paste customer info here',
                border: OutlineInputBorder(),
              ),
              maxLines: 3, // Allow multiline input
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: urgency,
              onChanged: (value) {
                setState(() {
                  urgency = value!;
                });
              },
              items: ['Urgent', 'Medium', 'Voice'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              decoration: InputDecoration(
                labelText: 'Urgency',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final callbackTime = await showDateTimePicker(context);
                if (infoController.text.isNotEmpty && callbackTime != null) {
                  final infoParts = infoController.text.split(','); // Assume CSV format
                  if (infoParts.length >= 3) {
                    _addCustomer(
                      infoParts[0].trim(),
                      infoParts[1].trim(),
                      infoParts[2].trim(),
                      callbackTime,
                    );
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Invalid info. Use "Name, Phone, Email" format.')),
                    );
                  }
                }
              },
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _addCustomer(
      String name, String phone, String email, DateTime callbackTime) async {
    final easternTime =
    tz.TZDateTime.from(callbackTime, tz.getLocation('America/New_York'));

    setState(() {
      customers.add(Customer(
        id: DateTime.now().millisecondsSinceEpoch,
        name: name,
        phone: phone,
        email: email,
        callbackTime: easternTime.millisecondsSinceEpoch,
      ));
    });
    await _saveCustomers();
  }

  void _deleteCustomer(int id) async {
    setState(() {
      customers.removeWhere((customer) => customer.id == id);
    });
    await _saveCustomers();
  }

  Future<DateTime?> showDateTimePicker(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        // Combine date and time to create a DateTime object
        final selectedDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);

        // Convert to Eastern Time Zone
        final easternTime = tz.TZDateTime.from(selectedDateTime, tz.getLocation('America/New_York'));
        return easternTime;
      }
    }
    return null;
  }

  Widget _buildNotificationBox(Customer customer) {
    return Center(
      child: Container(
        width: 400,
        height: 200,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blueGrey,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Callback Now!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              '${customer.name}\n${customer.phone}\n${customer.email}',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Copy customer info to clipboard
                Clipboard.setData(ClipboardData(
                    text:
                    '${customer.name}\n${customer.phone}\n${customer.email}'));

                // Remove the notification
                setState(() {
                  currentNotification = null;
                });
              },
              child: Text('Copy Info'),
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Sales Tool (Eastern Time)'),
            Text(
              currentEasternTime,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              ElevatedButton(
                onPressed: () => _showAddCustomerDialog(),
                child: Text('Add New Customer'),
              ),
              Expanded(
                child: customers.isEmpty
                    ? Center(child: Text('No customers found. Add a new one!'))
                    : ListView.builder(
                  itemCount: customers.length,
                  itemBuilder: (context, index) {
                    final customer = customers[index];
                    final callbackTime =
                    tz.TZDateTime.fromMillisecondsSinceEpoch(
                      tz.getLocation('America/New_York'),
                      customer.callbackTime,
                    );
                    return Card(
                      margin: EdgeInsets.symmetric(
                          vertical: 8, horizontal: 16),
                      child: ListTile(
                        title: Text(customer.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Phone: ${customer.phone}'),
                            Text('Email: ${customer.email}'),
                            Text('Callback: $callbackTime'),
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteCustomer(customer.id),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          if (currentNotification != null)
            _buildNotificationBox(currentNotification!),
        ],
      ),
    );
  }
}

class Customer {
  final int id;
  final String name;
  final String phone;
  final String email;
  final int callbackTime;

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.callbackTime,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'],
      name: json['name'],
      phone: json['phone'],
      email: json['email'],
      callbackTime: json['callbackTime'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'callbackTime': callbackTime,
    };
  }
}
