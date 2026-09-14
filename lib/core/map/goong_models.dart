/// Toạ độ một điểm.
class GoongLatLng {
  final double lat;
  final double lng;

  const GoongLatLng(this.lat, this.lng);

  factory GoongLatLng.fromJson(Map<String, dynamic> json) => GoongLatLng(
        (json['lat'] as num).toDouble(),
        (json['lng'] as num).toDouble(),
      );

  /// Dạng Goong nhận trong query: `lat,lng`.
  @override
  String toString() => '$lat,$lng';

  // 🔴 `==` / `hashCode` là BẮT BUỘC: lớp này làm khoá của `reverseGeocodeProvider` (`.family`).
  // Riverpod so khoá bằng `==`; thiếu hai hàm này thì mỗi lần dựng lại một `GoongLatLng` cùng toạ độ
  // vẫn là một khoá MỚI ⇒ bộ nhớ đệm không bao giờ trúng (gọi lại Goong mỗi lần vẽ khung hình) và
  // các mục cũ nằm lại trong bộ nhớ. Không có lỗi nào hiện ra, chỉ là hoá đơn Goong phình lên.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GoongLatLng && other.lat == lat && other.lng == lng);

  @override
  int get hashCode => Object.hash(lat, lng);
}

/// Đơn vị hành chính Goong trả kèm địa chỉ.
///
/// ⚠️ Goong v2 chỉ trả **hai cấp**: `commune` (xã/phường) và `province` (tỉnh/thành) — đúng theo bộ đơn vị
/// hành chính mới. KHÔNG có cấp quận/huyện; đừng chờ `district`, nó không tồn tại ở v2.
class GoongCompound {
  final String? commune;
  final String? province;

  const GoongCompound({this.commune, this.province});

  factory GoongCompound.fromJson(Map<String, dynamic>? json) => GoongCompound(
        commune: json?['commune'] as String?,
        province: json?['province'] as String?,
      );
}

/// Một địa điểm — dùng chung cho kết quả geocode và place/detail.
class GoongPlace {
  /// Địa chỉ đầy đủ, vd `117 Lý Thường Kiệt, Minh Phụng, Hồ Chí Minh`.
  final String formattedAddress;

  /// Tên riêng nếu có, vd `Showrom Vitto Thúy Nghị`. Rỗng với địa chỉ thuần.
  final String name;
  final GoongLatLng? location;
  final GoongCompound compound;
  final String? placeId;

  const GoongPlace({
    required this.formattedAddress,
    required this.name,
    required this.location,
    required this.compound,
    this.placeId,
  });

  factory GoongPlace.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'] as Map<String, dynamic>?;
    final loc = geometry?['location'] as Map<String, dynamic>?;

    return GoongPlace(
      formattedAddress: (json['formatted_address'] as String?)?.trim() ?? '',
      name: (json['name'] as String?)?.trim() ?? '',
      location: loc == null ? null : GoongLatLng.fromJson(loc),
      compound: GoongCompound.fromJson(json['compound'] as Map<String, dynamic>?),
      placeId: json['place_id'] as String?,
    );
  }
}

/// Một gợi ý của ô tìm kiếm địa chỉ.
///
/// Autocomplete **không trả toạ độ** — phải gọi tiếp `place/detail` với `placeId` mới có lat/lng.
class GoongPrediction {
  final String placeId;
  final String description;

  /// Dòng đầu in đậm trên danh sách gợi ý (tên địa điểm), rỗng thì dùng [description].
  final String mainText;

  /// Dòng phụ (phần địa chỉ còn lại).
  final String secondaryText;

  /// Autocomplete v2 CÓ trả xã/phường + tỉnh ngay trong gợi ý — đủ để điền sẵn hai ô đó mà không
  /// tốn thêm một lượt gọi `place/detail`. Chỉ toạ độ mới bắt buộc phải gọi tiếp.
  final GoongCompound compound;

  const GoongPrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
    required this.compound,
  });

  factory GoongPrediction.fromJson(Map<String, dynamic> json) {
    final structured = json['structured_formatting'] as Map<String, dynamic>?;
    final description = (json['description'] as String?)?.trim() ?? '';

    return GoongPrediction(
      placeId: json['place_id'] as String? ?? '',
      description: description,
      mainText: (structured?['main_text'] as String?)?.trim() ?? description,
      secondaryText: (structured?['secondary_text'] as String?)?.trim() ?? '',
      compound: GoongCompound.fromJson(json['compound'] as Map<String, dynamic>?),
    );
  }
}

/// Khoảng cách và thời gian đi giữa hai điểm.
class GoongDistance {
  /// Mét.
  final int meters;

  /// Giây.
  final int seconds;

  /// Chuỗi Goong đã định dạng sẵn, vd `2.39 km`.
  final String distanceText;

  /// vd `8 phút`.
  final String durationText;

  const GoongDistance({
    required this.meters,
    required this.seconds,
    required this.distanceText,
    required this.durationText,
  });

  factory GoongDistance.fromJson(Map<String, dynamic> json) {
    final distance = json['distance'] as Map<String, dynamic>?;
    final duration = json['duration'] as Map<String, dynamic>?;

    return GoongDistance(
      meters: (distance?['value'] as num?)?.toInt() ?? 0,
      seconds: (duration?['value'] as num?)?.toInt() ?? 0,
      distanceText: distance?['text'] as String? ?? '',
      durationText: duration?['text'] as String? ?? '',
    );
  }
}
