import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/database/app_database.dart' show queueMaybeOnServerKey;
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/connectivity_provider.dart';
import '../../../../core/network/refresh_outcome.dart';
import '../../../../core/services/geo_catalog_service.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/utils/account_key.dart';
import '../../domain/entities/customer_dynamic_column.dart';
import '../../domain/entities/customer_entity.dart';
import '../../domain/entities/customer_meta_entity.dart';
import '../../domain/repositories/customer_repository.dart';
import '../datasources/customer_local_data_source.dart';
import '../services/customer_api_service.dart';
import '../utils/customer_payload_helper.dart';
import '../../../visit/data/models/visit_material_model.dart';
import '../../../visit/data/repositories/visit_material_repository.dart';
import '../../../forms/presentation/viewmodels/forms_view_model.dart';
import '../../../../core/dynamic_form/matrix_photo_key.dart';
import '../../../../core/utils/offline_photo_store.dart';

final customerApiServiceProvider = Provider<CustomerApiService>((ref) {
  return CustomerApiService(ref.read(apiClientProvider));
});

/// Tăng mỗi khi lượt tải NGẦM danh sách điểm bán đầy đủ ghi xong vào SQLite — màn Tuyến / Danh sách điểm bán nghe để
/// nạp lại từ máy. Không có nó, màn hiện bản cũ trong máy (vd 199 điểm) tới khi người dùng kéo làm mới.
final customerCacheVersionProvider = StateProvider<int>((ref) => 0);

final customerLocalDataSourceProvider = Provider<CustomerLocalDataSource>((ref) {
  final db = ref.read(appDatabaseProvider);
  return CustomerLocalDataSource(db);
});

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepositoryImpl(
    ref.read(customerApiServiceProvider),
    ref.read(customerLocalDataSourceProvider),
    ref.read(syncServiceProvider),
    ref,
  );
});

class CustomerRepositoryImpl implements CustomerRepository {
  final CustomerApiService _apiService;
  final CustomerLocalDataSource _localDataSource;
  final SyncService _syncService;
  final Ref? _ref;
  final bool Function()? _isOnlineChecker;

  List<CustomerEntity> _cachedCustomersStore = [];
  int? _cachedCustomersOwner;

  /// Danh sách điểm bán giữ trong bộ nhớ — CỦA tài khoản đang đăng nhập: đổi tài khoản thì bỏ (repository sống suốt vòng
  /// đời app; không bỏ thì người sau mất mạng được trả danh sách của người trước, #24698 nhóm 3).
  List<CustomerEntity> get _cachedCustomers {
    if (_cachedCustomersOwner != _localDataSource.ownerUserId) {
      _cachedCustomersStore = [];
      _cachedCustomersOwner = _localDataSource.ownerUserId;
    }
    return _cachedCustomersStore;
  }

  set _cachedCustomers(List<CustomerEntity> value) {
    _cachedCustomersStore = value;
    _cachedCustomersOwner = _localDataSource.ownerUserId;
  }
  List<CustomerDynamicColumn> _cachedColumns = [];
  CustomerMetaData? _cachedMeta;

  CustomerRepositoryImpl(
    this._apiService,
    this._localDataSource,
    this._syncService, [
    this._ref,
    this._isOnlineChecker,
  ]);

  bool get _isOnline => _isOnlineChecker != null
      ? _isOnlineChecker()
      : (_ref?.read(connectivityProvider).isOnline ?? true);

  @override
  Future<List<CustomerEntity>> getCustomers({
    int page = 1,
    int perPage = 100,
    String? query,
    bool forceRefresh = false,
  }) async {
    // 1. Khi thiết bị ngoại tuyến (không có mạng) -> tải trực tiếp từ SQLite cục bộ
    if (!_isOnline) {
      final localList = await _localDataSource.getLocalCustomers(query: query);
      if (localList.isNotEmpty) {
        _cachedCustomers = localList;
        return localList;
      }
      if (_cachedCustomers.isNotEmpty) {
        return _cachedCustomers;
      }
      throw AppException('Không có kết nối mạng và chưa có dữ liệu điểm bán lưu trên máy');
    }

    // 2. Khi thiết bị trực tuyến (Online):
    // Nếu không bắt buộc tải mới (forceRefresh = false) và đã có sẵn dữ liệu cục bộ -> trả về ngay và đồng bộ ngầm
    if (!forceRefresh) {
      try {
        final localList = await _localDataSource.getLocalCustomers(query: query);
        final account = await _account();
        if (localList.isNotEmpty) {
          _cachedCustomers = localList;
          // Kích hoạt làm mới và ghi đè cache ngầm từ máy chủ
          _refreshInBackground(page, perPage, query, account);
          return localList;
        }
        // Máy trống mà lượt tải đủ VỪA xong của chính tài khoản này ra 0 điểm ⇒ server thật sự không có điểm bán nào;
        // trả rỗng, không tải lại — không thì "tải xong → báo màn → màn nạp lại → máy trống → tải" lặp vô tận.
        // (Ra >0 điểm mà máy trống = bảng đã bị xoá sau đó, vd đăng xuất rồi vào lại ⇒ phải tải.)
        if ((query == null || query.isEmpty) && _recentlySynced(account) && _lastFullSyncCount == 0) return localList;
      } catch (_) {}
    }

    // 3. Tải từ API server khi forceRefresh = true hoặc khi SQLite chưa có dữ liệu
    try {
      // Lưu cache vào SQLite cục bộ (tự động ghi đè và dọn dẹp các khách hàng đã bị xóa trên server)
      if (query == null || query.isEmpty) {
        // Kéo làm mới có thể đi chung lượt tải đã chạy từ trước (ngoài lượt làm mới) — ghi kết quả của nó cho lượt này.
        try {
          await _sharedFullFetch(page, perPage, await _account());
          RefreshOutcome.record(reachedServer: true);
        } catch (e) {
          if (e is! _AccountChangedException) RefreshOutcome.record(reachedServer: false);
          rethrow;
        }
      } else {
        await _fetchAndCache(page, perPage, query, await _account());
      }

      // Đọc lại từ SQLite để gộp cả các khách hàng offline vừa tạo đang chờ đồng bộ
      final mergedList = await _localDataSource.getLocalCustomers(query: query);
      _cachedCustomers = CustomerLocalDataSource.deduplicateCustomers(mergedList);
      return _cachedCustomers;
    } catch (e) {
      // Khi API lỗi hoặc rớt mạng giữa chừng -> Sử dụng SQLite cục bộ đã lưu trước đó
      final localList = await _localDataSource.getLocalCustomers(query: query);
      // Kết quả là của tài khoản cũ ⇒ chỉ trả bản trong máy của tài khoản hiện tại; danh sách trong bộ nhớ có thể còn
      // là của người cũ, không trả.
      if (e is _AccountChangedException) return localList;
      if (localList.isNotEmpty) {
        _cachedCustomers = localList;
        return localList;
      }
      if (_cachedCustomers.isNotEmpty) {
        return _cachedCustomers;
      }
      rethrow;
    }
  }

  /// Trần số trang tải một lượt — chỉ để chặn vòng lặp vô hạn nếu máy chủ trả `pageCount` sai.
  static const int _maxPages = 100;

