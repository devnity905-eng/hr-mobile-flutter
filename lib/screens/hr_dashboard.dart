import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' as intl;
import '../main.dart';
import '../services/api_service.dart';

class HRDashboard extends StatefulWidget {
  const HRDashboard({super.key});

  @override
  State<HRDashboard> createState() => _HRDashboardState();
}

class _HRDashboardState extends State<HRDashboard> {
  // Simulated list of pending leave requests
  final List<Map<String, dynamic>> _leaveRequests = [
    {
      'id': 'lv_1',
      'name': 'أحمد علي',
      'job': 'مهندس برمجيات',
      'type': 'سنوية',
      'days': '3 أيام',
      'date': '2026-06-01',
    },
    {
      'id': 'lv_2',
      'name': 'سارة محمد',
      'job': 'مهندسة برمجيات',
      'type': 'مرضية',
      'days': 'يوم واحد',
      'date': '2026-05-30',
    },
  ];

  // Simulated list of pending loan requests
  final List<Map<String, dynamic>> _loanRequests = [
    {
      'id': 'ln_1',
      'name': 'سارة محمد',
      'job': 'مهندسة برمجيات',
      'amount': '3000 جنيه',
      'months': '6 أشهر',
    },
  ];

  // Simulated live attendance log with coordinates
  final List<Map<String, dynamic>> _attendanceLog = [
    {
      'name': 'أحمد علي',
      'time': '09:05 ص',
      'status': 'داخل النطاق الجغرافي',
      'distance': '45 متر',
      'isValid': true,
      'coords': '30.0441, 31.2359',
    },
    {
      'name': 'سارة محمد',
      'time': '08:58 ص',
      'status': 'داخل النطاق الجغرافي',
      'distance': '12 متر',
      'isValid': true,
      'coords': '30.0443, 31.2358',
    },
    {
      'name': 'خالد محمود',
      'time': '09:22 ص',
      'status': 'خارج النطاق الجغرافي (مرفوض)',
      'distance': '1.4 كيلومتر',
      'isValid': false,
      'coords': '30.0520, 31.2462',
    },
  ];

