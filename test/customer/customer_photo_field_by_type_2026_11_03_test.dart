import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/dynamic_form/matrix_photo_key.dart';
import 'package:vthm_dms/core/dynamic_form/models/dynamic_form_field.dart';
import 'package:vthm_dms/features/customer/data/utils/customer_payload_helper.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_meta_entity.dart';
import 'package:vthm_dms/features/customer/presentation/screens/add_customer_screen.dart';

/// Ô ảnh của form điểm bán nhận theo LOẠI Ô server gửi (`input_type: image`), không đoán theo mã ô (03/11/2026): mã
/// tiếng Việt không dấu như `doanh_so_…`, `san_sang_danh_…`, `hoan_thanh_…` chứa chuỗi "anh_" từng bị vẽ thành ô chụp ảnh,
/// và lúc Lưu giá trị của chúng bị đem đi tải lên như ảnh.
void main() {
  const routes = [DynamicFormOption(label: 'Tuyến A', value: 5)];

  final schema = {
    'data': {
      'fields': [
        {'code': 'name', 'label': 'Tên điểm bán', 'input_type': 'text', 'kind': 'fixed', 'required': true},
        {'code': 'photo_file_id', 'label': 'Ảnh điểm bán', 'input_type': 'image', 'kind': 'fixed', 'max_files': 5},
        {'code': 'doanh_so_gach_uoc_tinh_trd_thang', 'label': 'Doanh số gạch ước tính', 'input_type': 'currency', 'kind': 'dynamic'},
        {'code': 'san_sang_danh_cho_vthm_so_mat', 'label': 'Sẵn sàng dành cho VTHM', 'input_type': 'number', 'kind': 'dynamic'},
        {'code': 'danh_gia_tiem_nang', 'label': 'Đánh giá tiềm năng', 'input_type': 'text', 'kind': 'dynamic'},
        {'code': 'hoan_thanh_truoc', 'label': 'Hoàn thành trước', 'input_type': 'date', 'kind': 'dynamic'},
        {'code': 'anh_quay_ke', 'label': 'Ảnh quầy kệ', 'input_type': 'image', 'kind': 'dynamic', 'max_files': 3},
      ],
    },
  };

  test('ô số / chữ / ngày có mã chứa "anh_" giữ đúng loại; ô ảnh vẫn là ô ảnh', () {
    final f = buildCustomerFormFields(schema, meta: const CustomerMetaData(), routeOptions: routes, defaultRouteId: 5);
    DynamicFormFieldType typeOf(String code) => f.firstWhere((x) => x.code == code).type;

    expect(typeOf('doanh_so_gach_uoc_tinh_trd_thang'), DynamicFormFieldType.number);
    expect(typeOf('san_sang_danh_cho_vthm_so_mat'), DynamicFormFieldType.number);
    expect(typeOf('danh_gia_tiem_nang'), DynamicFormFieldType.text);
    expect(typeOf('hoan_thanh_truoc'), DynamicFormFieldType.date);
    expect(typeOf('photo_file_id'), DynamicFormFieldType.photo);
    expect(typeOf('anh_quay_ke'), DynamicFormFieldType.photo);
  });

  test('ảnh ô chụp ảnh tự khai nhận theo ĐƯỜNG DẪN ẢNH, không đoán theo mã ô (#24792)', () async {
    final uploaded = <String>[];
    Future<String?> up(String p) async {
      uploaded.add(p);
      return 'e' * 32;
    }

    expect(await resolveLocalPhotos(1500000, up), 1500000);
    expect(await resolveLocalPhotos('Tốt', up), 'Tốt');
    expect(await resolveLocalPhotos(['a', 'b'], up), ['a', 'b']);
    expect(await resolveLocalPhotos(['/data/x/anh.jpg', 'd' * 32, '/crm/customer-photos/public/${'c' * 32}'], up),
        ['e' * 32, 'd' * 32, 'c' * 32]);
    expect(uploaded, ['/data/x/anh.jpg']);
    expect(
      CustomerPayloadHelper.dynamicLocalPhotoPaths({
        'anh_quay_ke': ['/data/x/a.jpg'],
        'doanh_so': '/khong-phai-anh',
        'photo_tokens': ['/data/x/mat_tien.jpg'], // ảnh mặt tiền — khoá cố định, xử lý riêng
        'data': {'k': 'file:///b.png'},
      }),
      ['/data/x/a.jpg', 'file:///b.png'],
    );
  });
}
