import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../../../core/db/hive_setup.dart';
import '../../../core/db/models/offline_transaction.dart';

class NearbyTransferService {
  final Strategy strategy = Strategy.P2P_STAR; // High bandwidth, multi-device
  bool isAdvertising = false;
  bool isDiscovering = false;

  Function(String userName)? onUserFound;
  Function(String endpointId, String userName)? onEndpointFound;
  Function(String payload)? onTransferReceived;
  Function(String msg)? onError;

  Future<bool> _checkPermissions() async {
    // Android requires GPS to be turned on for Nearby Connections
    if (Platform.isAndroid && await Permission.location.serviceStatus.isDisabled) {
      onError?.call('GPS/Location services are disabled. Please turn them on in Settings.');
      return false;
    }

    final statuses = await [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.nearbyWifiDevices,
    ].request();

    // Check if core permissions are granted
    if (statuses[Permission.location] == PermissionStatus.denied ||
        statuses[Permission.bluetooth] == PermissionStatus.denied) {
      onError?.call('Location and Bluetooth permissions are required for Radio Transfer.');
      return false;
    }

    return true;
  }

  Future<void> startAdvertising() async {
    try {
      bool hasPerms = await _checkPermissions();
      if (!hasPerms) return;
      
      final wallet = HiveSetup.getWallet();
      if (wallet == null) return;

      // Broadcast both name and clerkId for Zero-Trust routing
      final endpointName = '${wallet.name}::${wallet.clerkId}';

      bool a = await Nearby().startAdvertising(
        endpointName,
        strategy,
        serviceId: 'harshpay',
        onConnectionInitiated: (String id, ConnectionInfo info) {
          // Auto-accept connection
          Nearby().acceptConnection(
            id,
            onPayLoadRecieved: (endid, payload) {
              if (payload.type == PayloadType.BYTES) {
                String str = String.fromCharCodes(payload.bytes!);
                _processIncomingRadioTransfer(str);
              }
            },
            onPayloadTransferUpdate: (endid, payloadTransferUpdate) {},
          );
        },
        onConnectionResult: (id, status) {},
        onDisconnected: (id) {},
      );
      isAdvertising = a;
    } catch (e) {
      onError?.call('Advertising failed: $e');
    }
  }

  Future<void> startDiscovering() async {
    try {
      bool hasPerms = await _checkPermissions();
      if (!hasPerms) return;
      
      final wallet = HiveSetup.getWallet();
      if (wallet == null) return;

      final endpointName = '${wallet.name}::${wallet.clerkId}';

      bool a = await Nearby().startDiscovery(
        endpointName,
        strategy,
        serviceId: 'harshpay',
        onEndpointFound: (String id, String endpointInfo, String serviceId) {
          // Parse name and clerkId from endpointInfo
          final parts = endpointInfo.split('::');
          final userName = parts[0];

          onUserFound?.call(userName);
          // Pass clerkId disguised as the userName string to the UI or store it
          onEndpointFound?.call(id, endpointInfo); 
          // Request connection instantly
          Nearby().requestConnection(
            endpointName,
            id,
            onConnectionInitiated: (id, info) {
              Nearby().acceptConnection(
                id,
                onPayLoadRecieved: (endid, payload) {},
                onPayloadTransferUpdate: (endid, payloadTransferUpdate) {},
              );
            },
            onConnectionResult: (id, status) {},
            onDisconnected: (id) {},
          );
        },
        onEndpointLost: (String? id) {},
      );
      isDiscovering = a;
    } catch (e) {
      onError?.call('Discovery failed: $e');
    }
  }

  Future<void> sendMoneyOverRadio(String targetEndpointId, double amount, String endpointInfo) async {
    final wallet = HiveSetup.getWallet();
    if (wallet == null) return;

    if (wallet.syncedBalance < amount) {
      onError?.call('Insufficient offline balance for radio transfer');
      return;
    }

    final parts = endpointInfo.split('::');
    final targetName = parts[0];
    final receiverId = parts.length > 1 ? parts[1] : 'unknown';

    // TWO-WAY ESCROW: Do NOT deduct locally!
    final txId = const Uuid().v4();
    final senderId = wallet.clerkId;
    final now = DateTime.now().millisecondsSinceEpoch;
    final encodedTxId = '$txId::$receiverId::$senderId';

    // 2. Save offline transaction
    final tx = OfflineTransaction(
      txId: encodedTxId,
      type: 'debit',
      amount: amount,
      title: 'Radio transfer to $targetName',
      timestamp: now,
      isSynced: false,
    );
    await HiveSetup.saveTransaction(tx);

    // 3. Beam over radio
    final payloadData = {
      'txId': encodedTxId,
      'senderName': wallet.name,
      'senderId': senderId,
      'receiverId': receiverId,
      'timestamp': now,
      'amount': amount,
    };
    Nearby().sendBytesPayload(
      targetEndpointId,
      Uint8List.fromList(jsonEncode(payloadData).codeUnits),
    );
  }

  void _processIncomingRadioTransfer(String jsonPayload) async {
    try {
      final data = jsonDecode(jsonPayload);
      final double amount = (data['amount'] as num).toDouble();
      final String senderName = data['senderName'];
      final String txId = data['txId'];
      final int txTimestamp = data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch;

      final wallet = HiveSetup.getWallet();
      if (wallet != null) {
        // TWO-WAY ESCROW: Do NOT add to syncedBalance!
        final tx = OfflineTransaction(
          txId: txId,
          type: 'credit',
          amount: amount,
          title: 'Received offline from $senderName',
          timestamp: txTimestamp,
          isSynced: false,
        );
        await HiveSetup.saveTransaction(tx);
      }

      onTransferReceived?.call('Received ₹$amount over radio from $senderName\\n(Pending Escrow Verification)');
    } catch (e) {
      onError?.call('Failed to parse incoming radio money');
    }
  }

  Future<void> stopAll() async {
    await Nearby().stopAdvertising();
    await Nearby().stopDiscovery();
    await Nearby().stopAllEndpoints();
    isAdvertising = false;
    isDiscovering = false;
  }
}
