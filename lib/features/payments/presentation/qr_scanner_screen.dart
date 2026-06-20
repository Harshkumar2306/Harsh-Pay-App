import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import '../../../core/theme/app_colors.dart';
import '../../../core/db/hive_setup.dart';
import '../../../core/db/models/offline_transaction.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isScanning = true;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_isScanning) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        setState(() => _isScanning = false);
        
        final String scannedData = barcode.rawValue!;
        if (scannedData.startsWith('harshpay://offline?data=')) {
          final jsonString = scannedData.replaceFirst('harshpay://offline?data=', '');
          try {
            final payload = jsonDecode(jsonString);
            _processScannedPayload(payload);
          } catch (e) {
             _showError('Invalid QR Code Format');
          }
        } else {
           _showError('Unrecognized QR Code');
        }
        break;
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: const TextStyle(color: Colors.white)), backgroundColor: AppColors.error));
    setState(() => _isScanning = true);
  }

  void _processScannedPayload(Map<String, dynamic> payload) {
    if (payload['amount'] == null) {
      // The receiver didn't specify an amount, so ask the sender (us) to enter one
      _promptForAmount(payload);
    } else {
      // The receiver hardcoded an amount in the QR code
      _executeTransfer(payload, (payload['amount'] as num).toDouble());
    }
  }

  void _promptForAmount(Map<String, dynamic> payload) {
    final TextEditingController amountController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Send to ${payload['name']}', style: const TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            hintText: '₹0',
            hintStyle: TextStyle(color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.background,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _isScanning = true);
            },
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              final amt = double.tryParse(amountController.text);
              if (amt != null && amt > 0) {
                Navigator.pop(context);
                _executeTransfer(payload, amt);
              }
            },
            child: const Text('Send Offline', style: TextStyle(color: AppColors.background, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _executeTransfer(Map<String, dynamic> payload, double amount) async {
    final wallet = HiveSetup.getWallet();
    if (wallet == null) {
      _showError('Your wallet is not synced!');
      return;
    }

    if (wallet.syncedBalance < amount) {
      _showError('Insufficient Offline Balance!');
      return;
    }

    // Mathematically deduct from our local wallet
    wallet.syncedBalance -= amount;
    await HiveSetup.saveWallet(wallet);

    // Mathematically record the Offline Transaction
    // We encode the receiver's ID into the txId so the cloud knows who to credit!
    final txId = const Uuid().v4();
    final receiverId = payload['id'] ?? 'unknown';
    
    final tx = OfflineTransaction(
      txId: '$txId::$receiverId',
      type: 'debit',
      amount: amount,
      title: 'Sent offline to ${payload['name']}',
      timestamp: DateTime.now().millisecondsSinceEpoch,
      isSynced: false,
    );
    await HiveSetup.saveTransaction(tx);

    if (!mounted) return;
    
    // Show massive success!
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.primary,
        title: const Icon(Icons.check_circle, color: AppColors.background, size: 64),
        content: Text(
          'Successfully sent ₹$amount offline to ${payload['name']}!',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.background, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.background),
            onPressed: () {
              Navigator.pop(context); // close dialog
              context.go('/home'); // go home
            },
            child: const Text('Done', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan QR to Pay'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),
          // Target Overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 4),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          const Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Text(
              'Align QR code within the frame to send money offline',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          )
        ],
      ),
    );
  }
}
