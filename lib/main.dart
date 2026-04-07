import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
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
import 'package:fixitzed_app/screens/profile/notification_booking_detail_screen.dart';
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
import 'package:fixitzed_app/services/fcm_service.dart';
import 'package:fixitzed_app/common/connectivity/connectivity_overlay.dart';
import 'package:fixitzed_app/widgets/session_redirector.dart';
import 'package:fixitzed_app/utils/app_snack.dart';
import 'package:fixitzed_app/widgets/auth_required.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppTheme.load();
  await LocalNotificationService.instance.init();
  LocalNotificationService.instance.bindNavigator(appNavigatorKey);
  await FcmService.instance.init();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.mode,
      builder: (context, mode, _) {
        final lightTheme = AppTheme.light();
        final darkTheme = AppTheme.dark();
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          scaffoldMessengerKey: AppSnack.scaffoldMessengerKey,
          title: 'FixItZed',
          debugShowCheckedModeBanner: false,
          theme: lightTheme.copyWith(
            textTheme: GoogleFonts.urbanistTextTheme(lightTheme.textTheme),
          ),
          darkTheme: darkTheme.copyWith(
            textTheme: GoogleFonts.urbanistTextTheme(darkTheme.textTheme),
          ),
          themeMode: mode,
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashScreen(),
            '/onboarding': (context) => const OnboardingScreen(),
            '/auth': (context) => const SignInScreen(),
            '/signup': (context) => const SignUpScreen(),
            '/home': (context) => const DashboardScreen(),
            '/notifications': (context) => const AuthRequiredPage(
              title: 'Sign in to view notifications',
              message:
                  'Your alerts are tied to your account, bookings and payments.',
              actionLabel: 'View notifications',
              child: NotificationsScreen(),
            ),
            '/services': (context) => const ServicesListScreen(),
            '/fixers': (context) => const FixersListScreen(),
            '/profile/edit': (context) => const AuthRequiredPage(
              title: 'Sign in to edit your profile',
              message: 'Profile changes are saved to your FixItZed account.',
              actionLabel: 'Edit profile',
              child: EditProfileScreen(),
            ),
            '/profile/addresses': (context) => const AuthRequiredPage(
              title: 'Sign in to manage addresses',
              message: 'Saved addresses are private to your FixItZed account.',
              actionLabel: 'Manage addresses',
              child: ManageAddressScreen(),
            ),
            '/profile/payments': (context) => const AuthRequiredPage(
              title: 'Sign in to manage payments',
              message: 'Payment methods are private to your FixItZed account.',
              actionLabel: 'Manage payments',
              child: PaymentMethodsScreen(),
            ),
            '/profile/bookings': (context) => const AuthRequiredPage(
              title: 'Sign in to view bookings',
              message: 'Booking history is only available after you sign in.',
              actionLabel: 'View bookings',
              child: MyBookingScreen(),
            ),
            '/profile/booking-detail': (context) => const AuthRequiredPage(
              title: 'Sign in to view booking details',
              message: 'Booking details are private to your FixItZed account.',
              actionLabel: 'View booking details',
              child: NotificationBookingDetailScreen(),
            ),
            '/profile/settings': (context) => const AuthRequiredPage(
              title: 'Sign in to manage account settings',
              message:
                  'Account settings, security and deletion tools are available after sign in.',
              actionLabel: 'Manage settings',
              child: SettingsScreen(),
            ),
            '/profile/invite': (context) => const AuthRequiredPage(
              title: 'Sign in to invite friends',
              message:
                  'Your invite link is generated from your FixItZed account.',
              actionLabel: 'Invite friends',
              child: InviteFriendScreen(),
            ),
            '/profile/help': (context) => const HelpCenterScreen(),
            '/profile/faqs': (context) => const FaqsScreen(),
            '/profile/password': (context) => const AuthRequiredPage(
              title: 'Sign in to change your password',
              message:
                  'Password changes require access to your FixItZed account.',
              actionLabel: 'Change password',
              child: ChangePasswordScreen(),
            ),
            '/about': (context) => const AboutScreen(),
            '/fixer/apply': (context) => const AuthRequiredPage(
              title: 'Sign in to apply as a Fixer',
              message:
                  'Applications are linked to your FixItZed account for review.',
              actionLabel: 'Apply as a Fixer',
              child: BecomeFixerScreen(),
            ),
            '/account_blocked': (context) => const AccountBlockedScreen(),
          },
          builder: (context, child) {
            if (child == null) return const SizedBox.shrink();
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: AppTheme.systemOverlayStyle(context),
              child: SessionRedirector(
                child: ConnectivityOverlay(child: child),
              ),
            );
          },
        );
      },
    );
  }
}
