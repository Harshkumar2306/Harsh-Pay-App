import 'dart:convert';
import 'dart:typed_data';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:uuid/uuid.dart';
import '../../../core/db/hive_setup.dart';
import '../../../core/db/models/offline_transaction.dart';

class NearbyTransferService {
  final Strategy strategy = Strategy.P2P_STAR; // High bandwidth, multi-device
  bool isAdvertising = false;
  bool isDiscovering = false;

  Function(String userName)? onUserFound;
  Function(String payload)? onTransferReceived;
  Function(String msg)? onError;

  Future<void> startAdvertising() async {
    try {
      final wallet = HiveSetup.getWallet();
      if (wallet == null) return;

      bool a = await Nearby().startAdvertising(
        wallet.name,
        strategy,
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
      final wallet = HiveSetup.getWallet();
      if (wallet == null) return;

      bool a = await Nearby().startDiscovery(
        wallet.name,
        strategy,
        onEndpointFound: (String id, String userName, String serviceId) {
          onUserFound?.call(userName);
          // Request connection instantly
          Nearby().requestConnection(
            wallet.name,
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

  Future<void> sendMoneyOverRadio(String targetEndpointId, double amount, String targetName) async {
    final wallet = HiveSetup.getWallet();
    if (wallet == null) return;

    if (wallet.syncedBalance < amount) {
      onError?.call('Insufficient offline balance for radio transfer');
      return;
    }

    // 1. Deduct locally
    wallet.syncedBalance -= amount;
    await HiveSetup.saveWallet(wallet);

    // 2. Save offline transaction
    final tx = OfflineTransaction(
      txId: const Uuid().v4(),
      type: 'debit',
      amount: amount,
      title: 'Radio transfer to $targetName',
      timestamp: DateTime.now().millisecondsSinceEpoch,
      isSynced: false,
    );
    await HiveSetup.saveTransaction(tx);

    // 3. Beam over radio
    final payloadData = {
      'txId': tx.txId,
      'senderName': wallet.name,
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

      final wallet = HiveSetup.getWallet();
      if (wallet != null) {
        wallet.syncedBalance += amount;
        await HiveSetup.saveWallet(wallet);

        final tx = OfflineTransaction(
          txId: data['txId'] ?? const Uuid().v4(),
          type: 'credit',
          amount: amount,
          title: 'Received offline from $senderName',
          timestamp: DateTime.now().millisecondsSinceEpoch,
          isSynced: false,
        );
        await HiveSetup.saveTransaction(tx);
      }

      onTransferReceived?.call('Received ₹$amount over radio from $senderName');
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