  /// Tải ĐỦ mọi trang từ [startPage] tới `pageCount` máy chủ báo. Máy chủ chặn `per-page` tối đa 200, nên chỉ
  /// lấy trang 1 thì người phụ trách hơn 200 điểm bán bị cụt danh sách — và `reconcile` còn XOÁ khỏi SQLite
  /// những điểm bán nằm ở các trang sau. Lỗi ở bất kỳ trang nào thì ném ra cả lượt (không cache nửa vời).
  ///
  /// `complete` = chắc chắn nhận TRỌN danh sách: phân trang theo vị trí, server thêm/xoá điểm bán giữa hai trang thì
  /// các dòng sau xô lên và một dòng bị sót — `total` đổi giữa chừng hay số dòng nhận khác `total` ⇒ không trọn, và
  /// khi đó KHÔNG được reconcile (sẽ xoá nhầm dòng bị sót).
  Future<({List<CustomerEntity> list, bool complete})> _fetchAllPages(int startPage, int perPage, String? query) async {
    final all = <CustomerEntity>[];
    var page = startPage;
    int? firstTotal;
    var complete = true;
    while (true) {
      final response = await _apiService.getMineCustomers(
        page: page,
        perPage: perPage,
        q: query,
        context: 'mobile',
      );
      if (page == startPage) _cachedColumns = response.dynamicColumns;
      firstTotal ??= response.total;
      all.addAll(response.data);
      if (response.total != firstTotal) complete = false;
      if (response.data.isEmpty || page >= response.pageCount) break;
      if (page - startPage + 1 >= _maxPages) {
        complete = false;
        break;
      }
      page++;
    }
    if (startPage != 1 || all.map((c) => c.id).toSet().length != firstTotal) complete = false;
    return (list: all, complete: complete);
  }

  /// Tải đủ mọi trang rồi ghi vào SQLite; danh sách đầy đủ (không từ khoá) thì reconcile theo ảnh chụp chụp TRƯỚC khi
  /// tải — điểm bán thành "đã đồng bộ" giữa chừng không bị xoá nhầm ([CustomerLocalDataSource.cacheRemoteCustomers]).
  /// [account]: tài khoản của lượt tải — do người gọi đọc MỘT lần và dùng cho cả nhãn lượt chung ([_sharedFullFetch]).
  Future<void> _fetchAndCache(int page, int perPage, String? query, String? account) async {
    final fullList = query == null || query.isEmpty;
    final syncedBefore = fullList ? await _localDataSource.syncedServerIds() : null;
    final fetched = await _fetchAllPages(page, perPage, query);
    // Đổi tài khoản trong lúc tải (đăng xuất → người khác đăng nhập) ⇒ kết quả là của người cũ, KHÔNG ghi vào máy —
    // kiểm cả trước mỗi lô ghi ([CustomerLocalDataSource.cacheRemoteCustomers] `isStale`).
    Future<bool> accountChanged() async => await _account() != account;
    if (await accountChanged()) _throwAccountChanged();
    await _localDataSource.cacheRemoteCustomers(
      fetched.list,
      reconcile: fullList && fetched.complete,
      syncedIdsBeforeFetch: syncedBefore,
      isStale: accountChanged,
    );
    if (await accountChanged()) _throwAccountChanged();
    if (fullList) {
      _lastFullSyncAt = DateTime.now();
      _lastFullSyncAccount = account;
      _lastFullSyncCount = fetched.list.length;
      // Báo MỌI màn đang mở nạp lại từ máy (kéo làm mới ở màn Tuyến thì màn Danh sách cũng có bản mới).
      _ref?.read(customerCacheVersionProvider.notifier).state++;
    }
  }

  /// Kết quả là của tài khoản cũ — KHÔNG đụng [_cachedCustomers] (có thể đã là của tài khoản mới); nhánh lỗi của
  /// [getCustomers] nhận ra ngoại lệ này và chỉ trả bản trong máy.
  Never _throwAccountChanged() => throw _AccountChangedException();

  /// Tài khoản đang đăng nhập — đọc hỏng thì coi như chưa rõ (null), không làm hỏng lượt tải danh sách.
  Future<String?> _account() async {
    try {
      return cacheAccountKey(await SharedPreferences.getInstance());
    } catch (_) {
      return null;
    }
  }

  /// Lượt tải đủ danh sách gần nhất thành công (và của TÀI KHOẢN nào) — tải ngầm khi mở màn chỉ chạy nếu đã quá
  /// [_backgroundRefreshEvery] hoặc đã đổi tài khoản (repository dùng chung, không bị huỷ khi đăng xuất).
  DateTime? _lastFullSyncAt;
  String? _lastFullSyncAccount;
  int? _lastFullSyncCount;

  /// Lượt tải ĐỦ danh sách đang chạy (ngầm hay thường) và của tài khoản nào — mọi lượt tải đủ cùng tài khoản đi chung
  /// một lượt này: màn Tuyến + Danh sách cùng mở, hay kéo làm mới lúc đang tải ngầm, không thành nhiều lượt song song.
  Future<void>? _fullFetch;
  String? _fullFetchAccount;

  /// Khoảng tối thiểu giữa hai lượt tải ngầm khi chỉ mở/chuyển màn (kéo làm mới thì luôn tải). Mỗi lượt là ~11 lần gọi
  /// API cho 1.000+ điểm bán; provider màn hình autoDispose nên mỗi lần chuyển tab lại gọi `getCustomers`. Đây cũng là
  /// thứ chặn vòng lặp: tải ngầm xong → báo màn → màn nạp lại từ máy → không tải ngầm lần nữa.
  static const _backgroundRefreshEvery = Duration(minutes: 5);

  bool _recentlySynced(String? account) {
    final last = _lastFullSyncAt;
    return last != null && _lastFullSyncAccount == account && DateTime.now().difference(last) < _backgroundRefreshEvery;
  }

  /// Lượt tải đủ chung theo tài khoản (xem [_fullFetch]). Lỗi KHÔNG nuốt ở đây: người chờ (kéo làm mới) nhận đúng lỗi.
  Future<void> _sharedFullFetch(int page, int perPage, String? account) {
    final running = _fullFetch;
    if (running != null && _fullFetchAccount == account) return running;
    late final Future<void> run;
    run = _fetchAndCache(page, perPage, null, account).whenComplete(() {
      if (identical(_fullFetch, run)) _fullFetch = null;
    });
    _fullFetch = run;
    _fullFetchAccount = account;
    return run;
  }

  void _refreshInBackground(int page, int perPage, String? query, String? account) {
    final fullList = query == null || query.isEmpty;
    if (fullList && _recentlySynced(account)) return;
    unawaited(_fetchRemoteAndCache(page, perPage, query, account));
  }

  /// Lượt tải ngầm — lỗi thì nuốt (màn đang hiện bản trong máy).
  Future<void> _fetchRemoteAndCache(int page, int perPage, String? query, String? account) async {
    try {
      if (query == null || query.isEmpty) {
        await _sharedFullFetch(page, perPage, account);
      } else {
        await _fetchAndCache(page, perPage, query, account);
      }
      final mergedList = await _localDataSource.getLocalCustomers(query: query);
      _cachedCustomers = mergedList;
    } catch (_) {}
  }

  /// Tài khoản mà [_cachedMeta] / [_cachedColumns] đang giữ — đổi tài khoản thì bỏ cả hai bản trong bộ nhớ.
  String? _cachedMetaAccount;

  /// Khoá lưu danh mục điểm bán trong máy, TÁCH theo tài khoản (cùng lý do với schema). `logout()` xoá `cached_customer_meta*`.
  String _metaPrefsKey(String account) => 'cached_customer_meta_$account';

