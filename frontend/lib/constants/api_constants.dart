class ApiConstants {
  // Cổng HTTP backend NutriSnap đang chạy
  static const String baseUrl = 'http://localhost:5065';

  static const String login = '$baseUrl/api/auth/login';
  static const String register = '$baseUrl/api/auth/register';
  static const String forgotPassword = '$baseUrl/api/auth/forgotPassword';
  static const String resetPassword = '$baseUrl/api/auth/resetPassword';
}