import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/db/hive_setup.dart';
import '../services/nearby_service.dart';

class RadioTransferScreen extends StatefulWidget {
  const RadioTransferScreen({super.key});

  @override
  State<RadioTransferScreen> createState() => _RadioTransferScreenState();
}

class _RadioTransferScreenState extends State<RadioTransferScreen> with TickerProviderStateMixin {
  final NearbyTransferService _nearbyService = NearbyTransferService();

  bool _isAdvertising = false;
  bool _isDiscovering = false;
  String? _discoveredUser;
  String? _discoveredEndpointId;
  String? _statusMessage;
  bool _transferSuccess = false;
  bool _isLoading = false;

  final TextEditingController _amountController = TextEditingController();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _setupCallbacks();
  }

  void _setupCallbacks() {
    _nearbyService.onUserFound = (endpointInfo) {
      if (mounted) {
        final realName = endpointInfo.split('::')[0];
        setState(() {
          _discoveredUser = endpointInfo; // Store full info for sending
          _statusMessage = 'Found $realName nearby!';
        });
        HapticFeedback.mediumImpact();
      }
    };

    _nearbyService.onEndpointFound = (endpointId, endpointInfo) {
      if (mounted) {
        final realName = endpointInfo.split('::')[0];
        setState(() {
          _discoveredEndpointId = endpointId;
          _discoveredUser = endpointInfo; // Store full info for sending
          _statusMessage = 'Connected to $realName — enter amount and send!';
        });
        HapticFeedback.mediumImpact();
      }
    };

    _nearbyService.onTransferReceived = (msg) {
      if (mounted) {
        setState(() {
          _transferSuccess = true;
          _statusMessage = msg;
          _isAdvertising = false;
        });
        HapticFeedback.heavyImpact();
      }
    };

    _nearbyService.onError = (err) {
      if (mounted) {
        setState(() => _statusMessage = 'Error: $err');
      }
    };
  }

  Future<void> _startReceiving() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Broadcasting your presence...';
      _discoveredUser = null;
      _discoveredEndpointId = null;
      _transferSuccess = false;
    });
    await _nearbyService.startAdvertising();
    if (mounted) {
      setState(() {
        _isAdvertising = _nearbyService.isAdvertising;
        _isLoading = false;
        if (_isAdvertising) {
          _statusMessage = 'Waiting for sender to find you...';
        }
      });
    }
  }

  Future<void> _startSending() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Scanning for nearby devices...';
      _discoveredUser = null;
      _discoveredEndpointId = null;
      _transferSuccess = false;
    });
    await _nearbyService.startDiscovering();
    if (mounted) {
      setState(() {
        _isDiscovering = _nearbyService.isDiscovering;
        _isLoading = false;
        if (_isDiscovering) {
          _statusMessage = 'Looking for receivers nearby...';
        }
      });
    }
  }

  Future<void> _sendMoney() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() => _statusMessage = 'Enter a valid amount');
      return;
    }

    if (_discoveredEndpointId == null) {
      setState(() => _statusMessage = 'No device connected yet. Wait for discovery.');
      return;
    }

    HapticFeedback.heavyImpact();
    await _nearbyService.sendMoneyOverRadio(_discoveredEndpointId!, amount, _discoveredUser ?? 'Unknown');
    final realName = _discoveredUser?.split('::')[0] ?? 'Unknown';
    setState(() {
      _transferSuccess = true;
      _statusMessage = 'Sent ₹$amount to $realName over Radio!\\n(Pending Escrow Verification)';
    });
  }

  Future<void> _stopAll() async {
    await _nearbyService.stopAll();
    setState(() {
      _isAdvertising = false;
      _isDiscovering = false;
      _discoveredUser = null;
      _discoveredEndpointId = null;
      _statusMessage = null;
      _transferSuccess = false;
    });
  }

  @override
  void dispose() {
    _nearbyService.stopAll();
    _pulseController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallet = HiveSetup.getWallet();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Radio Transfer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_isAdvertising || _isDiscovering)
            TextButton(
              onPressed: _stopAll,
              child: const Text('Stop', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: SafeArea(
        child: Platform.isIOS ? _buildIosNotSupported() : SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Radar animation
              SizedBox(
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_isAdvertising || _isDiscovering) ...[
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (_, __) => Container(
                          width: 180 + (_pulseController.value * 80),
                          height: 180 + (_pulseController.value * 80),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 1 - _pulseController.value),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (_, __) {
                          final delayed = (_pulseController.value + 0.5) % 1.0;
                          return Container(
                            width: 180 + (delayed * 80),
                            height: 180 + (delayed * 80),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 1 - delayed),
                                width: 2,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: _transferSuccess
                              ? [const Color(0xFF10B981), const Color(0xFF059669)]
                              : [AppColors.surface, AppColors.surface],
                        ),
                        border: Border.all(color: AppColors.primary, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 30,
                          ),
                        ],
                      ),
                      child: Icon(
                        _transferSuccess ? Icons.check_circle : Icons.wifi_tethering_rounded,
                        color: AppColors.primary,
                        size: 52,
                      ),
                    ),
                    if (_discoveredUser != null)
                      Positioned(
                        top: 20,
                        right: 30,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.primary),
                          ),
                          child: Text(
                            _discoveredUser!,
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ).animate().scale(curve: Curves.easeOutBack),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Status
              if (_statusMessage != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _transferSuccess ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _transferSuccess ? AppColors.primary : AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isLoading) ...[
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        ),
                        const SizedBox(width: 10),
                      ] else if (_transferSuccess) ...[
                        const Icon(Icons.check_circle, color: AppColors.primary, size: 16),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          _statusMessage!,
                          style: TextStyle(
                            color: _transferSuccess ? AppColors.primary : AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(),

              const SizedBox(height: 32),

              // Balance card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Offline Balance', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text(
                      '₹ ${(wallet?.syncedBalance ?? 0).toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -1),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Wallet: ${wallet?.name ?? 'Not synced'}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Mode buttons (if nothing active)
              if (!_isAdvertising && !_isDiscovering && !_transferSuccess) ...[
                const Text(
                  'How do you want to use Radio?',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _ModeCard(
                        icon: Icons.download_rounded,
                        label: 'Receive Money',
                        subtitle: 'Show your radio signal so someone can send you money',
                        color: const Color(0xFF059669),
                        onTap: _isLoading ? null : _startReceiving,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ModeCard(
                        icon: Icons.upload_rounded,
                        label: 'Send Money',
                        subtitle: 'Find someone nearby and beam them money',
                        color: AppColors.primary,
                        onTap: _isLoading ? null : _startSending,
                      ),
                    ),
                  ],
                ),
              ],

              // RECEIVING mode UI
              if (_isAdvertising && !_transferSuccess) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.sensors_rounded, color: AppColors.primary, size: 40),
                      SizedBox(height: 12),
                      Text('Your Radio is ON', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      SizedBox(height: 6),
                      Text(
                        'Ask the sender to tap "Send Money" on their phone. They will discover you automatically.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],

              // SENDING mode UI
              if (_isDiscovering && !_transferSuccess) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      if (_discoveredUser == null) ...[
                        const Icon(Icons.radar_rounded, color: AppColors.primary, size: 40),
                        const SizedBox(height: 12),
                        const Text('Scanning...', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        const Text(
                          'Make sure receiver has tapped "Receive Money". Keep phones close together.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ] else ...[
                        const Icon(Icons.person_pin_circle_rounded, color: AppColors.primary, size: 40),
                        const SizedBox(height: 12),
                        Text('Connected to $_discoveredUser!', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            hintText: '₹ Amount',
                            hintStyle: const TextStyle(color: AppColors.textSecondary),
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: const Icon(Icons.send_rounded, color: Colors.black),
                            label: const Text('Beam Money', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                            onPressed: _sendMoney,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              if (_transferSuccess) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _stopAll,
                    child: const Text('Done / New Transfer', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],

              const SizedBox(height: 32),
              const Text(
                '📡 Radio works without internet using Bluetooth & Wi-Fi Direct. Keep both phones unlocked and close together.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIosNotSupported() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.apple_rounded, size: 50, color: Colors.redAccent),
            ),
            const SizedBox(height: 24),
            const Text(
              'iOS Not Supported Yet',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Radio Transfer (Nearby Connections) is currently an Android-exclusive feature. Cross-platform iOS support is coming in a future update!',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              label: const Text('Go Back', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surface,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  const _ModeCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11), textAlign: TextAlign.center),
          ],
        ),
      ).animate().scale(curve: Curves.easeOutBack),
    );
  }
}