  /// Bỏ bản danh mục/cột trong bộ nhớ nếu nó của tài khoản khác tài khoản đang đăng nhập.
  void _dropMetaOfOtherAccount(String? account) {
    if (_cachedMetaAccount == account) return;
    _cachedMeta = null;
    _cachedColumns = [];
    _cachedMetaAccount = account;
  }

  /// Giữ danh mục vừa có cho [account] — CHỈ khi đó vẫn là tài khoản đang đăng nhập (xem [cacheAccountKey]).
  Future<bool> _keepMeta(SharedPreferences prefs, String? account, Map<String, dynamic> raw, {bool persist = true}) async {
    if (cacheAccountKey(prefs) != account) return false;
    if (account == null) return true;
    _cachedMeta = CustomerMetaData.fromJson(raw);
    _cachedMetaAccount = account;
    if (_cachedMeta!.dynamicColumns.isNotEmpty) {
      _cachedColumns = _cachedMeta!.dynamicColumns;
    }
    if (persist) await prefs.setString(_metaPrefsKey(account), jsonEncode(raw));
    return true;
  }

  @override
  Future<List<CustomerDynamicColumn>> getDynamicColumns({bool forceRefresh = false}) async {
    _dropMetaOfOtherAccount(cacheAccountKey(await SharedPreferences.getInstance()));
    if (!forceRefresh && _cachedColumns.isNotEmpty) {
      return _cachedColumns;
    }
    final meta = await getCustomerMeta(forceRefresh: forceRefresh);
    return meta.dynamicColumns;
  }

  @override
  Future<CustomerMetaData> getCustomerMeta({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final account = cacheAccountKey(prefs);
    _dropMetaOfOtherAccount(account);
    if (!forceRefresh && account != null && _cachedMeta != null) {
      return _cachedMeta!;
    }

    // Bản lưu trong máy của đúng tài khoản; chưa rõ tài khoản thì không đọc.
    Map<String, dynamic>? fromDisk() {
      final raw = account == null ? null : prefs.getString(_metaPrefsKey(account));
      if (raw == null || raw.isEmpty) return null;
      try {
        return jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    }

    if (!forceRefresh) {
      final disk = fromDisk();
      if (disk != null) {
        try {
          if (await _keepMeta(prefs, account, disk, persist: false)) {
            unawaited(_refreshMetaInBackground());
            return _cachedMeta ?? CustomerMetaData.fromJson(disk);
          }
        } catch (_) {}
      }
    }

    try {
      final meta = await _apiService.getCustomerMeta(context: 'mobile');
      // 🔴 Đổi tài khoản / đăng xuất trong lúc chờ mạng ⇒ danh mục của người cũ: không giữ, không ghi lại bản lưu logout()
      // vừa xoá; còn tài khoản khác thì làm lại cho người đang đăng nhập.
      if (cacheAccountKey(prefs) != account) {
        if (cacheAccountKey(prefs) == null) return kDefaultCustomerMeta;
        return await getCustomerMeta(forceRefresh: forceRefresh);
      }
      if (meta.isNotEmpty) {
        await _keepMeta(prefs, account, meta);
        return _cachedMeta ?? CustomerMetaData.fromJson(meta);
      }
    } catch (_) {
      if (cacheAccountKey(prefs) != account) {
        if (cacheAccountKey(prefs) == null) return kDefaultCustomerMeta;
        return await getCustomerMeta(forceRefresh: forceRefresh);
      }
      if (account != null && _cachedMeta != null) return _cachedMeta!;
      final disk = fromDisk();
      if (disk != null) {
        try {
          await _keepMeta(prefs, account, disk, persist: false);
          return _cachedMeta ?? CustomerMetaData.fromJson(disk);
        } catch (_) {}
      }
    }

    // Server trả rỗng (không lỗi) ⇒ vẫn ưu tiên bản lưu của chính tài khoản này trước bộ mặc định cứng.
    if (account != null && _cachedMeta == null) {
      final disk = fromDisk();
      if (disk != null) {
        try {
          await _keepMeta(prefs, account, disk, persist: false);
        } catch (_) {}
      }
    }

    return (account != null ? _cachedMeta : null) ?? kDefaultCustomerMeta;
  }

  Future<void> _refreshMetaInBackground() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final account = cacheAccountKey(prefs);
      if (account == null) return;
      final meta = await _apiService.getCustomerMeta(context: 'mobile');
      if (meta.isNotEmpty) await _keepMeta(prefs, account, meta);
    } catch (_) {}
  }

