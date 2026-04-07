import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:fixitzed_app/screens/sign_in_screen.dart';
import 'package:fixitzed_app/screens/sign_up_screen.dart';
import 'package:fixitzed_app/services/token_storage.dart';
import 'package:fixitzed_app/core/app_theme.dart';

enum _AuthRequiredChoice { signIn, signUp }

Future<bool> isAuthenticated() async {
  final token = await TokenStorage.instance.getToken();
  return token != null && token.isNotEmpty;
}

Future<bool> ensureAuthenticated(
  BuildContext context, {
  String title = 'Sign in required',
  String message =
      'Create or sign in to your account to continue with this action.',
  String actionLabel = 'Continue',
}) async {
  if (await isAuthenticated()) return true;
  if (!context.mounted) return false;

  final choice = await showModalBottomSheet<_AuthRequiredChoice>(
    context: context,
    useSafeArea: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AuthRequiredSheet(
      title: title,
      message: message,
      actionLabel: actionLabel,
    ),
  );

  if (choice == null || !context.mounted) return false;

  final route = MaterialPageRoute<bool>(
    fullscreenDialog: true,
    builder: (_) => choice == _AuthRequiredChoice.signIn
        ? const SignInScreen(returnOnSuccess: true)
        : const SignUpScreen(returnOnSuccess: true),
  );
  final result = await Navigator.of(context, rootNavigator: true).push(route);
  return result == true;
}

class AuthRequiredPage extends StatefulWidget {
  const AuthRequiredPage({
    super.key,
    required this.child,
    this.title = 'Sign in required',
    this.message =
        'Sign in to access your account tools, booking history and saved details.',
    this.actionLabel = 'Continue',
  });

  final Widget child;
  final String title;
  final String message;
  final String actionLabel;

  @override
  State<AuthRequiredPage> createState() => _AuthRequiredPageState();
}

class _AuthRequiredPageState extends State<AuthRequiredPage> {
  late Future<bool> _authFuture;

  @override
  void initState() {
    super.initState();
    _authFuture = isAuthenticated();
  }

  void _refreshAuthState() {
    setState(() => _authFuture = isAuthenticated());
  }

  Future<void> _authenticate({required bool createAccount}) async {
    final route = MaterialPageRoute<bool>(
      fullscreenDialog: true,
      builder: (_) => createAccount
          ? const SignUpScreen(returnOnSuccess: true)
          : const SignInScreen(returnOnSuccess: true),
    );
    final result = await Navigator.of(context, rootNavigator: true).push(route);
    if (!mounted) return;
    if (result == true) {
      _refreshAuthState();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _authFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data == true) {
          return widget.child;
        }

        return _AuthRequiredScaffold(
          title: widget.title,
          message: widget.message,
          actionLabel: widget.actionLabel,
          onSignIn: () => _authenticate(createAccount: false),
          onSignUp: () => _authenticate(createAccount: true),
          onContinueBrowsing: () => Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/home', (route) => false),
        );
      },
    );
  }
}

class _AuthRequiredScaffold extends StatelessWidget {
  const _AuthRequiredScaffold({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onSignIn,
    required this.onSignUp,
    required this.onContinueBrowsing,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onSignIn;
  final VoidCallback onSignUp;
  final VoidCallback onContinueBrowsing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = theme.fx;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: _AuthRequiredCard(
                title: title,
                message: message,
                actionLabel: actionLabel,
                onSignIn: onSignIn,
                onSignUp: onSignUp,
                onContinueBrowsing: onContinueBrowsing,
                colors: colors,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthRequiredSheet extends StatelessWidget {
  const _AuthRequiredSheet({
    required this.title,
    required this.message,
    required this.actionLabel,
  });

  final String title;
  final String message;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final colors = theme.fx;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        color: theme.cardColor,
        padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            _AuthRequiredCard(
              title: title,
              message: message,
              actionLabel: actionLabel,
              onSignIn: () =>
                  Navigator.of(context).pop(_AuthRequiredChoice.signIn),
              onSignUp: () =>
                  Navigator.of(context).pop(_AuthRequiredChoice.signUp),
              onContinueBrowsing: () => Navigator.of(context).pop(),
              colors: colors,
              embedded: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthRequiredCard extends StatelessWidget {
  const _AuthRequiredCard({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onSignIn,
    required this.onSignUp,
    required this.onContinueBrowsing,
    required this.colors,
    this.embedded = false,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onSignIn;
  final VoidCallback onSignUp;
  final VoidCallback onContinueBrowsing;
  final AppThemeColors colors;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(embedded ? 0 : 22),
      decoration: embedded
          ? null
          : BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.border),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow,
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: colors.surfaceTint,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock_outline_rounded,
              color: colors.brand,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.urbanist(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.urbanist(
              color: colors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSignIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.brand,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                actionLabel.trim().isEmpty || actionLabel == 'Continue'
                    ? 'Sign In'
                    : 'Sign In to $actionLabel',
                style: GoogleFonts.urbanist(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onSignUp,
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.brand,
                side: BorderSide(color: colors.brand.withOpacity(0.55)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Create Account',
                style: GoogleFonts.urbanist(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: onContinueBrowsing,
            child: Text(
              'Maybe Not Now',
              style: GoogleFonts.urbanist(
                color: colors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
