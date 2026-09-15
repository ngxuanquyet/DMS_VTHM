import '../../../../core/map/goong_models.dart';

class WorkplaceLocation {
  final String id;
  final String name;
  final String mobiworkId;
  final double lat;
  final double lng;
  final int? customerTypeId;
  final int? channelId;
  final int? regionId;

  const WorkplaceLocation({
    required this.id,
    required this.name,
    required this.mobiworkId,
    required this.lat,
    required this.lng,
    this.customerTypeId = 4,
    this.channelId,
    this.regionId,
  });

  GoongLatLng get toGoongLatLng => GoongLatLng(lat, lng);
}

/// 2 địa điểm chấm công cố định theo dữ liệu hệ thống
const List<WorkplaceLocation> kFixedWorkplaces = [
  WorkplaceLocation(
    id: 'showroom_242_vcc',
    name: 'SHOWROOM 242 VCC',
    mobiworkId: '6a8e6566731674f46f5f89a8',
    lat: 21.0638493,
    lng: 105.8052796,
    customerTypeId: 4,
    channelId: 14,
    regionId: 3,
  ),
  WorkplaceLocation(
    id: 'nha_may_vvp',
    name: 'Nhà Máy VVP',
    mobiworkId: '68bf8446bd53dc546ca1ab',
    lat: 21.3951522,
    lng: 105.5928053,
    customerTypeId: 4,
    channelId: 15,
    regionId: 62,
  ),
];