  @override
  Future<CustomerEntity> updateCustomer({
    required int id,
    required Map<String, dynamic> changes,
    String? clientUuid,
  }) async {
    // 1. Nếu là bản ghi tạo offline chưa có trên server (id <= 0)
    final isLocalPendingRecord = id <= 0;
    if (isLocalPendingRecord) {
      String? targetUuid = clientUuid;
      if (targetUuid == null) {
        final found = _cachedCustomers.where((c) => c.id == id && c.clientUuid != null).firstOrNull;
        targetUuid = found?.clientUuid;
      }

      if (targetUuid != null) {
        final updated = await _localDataSource.updateCustomerOffline(targetUuid, changes);
        final index = _cachedCustomers.indexWhere((c) => c.clientUuid == targetUuid);
        if (index != -1) {
          _cachedCustomers[index] = updated;
        } else {
          _cachedCustomers.add(updated);
        }

        // Tự động kích hoạt đồng bộ lại ngay nếu thiết bị có kết nối mạng
        unawaited(_syncService.syncQueue());
        return updated;
      }
    }

    // 2. Khách hàng đã có trên server (id > 0)
    // Cả khách hàng do user tự tạo hay được phân công, khi đã có id > 0 thì phải gọi API cập nhật lên server
    // Còn lệnh sửa chưa gửi xong của điểm bán này ⇒ lần sửa này cũng đi hàng đợi, đứng sau nó: PATCH thẳng rồi lệnh cũ
    // gửi sau sẽ ĐÈ giá trị mới bằng giá trị cũ (rà soát #24698 vòng 3).
    final uuidForQueue = clientUuid ?? _cachedCustomers.where((c) => c.id == id).firstOrNull?.clientUuid;
    if (_isOnline && !await _localDataSource.hasUnsentCustomerUpdate(id, uuidForQueue)) {
      try {
        // Ảnh ô động trên máy ⇒ tải lên ngay trước khi PATCH (bản gửi đi); lỗi tải ném [NetworkException] ⇒ hàng đợi với
        // `changes` GỐC (đường dẫn — đồng bộ tải lại; token đã tải bị server dọn sau 1 ngày) (#24698 vòng 4–5, #24792).
        final cur = _cachedCustomers.where((c) => c.id == id).firstOrNull;
        final banChep = CustomerPayloadHelper.dynamicLocalPhotoPaths(changes);
        Future<String> taiAnh(String path) =>
            _uploadPhotoOrQueue(path, locationName: cur?.name, lat: cur?.lat, lng: cur?.lng);
        final body = await CustomerPayloadHelper.resolveDynamicPhotos(changes, taiAnh);
        // Ảnh mặt tiền: màn sửa giữ đường dẫn ảnh trên máy (#24698 vòng 6) ⇒ tải ở đây, cùng luật lỗi với ảnh ô động.
        // Chỉ tệp CÒN trên máy (kể cả iOS đổi thư mục app); tệp đã mất giữ nguyên chuỗi như trước (không đẩy cả lần sửa
        // xuống hàng đợi để chết 410). Bản chép của màn sửa KHÔNG dọn ở đây — tệp có thể còn dòng hàng đợi khác trỏ tới.
        if (body['photo_tokens'] is List) {
          final anh = <String>[];
          for (final raw in body['photo_tokens'] as List) {
            final p = raw.toString().trim();
            final tep = _isLocalFile(p) ? await OfflinePhotoStore.existingFile(p) : null;
            anh.add(tep != null ? await taiAnh(tep.path) : p);
          }
          body['photo_tokens'] = anh;
        }
        await _apiService.updateCustomer(id, body);
        changes = body;
        // Mỗi lần sửa là một dòng nhật ký ⇒ uuid MỚI (khoá điểm bán cố định thì lần sửa thứ hai bị khử trùng, biến mất).
        // `logDirectSend` tự nuốt lỗi — không thể biến lệnh server ĐÃ nhận thành "chuyển hàng đợi".
        await _localDataSource.db.logDirectSend(
          entity: 'customer',
          op: 'update',
          clientUuid: const Uuid().v4(),
          payload: {'name': body['name'], 'address': body['address'], 'route': body['route']},
          serverId: id,
        );
        // Ảnh đã lên server, bản trong máy ghi token (bước 3) ⇒ dọn bản chép lâu dài màn sửa vừa tạo.
        await deleteOfflineCustomerPhotos(banChep);
      } catch (e) {
        // Lỗi nghiệp vụ hoặc validate từ server (4xx, trừ 408/429) -> rethrow cho UI hiển thị
        if (e is AppException &&
            e.statusCode != null &&
            e.statusCode! >= 400 &&
            e.statusCode! < 500 &&
            e.statusCode != 408 &&
            e.statusCode != 429) {
          rethrow;
        }
        // Nếu lỗi mất mạng giữa chừng, đưa vào hàng đợi offline
        if (!_isNetworkError(e)) {
          rethrow;
        }
        final queued = await _updateCustomerOfflineQueue(id, changes, clientUuid: clientUuid);
        unawaited(_syncService.syncQueue());
        return queued;
      }
    } else {
      // Khi ngoại tuyến không có mạng (hoặc phải đứng sau lệnh sửa chưa gửi), đưa vào hàng đợi offline
      final queued = await _updateCustomerOfflineQueue(id, changes, clientUuid: clientUuid);
      if (_isOnline) unawaited(_syncService.syncQueue());
      return queued;
    }

    // 3. Cập nhật trong cache RAM và CSDL SQLite cục bộ
    final index = _cachedCustomers.indexWhere(
      (c) => (id > 0 && c.id == id) || (clientUuid != null && c.clientUuid == clientUuid),
    );
    if (index != -1) {
      final current = _cachedCustomers[index];
      final updated = _applyChangesToCustomer(current, changes);
      _cachedCustomers[index] = updated;

      // Đồng bộ vào SQLite để dữ liệu offline luôn mới nhất
      await _localDataSource.cacheRemoteCustomers([updated]);
      // Ô ma trận: số mặt / % SOS do SERVER tính (bản trong máy chỉ có số nhập — chi tiết hiện "chờ đồng bộ") ⇒ lấy lại bản
      // server; lỗi thì getCustomerDetail trả bản trong máy (#24698 vòng 4).
      final data = changes['data'];
      if (data is Map && data.values.any((v) => v is Map && v.containsKey('counts'))) return getCustomerDetail(id);
      return updated;
    }

    // PATCH đã thành công mà điểm bán không có trong bộ nhớ (mở từ thông báo / bộ nhớ vừa làm mới) ⇒ lấy bản server; báo
    // "không tìm thấy" là người dùng tưởng lưu hỏng mà lưu lại.
    if (id > 0) return getCustomerDetail(id);
    throw Exception('Không tìm thấy điểm bán ID: $id');
  }

  /// Đường dẫn ảnh TRÊN MÁY (cần tải lên) — đường tuyệt đối hoặc `file://`; token / URL / đường xem trên server giữ nguyên.
  /// KHÔNG dùng CustomerEntity.isLocalFilePath: nó nhận cả URL `https://` (chứa ':/') và chuỗi có 'cache'/'tmp'.
  static bool _isLocalFile(String s) =>
      (s.startsWith('/') || s.startsWith('file://')) && !s.contains('/crm/customer-photos/');

  bool _isNetworkError(dynamic e) {
    if (!_isOnline) return true;
    if (e is SocketException || e is HttpException) return true;
    if (e is AppException) {
      if (e.statusCode == null) return true;
      if (isTemporaryServerError(e)) return true;
    }
    final str = e.toString().toLowerCase();
    return str.contains('socketexception') ||
        str.contains('network') ||
        str.contains('connection') ||
        str.contains('timeout') ||
        str.contains('mất kết nối');
  }

  Future<CustomerEntity> _updateCustomerOfflineQueue(
    int id,
    Map<String, dynamic> changes, {
    String? clientUuid,
  }) async {
    final index = _cachedCustomers.indexWhere(
      (c) => (id > 0 && c.id == id) || (clientUuid != null && c.clientUuid == clientUuid),
    );
    if (index == -1) {
      throw Exception('Không tìm thấy điểm bán ID: $id để cập nhật offline');
    }

    final current = _cachedCustomers[index];
    // Mã rỗng ('' từ server) không phải khoá: lệnh sửa của các điểm bán khác nhau sẽ khớp nhau ⇒ dùng mã server.
    final effectiveUuid = [clientUuid, current.clientUuid].firstWhere((u) => u != null && u.isNotEmpty,
        orElse: () => 'server_$id')!;
    // Ảnh mới ⇒ chép vào thư mục lưu lâu dài TRƯỚC khi ghi bản trong máy và hàng đợi — hai nơi trỏ CÙNG một tệp bền
    // (thư mục tạm của camera bị dọn thì ảnh ở chi tiết điểm bán vỡ, #24698).
    if (changes['photo_tokens'] is List) {
      changes = {
        ...changes,
        'photo_tokens': await _localDataSource.persistOfflinePhotos(
            (changes['photo_tokens'] as List).map((e) => e.toString()).toList(), '${effectiveUuid}_edit'),
      };
    }
    final updated = _applyChangesToCustomer(current, changes);
    _cachedCustomers[index] = updated;

    // 1. Đẩy vào hàng đợi sync_queue TRƯỚC khi ghi bản sửa vào máy: lần tải danh sách chạy song song chỉ chừa dòng còn
    // lệnh sửa chờ — ghi bản sửa trước thì giữa hai bước nó bị bản server cũ đè (#24698 vòng 3).
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    await _localDataSource.enqueueCustomerUpdate(
      serverId: id,
      clientUuid: effectiveUuid,
      changes: changes,
      nowMs: nowMs,
    );

    // 2. Cập nhật vào SQLite LocalCustomers
    await _localDataSource.cacheRemoteCustomers([updated], localEdit: true);

    return updated;
  }

