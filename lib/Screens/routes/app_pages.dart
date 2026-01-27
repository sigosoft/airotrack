import 'package:get/get.dart';
import '../modules/splash/bindings/splash_binding.dart';
import '../modules/splash/views/splash_view.dart';
import '../modules/welcome/bindings/welcome_binding.dart';
import '../modules/welcome/views/welcome_view.dart';
import '../modules/login/bindings/login_binding.dart';
import '../modules/login/views/login_view.dart';
import '../modules/register/bindings/register_binding.dart';
import '../modules/register/views/register_view.dart';
import '../modules/forgot_password/bindings/forgot_password_binding.dart';
import '../modules/forgot_password/views/forgot_password_view.dart';
import '../modules/otp_verification/bindings/otp_verification_binding.dart';
import '../modules/otp_verification/views/otp_verification_view.dart';
import '../modules/reset_password/bindings/reset_password_binding.dart';
import '../modules/reset_password/views/reset_password_view.dart';

import '../modules/home/bindings/home_binding.dart';
import '../modules/home/views/home_view.dart';
import '../modules/dashboard/bindings/dashboard_binding.dart';
import '../modules/dashboard/views/dashboard_view.dart';
import '../modules/notification/bindings/notification_binding.dart';
import '../modules/notification/views/notification_view.dart';
import '../modules/reminders/bindings/reminders_binding.dart';
import '../modules/reminders/views/reminders_view.dart';
import '../modules/reminders/bindings/add_reminder_binding.dart';
import '../modules/reminders/views/add_reminder_view.dart';
import '../modules/alerts/bindings/alerts_binding.dart';
import '../modules/alerts/views/alerts_view.dart';
import '../modules/statistics/bindings/statistics_binding.dart';
import '../modules/statistics/views/statistics_view.dart';
import 'app_routes.dart';

class AppPages {
  static const INITIAL = Routes.SPLASH;

  static final routes = [
    GetPage(
      name: Routes.SPLASH,
      page: () => const SplashView(),
      binding: SplashBinding(),
    ),
    GetPage(
      name: Routes.WELCOME,
      page: () => const WelcomeView(),
      binding: WelcomeBinding(),
    ),
    GetPage(
      name: Routes.LOGIN,
      page: () => const LoginView(),
      binding: LoginBinding(),
    ),
    GetPage(
      name: Routes.REGISTER,
      page: () => const RegisterView(),
      binding: RegisterBinding(),
    ),
    GetPage(
      name: Routes.FORGOT_PASSWORD,
      page: () => const ForgotPasswordView(),
      binding: ForgotPasswordBinding(),
    ),
    GetPage(
      name: Routes.OTP_VERIFICATION,
      page: () => const OTPVerificationView(),
      binding: OTPVerificationBinding(),
    ),
    GetPage(
      name: Routes.RESET_PASSWORD,
      page: () => const ResetPasswordView(),
      binding: ResetPasswordBinding(),
    ),
    // Added a placeholder for HOME route
    GetPage(
      name: Routes.HOME,
      page: () => const HomeView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: Routes.DASHBOARD,
      page: () => const DashboardView(),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: Routes.NOTIFICATION,
      page: () => const NotificationView(),
      binding: NotificationBinding(),
    ),
    GetPage(
      name: Routes.REMINDERS,
      page: () => const RemindersView(),
      binding: RemindersBinding(),
    ),
    GetPage(
      name: Routes.ADD_REMINDER,
      page: () => const AddReminderView(),
      binding: AddReminderBinding(),
    ),
    GetPage(
      name: Routes.ALERTS,
      page: () => const AlertsView(),
      binding: AlertsBinding(),
    ),
    GetPage(
      name: Routes.STATISTICS,
      page: () => const StatisticsView(),
      binding: StatisticsBinding(),
    ),
  ];
}
