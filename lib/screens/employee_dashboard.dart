import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart' as intl;
import '../main.dart';
import '../services/api_service.dart';

class EmployeeDashboard extends StatefulWidget {
  const EmployeeDashboard({super.key});

  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard> {
  int _currentBottomNavIndex = 0; // الرئيسية is index 0
  Timer? _backgroundTrackingTimer;
  bool _isInit = true;

  // Forms Controllers
  final _leaveDaysController = TextEditingController(text: '3');
  String _leaveType = 'annual'; // annual, sick, casual
  final _loanAmountController = TextEditingController(text: '2000');
  final _loanInstallmentController = TextEditingController(text: '4');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      // Silently log location in background
      _silentRegisterLocation();
      _backgroundTrackingTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
        _silentRegisterLocation();
      });
      _isInit = false;
    }
  }

  @override
  void dispose() {
    _backgroundTrackingTimer?.cancel();
    super.dispose();
  }

  // Silent background tracking logic
  void _silentRegisterLocation() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isHRPreview) return; // Do not track HR manager's location
      
      final sync = Provider.of<SyncProvider>(context, listen: false);
      final locProv = Provider.of<LocationsProvider>(context, listen: false);

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
        );

        double distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          30.0444,
          31.2357,
        );

        String locationLabel = distance <= 250.0 
            ? 'مقر العمل (تحديد تلقائي)' 
            : 'خارج مقر العمل (تحديد تلقائي)';

        await locProv.registerLocation(
          employeeId: auth.employeeId,
          placeName: locationLabel,
          syncProvider: sync,
        );
      }
    } catch (_) {
      // Stealth fail
    }
  }

  void _showHRPreviewBlockedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: const [
              Text(
                'تنبيه المعاينة النشطة',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFFD97706),
                ),
              ),
              SizedBox(width: 8),
              Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFF59E0B),
                size: 24,
              ),
            ],
          ),
          content: const Text(
            'عذراً! لا يمكن إجراء أي معاملات أو حركات نيابة عن الموظف أثناء وضع المعاينة. يجب على الموظف تسجيل الدخول بنفسه من جهازه الشخصي لتسجيل حضور أو تقديم طلبات.',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              color: Color(0xFF1E293B),
              height: 1.5,
            ),
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                ),
                child: const Text(
                  'حسناً، فهمت ذلك',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFormDialog({
    required String title,
    required Widget Function(BuildContext context, StateSetter setDialogState) builder,
    required VoidCallback onSubmit,
  }) {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Colors.black12),
              ),
              title: Text(
                title,
                textAlign: TextAlign.right,
                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E293B)),
              ),
              content: Directionality(
                textDirection: TextDirection.rtl,
                child: SingleChildScrollView(child: builder(context, setDialogState)),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  onPressed: () {
                    onSubmit();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('إرسال الطلب', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
                ),
              ],
            );
          }
        ),
      ),
    );
  }

  void _requestLeave(AuthProvider auth, SyncProvider sync) {
    _showFormDialog(
      title: 'تقديم طلب إجازة جديدة',
      builder: (context, setDialogState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('نوع الإجازة:', style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF475569))),
          DropdownButtonFormField<String>(
            value: _leaveType,
            dropdownColor: Colors.white,
            items: const [
              DropdownMenuItem(value: 'annual', child: Text('سنوية', style: TextStyle(fontFamily: 'Cairo', color: Colors.black))),
              DropdownMenuItem(value: 'sick', child: Text('مرضية', style: TextStyle(fontFamily: 'Cairo', color: Colors.black))),
              DropdownMenuItem(value: 'casual', child: Text('طارئة', style: TextStyle(fontFamily: 'Cairo', color: Colors.black))),
            ],
            onChanged: (val) {
              setDialogState(() {
                _leaveType = val ?? 'annual';
              });
            },
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('عدد الأيام المطلوبة:', style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF475569))),
          TextField(
            controller: _leaveDaysController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              hintText: 'مثال: 3',
            ),
          ),
        ],
      ),
      onSubmit: () {
        final data = {
          'employee_id': auth.employeeId,
          'leave_type': _leaveType,
          'days': int.tryParse(_leaveDaysController.text) ?? 1,
          'start_date': intl.DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 2))),
        };
        sync.addToQueue('leave_request', data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تسجيل طلب الإجازة بنجاح وجار المزامنة.', textDirection: TextDirection.rtl),
            backgroundColor: Color(0xFF0D9488),
          ),
        );
      },
    );
  }

  void _requestLoan(AuthProvider auth, SyncProvider sync) {
    _showFormDialog(
      title: 'تقديم طلب سلفة مالية (قرض)',
      builder: (context, setDialogState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('مبلغ السلفة المطلوب (بالجنيه):', style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF475569))),
          TextField(
            controller: _loanAmountController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              hintText: 'مثال: 2000',
            ),
          ),
          const SizedBox(height: 16),
          const Text('مدة السداد بالأشهر (الأقساط):', style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF475569))),
          TextField(
            controller: _loanInstallmentController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              hintText: 'مثال: 4 أشهر',
            ),
          ),
        ],
      ),
      onSubmit: () {
        final data = {
          'employee_id': auth.employeeId,
          'amount': double.tryParse(_loanAmountController.text) ?? 1000.0,
          'installment_months': int.tryParse(_loanInstallmentController.text) ?? 1,
        };
        sync.addToQueue('loan_request', data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تسجيل طلب السلفة بنجاح وجار المزامنة.', textDirection: TextDirection.rtl),
            backgroundColor: Color(0xFF0D9488),
          ),
        );
      },
    );
  }

  void _requestDelay(AuthProvider auth, SyncProvider sync) {
    final hoursController = TextEditingController(text: '2');
    final reasonController = TextEditingController();
    _showFormDialog(
      title: 'طلب إذن تأخير عن العمل',
      builder: (context, setDialogState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('عدد ساعات التأخير المطلوبة:', style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF475569))),
          TextField(
            controller: hoursController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              hintText: 'مثال: 2',
            ),
          ),
          const SizedBox(height: 16),
          const Text('السبب:', style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF475569))),
          TextField(
            controller: reasonController,
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              hintText: 'اكتب سبب التأخير هنا',
            ),
          ),
        ],
      ),
      onSubmit: () {
        final data = {
          'employee_id': auth.employeeId,
          'hours': hoursController.text,
          'reason': reasonController.text,
          'date': intl.DateFormat('yyyy-MM-dd').format(DateTime.now()),
        };
        sync.addToQueue('delay_request', data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تسجيل طلب إذن التأخير بنجاح وجار المزامنة.', textDirection: TextDirection.rtl),
            backgroundColor: Color(0xFF0D9488),
          ),
        );
      },
    );
  }

  void _requestWorkFromHome(AuthProvider auth, SyncProvider sync) {
    final reasonController = TextEditingController();
    _showFormDialog(
      title: 'طلب عمل من المنزل (WFH)',
      builder: (context, setDialogState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('تاريخ اليوم المطلوب:', style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF475569))),
          Text(intl.DateFormat('yyyy-MM-dd').format(DateTime.now()), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black)),
          const SizedBox(height: 16),
          const Text('سبب طلب العمل من المنزل:', style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF475569))),
          TextField(
            controller: reasonController,
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              hintText: 'اكتب تفاصيل السبب هنا',
            ),
          ),
        ],
      ),
      onSubmit: () {
        final data = {
          'employee_id': auth.employeeId,
          'reason': reasonController.text,
          'date': intl.DateFormat('yyyy-MM-dd').format(DateTime.now()),
        };
        sync.addToQueue('wfh_request', data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تسجيل طلب العمل من المنزل بنجاح وجار المزامنة.', textDirection: TextDirection.rtl),
            backgroundColor: Color(0xFF0D9488),
          ),
        );
      },
    );
  }

  void _requestExit(AuthProvider auth, SyncProvider sync) {
    final timeController = TextEditingController(text: '02:00 م');
    final reasonController = TextEditingController();
    _showFormDialog(
      title: 'تقديم طلب إذن انصراف مبكر',
      builder: (context, setDialogState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('وقت المغادرة المطلوب:', style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF475569))),
          TextField(
            controller: timeController,
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              hintText: 'مثال: 02:00 مساءً',
            ),
          ),
          const SizedBox(height: 16),
          const Text('السبب:', style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF475569))),
          TextField(
            controller: reasonController,
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              hintText: 'سبب الانصراف المبكر',
            ),
          ),
        ],
      ),
      onSubmit: () {
        final data = {
          'employee_id': auth.employeeId,
          'time': timeController.text,
          'reason': reasonController.text,
          'date': intl.DateFormat('yyyy-MM-dd').format(DateTime.now()),
        };
        sync.addToQueue('exit_request', data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تسجيل طلب إذن الانصراف بنجاح وجار المزامنة.', textDirection: TextDirection.rtl),
            backgroundColor: Color(0xFF0D9488),
          ),
        );
      },
    );
  }

  void _showNotifications() {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.black12),
          ),
          title: const Text(
            'تنبيهات النظام والإشعارات',
            textAlign: TextAlign.right,
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E293B)),
          ),
          content: Directionality(
            textDirection: TextDirection.rtl,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildNotificationTile('تم اعتماد إجازتك السنوية بنجاح 🟢', 'منذ ساعتين - الإدارة المالية'),
                  const Divider(color: Colors.black12),
                  _buildNotificationTile('تم إيداع راتب شهر مايو في حسابك 💳', 'أمس - كشف الحساب والرواتب'),
                  const Divider(color: Colors.black12),
                  _buildNotificationTile('الرجاء تحديث ملف التأمين الاجتماعي الخاص بك 🪪', 'منذ 3 أيام - شؤون الموظفين'),
                  const Divider(color: Colors.black12),
                  _buildNotificationTile('مرحبًا بك في تطبيق PayPalace الجديد 🎉', 'منذ أسبوع - الإدارة العامة'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق', style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF0D9488), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationTile(String text, String time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Color(0xFF1E293B), fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(time, style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  void _showAllActivitiesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.black12),
          ),
          title: const Text(
            'سجل النشاطات الكامل',
            textAlign: TextAlign.right,
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E293B)),
          ),
          content: Directionality(
            textDirection: TextDirection.rtl,
            child: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: [
                  _buildAllActivityTile('تمت الموافقة على طلب الإجازة السنوية 🟢', 'منذ ساعتين - الموارد البشرية', Icons.check_circle_outline_rounded, const Color(0xFF10B981)),
                  const Divider(color: Colors.black12),
                  _buildAllActivityTile('تم صرف راتب شهر مايو في الحساب البنكي 💳', 'أمس - الإدارة المالية', Icons.account_balance_wallet_outlined, const Color(0xFF0D9488)),
                  const Divider(color: Colors.black12),
                  _buildAllActivityTile('تسجيل حضور ناجح – فرع القاهرة الرئيسي 📍', 'منذ 3 أيام (09:02 ص)', Icons.location_on_outlined, const Color(0xFF0D9488)),
                  const Divider(color: Colors.black12),
                  _buildAllActivityTile('تسجيل انصراف ناجح – فرع القاهرة الرئيسي 📍', 'منذ 3 أيام (05:01 م)', Icons.exit_to_app_rounded, const Color(0xFFEF4444)),
                  const Divider(color: Colors.black12),
                  _buildAllActivityTile('تسجيل حضور ناجح – فرع القاهرة الرئيسي 📍', 'منذ 4 أيام (08:58 ص)', Icons.location_on_outlined, const Color(0xFF0D9488)),
                  const Divider(color: Colors.black12),
                  _buildAllActivityTile('تسجيل انصراف ناجح – فرع القاهرة الرئيسي 📍', 'منذ 4 أيام (04:59 م)', Icons.exit_to_app_rounded, const Color(0xFFEF4444)),
                  const Divider(color: Colors.black12),
                  _buildAllActivityTile('تم اعتماد وصرف السلفة المالية بقيمة 2000 ج.م 💵', 'منذ أسبوع - الإدارة العامة', Icons.monetization_on_outlined, const Color(0xFFF59E0B)),
                  const Divider(color: Colors.black12),
                  _buildAllActivityTile('طلب إذن تأخير لمدة ساعتين مقبول من الإدارة 🕒', 'منذ أسبوعين', Icons.watch_later_outlined, const Color(0xFF3B82F6)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق', style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF0D9488), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _startAttendanceFlow(BuildContext context, AuthProvider auth, AttendanceProvider attendance, SyncProvider sync) async {
    // 1. Verify GPS coordinates first in background
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('جاري التحقق من النطاق الجغرافي GPS...', textDirection: TextDirection.rtl),
        backgroundColor: Color(0xFF0D9488),
        duration: Duration(seconds: 1),
      ),
    );

    // Verify location
    bool withinRange = false;
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        30.0444,
        31.2357,
      );
      if (distance <= 250.0) {
        withinRange = true;
      }
    } catch (_) {
      // Fallback
    }

    // If already checked in, checkout doesn't require a selfie (direct check-out)
    if (attendance.isCheckedIn) {
      final success = await attendance.toggleAttendance(auth.employeeId, sync);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تسجيل انصرافك بنجاح! 👋', textDirection: TextDirection.rtl),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
      return;
    }

    // Verify GPS range
    if (!withinRange) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('عذراً! أنت خارج النطاق الجغرافي المعتمد للفرع. النطاق المسموح به 250 متر فقط.', textDirection: TextDirection.rtl),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    // 2. Open Selfie Dialog
    _showSelfieCaptureDialog(context, () async {
      // Once selfie is captured, complete check-in
      final success = await attendance.toggleAttendance(auth.employeeId, sync);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم التحقق من الوجه وتسجيل حضورك الجغرافي بنجاح! 🟢', textDirection: TextDirection.rtl),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    });
  }

  void _showSelfieCaptureDialog(BuildContext context, VoidCallback onCaptured) {
    showDialog(
      context: context,
      barrierDismissible: false, // Must take selfie
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            bool isCapturing = false;
            bool isSuccess = false;

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Colors.black12),
              ),
              title: const Text(
                'التحقق من الهوية بالصورة الشخصية (سيلفي)',
                textAlign: TextAlign.right,
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
              ),
              content: Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'يرجى وضع وجهك داخل الإطار الدائري والتقاط صورة للتحقق التلقائي بمطابقة الملامح.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 20),
                    // Simulated Camera Circular Frame
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSuccess ? const Color(0xFF10B981) : const Color(0xFF0D9488),
                              width: 3,
                            ),
                            color: const Color(0xFFF1F5F9),
                          ),
                          child: ClipOval(
                            child: isCapturing
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF0D9488),
                                    ),
                                  )
                                : (isSuccess
                                    ? const Icon(
                                        Icons.check_circle_rounded,
                                        color: Color(0xFF10B981),
                                        size: 80,
                                      )
                                    : const Icon(
                                        Icons.face_retouching_natural_rounded,
                                        color: Color(0xFF94A3B8),
                                        size: 80,
                                      )),
                          ),
                        ),
                        // Scanner line animation overlay
                        if (!isCapturing && !isSuccess)
                          Positioned(
                            top: 30,
                            child: Container(
                              width: 140,
                              height: 2,
                              decoration: BoxDecoration(
                                color: const Color(0xFF06B6D4).withOpacity(0.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF06B6D4).withOpacity(0.5),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isCapturing
                          ? 'جاري فحص ملامح الوجه للتحقق...'
                          : (isSuccess ? 'تم التحقق بنجاح! ✔️' : 'الكاميرا جاهزة للالتقاط'),
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isSuccess ? const Color(0xFF10B981) : const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                if (!isSuccess)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'إلغاء',
                      style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF64748B)),
                    ),
                  ),
                if (!isSuccess)
                  ElevatedButton.icon(
                    onPressed: isCapturing
                        ? null
                        : () {
                            setDialogState(() {
                              isCapturing = true;
                            });
                            // Simulate face scanning/capture for 2 seconds
                            Timer(const Duration(seconds: 2), () {
                              setDialogState(() {
                                isCapturing = false;
                                isSuccess = true;
                              });
                              Timer(const Duration(milliseconds: 800), () {
                                Navigator.pop(context);
                                onCaptured();
                              });
                            });
                          },
                    icon: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                    label: const Text(
                      'التقاط سيلفي',
                      style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAllActivityTile(String text, String time, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Color(0xFF1E293B), fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(time, style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }


  void _viewPayslip(AuthProvider auth) {
    double gross = auth.salary;
    double insuranceBase = gross > 10000 ? 10000 : gross;
    double employeeInsurance = insuranceBase * 0.11;
    
    double annualGross = (gross - employeeInsurance) * 12;
    double personalExemption = 20000;
    double taxableIncome = annualGross - personalExemption;
    if (taxableIncome < 0) taxableIncome = 0;
    
    double annualTax = 0;
    if (taxableIncome > 0) {
      if (taxableIncome <= 15000) {
        annualTax += taxableIncome * 0.025;
      } else if (taxableIncome <= 30000) {
        annualTax += (15000 * 0.025) + ((taxableIncome - 15000) * 0.10);
      } else if (taxableIncome <= 45000) {
        annualTax += (15000 * 0.025) + (15000 * 0.10) + ((taxableIncome - 30000) * 0.15);
      } else {
        annualTax += (15000 * 0.025) + (15000 * 0.10) + (15000 * 0.15) + ((taxableIncome - 45000) * 0.20);
      }
    }
    double monthlyTax = annualTax / 12;
    double simulatedLoanDeduction = auth.employeeId == 'e1' ? 1000.0 : 0.0;
    double netSalary = gross - employeeInsurance - monthlyTax - simulatedLoanDeduction;

    _showFormDialog(
      title: 'كشف الراتب وتفاصيل الضرائب والتأمينات',
      builder: (context, setDialogState) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildBreakdownRow('الراتب الإجمالي الأساسي', gross, isEgp: true),
          _buildBreakdownRow('تأمينات اجتماعية موظف (11%)', -employeeInsurance, isEgp: true, isDeduction: true),
          _buildBreakdownRow('ضريبة كسب العمل المصرية', -monthlyTax, isEgp: true, isDeduction: true),
          if (simulatedLoanDeduction > 0)
            _buildBreakdownRow('سداد قسط سلفة معتمد', -simulatedLoanDeduction, isEgp: true, isDeduction: true),
          const Divider(color: Colors.black12, height: 24),
          _buildBreakdownRow('صافي الراتب النهائي المستحق', netSalary, isEgp: true, isHighlighted: true),
        ],
      ),
      onSubmit: () {},
    );
  }

  Widget _buildBreakdownRow(String title, double value, {bool isEgp = false, bool isDeduction = false, bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: isHighlighted ? 15 : 13,
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
              color: isHighlighted ? const Color(0xFF0D9488) : const Color(0xFF475569),
            ),
          ),
          Text(
            '${value > 0 && !isHighlighted ? '+' : ''}${value.toStringAsFixed(1)} ${isEgp ? 'ج.م' : ''}',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: isHighlighted ? 15 : 13,
              fontWeight: FontWeight.bold,
              color: isDeduction ? const Color(0xFFEF4444) : (isHighlighted ? const Color(0xFF0D9488) : const Color(0xFF10B981)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final attendance = Provider.of<AttendanceProvider>(context);
    final sync = Provider.of<SyncProvider>(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      bottomNavigationBar: _buildBottomNavigationBar(),
      body: Column(
        children: [
          // 1. Connection Drop Notification Banner
          if (sync.isOffline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: const Color(0xFFD97706),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'وضع العمل دون اتصال نشط حالياً. سيتم المزامنة تلقائياً فور توفر الإنترنت.',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

          // 2. Premium Top Preview Banner (Shown only for HR Preview Mode)
          if (auth.isHRPreview)
            Container(
              color: const Color(0xFF0F172A), // Elegant Slate Dark Blue
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: SafeArea(
                bottom: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back to HR Dashboard button
                    GestureDetector(
                      onTap: () => auth.stopHRPreview(),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          children: const [
                            Icon(Icons.arrow_back_rounded, color: Colors.white, size: 14),
                            SizedBox(width: 6),
                            Text(
                              'العودة للإدارة',
                              style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.remove_red_eye_rounded, color: Color(0xFF0D9488), size: 18),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: const [
                            Text(
                              'وضع معاينة حساب الموظف',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'تصفح فقط - المعاملات غير مفعلة',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 9,
                                color: Colors.white60,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // 3. Dynamic Tab Content (Shown according to selected index)
          Expanded(
            child: _buildTabBody(auth, attendance, sync),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularMenuButton({required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(14),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({required String title, required String mainValue, required String subValue}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12.withOpacity(0.06)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 10,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            mainValue,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          Text(
            subValue,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 9,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem({required String title, required String time, required IconData icon}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          time,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 10,
            color: Color(0xFF94A3B8),
          ),
        ),
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFFE6F4EA),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(6),
              child: Icon(
                icon,
                color: const Color(0xFF137333),
                size: 16,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTabBody(AuthProvider auth, AttendanceProvider attendance, SyncProvider sync) {
    switch (_currentBottomNavIndex) {
      case 1:
        return _buildAttendanceTabBody(auth, attendance, sync);
      case 2:
        return _buildLeavesTabBody(auth, attendance, sync);
      case 3:
        return _buildSalaryTabBody(auth, attendance, sync);
      case 4:
        return _buildProfileTabBody(auth, attendance, sync);
      case 0:
      default:
        return _buildHomeTabBody(auth, attendance, sync);
    }
  }

  Widget _buildHomeTabBody(AuthProvider auth, AttendanceProvider attendance, SyncProvider sync) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Emerald Teal Welcome Profile Card
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F766E), // Emerald dark green card
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F766E).withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Notification bell icon with red badge dot
                    Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(8),
                          child: const Icon(
                            Icons.notifications_none_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      ],
                    ),
                    // Profile Text
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'مرحباً بك،',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            color: Colors.white70,
                          ),
                        ),
                        Text(
                          auth.employeeName,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${auth.jobTitle} - EMP-100${auth.employeeId == 'e1' ? '1' : '2'}',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Inner check-in status box
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Register attendance button
                      GestureDetector(
                        onTap: auth.isHRPreview
                            ? () => _showHRPreviewBlockedDialog(context)
                            : () => _startAttendanceFlow(context, auth, attendance, sync),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: attendance.isVerifyingGPS
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D9488)),
                                )
                              : Text(
                                  attendance.isCheckedIn ? 'سجل الآن' : 'سجل الآن',
                                  style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F766E),
                                  ),
                                ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'حالة اليوم:',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11,
                              color: Colors.white60,
                            ),
                          ),
                          Text(
                            attendance.isCheckedIn ? 'تم تسجيل حضورك اليوم' : 'لم يتم تسجيل الحضور',
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 4. Quick Actions (إجراءات سريعة)
          const Text(
            'إجراءات سريعة',
            textAlign: TextAlign.right,
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCircularMenuButton(
                label: 'تسجيل حضور',
                icon: Icons.location_on_rounded,
                color: const Color(0xFF0D9488),
                onTap: auth.isHRPreview
                    ? () => _showHRPreviewBlockedDialog(context)
                    : () async {
                        await attendance.toggleAttendance(auth.employeeId, sync);
                      },
              ),
              _buildCircularMenuButton(
                label: 'طلب إجازة',
                icon: Icons.calendar_today_rounded,
                color: const Color(0xFF3B82F6),
                onTap: auth.isHRPreview
                    ? () => _showHRPreviewBlockedDialog(context)
                    : () => _requestLeave(auth, sync),
              ),
              _buildCircularMenuButton(
                label: 'طلب سلفة',
                icon: Icons.account_balance_wallet_rounded,
                color: const Color(0xFFF97316),
                onTap: auth.isHRPreview
                    ? () => _showHRPreviewBlockedDialog(context)
                    : () => _requestLoan(auth, sync),
              ),
              _buildCircularMenuButton(
                label: 'قسيمة الراتب',
                icon: Icons.receipt_long_rounded,
                color: const Color(0xFFA855F7),
                onTap: auth.isHRPreview
                    ? () => _showHRPreviewBlockedDialog(context)
                    : () => _viewPayslip(auth),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 5. Other Requests (طلبات أخرى)
          const Text(
            'طلبات أخرى',
            textAlign: TextAlign.right,
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCircularMenuButton(
                label: 'إذن تأخير',
                icon: Icons.watch_later_rounded,
                color: const Color(0xFFEA580C),
                onTap: auth.isHRPreview
                    ? () => _showHRPreviewBlockedDialog(context)
                    : () => _requestDelay(auth, sync),
              ),
              _buildCircularMenuButton(
                label: 'عمل من المنزل',
                icon: Icons.home_work_rounded,
                color: const Color(0xFF2563EB),
                onTap: auth.isHRPreview
                    ? () => _showHRPreviewBlockedDialog(context)
                    : () => _requestWorkFromHome(auth, sync),
              ),
              _buildCircularMenuButton(
                label: 'إذن انصراف',
                icon: Icons.exit_to_app_rounded,
                color: const Color(0xFFD946EF),
                onTap: auth.isHRPreview
                    ? () => _showHRPreviewBlockedDialog(context)
                    : () => _requestExit(auth, sync),
              ),
              _buildCircularMenuButton(
                label: 'التنبيهات',
                icon: Icons.notifications_active_rounded,
                color: const Color(0xFFEF4444),
                onTap: auth.isHRPreview
                    ? () => _showHRPreviewBlockedDialog(context)
                    : () => _showNotifications(),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // 6. Account Summary Cards (ملخص حسابي)
          const Text(
            'ملخص حسابي',
            textAlign: TextAlign.right,
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _buildSummaryCard(
                title: 'رصيد الإجازات',
                mainValue: auth.employeeId == 'e1' ? '14 يوم' : '18 يوم',
                subValue: 'من أصل 21',
              ),
              _buildSummaryCard(
                title: 'ساعات الشهر',
                mainValue: '148 س',
                subValue: 'هدف 176 س',
              ),
              _buildSummaryCard(
                title: 'السلف المتبقية',
                mainValue: auth.employeeId == 'e1' ? '2,400 ج' : '0 ج',
                subValue: auth.employeeId == 'e1' ? '3 أقساط' : 'لا يوجد سلفة',
              ),
              _buildSummaryCard(
                title: 'آخر راتب',
                mainValue: auth.employeeId == 'e1' ? '9,820 ج' : '6,940 ج',
                subValue: 'مايو 2026',
              ),
            ],
          ),
          const SizedBox(height: 28),

          // 7. Recent Activities Timeline (آخر النشاطات)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => _showAllActivitiesDialog(context),
                child: const Text(
                  'عرض الكل >',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0D9488)),
                ),
              ),
              const Text(
                'آخر النشاطات',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black12.withOpacity(0.06)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildActivityItem(
                  title: 'تمت الموافقة على طلب الإجازة',
                  time: 'منذ ساعتين',
                  icon: Icons.trending_up_rounded,
                ),
                const Divider(color: Colors.black12, height: 24),
                _buildActivityItem(
                  title: 'تم صرف راتب شهر مايو',
                  time: 'أمس',
                  icon: Icons.account_balance_wallet_outlined,
                ),
                const Divider(color: Colors.black12, height: 24),
                _buildActivityItem(
                  title: 'تسجيل حضور – فرع القاهرة',
                  time: '3 أيام',
                  icon: Icons.location_on_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildAttendanceTabBody(AuthProvider auth, AttendanceProvider attendance, SyncProvider sync) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header Card (تسجيل الحضور)
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F766E),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: const [
                Text(
                  'الخميس، 28 مايو',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.white70),
                ),
                SizedBox(height: 4),
                Text(
                  'تسجيل الحضور',
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Inner Clock & Location Card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black12.withOpacity(0.06)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              children: [
                const Text(
                  'الوقت الحالي',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  textDirection: TextDirection.rtl,
                  children: const [
                    Text(
                      '08:20:29',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: 2),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'ص',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  textDirection: TextDirection.rtl,
                  children: const [
                    Icon(Icons.location_on_outlined, color: Color(0xFF0D9488), size: 14),
                    SizedBox(width: 4),
                    Text(
                      'فرع القاهرة - التجمع الخامس',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Color(0xFF0D9488), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Register Button (تسجيل حضور)
          ElevatedButton.icon(
            onPressed: auth.isHRPreview 
                ? () => _showHRPreviewBlockedDialog(context)
                : () => _startAttendanceFlow(context, auth, attendance, sync),
            icon: const Icon(Icons.fingerprint_rounded, color: Colors.white, size: 18),
            label: const Text(
              'تسجيل حضور',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
          const SizedBox(height: 24),

          // 4. History Logs list
          const Text(
            'سجل آخر 7 أيام',
            textAlign: TextAlign.right,
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black12.withOpacity(0.06)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildAttendanceHistoryRow('الأحد 24 مايو', 'حضور 08:55 • انصراف 17:02', 'بالموعد', const Color(0xFF10B981)),
                const Divider(color: Colors.black12),
                _buildAttendanceHistoryRow('السبت 23 مايو', 'حضور 09:12 • انصراف 17:30', 'متأخر', const Color(0xFFF59E0B)),
                const Divider(color: Colors.black12),
                _buildAttendanceHistoryRow('الخميس 21 مايو', 'حضور 08:48 • انصراف 17:00', 'بالموعد', const Color(0xFF10B981)),
                const Divider(color: Colors.black12),
                _buildAttendanceHistoryRow('الأربعاء 20 مايو', 'حضور 08:50 • انصراف 16:58', 'بالموعد', const Color(0xFF10B981)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceHistoryRow(String day, String subtitle, String status, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(day, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text(
              status,
              style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeavesTabBody(AuthProvider auth, AttendanceProvider attendance, SyncProvider sync) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header Card (الإجازات)
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F766E),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: const [
                Text(
                  'رصيدك وطلباتك',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.white70),
                ),
                SizedBox(height: 4),
                Text(
                  'الإجازات',
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Balances row (سنوية، مرضية، طارئة، بدون مرتب)
          Row(
            children: [
              Expanded(child: _buildBalanceBox('سنوية', '14')),
              const SizedBox(width: 8),
              Expanded(child: _buildBalanceBox('مرضية', '6')),
              const SizedBox(width: 8),
              Expanded(child: _buildBalanceBox('طارئة', '3')),
              const SizedBox(width: 8),
              Expanded(child: _buildBalanceBox('بدون مرتب', '—')),
            ],
          ),
          const SizedBox(height: 16),

          // 3. Request Leave Button
          ElevatedButton.icon(
            onPressed: auth.isHRPreview 
                ? () => _showHRPreviewBlockedDialog(context)
                : () => _requestLeave(auth, sync),
            icon: const Icon(Icons.add, color: Colors.white, size: 16),
            label: const Text(
              'طلب إجازة جديدة',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006D5B),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),

          // 4. Request Info Card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black12.withOpacity(0.06)),
            ),
            padding: const EdgeInsets.all(12),
            child: const Center(
              child: Text(
                'طلبات (تأخير • عمل من المنزل • انصراف)',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 5. My Requests List
          const Text(
            'طلباتي',
            textAlign: TextAlign.right,
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black12.withOpacity(0.06)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildLeaveHistoryRow('إجازة سنوية', '20 يونيو ← 24 يونيو • 5 يوم', 'مقبول', const Color(0xFF10B981)),
                const Divider(color: Colors.black12),
                _buildLeaveHistoryRow('إجازة مرضية', '12 مايو ← 12 مايو • 1 يوم', 'مقبول', const Color(0xFF10B981)),
                const Divider(color: Colors.black12),
                _buildLeaveHistoryRow('إجازة طارئة', '02 يونيو ← 03 يونيو • 2 يوم', 'قيد المراجعة', const Color(0xFFF59E0B)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceBox(String label, String value) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12.withOpacity(0.06)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Color(0xFF64748B))),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _buildLeaveHistoryRow(String title, String desc, String status, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text(
              status,
              style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryTabBody(AuthProvider auth, AttendanceProvider attendance, SyncProvider sync) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header Card (قسيمة الراتب)
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF9D1CFF),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: const [
                Text(
                  'شهر مايو 2026',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.white70),
                ),
                SizedBox(height: 4),
                Text(
                  'قسيمة الراتب',
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Net Salary Purple Box
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFB654FF),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: const [
                Text('صافي الراتب', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.white70)),
                SizedBox(height: 4),
                Text(
                  '8,820 ج',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                SizedBox(height: 4),
                Text('تم الإيداع في 28 مايو 2026', style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. Earnings Section (المستحقات)
          const Text('المستحقات', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF10B981))),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black12.withOpacity(0.06)),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _buildSalaryDetailItem('الراتب الأساسي', '+8,000 ج', false),
                const Divider(color: Colors.black12),
                _buildSalaryDetailItem('بدل مواصلات', '+800 ج', false),
                const Divider(color: Colors.black12),
                _buildSalaryDetailItem('بدل سكن', '+1,500 ج', false),
                const Divider(color: Colors.black12),
                _buildSalaryDetailItem('ساعات إضافية', '+420 ج', false),
                const Divider(color: Colors.black12, height: 20),
                _buildSalaryDetailItem('الإجمالي', '10,720 ج', true),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 4. Deductions Section (الاستقطاعات)
          const Text('الاستقطاعات', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFEF4444))),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black12.withOpacity(0.06)),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _buildSalaryDetailItem('تأمينات اجتماعية', '-880 ج', false, isDeduction: true),
                const Divider(color: Colors.black12),
                _buildSalaryDetailItem('ضريبة دخل', '-620 ج', false, isDeduction: true),
                const Divider(color: Colors.black12),
                _buildSalaryDetailItem('قسط سلفة', '-400 ج', false, isDeduction: true),
                const Divider(color: Colors.black12, height: 20),
                _buildSalaryDetailItem('الإجمالي', '1,900 ج', true, isDeduction: true),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 5. Download PDF Button
          ElevatedButton.icon(
            onPressed: auth.isHRPreview 
                ? () => _showHRPreviewBlockedDialog(context)
                : () {},
            icon: const Icon(Icons.download_rounded, color: Colors.white, size: 16),
            label: const Text(
              'تحميل PDF',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006D5B),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 24),

          // 6. Previous Months Section
          const Text('شهور سابقة', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B))),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black12.withOpacity(0.06)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildPreviousMonthRow('أبريل 2026', '9,820 ج'),
                const Divider(color: Colors.black12),
                _buildPreviousMonthRow('مارس 2026', '9,820 ج'),
                const Divider(color: Colors.black12),
                _buildPreviousMonthRow('فبراير 2026', '9,820 ج'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryDetailItem(String label, String value, bool isTotal, {bool isDeduction = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: isTotal ? 13 : 12,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? const Color(0xFF0F172A) : const Color(0xFF475569),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 14 : 12,
            fontWeight: FontWeight.bold,
            color: isTotal 
                ? (isDeduction ? const Color(0xFFEF4444) : const Color(0xFF0F172A))
                : (isDeduction ? const Color(0xFFEF4444) : const Color(0xFF10B981)),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviousMonthRow(String month, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFF0D9488), size: 16),
              const SizedBox(width: 8),
              Text(month, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            ],
          ),
          Row(
            children: [
              Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_back_ios_new_rounded, size: 10, color: Color(0xFF64748B)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTabBody(AuthProvider auth, AttendanceProvider attendance, SyncProvider sync) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF06B6D4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: const Color(0xFF0F766E).withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      child: const Text('بطاقة رقمية', style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    const Icon(Icons.fingerprint_rounded, color: Colors.white, size: 28),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            auth.employeeName,
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            auth.jobTitle,
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.white70),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'كود الموظف: EMP-100${auth.employeeId == 'e1' ? '1' : '2'}',
                            style: const TextStyle(fontSize: 11, color: Colors.white60),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: const Icon(Icons.person_rounded, size: 40, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('البيانات الأساسية والوظيفية', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B))),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black12.withOpacity(0.06)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildProfileDetailRow('فرع التوظيف التابع له', 'فرع القاهرة الرئيسي'),
                const Divider(color: Colors.black12),
                _buildProfileDetailRow('القسم والفرقة', 'تطوير البرمجيات والحلول الذكية'),
                const Divider(color: Colors.black12),
                _buildProfileDetailRow('الوردية ومواعيد العمل', 'الوردية الصباحية (09:00 ص – 05:00 م)'),
                const Divider(color: Colors.black12),
                _buildProfileDetailRow('التغطية الطبية المعتمدة', 'الفئة A (شاملة وممتازة)'),
                const Divider(color: Colors.black12),
                _buildProfileDetailRow('الاشتراك بالتأمين الاجتماعي', 'نشط (الرقم التأميني: 54930291)'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => auth.logout(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444).withOpacity(0.12),
              foregroundColor: const Color(0xFFEF4444),
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('تسجيل الخروج من التطبيق', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(value, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentBottomNavIndex,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: const Color(0xFF0D9488),
      unselectedItemColor: const Color(0xFF64748B),
      selectedLabelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 10),
      unselectedLabelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 10),
      onTap: (index) {
        setState(() {
          _currentBottomNavIndex = index;
        });
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_rounded),
          label: 'الرئيسية',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.fingerprint_rounded),
          label: 'الحضور',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today_rounded),
          label: 'الإجازات',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long_rounded),
          label: 'الراتب',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_rounded),
          label: 'حسابي',
        ),
      ],
    );
  }
}
