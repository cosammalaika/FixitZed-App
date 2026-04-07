import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:fixitzed_app/core/app_theme.dart';
import 'package:fixitzed_app/services/payment_preferences.dart';
import 'package:fixitzed_app/services/payment_service.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _methods = const [];
  String? _defaultMethod;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final service = PaymentService();
    final methods = await service.fetchMethods();
    final savedDefault = await PaymentPreferences.defaultMethod();
    if (!mounted) return;
    setState(() {
      _methods = methods;
      _defaultMethod =
          savedDefault ??
          (methods.isNotEmpty
              ? (methods.first['code'] ?? 'cash').toString()
              : null);
      _loading = false;
    });
  }

  Future<void> _setDefault(String code) async {
    await PaymentPreferences.setDefaultMethod(code);
    if (!mounted) return;
    setState(() => _defaultMethod = code);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Default payment method set to $code')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.fx;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        title: Text(
          'Payment Methods',
          style: GoogleFonts.urbanist(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _methods.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.payments_outlined,
                      size: 64,
                      color: colors.textMuted,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No payment methods available right now.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.urbanist(
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Payments will default to cash when none are configured.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.urbanist(color: colors.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _load,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: _methods.length,
                itemBuilder: (context, index) {
                  final method = _methods[index];
                  final code = (method['code'] ?? method['name'] ?? 'cash')
                      .toString();
                  final title = (method['name'] ?? method['label'] ?? code)
                      .toString();
                  final description =
                      (method['description'] ?? method['instructions'] ?? '')
                          .toString();
                  final account =
                      (method['account'] ??
                              method['account_number'] ??
                              method['mobile'])
                          ?.toString();
                  final isDefault = code == _defaultMethod;
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: GoogleFonts.urbanist(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ),
                              if (isDefault)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceTint,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(
                                    'Default',
                                    style: TextStyle(
                                      color: colors.brand,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              description,
                              style: GoogleFonts.urbanist(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                          if (account != null && account.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.account_balance_wallet_outlined,
                                  size: 18,
                                  color: colors.brand,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    account,
                                    style: TextStyle(color: colors.textPrimary),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              onPressed: isDefault
                                  ? null
                                  : () => _setDefault(code),
                              icon: const Icon(Icons.check_circle_outline),
                              label: Text(
                                isDefault ? 'In use' : 'Use as default',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
