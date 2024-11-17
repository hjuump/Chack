import 'package:chack_project/screens/timer_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../components/annual_goal_card.dart';
import '../components/monthly_reading_card.dart';
import '../components/custom_bottom_nav_bar.dart';
import '../components/custom_search_bar.dart';
import '../components/book_recommendation/book_recommendation_list.dart';
import '../components/recent_book_popup.dart';
import '../services/authentication_service.dart';
import '../constants/icons.dart';
import '../constants/colors.dart';
import '../constants/text_styles.dart';
import '../screens/profile_screen.dart';
import '../screens/bookshelf_screen.dart';
import '../screens/search/search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  final AuthService _authService = AuthService();
  String? _userId;
  String? _age; // null일 수 있음을 명시
  bool _isPopupVisible = true;

  @override
  void initState() {
    super.initState();
    _checkUserAuth();
  }

  Future<void> _checkUserAuth() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      await _getUserAge(user.uid);
    }
  }

  Future<void> _getUserAge(String uid) async {
    try {
      print('HomeScreen: 사용자 정보 로드 시작 - UID: $uid');
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null && userData['age'] != null) {
          setState(() {
            _userId = uid;
            _age = userData['age'].toString(); // age를 문자열로 변환
          });
          print('HomeScreen: 사용자 나이 그룹 로드 완료: $_age');
        } else {
          print('HomeScreen: 사용자 문서에 age 필드가 없음');
        }
      } else {
        print('HomeScreen: 사용자 문서가 존재하지 않음');
      }
    } catch (e) {
      print('HomeScreen: 사용자 정보 로드 중 오류 발생: $e');
    }
  }

  Future<void> _handleLogout() async {
    try {
      await _authService.signOut();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그아웃 중 오류가 발생했습니다: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
          _pageController.jumpToPage(0);
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  CustomSearchBar(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SearchScreen(),
                        ),
                      );
                    },
                    onProfileTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfileScreen(),
                        ),
                      );
                    },
                  ),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() => _currentIndex = index);
                      },
                      children: [
                        _HomeTab(
                          userId: _userId,
                          age: _age,
                        ),
                        const BookshelfScreen(),
                        const _TimerTab(),
                        const _StatisticsTab(),
                      ],
                    ),
                  ),
                ],
              ),
              RecentBookPopup(
                isVisible: _isPopupVisible,
                onClose: () {
                  setState(() {
                    _isPopupVisible = false;
                  });
                },
                imageUrl: 'https://via.placeholder.com/60x80',
                title: '채식주의자',
              )
            ],
          ),
        ),
        bottomNavigationBar: CustomBottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
            _pageController.jumpToPage(index);
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

class _HomeTab extends StatelessWidget {
  final String? userId;
  final String? age;

  const _HomeTab({
    required this.userId,
    required this.age,
  });

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return ColoredBox(
      color: AppColors.backgroundColor,
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (userId != null && age != null) // userId와 age가 모두 있을 때만 표시
                SizedBox(
                  height: 170,
                  child: BookRecommendationList(
                    userId: userId!,
                    age: age!,
                  ),
                ),
              const Padding(
                padding: EdgeInsets.all(15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '홈',
                        style: AppTextStyles.titleStyle,
                      ),
                    ),
                  ],
                ),
              ),
              // 연간 독서 목표 카드
              const AnnualGoalCard(
                progress: 0.5, // 달성률
                remainingBooks: 9, // 남은 책 수
              ),
              const SizedBox(height: 30),
              // 이번 달 독서 현황 카드
              const MonthlyReadingCard(
                daysInMonth: 30, // 11월의 일수
                readingDays: [
                  1,
                  2,
                  4,
                  5,
                  6,
                  10,
                  11,
                  12,
                  13,
                  14,
                  15,
                  16,
                  17,
                  20,
                  21,
                  22
                ],
              ),
              const SizedBox(height: 200),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimerTab extends StatelessWidget {
  const _TimerTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: TimerScreen(),
    );
  }
}

class _StatisticsTab extends StatelessWidget {
  const _StatisticsTab();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.backgroundColor,
      child: const Center(
        child: Text(
          '통계',
          style: TextStyle(
            fontSize: 24,
            fontFamily: 'SUITE',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
