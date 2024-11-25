import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../services/recommended_books_service.dart';
import 'package:logger/logger.dart';

class LibraryInfoProvider {
  final LocationService _locationService = LocationService();
  final RecommendedBooksService recommendedBooksService;
  final Logger _logger = Logger();

  // 멤버 변수
  StreamSubscription<Position>? _locationSubscription;
  static const double _updateDistanceThreshold = 100.0; // meters

  LibraryInfoProvider({required this.recommendedBooksService});

  Future<void> setupLocationSubscription({
    required String isbn,
    required Function(String) onLibraryNameUpdate,
    required Function(String) onDistanceUpdate,
    required Function(String) onLoanStatusUpdate,
    required Function(String) onError,
  }) async {
    try {
      _logger.d('LibraryInfoProvider: 위치 구독 설정 시작');
      
      // 초기 위치 정보 가져오기
      final initialPosition = await _locationService.getCurrentLocation();
      await _fetchLibraryInfo(
        isbn: isbn,
        position: initialPosition,
        onLibraryNameUpdate: onLibraryNameUpdate,
        onDistanceUpdate: onDistanceUpdate,
        onLoanStatusUpdate: onLoanStatusUpdate,
        onError: onError,
      );

      // LocationService의 위치 스트림 구독
      _locationSubscription = _locationService.positionStream.listen(
        (Position position) async {
          _logger.d('LibraryInfoProvider: 새로운 위치 업데이트 수신');
          
          // 위치 변경이 임계값을 초과하는 경우에만 도서관 정보 업데이트
          if (_shouldUpdateLibraryInfo(position, initialPosition)) {
            await _fetchLibraryInfo(
              isbn: isbn,
              position: position,
              onLibraryNameUpdate: onLibraryNameUpdate,
              onDistanceUpdate: onDistanceUpdate,
              onLoanStatusUpdate: onLoanStatusUpdate,
              onError: onError,
            );
          }
        },
        onError: (error) {
          _logger.e('LibraryInfoProvider: 위치 스트림 에러', error);
          onError('위치 정보를 가져오는 데 실패했습니다.');
        },
      );
    } catch (e) {
      _logger.e('LibraryInfoProvider: 위치 구독 설정 실패', e);
      onError('위치 정보를 가져오는 데 실패했습니다.');
    }
  }

  bool _shouldUpdateLibraryInfo(Position newPosition, Position lastPosition) {
    final distance = Geolocator.distanceBetween(
      lastPosition.latitude,
      lastPosition.longitude,
      newPosition.latitude,
      newPosition.longitude,
    );

    return distance > _updateDistanceThreshold;
  }

  Future<void> _fetchLibraryInfo({
    required String isbn,
    required Position position,
    required Function(String) onLibraryNameUpdate,
    required Function(String) onDistanceUpdate,
    required Function(String) onLoanStatusUpdate,
    required Function(String) onError,
  }) async {
    try {
      _logger.d('LibraryInfoProvider: 도서관 정보 가져오기 시작');
      
      final libraryInfo = await recommendedBooksService.fetchLibrary(
        isbn,
        position,
      );

      if (libraryInfo == null || libraryInfo.isEmpty) {
        _logger.w('LibraryInfoProvider: 주변 도서관 정보 없음');
        onLibraryNameUpdate('주변 도서관 정보가 없습니다.');
        onDistanceUpdate('');
        onLoanStatusUpdate('');
        return;
      }

      final name = libraryInfo['name'] ?? '도서관 정보 없음';
      final distance = '${((libraryInfo['distance'] as num).toDouble() / 1000).toStringAsFixed(1)}km';
      final loanStatus = libraryInfo['loanAvailable'] == 'Y' ? '대출 가능' : '대출 불가';

      _logger.i('LibraryInfoProvider: 도서관 정보 업데이트 - $name, $distance');
      
      onLibraryNameUpdate(name);
      onDistanceUpdate(distance);
      onLoanStatusUpdate(loanStatus);
    } catch (e) {
      _logger.e('LibraryInfoProvider: 도서관 정보 가져오기 실패', e);
      onError('도서관 정보를 가져오는 데 실패했습니다.');
    }
  }

  Future<void> dispose() async {
    _logger.d('LibraryInfoProvider: 리소스 정리');
    await _locationSubscription?.cancel();
    _locationSubscription = null;
  }
}