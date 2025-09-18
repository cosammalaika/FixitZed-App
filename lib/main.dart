import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:fixitzed_app/screens/splash_screen.dart';
import 'package:fixitzed_app/screens/onboarding_screen.dart';
import 'package:fixitzed_app/screens/sign_in_screen.dart';
import 'package:fixitzed_app/screens/sign_up_screen.dart';
import 'package:fixitzed_app/screens/dashboard_screen.dart';
import 'package:fixitzed_app/screens/notifications_screen.dart';
import 'package:fixitzed_app/screens/profile/edit_profile_screen.dart';
import 'package:fixitzed_app/screens/profile/manage_address_screen.dart';
import 'package:fixitzed_app/screens/profile/payment_methods_screen.dart';
import 'package:fixitzed_app/screens/profile/my_booking_screen.dart';
import 'package:fixitzed_app/screens/profile/settings_screen.dart';
import 'package:fixitzed_app/screens/profile/help_center_screen.dart';
import 'package:fixitzed_app/screens/profile/faqs_screen.dart';
import 'package:fixitzed_app/screens/fixer/become_fixer_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFFF1592A);
    return MaterialApp(
      title: 'FixItZed',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: brand),
        primaryColor: brand,
        textTheme: GoogleFonts.urbanistTextTheme(Theme.of(context).textTheme),
        checkboxTheme: CheckboxThemeData(
          fillColor: MaterialStatePropertyAll(brand),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: MaterialStatePropertyAll(brand),
          trackColor: MaterialStatePropertyAll(brand.withOpacity(0.4)),
        ),
        radioTheme: RadioThemeData(
          fillColor: MaterialStatePropertyAll(brand),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/auth': (context) => const SignInScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/home': (context) => const DashboardScreen(),
        '/notifications': (context) => const NotificationsScreen(),
        '/profile/edit': (context) => const EditProfileScreen(),
        '/profile/addresses': (context) => const ManageAddressScreen(),
        '/profile/payments': (context) => const PaymentMethodsScreen(),
        '/profile/bookings': (context) => const MyBookingScreen(),
        '/profile/settings': (context) => const SettingsScreen(),
        '/profile/help': (context) => const HelpCenterScreen(),
        '/profile/faqs': (context) => const FaqsScreen(),
        '/fixer/apply': (context) => const BecomeFixerScreen(),
      },
    );
  }
}
