import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fixitzed_app/screens/splash_screen.dart';
import 'package:fixitzed_app/screens/onboarding_screen.dart';
import 'package:fixitzed_app/screens/sign_in_screen.dart';
import 'package:fixitzed_app/screens/sign_up_screen.dart';
import 'package:fixitzed_app/screens/dashboard_screen.dart';
import 'package:fixitzed_app/screens/notifications_screen.dart';
import 'package:fixitzed_app/screens/services_list_screen.dart';
import 'package:fixitzed_app/screens/fixers_list_screen.dart';
import 'package:fixitzed_app/screens/profile/edit_profile_screen.dart';
import 'package:fixitzed_app/screens/profile/manage_address_screen.dart';
import 'package:fixitzed_app/screens/profile/payment_methods_screen.dart';
import 'package:fixitzed_app/screens/profile/my_booking_screen.dart';
import 'package:fixitzed_app/screens/profile/settings_screen.dart';
import 'package:fixitzed_app/screens/profile/help_center_screen.dart';
import 'package:fixitzed_app/screens/profile/faqs_screen.dart';
import 'package:fixitzed_app/screens/profile/invite_friend_screen.dart';
import 'package:fixitzed_app/screens/profile/change_password_screen.dart';
import 'package:fixitzed_app/screens/fixer/become_fixer_screen.dart';
import 'package:fixitzed_app/screens/about_screen.dart';
import 'package:fixitzed_app/screens/auth/account_blocked_screen.dart';
import 'package:fixitzed_app/core/app_theme.dart';
import 'package:fixitzed_app/services/local_notification_service.dart';
import 'package:fixitzed_app/common/connectivity/connectivity_overlay.dart';
import 'package:fixitzed_app/widgets/session_redirector.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppTheme.load();
  await LocalNotificationService.instance.init();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.mode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'FixItZed',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light().copyWith(
            textTheme: GoogleFonts.urbanistTextTheme(
              Theme.of(context).textTheme,
            ),
          ),
          darkTheme: AppTheme.dark().copyWith(
            textTheme: GoogleFonts.urbanistTextTheme(
              Theme.of(context).textTheme,
            ),
          ),
          themeMode: mode,
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashScreen(),
            '/onboarding': (context) => const OnboardingScreen(),
            '/auth': (context) => const SignInScreen(),
            '/signup': (context) => const SignUpScreen(),
            '/home': (context) => const DashboardScreen(),
            '/notifications': (context) => const NotificationsScreen(),
            '/services': (context) => const ServicesListScreen(),
            '/fixers': (context) => const FixersListScreen(),
            '/profile/edit': (context) => const EditProfileScreen(),
            '/profile/addresses': (context) => const ManageAddressScreen(),
            '/profile/payments': (context) => const PaymentMethodsScreen(),
            '/profile/bookings': (context) => const MyBookingScreen(),
            '/profile/settings': (context) => const SettingsScreen(),
            '/profile/invite': (context) => const InviteFriendScreen(),
            '/profile/help': (context) => const HelpCenterScreen(),
            '/profile/faqs': (context) => const FaqsScreen(),
            '/profile/password': (context) => const ChangePasswordScreen(),
            '/about': (context) => const AboutScreen(),
            '/fixer/apply': (context) => const BecomeFixerScreen(),
            '/account_blocked': (context) => const AccountBlockedScreen(),
          },
          builder: (context, child) {
            if (child == null) return const SizedBox.shrink();
            return SessionRedirector(child: ConnectivityOverlay(child: child));
          },
        );
      },
    );
  }
}