  bool _isInit = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      Provider.of<LocationsProvider>(context, listen: false).fetchAllLocations();
      _isInit = false;
    }
  }

  void _handleLeaveAction(int index, bool approved) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          approved ? 'تمت الموافقة على طلب الإجازة بنجاح.' : 'تم رفض طلب الإجازة.',
          textDirection: TextDirection.rtl,
        ),
        backgroundColor: approved ? const Color(0xFF10B981) : const Color(0xFFEF4444),
      ),
    );
    setState(() {
      _leaveRequests.removeAt(index);
    });
  }

  void _handleLoanAction(int index, bool approved) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          approved ? 'تمت الموافقة على السلفة وجدولة الأقساط.' : 'تم رفض طلب السلفة.',
          textDirection: TextDirection.rtl,
        ),
        backgroundColor: approved ? const Color(0xFF10B981) : const Color(0xFFEF4444),
      ),
    );
    setState(() {
      _loanRequests.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final sync = Provider.of<SyncProvider>(context);

    return Scaffold(
      body: Stack(
        children: [
          // Background decorator
          Container(color: const Color(0xFF0F172A)),
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF06B6D4).withOpacity(0.12),
                    blurRadius: 100,
                  ),
                ],
              ),
            ),
          ),

          // Main View
          SafeArea(
            child: Column(
              children: [
                // 1. Connection banner
                if (sync.isOffline)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    color: const Color(0xFFD97706),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'وضع العمل دون اتصال نشط حالياً. سيتم إرسال ومزامنة عملياتك فور استقرار السيرفر.',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),

                // 2. Custom Appbar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => auth.logout(),
                        icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
                      ),
                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(auth.employeeName, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(auth.jobTitle, style: const TextStyle(fontFamily: 'Cairo', color: Color(0xFF06B6D4), fontSize: 12)),
                            ],
                          ),
                          const SizedBox(width: 12),
                          const CircleAvatar(
                            backgroundColor: Color(0xFF06B6D4),
                            child: Icon(Icons.security_rounded, color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 3. Tab controller & screens
                Expanded(
                  child: DefaultTabController(
                    length: 3,
                    child: Column(
                      children: [
                        // Tab Bar Design
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: TabBar(
                            indicatorColor: const Color(0xFF06B6D4),
                            indicatorWeight: 3.0,
                            labelColor: const Color(0xFF06B6D4),
                            unselectedLabelColor: const Color(0xFF94A3B8),
                            labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12),
                            tabs: const [
                              Tab(text: 'الحضور اللحظي'),
                              Tab(text: 'طلبات الإجازات'),
                              Tab(text: 'طلبات السلف'),
                            ],
                          ),
                        ),

                        // Tab views
                        Expanded(
                          child: TabBarView(
                            children: [
                              // Tab 1: Live Attendance Log
                              _buildLiveAttendanceTab(),
                              // Tab 2: Leave Approvals
                              _buildLeaveRequestsTab(),
                              // Tab 3: Loan Approvals
                              _buildLoanRequestsTab(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveAttendanceTab() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _attendanceLog.length,
      itemBuilder: (context, index) {
        final log = _attendanceLog[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: log['isValid'] ? const Color(0xFF10B981).withOpacity(0.15) : const Color(0xFFEF4444).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Text(
                      log['isValid'] ? 'سليم' : 'مرفوض جغرافيًا',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: log['isValid'] ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ),
                    ),
                  ),
                  Text(
                    log['name'],
                    style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(log['coords'], style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const Text('الإحداثيات الجغرافية:', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Color(0xFF94A3B8))),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(log['distance'], style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: log['isValid'] ? const Color(0xFF10B981) : const Color(0xFFEF4444))),
                  const Text('المسافة التقريبية للفرع:', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Color(0xFF94A3B8))),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(log['time'], style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  const Text('وقت تسجيل الحضور:', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Color(0xFF94A3B8))),
                ],
              ),
              const Divider(color: Colors.white10, height: 20),
              GestureDetector(
                onTap: () {
                  String empId = 'e1';
                  double salary = 12000.0;
                  String jobTitle = 'مهندس برمجيات';
                  if (log['name'] == 'سارة محمد') {
                    empId = 'e2';
                    salary = 8500.0;
                    jobTitle = 'مهندسة برمجيات';
                  } else if (log['name'] == 'خالد محمود') {
                    empId = 'e3';
                    salary = 9500.0;
                    jobTitle = 'مصمم واجهات';
                  }
                  
                  auth.startHRPreview(empId, log['name'], salary, jobTitle);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3)),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.remove_red_eye_rounded, color: Color(0xFF06B6D4), size: 14),
                      SizedBox(width: 6),
                      Text(
                        'معاينة لوحة الموظف (عرض فقط)',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF06B6D4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLeaveRequestsTab() {
    if (_leaveRequests.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد طلبات إجازة معلقة حالياً.',
          style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF94A3B8)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _leaveRequests.length,
      itemBuilder: (context, index) {
        final req = _leaveRequests[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    req['job'],
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                  Text(
                    req['name'],
                    style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              const Divider(color: Colors.white12, height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${req['type']} (${req['days']})', style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Color(0xFF06B6D4))),
                  const Text('تفاصيل الإجازة:', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Color(0xFF94A3B8))),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(req['date'], style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  const Text('تاريخ بدء الإجازة:', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Color(0xFF94A3B8))),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleLeaveAction(index, false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444).withOpacity(0.15),
                        foregroundColor: const Color(0xFFEF4444),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('رفض الطلب', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleLeaveAction(index, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('اعتماد الإجازة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoanRequestsTab() {
    if (_loanRequests.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد طلبات سلف معلقة حالياً.',
          style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF94A3B8)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _loanRequests.length,
      itemBuilder: (context, index) {
        final req = _loanRequests[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    req['job'],
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                  Text(
                    req['name'],
                    style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              const Divider(color: Colors.white12, height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(req['amount'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                  const Text('مبلغ السلفة المطلوب:', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Color(0xFF94A3B8))),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(req['months'], style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.white70)),
                  const Text('مدة التقسيط المخططة:', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Color(0xFF94A3B8))),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleLoanAction(index, false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444).withOpacity(0.15),
                        foregroundColor: const Color(0xFFEF4444),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('رفض الطلب', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleLoanAction(index, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('اعتماد وصرف السلفة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLocationsMonitorTab() {
    return Consumer<LocationsProvider>(
      builder: (context, locProv, _) {
        if (locProv.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF06B6D4)),
          );
        }

        if (locProv.locations.isEmpty) {
          return const Center(
            child: Text(
              'لا توجد أماكن جغرافية مسجلة في النظام حالياً.',
              style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF94A3B8)),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => locProv.fetchAllLocations(),
          color: const Color(0xFF06B6D4),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: locProv.locations.length,
            itemBuilder: (context, index) {
              final loc = locProv.locations[index];
              final employeeName = loc.employeeNameAr.isNotEmpty 
                  ? loc.employeeNameAr 
                  : (loc.employeeId == 'e1' ? 'أحمد علي' : 'سارة محمد');
                  
              final formattedDate = intl.DateFormat('yyyy-MM-dd | hh:mm a').format(loc.visitedAt);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          child: Text(
                            loc.placeName,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: Color(0xFF818CF8),
                            ),
                          ),
                        ),
                        Text(
                          employeeName,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white10, height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${loc.latitude.toStringAsFixed(6)}, ${loc.longitude.toStringAsFixed(6)}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        const Text(
                          'الإحداثيات الجغرافية:',
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formattedDate,
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                        const Text(
                          'وقت التوثيق والتسجيل:',
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
