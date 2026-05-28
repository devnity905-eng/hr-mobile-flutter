import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/employee_dashboard.dart';
import 'screens/hr_dashboard.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => SyncProvider()),
        ChangeNotifierProvider(create: (_) => LocationsProvider()),
      ],
      child: const HRApp(),
    ),
  );
}

class HRApp extends StatelessWidget {
  const HRApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PayPalace HR',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF0D9488),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        cardColor: Colors.white,
        fontFamily: 'Cairo',
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF0D9488),
          secondary: Color(0xFF06B6D4),
          surface: Colors.white,
          background: Color(0xFFF8FAFC),
          error: Color(0xFFEF4444),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Color(0xFF1E293B),
          onBackground: Color(0xFF0F172A),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          bodyLarge: TextStyle(fontSize: 14, color: Color(0xFF475569)),
          bodyMedium: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
      ),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    if (!auth.isAuthenticated) {
      return const LoginScreen();
    }
    
    if (auth.role == 'hr') {
      if (auth.isHRPreview) {
        return const EmployeeDashboard();
      }
      return const HRDashboard();
    } else {
      return const EmployeeDashboard();
    }
  }
}

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  String _employeeId = '';
  String _employeeName = '';
  String _role = 'employee'; // 'employee' or 'hr'
  String _branchId = 'b1';
  double _salary = 12000.0;
  String _jobTitle = 'مهندس برمجيات';

  // HR Masquerading / Preview Mode state
  bool _isHRPreview = false;
  String _previewEmployeeId = '';
  String _previewEmployeeName = '';
  double _previewSalary = 12000.0;
  String _previewJobTitle = '';

  bool get isAuthenticated => _isAuthenticated;
  bool get isHRPreview => _isHRPreview;
  
  String get employeeId => _isHRPreview ? _previewEmployeeId : _employeeId;
  String get employeeName => _isHRPreview ? _previewEmployeeName : _employeeName;
  String get role => _role;
  String get branchId => _branchId;
  double get salary => _isHRPreview ? _previewSalary : _salary;
  String get jobTitle => _isHRPreview ? _previewJobTitle : _jobTitle;

  void startHRPreview(String empId, String empName, double sal, String title) {
    _isHRPreview = true;
    _previewEmployeeId = empId;
    _previewEmployeeName = empName;
    _previewSalary = sal;
    _previewJobTitle = title;
    notifyListeners();
  }

  void stopHRPreview() {
    _isHRPreview = false;
    _previewEmployeeId = '';
    _previewEmployeeName = '';
    _previewSalary = 12000.0;
    _previewJobTitle = '';
    notifyListeners();
  }

  void login(String email, String password, String selectedRole) {
    // Simulating authentication against seeded database
    _isAuthenticated = true;
    _role = selectedRole;
    _isHRPreview = false; // Reset preview on new login
    
    if (selectedRole == 'hr') {
      _employeeId = 'hr1';
      _employeeName = 'أ. محمد المنشاوي (HR)';
      _jobTitle = 'مدير الموارد البشرية';
    } else {
      if (email.contains('sara')) {
        _employeeId = 'e2';
        _employeeName = 'سارة محمد';
        _salary = 8500.0;
        _jobTitle = 'مهندس برمجيات';
      } else {
        _employeeId = 'e1';
        _employeeName = 'أحمد علي';
        _salary = 12000.0;
        _jobTitle = 'مهندس برمجيات';
      }
    }
    notifyListeners();
  }

  void logout() {
    _isAuthenticated = false;
    _employeeId = '';
    _employeeName = '';
    _role = 'employee';
    _isHRPreview = false;
    notifyListeners();
  }
}