  CustomerEntity _applyChangesToCustomer(CustomerEntity current, Map<String, dynamic> changes) {
    final newDynamicFields = Map<String, dynamic>.from(current.dynamicFields);
    if (changes['data'] is Map) {
      newDynamicFields.addAll(changes['data'] as Map<String, dynamic>);
    }
    // Sinh nhật là ô gốc nhưng giữ trong dynamicFields để màn sửa nạp lại (#24698 lỗi 11).
    if (changes['birthday'] != null) newDynamicFields['birthday'] = changes['birthday'];
    if (changes.containsKey('delivery_address')) newDynamicFields['delivery_address'] = changes['delivery_address'];

    // Tỉnh/xã theo danh mục (#24072): ghi id MỚI vào bản nhớ (cả RAM lẫn SQLite qua cacheRemoteCustomers) và gỡ cờ "suy từ
    // địa chỉ cũ" — để nguyên id cũ + cờ cũ thì lần sửa sau gửi lại cặp CŨ và đè mất lựa chọn vừa lưu (review 23/10).
    String? geoProvinceName = current.provinceName;
    String? geoWardName = current.wardName;
    if (changes.containsKey('province_id') || changes.containsKey('ward_id')) {
      for (final k in const ['province_id', 'ward_id']) {
        if (changes.containsKey(k)) newDynamicFields[k] = int.tryParse(changes[k]?.toString() ?? '');
      }
      // Server: xoá tỉnh ⇒ xoá luôn xã; đổi tỉnh không kèm xã ⇒ bỏ xã cũ.
      if (changes.containsKey('province_id') && !changes.containsKey('ward_id')) newDynamicFields['ward_id'] = null;
      final pid = newDynamicFields['province_id'] as int?;
      newDynamicFields['geo_source'] = pid == null ? null : 'entered';
      final catalog = GeoCatalogService.memory;
      // Chưa nạp danh mục ⇒ để TRỐNG tên (lần làm mới sau server trả tên đúng) — rơi về tên cũ là hiện tỉnh A cạnh id tỉnh B.
      geoProvinceName = pid == null ? null : catalog?.province(pid)?.fullName;
      final wid = newDynamicFields['ward_id'] as int?;
      geoWardName = wid == null ? null : catalog?.ward(wid)?.fullName;
    }

    List<String> newPhotoUrls = List<String>.from(current.photoUrls);
    String? newPhotoUrl = current.photoUrl;
    if (changes['photo_tokens'] is List) {
      final tokens = (changes['photo_tokens'] as List).map((e) => e.toString()).toList();
      newPhotoUrls = tokens;
      newPhotoUrl = tokens.isNotEmpty ? tokens.first : null;
      newDynamicFields['photo_tokens'] = tokens;
      newDynamicFields['photo_urls'] = tokens;
      if (newPhotoUrl != null) newDynamicFields['photo_url'] = newPhotoUrl;
    }

    return current.copyWith(
      code: changes['code']?.toString() ?? current.code,
      name: changes['name']?.toString() ?? current.name,
      customerTypeId: changes.containsKey('customer_type_id')
          ? (changes['customer_type_id'] as int?)
          : current.customerTypeId,
      channelId: changes.containsKey('channel_id')
          ? (changes['channel_id'] as int?)
          : current.channelId,
      regionId: changes.containsKey('region_id')
          ? (changes['region_id'] as int?)
          : current.regionId,
      regionName: changes.containsKey('region_name')
          ? changes['region_name']?.toString()
          : current.regionName,
      provinceName: changes.containsKey('province_name')
          ? changes['province_name']?.toString()
          : geoProvinceName,
      wardName: changes.containsKey('ward_name')
          ? changes['ward_name']?.toString()
          : geoWardName,
      contactPerson: changes['contact_name']?.toString() ??
          changes['contact_person']?.toString() ??
          current.contactPerson,
      contactTitle: changes.containsKey('contact_title')
          ? changes['contact_title']?.toString()
          : current.contactTitle,
      phone: changes['phone']?.toString() ?? current.phone,
      email: changes.containsKey('email')
          ? changes['email']?.toString()
          : current.email,
      address: changes['address']?.toString() ?? current.address,
      lat: changes.containsKey('coords')
          ? (changes['coords'] is Map ? (changes['coords']['lat'] as num?)?.toDouble() : null)
          : (changes.containsKey('lat')
              ? (changes['lat'] is num ? (changes['lat'] as num).toDouble() : null)
              : current.lat),
      lng: changes.containsKey('coords')
          ? (changes['coords'] is Map ? (changes['coords']['lng'] as num?)?.toDouble() : null)
          : (changes.containsKey('lng')
              ? (changes['lng'] is num ? (changes['lng'] as num).toDouble() : null)
              : current.lng),
      coordsMock: changes.containsKey('coords')
          ? (changes['coords'] is Map ? changes['coords']['mock'] as bool? : null)
          : current.coordsMock,
      geofenceRadiusM: changes.containsKey('geofence_radius_m')
          ? (changes['geofence_radius_m'] as int?)
          : current.geofenceRadiusM,
      route: changes.containsKey('route')
          ? (changes['route']?.toString() ?? current.route)
          : current.route,
      routes: changes.containsKey('routes') && changes['routes'] is List
          ? (changes['routes'] as List).map((e) => e.toString()).toList()
          : (changes.containsKey('route') ? [changes['route'].toString()] : current.routes),
      routeIds: changes.containsKey('route_ids') && changes['route_ids'] is List
          ? (changes['route_ids'] as List).map((e) => int.tryParse(e.toString()) ?? 0).where((id) => id > 0).toList()
          : current.routeIds,
      dynamicFields: newDynamicFields,
      photoUrl: newPhotoUrl,
      photoUrls: newPhotoUrls,
    );
  }

