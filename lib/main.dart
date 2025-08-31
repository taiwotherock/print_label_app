import 'dart:typed_data';

import 'package:bluetooth_print_plus/bluetooth_print_plus.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluetooth Printer Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const PrinterPage(),
    );
  }
}

class PrinterPage extends StatefulWidget {
  const PrinterPage({super.key});

  @override
  State<PrinterPage> createState() => _PrinterPageState();
}

class _PrinterPageState extends State<PrinterPage> {
  List<BluetoothDevice> devices = [];
  BluetoothDevice? selectedDevice;
  String status = "Idle";

  @override
  void initState() {
    super.initState();

    // Listen for scan results
    BluetoothPrintPlus.scanResults.listen((list) {
      setState(() {
        // Filter only likely printer devices by name
        devices = list.where((d) {
          final name = d.name.toLowerCase();
          return name.contains("printer") ||
              name.contains("pos") ||
              name.contains("gprinter") ||
              name.contains("rpp");
        }).toList();
      });
    });

    // Listen for connection state changes
    BluetoothPrintPlus.connectState.listen((cs) {
      setState(() {
        status = "Connection: $cs";
      });
    });

    // Listen for scanning status
    BluetoothPrintPlus.isScanning.listen((scanning) {
      setState(() {
        status = scanning ? "🔍 Scanning..." : "Scan stopped";
      });
    });
  }

  Future<void> startScan() async {
    setState(() => status = "Starting scan...");
    await BluetoothPrintPlus.startScan(timeout: const Duration(seconds: 5));
  }

  Future<void> connectAndPrint() async {
    if (selectedDevice == null) {
      setState(() => status = "⚠️ No printer selected");
      return;
    }

    setState(() => status = "Connecting to ${selectedDevice!.name}...");
    await BluetoothPrintPlus.connect(selectedDevice!);

    final isConnected = BluetoothPrintPlus.isConnected;
    if (!isConnected) {
      setState(() => status = "❌ Connection failed");
      return;
    }

    setState(() => status = "✅ Connected — printing...");

    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);

      List<int> bytes = [];

      bytes += generator.text(
        'MY SHOP',
        styles: PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          bold: true,
        ),
      );

      bytes += generator.text(
        '123 Main Street',
        styles: PosStyles(align: PosAlign.center),
      );
      bytes += generator.text(
        'Tel: +1 555 1234',
        styles: PosStyles(align: PosAlign.center),
      );
      bytes += generator.hr();

      bytes += generator.row([
        PosColumn(text: 'Item', width: 6),
        PosColumn(
          text: 'Price',
          width: 6,
          styles: PosStyles(align: PosAlign.right),
        ),
      ]);

      bytes += generator.row([
        PosColumn(text: 'Burger', width: 6),
        PosColumn(
          text: '\$5.99',
          width: 6,
          styles: PosStyles(align: PosAlign.right),
        ),
      ]);

      bytes += generator.row([
        PosColumn(text: 'Fries', width: 6),
        PosColumn(
          text: '\$2.49',
          width: 6,
          styles: PosStyles(align: PosAlign.right),
        ),
      ]);

      bytes += generator.hr();
      bytes += generator.text(
        'TOTAL: \$8.48',
        styles: PosStyles(
          align: PosAlign.right,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          bold: true,
        ),
      );

      bytes += generator.feed(2);
      bytes += generator.text(
        'Thank you!',
        styles: PosStyles(align: PosAlign.center, bold: true),
      );
      bytes += generator.cut();

      await BluetoothPrintPlus.write(Uint8List.fromList(bytes));

      setState(() => status = "✅ Print complete");
    } catch (e) {
      setState(() => status = "❌ Print error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bluetooth Printer Demo")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Status: $status",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                return ListTile(
                  leading: const Icon(Icons.print),
                  title: Text(device.name),
                  subtitle: Text(device.address),
                  selected: device == selectedDevice,
                  onTap: () {
                    setState(() => selectedDevice = device);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Wrap(
        spacing: 10,
        children: [
          FloatingActionButton(
            onPressed: startScan,
            tooltip: 'Scan',
            child: const Icon(Icons.search),
          ),
          FloatingActionButton(
            onPressed: connectAndPrint,
            tooltip: 'Connect & Print',
            child: const Icon(Icons.print),
          ),
        ],
      ),
    );
  }
}
