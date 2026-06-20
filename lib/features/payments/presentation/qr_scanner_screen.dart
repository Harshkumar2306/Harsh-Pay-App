import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/db/hive_setup.dart';
import '../../../core/db/models/offline_transaction.dart';
import '../../../core/network/api_client.dart';

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
      _showError('Insufficient balance!');
      return;
    }

    // Check if we are online
    final connectivityResult = await Connectivity().checkConnectivity();
    final bool isOnline = connectivityResult != ConnectivityResult.none;

    if (isOnline) {
      // ───────────────────────────────────────────────
      // ONLINE MODE — Instant UPI-style cloud payment
      // ───────────────────────────────────────────────
      _showLoadingDialog('Paying ₹$amount to ${payload['name']}...');

      final result = await ApiClient().payOnline(
        senderClerkId: wallet.clerkId,
        receiverClerkId: payload['id'] ?? '',
        amount: amount,
        note: 'Sent to ${payload['name']}',
      );

      if (!mounted) return;
      Navigator.pop(context); // close loading dialog

      if (result == null) {
        // Network dropped mid-request — fall back to offline
        await _executeOfflineTransfer(wallet, payload, amount);
        return;
      }

      if (result.containsKey('error')) {
        _showError(result['error']);
        return;
      }

      // Success! Update local balance from server's response
      final double newBalance = (result['newBalance'] as num).toDouble();
      wallet.syncedBalance = newBalance;
      await HiveSetup.saveWallet(wallet);

      // Record as a SYNCED transaction (no pending)
      final tx = OfflineTransaction(
        txId: 'ONLINE_${const Uuid().v4()}',
        type: 'debit',
        amount: amount,
        title: 'Sent to ${payload['name']}',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        isSynced: true, // Already synced!
      );
      await HiveSetup.saveTransaction(tx);

      if (!mounted) return;
      _showSuccessDialog(
        '✅ Paid ₹$amount to ${result['receiverName'] ?? payload['name']}!',
        isOnline: true,
      );
    } else {
      // ───────────────────────────────────────────────
      // OFFLINE MODE — Local debit, sync later
      // ───────────────────────────────────────────────
      await _executeOfflineTransfer(wallet, payload, amount);
    }
  }

  Future<void> _executeOfflineTransfer(dynamic wallet, Map<String, dynamic> payload, double amount) async {
    wallet.syncedBalance -= amount;
    await HiveSetup.saveWallet(wallet);

    final txId = const Uuid().v4();
    final receiverId = payload['id'] ?? 'unknown';

    final tx = OfflineTransaction(
      txId: '$txId::$receiverId',
      type: 'debit',
      amount: amount,
      title: 'Sent offline to ${payload['name']}',
      timestamp: DateTime.now().millisecondsSinceEpoch,
      isSynced: false, // Will sync when online
    );
    await HiveSetup.saveTransaction(tx);

    if (!mounted) return;
    _showSuccessDialog(
      '₹$amount sent to ${payload['name']} offline.\nWill sync when connected.',
      isOnline: false,
    );
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        content: Row(
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(width: 16),
            Expanded(child: Text(message, style: const TextStyle(color: AppColors.textPrimary))),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog(String message, {required bool isOnline}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isOnline ? AppColors.primary : AppColors.surface,
        title: Icon(
          isOnline ? Icons.check_circle : Icons.access_time_rounded,
          color: isOnline ? AppColors.background : AppColors.primary,
          size: 64,
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isOnline ? AppColors.background : AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isOnline ? AppColors.background : AppColors.primary,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/home');
            },
            child: Text(
              'Done',
              style: TextStyle(
                color: isOnline ? AppColors.primary : AppColors.background,
                fontWeight: FontWeight.bold,
              ),
            ),
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