  @override
  Future<CustomerEntity> createCustomer(Map<String, dynamic> input) async {
    final isOnline = _isOnline;
    // client_uuid sinh MỘT lần lúc bấm tạo, dùng cho CẢ lần gửi trực tuyến lẫn bản ghi hàng đợi: lần gửi trực tuyến quá
    // giờ mà server đã ghi thì hàng đợi gửi lại CÙNG uuid ⇒ server trả bản cũ. Sinh uuid mới ở nhánh ngoại tuyến là tạo
    // điểm bán TRÙNG + hai lượt "Tạo điểm bán" (rà soát #24698 lỗi 9).
    final existingUuid = input['client_uuid']?.toString();
    final data = <String, dynamic>{
      ...input,
      'client_uuid': (existingUuid != null && existingUuid.isNotEmpty) ? existingUuid : const Uuid().v4(),
    };

    if (isOnline) {
      var posted = false;
      try {
        final cleanPayload = await _prepareCleanCustomerPayload(data);
        posted = true;
        final dto = await _apiService.createCustomer(cleanPayload);

        final serverId = dto.id > 0 ? dto.id : 0;
        final serverCode = dto.code.isNotEmpty ? dto.code : '';

        if (serverId > 0) {
          // Lệnh gửi trực tuyến cũng vào nhật ký đã gửi (màn Báo cáo gửi dữ liệu).
          await _localDataSource.db.logDirectSend(
            entity: 'customer',
            op: 'create',
            clientUuid: data['client_uuid'].toString(),
            payload: {'name': data['name'], 'address': data['address'], 'route': data['route']},
            serverId: serverId,
          );
          // Ảnh ô động (ô ma trận, ô chụp ảnh tự khai) + ảnh mặt tiền màn tạo vừa chép đã lên server ⇒ dọn bản chép lâu
          // dài trên máy (điểm bán mới — không dòng hàng đợi nào khác trỏ tới).
          await deleteOfflineCustomerPhotos([
            ...CustomerPayloadHelper.dynamicLocalPhotoPaths(data),
            for (final k in const ['photo_tokens', 'photos'])
              if (data[k] is List) ...(data[k] as List).map((e) => '$e'),
          ]);
          // Vật tư đã ghi cùng lượt tạo ⇒ cache cho lượt viếng thăm đầu ngoại tuyến (#24526).
          if (cleanPayload['materials'] is List) {
            await cacheCreatedOutletMaterials(
              serverId,
              (cleanPayload['materials'] as List)
                  .whereType<Map>()
                  .map((m) => MaterialOperation.fromJson(Map<String, dynamic>.from(m)))
                  .toList(),
            );
          }
          final entity = _buildSyncedCustomerEntity(
            data: data,
            serverId: serverId,
            serverCode: serverCode,
            cleanPayload: cleanPayload,
          );

          await _localDataSource.cacheRemoteCustomers([entity]);
          _cachedCustomers.removeWhere((c) =>
              (entity.clientUuid != null && c.clientUuid == entity.clientUuid) ||
              (entity.id > 0 && c.id == entity.id) ||
              (entity.code.isNotEmpty && !entity.code.startsWith('PENDING_') && c.code == entity.code));
          _cachedCustomers.insert(0, entity);
          _cachedCustomers = CustomerLocalDataSource.deduplicateCustomers(_cachedCustomers);
          return entity;
        }
        // Server đã trả lời 2xx mà không đọc được mã ⇒ chắc chắn đã nhận: dòng hàng đợi mang dấu như ca quá giờ.
        data[queueMaybeOnServerKey] = true;
      } catch (e) {
        debugPrint('[CustomerRepositoryImpl] Lỗi khi tạo online ($e)');
        // 🔴 Theo spec 30/09 §7: Lỗi 4xx từ chối hẳn (validate thất bại) — TUYỆT ĐỐI không fallback sang ghi offline để
        // tránh tạo rác và làm tắc hàng đợi SyncQueue! Cùng luật phân loại với hàng đợi ([isPermanentRejection]).
        if (isPermanentRejection(e)) rethrow;
        // Lỗi lúc GỬI tạo (không phải lúc chuẩn bị ảnh) mà không chắc chưa ra khỏi máy ⇒ server có thể đã ghi (lần sửa sau
        // không gộp vào dòng tạo).
        if (posted && !(e is NetworkException && !e.mayHaveReachedServer)) data[queueMaybeOnServerKey] = true;
      }
    }

    // 1. Ghi máy trước, sinh client_uuid lúc nhập (BB-1, BB-2)
    final localEntity = await _localDataSource.createCustomerOffline(data);
    _cachedCustomers.removeWhere((c) =>
        (localEntity.clientUuid != null && c.clientUuid == localEntity.clientUuid) ||
        (localEntity.code.isNotEmpty && c.code == localEntity.code));
    _cachedCustomers.insert(0, localEntity);
    _cachedCustomers = CustomerLocalDataSource.deduplicateCustomers(_cachedCustomers);

    // 2. Kích hoạt tiến trình đồng bộ ngầm nếu có mạng (BB-1: Single Write Path)
    unawaited(_syncService.syncQueue());

    return localEntity;
  }

  /// Ảnh vật tư ⇒ token qua `POST /dms/form-photos` (cùng luồng ảnh thao tác vật tư của lượt). Không có Ref (test) ⇒
  /// coi như mất mạng: createCustomer rơi về hàng đợi.
  Future<String> _uploadMaterialPhoto(File file) async {
    final ref = _ref;
    if (ref == null) throw const NetworkException();
    return (await ref.read(formsApiServiceProvider).uploadPhoto(file)).token;
  }

  /// Tải MỘT ảnh điểm bán lúc tạo trực tuyến, trả token. Lỗi tạm (mạng / 5xx / 408 / 429 / phản hồi thiếu token) ⇒ ném
  /// [NetworkException] để createCustomer rơi về đường hàng đợi (chép ảnh vào thư mục lưu lâu dài, đồng bộ tải lại).
  /// Trước đây lỗi bị nuốt ⇒ điểm bán được tạo KHÔNG ảnh mà không báo gì (#24698). Lỗi 4xx khác ném nguyên để báo người dùng.
  Future<String> _uploadPhotoOrQueue(String path, {String? locationName, double? lat, double? lng}) async {
    Map<String, dynamic> res;
    try {
      res = await _apiService.uploadCustomerPhoto(path, locationName: locationName, lat: lat, lng: lng);
    } on AppException catch (e) {
      if (isPermanentRejection(e)) rethrow;
      throw const NetworkException('Tải ảnh điểm bán lỗi — lưu ngoại tuyến, gửi lại khi có mạng.');
    } catch (_) {
      throw const NetworkException('Tải ảnh điểm bán lỗi — lưu ngoại tuyến, gửi lại khi có mạng.');
    }
    final token = res['token']?.toString().trim();
    if (token == null || token.isEmpty) {
      throw const NetworkException('Tải ảnh điểm bán không nhận được mã ảnh — lưu ngoại tuyến.');
    }
    return token;
  }

  Future<Map<String, dynamic>> _prepareCleanCustomerPayload(Map<String, dynamic> data) async {
    // 1. Tải ảnh lên server để lấy token nếu đang là đường dẫn cục bộ (kèm tên + toạ độ điểm bán như màn tạo trước đây).
    final coords = data['coords'];
    double? toaDo(String k) => double.tryParse('${coords is Map ? coords[k] : data[k]}');
    Future<String> taiAnh(String path) => _uploadPhotoOrQueue(OfflinePhotoStore.toFilePath(path),
        locationName: data['name']?.toString() ?? 'Điểm bán mới', lat: toaDo('lat'), lng: toaDo('lng'));
    final resolvedTokens = <String>[];
    // `photos`: ô ảnh mặt tiền mã 'photos' — màn tạo giữ đường dẫn, không đọc là mất ảnh im lặng (#24698 vòng 6).
    final rawTokens =
        data['photo_tokens'] ?? data['photo_token'] ?? data['photo_file_id'] ?? data['photo'] ?? data['photos'];
    if (rawTokens is List) {
      for (final item in rawTokens) {
        final itemStr = item.toString().trim();
        if (itemStr.isEmpty) continue;
        if (itemStr.length == 32 && !itemStr.contains('/') && !itemStr.contains(r'\')) {
          resolvedTokens.add(itemStr);
        } else {
          resolvedTokens.add(await taiAnh(itemStr));
        }
      }
    } else if (rawTokens != null) {
      final itemStr = rawTokens.toString().trim();
      if (itemStr.isNotEmpty) {
        if (itemStr.length == 32 && !itemStr.contains('/') && !itemStr.contains(r'\')) {
          resolvedTokens.add(itemStr);
        } else {
          resolvedTokens.add(await taiAnh(itemStr));
        }
      }
    }

    // 1b. Vật tư khai lúc tạo (#24526): ảnh đổi ra token qua /dms/form-photos (luồng ảnh vật tư của lượt). Lỗi tải ảnh
    // ném ra ⇒ createCustomer rơi về đường hàng đợi (đổi ảnh lúc đồng bộ), không gửi thiếu ảnh.
    var source = data;
    if (data['materials'] is List) {
      source = {
        ...data,
        'materials': await resolveCreateMaterials(
          data['materials'],
          _uploadMaterialPhoto,
        ),
      };
    }

    // 1c. Ảnh trên máy của ô động — ô ma trận trưng bày (#24773), ô chụp ảnh tự khai (#24792) ⇒ token. Lỗi tải ném
    // [NetworkException] ⇒ createCustomer rơi về đường hàng đợi (đồng bộ tải lại), không gửi đường dẫn máy cho server từ
    // chối cả điểm bán.
    source = await CustomerPayloadHelper.resolveDynamicPhotos(source, _uploadPhotoOrQueue);

    // 2. Sử dụng CustomerPayloadHelper để xây dựng payload chuẩn 25 khoá gốc
    return CustomerPayloadHelper.buildCustomerApiPayload(
      sourceData: source,
      resolvedPhotoTokens: resolvedTokens.isNotEmpty ? resolvedTokens : null,
      isOfflineSync: false,
    );
  }

  CustomerEntity _buildSyncedCustomerEntity({
    required Map<String, dynamic> data,
    required int serverId,
    required String serverCode,
    required Map<String, dynamic> cleanPayload,
  }) {
    final name = (data['name'] ?? 'Điểm bán mới').toString().trim();
    final address = (data['address'] ?? '').toString().trim();
    final phone = (data['phone'] ?? '').toString().trim();
    final contactName = (data['contact_name'] ?? data['contact_person'] ?? data['contactPerson'] ?? '').toString().trim();
    final contactTitle = data['contact_title']?.toString().trim();
    final type = (data['type'] ?? data['customer_type_name'] ?? '').toString().trim();
    final route = (data['route'] ?? data['route_name'] ?? 'Tuyến mặc định').toString().trim();
    final routeIds = (cleanPayload['route_ids'] as List<int>?) ?? [];
    final clientUuid = cleanPayload['client_uuid']?.toString();
    final photoToken = cleanPayload['photo_token']?.toString();

    final regionId = cleanPayload['region_id'] is int
        ? cleanPayload['region_id'] as int
        : int.tryParse(cleanPayload['region_id']?.toString() ?? '');

    final customerTypeId = cleanPayload['customer_type_id'] is int
        ? cleanPayload['customer_type_id'] as int
        : int.tryParse(cleanPayload['customer_type_id']?.toString() ?? '');

    final channelId = cleanPayload['channel_id'] is int
        ? cleanPayload['channel_id'] as int
        : int.tryParse(cleanPayload['channel_id']?.toString() ?? '');

    final channelName = (data['channel_name'] ?? '').toString().trim();

    double? lat;
    double? lng;
    bool? coordsMock;
    if (cleanPayload['coords'] is Map) {
      final cMap = cleanPayload['coords'] as Map;
      lat = (cMap['lat'] as num?)?.toDouble() ?? double.tryParse(cMap['lat']?.toString() ?? '');
      lng = (cMap['lng'] as num?)?.toDouble() ?? double.tryParse(cMap['lng']?.toString() ?? '');
      coordsMock = cMap['mock'] as bool?;
    } else {
      if (cleanPayload['lat'] != null) lat = double.tryParse(cleanPayload['lat'].toString());
      if (cleanPayload['lng'] != null) lng = double.tryParse(cleanPayload['lng'].toString());
    }

    final now = DateTime.now();
    final clientTimeIso = '${now.toIso8601String()}+07:00';

    return CustomerEntity(
      id: serverId,
      code: serverCode,
      name: name,
      type: type,
      customerTypeId: customerTypeId,
      channelId: channelId,
      channelName: channelName.isNotEmpty ? channelName : null,
      regionId: regionId,
      route: route,
      routes: [route],
      routeIds: routeIds,
      address: address,
      contactPerson: contactName,
      contactTitle: contactTitle,
      phone: phone,
      lat: lat,
      lng: lng,
      coordsMock: coordsMock,
      status: 'active',
      approvalStatus: 'pending',
      approvalLabel: 'Chờ duyệt',
      approvalColor: 'warning',
      syncStatus: 'synced',
      clientUuid: clientUuid,
      isToday: CustomerEntity.isSameDayOfWeek(
        CustomerEntity.extractDayOfWeekFromName(route),
        DateTime.now().weekday,
      ),
      photoUrl: photoToken,
      photoUrls: photoToken != null ? [photoToken] : const [],
      createdAt: clientTimeIso,
      updatedAt: clientTimeIso,
    );
  }

  @override
  Future<CustomerEntity> getCustomerDetail(int id) async {
    try {
      final dto = await _apiService.getCustomerDetail(id);
      final entity = dto.toEntity();
      // Còn lệnh SỬA chờ gửi ⇒ bản server cũ hơn phần sửa: trả bản trong máy (cùng luật lần tải danh sách — vòng 3).
      if (await _localDataSource.hasUnsentCustomerUpdate(id, entity.clientUuid)) {
        final i = _cachedCustomers.indexWhere((c) => c.id == id);
        if (i != -1) return _cachedCustomers[i];
        final local = (await _localDataSource.getLocalCustomers()).where((c) => c.id == id).firstOrNull;
        if (local != null) return local;
      }
      unawaited(_localDataSource.cacheRemoteCustomers([entity]));
      final index = _cachedCustomers.indexWhere((c) => c.id == id);
      if (index != -1) {
        _cachedCustomers[index] = entity;
      }
      return entity;
    } catch (_) {
      final index = _cachedCustomers.indexWhere((c) => c.id == id);
      if (index != -1) {
        return _cachedCustomers[index];
      }
      try {
        final localList = await _localDataSource.getLocalCustomers();
        return localList.firstWhere((c) => c.id == id);
      } catch (_) {}
      rethrow;
    }
  }

  Map<String, dynamic>? _cachedSchema;

  /// Tài khoản mà [_cachedSchema] đang giữ — bản trong bộ nhớ chỉ trả cho ĐÚNG tài khoản này (không bao giờ giữ khi chưa
  /// rõ tài khoản).
  String? _cachedSchemaAccount;

  /// Khoá lưu schema trong máy, TÁCH theo tài khoản: schema mang giá trị "tự điền theo phòng ban" (`default`) tính riêng
  /// cho người tải về — dùng chung một khoá thì người sau đăng nhập lúc mất mạng được điền theo phòng của người trước.
  /// `logout()` xoá mọi khoá `cached_customer_form_schema*`.
  String _schemaPrefsKey(String account) => 'cached_customer_form_schema_$account';

  /// Giữ schema vừa có cho [account] — CHỈ khi đó vẫn là tài khoản đang đăng nhập (xem [cacheAccountKey]).
  Future<bool> _keepSchema(SharedPreferences prefs, String? account, Map<String, dynamic> schema, {bool persist = true}) async {
    if (cacheAccountKey(prefs) != account) return false;
    // Chưa rõ tài khoản ⇒ không giữ cả trong bộ nhớ (ngăn "không rõ ai" không được đọc lại).
    if (account == null) return true;
    _cachedSchema = schema;
    _cachedSchemaAccount = account;
    if (persist) await prefs.setString(_schemaPrefsKey(account), jsonEncode(schema));
    return true;
  }

  @override
  Future<Map<String, dynamic>> getCustomerFormSchema({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final account = cacheAccountKey(prefs);
    if (!forceRefresh && account != null && _cachedSchema != null && _cachedSchemaAccount == account) {
      return _cachedSchema!;
    }

    // Bản lưu trong máy của đúng tài khoản; chưa rõ tài khoản thì không đọc.
    Map<String, dynamic>? fromDisk() {
      final raw = account == null ? null : prefs.getString(_schemaPrefsKey(account));
      if (raw == null || raw.isEmpty) return null;
      try {
        return jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    }

    if (!forceRefresh) {
      final disk = fromDisk();
      if (disk != null) {
        await _keepSchema(prefs, account, disk, persist: false);
        unawaited(_refreshSchemaInBackground());
        return disk;
      }
    }

    try {
      final res = await _apiService.getCustomerFormSchema();
      // 🔴 Đổi tài khoản / đăng xuất trong lúc chờ mạng ⇒ đây là schema của người cũ: không giữ, không ghi lại bản lưu mà
      // `logout()` vừa xoá, và tải lại cho người đang đăng nhập thay vì đưa schema người cũ cho màn hình của người mới.
      if (!await _keepSchema(prefs, account, res)) {
        // Phiên vừa hết (tài khoản thành null) ⇒ không đưa schema người cũ ra, cũng không gọi lại lúc không có token (401).
        if (cacheAccountKey(prefs) == null) return kDefaultCustomerFormSchema;
        return await getCustomerFormSchema(forceRefresh: forceRefresh);
      }
      return res;
    } catch (e) {
      if (cacheAccountKey(prefs) != account) {
        if (cacheAccountKey(prefs) == null) return kDefaultCustomerFormSchema;
        return await getCustomerFormSchema(forceRefresh: forceRefresh);
      }
      if (_cachedSchema != null && _cachedSchemaAccount == account) return _cachedSchema!;
      final disk = fromDisk();
      if (disk != null) {
        await _keepSchema(prefs, account, disk, persist: false);
        return disk;
      }
      // Offline fallback: Trả về schema mặc định khi không có mạng và chưa từng lưu cache
      return kDefaultCustomerFormSchema;
    }
  }

  Future<void> _refreshSchemaInBackground() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final account = cacheAccountKey(prefs);
      if (account == null) return;
      final res = await _apiService.getCustomerFormSchema();
      await _keepSchema(prefs, account, res);
    } catch (_) {}
  }

  @override
  Future<Map<String, dynamic>> uploadCustomerPhoto(
    String filePath, {
    String? locationName,
    double? lat,
    double? lng,
  }) async {
    return _apiService.uploadCustomerPhoto(
      filePath,
      locationName: locationName,
      lat: lat,
      lng: lng,
    );
  }

  @override
  Future<bool> deleteCustomer(int id) async {
    try {
      await _apiService.deleteCustomer(id);
    } catch (_) {}

    await _localDataSource.deleteCustomerLocal(id);
    _cachedCustomers.removeWhere((c) => c.id == id);
    return true;
  }

  @override
  Future<bool> deletePendingCustomer(String clientUuid) async {
    if (!await _localDataSource.deletePendingCustomer(clientUuid)) return false;
    _cachedCustomers.removeWhere((c) => c.clientUuid == clientUuid);
    return true;
  }
}

/// Dữ liệu phân loại mặc định cho trường hợp chạy offline ngay từ lần cài đặt đầu tiên
const CustomerMetaData kDefaultCustomerMeta = CustomerMetaData(
  customerTypes: [
    CustomerCategoryItem(id: 1, code: 'DL', name: 'Đại lý', color: '#10B981'),
    CustomerCategoryItem(id: 2, code: 'C1', name: 'Đại lý C1', color: '#059669'),
    CustomerCategoryItem(id: 3, code: 'C2', name: 'Đại lý C2', color: '#047857'),
    CustomerCategoryItem(id: 4, code: 'NPP', name: 'Nhà phân phối', color: '#2563EB'),
    CustomerCategoryItem(id: 5, code: 'ST', name: 'Siêu thị / Tiện lợi', color: '#7C3AED'),
    CustomerCategoryItem(id: 6, code: 'BL', name: 'Điểm bán lẻ', color: '#D97706'),
    CustomerCategoryItem(id: 7, code: 'NM', name: 'Nhà máy / Cơ sở SX', color: '#4B5563'),
  ],
  channels: [
    CustomerCategoryItem(id: 1, code: 'GT', name: 'GT (Truyền thống)'),
    CustomerCategoryItem(id: 2, code: 'MT', name: 'MT (Hiện đại)'),
    CustomerCategoryItem(id: 3, code: 'KA', name: 'KA (Trọng điểm)'),
    CustomerCategoryItem(id: 4, code: 'HORECA', name: 'Horeca'),
  ],
  regions: [
    CustomerCategoryItem(id: 1, code: '01', name: '01 - Hà Nội'),
    CustomerCategoryItem(id: 3, code: '03', name: '03 - Phú Thọ'),
    CustomerCategoryItem(id: 8, code: '08', name: '08 - Miền Trung'),
    CustomerCategoryItem(id: 62, code: '62', name: '62 - Vĩnh Phúc'),
  ],
  provinces: [
    CustomerProvinceItem(provinceName: 'Tỉnh Vĩnh Phúc'),
    CustomerProvinceItem(provinceName: 'Thành phố Hà Nội'),
    CustomerProvinceItem(provinceName: 'Tỉnh Phú Thọ'),
    CustomerProvinceItem(provinceName: 'Tỉnh Thái Nguyên'),
  ],
  dynamicColumns: [],
);

/// Cấu hình biểu mẫu mặc định cho trường hợp chưa từng kết nối internet
const Map<String, dynamic> kDefaultCustomerFormSchema = {
  'data': {
    'form': {
      'name': 'Hồ sơ điểm bán',
      'code': 'customer_form',
    },
    'version': '1.0.0 (offline default)',
    'fields': [
      {
        'code': 'name',
        'label': 'Tên điểm bán',
        'type': 'text',
        'placeholder': 'Nhập tên cửa hàng, đại lý...',
        'is_required': true,
        'section': 'Thông tin chung',
      },
      {
        'code': 'customer_type_id',
        'label': 'Loại điểm bán',
        'type': 'single_choice',
        'is_required': true,
        'section': 'Thông tin chung',
      },
      {
        'code': 'channel_id',
        'label': 'Kênh bán hàng',
        'type': 'single_choice',
        'is_required': false,
        'section': 'Thông tin chung',
      },
      {
        'code': 'region_id',
        'label': 'Khu vực quản lý',
        'type': 'single_choice',
        'is_required': true,
        'section': 'Thông tin chung',
      },
      {
        'code': 'contact_name',
        'label': 'Người liên hệ',
        'type': 'text',
        'placeholder': 'Họ và tên chủ cửa hàng...',
        'is_required': false,
        'section': 'Thông tin liên hệ',
      },
      {
        'code': 'contact_title',
        'label': 'Chức vụ / Vai trò',
        'type': 'text',
        'placeholder': 'Chủ đại lý, Quản lý...',
        'is_required': false,
        'section': 'Thông tin liên hệ',
      },
      {
        'code': 'phone',
        'label': 'Số điện thoại',
        'type': 'text',
        'placeholder': '09xxxxxxxx',
        'is_required': false,
        'section': 'Thông tin liên hệ',
      },
      {
        'code': 'address',
        'label': 'Địa chỉ giao dịch',
        'type': 'long_text',
        'placeholder': 'Số nhà, tên đường, phường/xã, quận/huyện...',
        'is_required': false,
        'section': 'Địa chỉ & Vị trí',
      },
      {
        'code': 'coords',
        'label': 'Vị trí điểm bán trên bản đồ',
        'type': 'location',
        'is_required': true,
        'section': 'Vị trí trên bản đồ',
      },
      {
        'code': 'photo_file_id',
        'label': 'Ảnh điểm bán',
        'type': 'image',
        'max': 10,
        'max_files': 10,
        'is_required': false,
        'allow_gallery': false,
        'helper_text': 'Chụp tối đa 10 ảnh thực tế điểm bán từ máy ảnh',
        'section': 'Hình ảnh điểm bán',
      },
    ],
  },
};

/// Lượt tải đã đổi tài khoản giữa chừng (đăng xuất → người khác đăng nhập) — kết quả của người cũ, không ghi.
class _AccountChangedException extends AppException {
  _AccountChangedException() : super('Tài khoản đã đổi trong lúc tải danh sách điểm bán');
}
