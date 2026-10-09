import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/network/api_client.dart';
import 'package:vthm_dms/features/forms/data/models/form_photo_model.dart';
import 'package:vthm_dms/features/forms/data/models/market_form_model.dart';
import 'package:vthm_dms/features/forms/data/models/market_form_submission_model.dart';
import 'package:vthm_dms/features/forms/data/services/forms_api_service.dart';
import 'package:vthm_dms/features/forms/domain/entities/market_form_entity.dart';
import 'package:vthm_dms/features/forms/presentation/widgets/dynamic_renderer/market_form_renderer.dart';

class FakeApiClient implements ApiClient {
  dynamic postMultipartResponse;
  String? lastMultipartPath;
  FormData? lastFormData;

  @override
  Future<dynamic> postMultipart(
    String path, {
    required FormData formData,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    lastMultipartPath = path;
    lastFormData = formData;
    return postMultipartResponse;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('§1. Nhận diện ô ảnh trong schema & Bẫy parse config', () {
    test('Parse an toàn khi config là mảng rỗng [] (Bẫy PHP serialize)', () {
      final json = {
        'type': 'field',
        'ref': 'dms_test_cc_anh_bien_hieu',
        'required': false,
        'col_span': 12,
        'resolved': {
          'code': 'dms_test_cc_anh_bien_hieu',
          'label': 'Ảnh biển hiệu',
          'input_type': 'image',
          'config': [], // Mảng rỗng PHP
          'description': null,
          'show_in_list': false,
        }
      };

      final block = MarketFormBlockModel.fromJson(json).toEntity();

      expect(block.isImage, isTrue);
      expect(block.resolved.code, 'dms_test_cc_anh_bien_hieu');
      expect(block.resolved.label, 'Ảnh biển hiệu');
      expect(block.resolved.inputType, 'image');
      // Vắng mặt max_files hoặc config rỗng [] => mặc định 10 theo cấu hình hệ thống
      expect(block.resolved.maxFiles, 10);
    });

    test('Admin tường minh khai max_files = 1 thì nhận đúng 1', () {
      final json = {
        'type': 'field',
        'ref': 'dms_anh_bien_hieu',
        'required': false,
        'col_span': 12,
        'resolved': {
          'code': 'dms_anh_bien_hieu',
          'label': 'Ảnh biển hiệu',
          'input_type': 'image',
          'config': {'max_files': 1},
        }
      };

      final block = MarketFormBlockModel.fromJson(json).toEntity();
      expect(block.resolved.maxFiles, 1);
    });

    test('max_files <= 0 hoặc âm hiểu là 1', () {
      final json = {
        'type': 'field',
        'ref': 'dms_anh_ke',
        'required': true,
        'col_span': 12,
        'resolved': {
          'code': 'dms_anh_ke',
          'label': 'Ảnh kệ',
          'input_type': 'image',
          'config': {'max_files': 0},
        }
      };

      final block = MarketFormBlockModel.fromJson(json).toEntity();
      expect(block.resolved.maxFiles, 1);

      final jsonNegative = {
        'type': 'field',
        'ref': 'dms_anh_ke',
        'required': true,
        'col_span': 12,
        'resolved': {
          'code': 'dms_anh_ke',
          'label': 'Ảnh kệ',
          'input_type': 'image',
          'config': {'max_files': -5},
        }
      };

      final blockNeg = MarketFormBlockModel.fromJson(jsonNegative).toEntity();
      expect(blockNeg.resolved.maxFiles, 1);
    });

    test('Tự kẹp trần max_files xuống 10 khi admin khai vượt mức (ví dụ 20)', () {
      final json = {
        'type': 'field',
        'ref': 'dms_anh_ke',
        'required': true,
        'col_span': 12,
        'resolved': {
          'code': 'dms_anh_ke',
          'label': 'Ảnh kệ hàng',
          'input_type': 'image',
          'config': {'max_files': 20},
        }
      };

      final block = MarketFormBlockModel.fromJson(json).toEntity();
      expect(block.resolved.maxFiles, 10);
    });

    test('Nhận đúng max_files hợp lệ (ví dụ 5)', () {
      final json = {
        'type': 'field',
        'ref': 'dms_anh_ke',
        'required': true,
        'col_span': 12,
        'resolved': {
          'code': 'dms_anh_ke',
          'label': 'Ảnh kệ hàng',
          'input_type': 'image',
          'config': {'max_files': 5},
        }
      };

      final block = MarketFormBlockModel.fromJson(json).toEntity();
      expect(block.resolved.maxFiles, 5);
    });

    test('Parse max_files ở cấp resolved (bên ngoài config)', () {
      final json = {
        'type': 'field',
        'ref': 'dms_anh_bien_hieu',
        'required': false,
        'col_span': 12,
        'resolved': {
          'code': 'dms_anh_bien_hieu',
          'label': 'Ảnh biển hiệu',
          'input_type': 'image',
          'max_files': 10,
          'config': [],
        }
      };

      final block = MarketFormBlockModel.fromJson(json).toEntity();
      expect(block.resolved.maxFiles, 10);
    });

    test('Parse max_files ở cấp block', () {
      final json = {
        'type': 'field',
        'ref': 'dms_anh_bien_hieu',
        'required': false,
        'col_span': 12,
        'max_files': 10,
        'resolved': {
          'code': 'dms_anh_bien_hieu',
          'label': 'Ảnh biển hiệu',
          'input_type': 'image',
          'config': [],
        }
      };

      final block = MarketFormBlockModel.fromJson(json).toEntity();
      expect(block.resolved.maxFiles, 10);
    });

    test('Parse max_files khi config là chuỗi JSON', () {
      final json = {
        'type': 'field',
        'ref': 'dms_anh_bien_hieu',
        'required': false,
        'col_span': 12,
        'resolved': {
          'code': 'dms_anh_bien_hieu',
          'label': 'Ảnh biển hiệu',
          'input_type': 'image',
          'config': '{"max_files": 10}',
        }
      };

      final block = MarketFormBlockModel.fromJson(json).toEntity();
      expect(block.resolved.maxFiles, 10);
    });

    test('Parse max_photos hoặc max trong validation', () {
      final json = {
        'type': 'field',
        'ref': 'dms_anh_bien_hieu',
        'required': false,
        'col_span': 12,
        'resolved': {
          'code': 'dms_anh_bien_hieu',
          'label': 'Ảnh biển hiệu',
          'input_type': 'image',
          'config': {
            'validation': {'max': 10}
          },
        }
      };

      final block = MarketFormBlockModel.fromJson(json).toEntity();
      expect(block.resolved.maxFiles, 10);
    });
  });

  group('§2. Tải ảnh lên — POST /dms/form-photos', () {
    test('FormPhotoModel parse phản hồi 201 Created chính xác', () {
      final responseData = {
        'token': 'b83a1130671e0b1f5b75592494186ea5',
        'name': 'bien-hieu.png',
        'ext': 'png',
        'size': 70,
        'mime': 'image/png',
        'url': '/dms/form-photos/public/b83a1130671e0b1f5b75592494186ea5',
      };

      final model = FormPhotoModel.fromJson(responseData);
      expect(model.token, 'b83a1130671e0b1f5b75592494186ea5');
      expect(model.token.length, 32);
      expect(model.name, 'bien-hieu.png');
      expect(model.ext, 'png');
      expect(model.size, 70);
      expect(model.mime, 'image/png');
      expect(model.url, '/dms/form-photos/public/b83a1130671e0b1f5b75592494186ea5');
      expect(
        model.fullUrl,
        'https://api-app.vthmgroup.vn/dms/form-photos/public/b83a1130671e0b1f5b75592494186ea5',
      );
    });

    test('FormsApiService.uploadPhoto gọi postMultipart với endpoint /dms/form-photos', () async {
      final fakeClient = FakeApiClient();
      final apiService = FormsApiService(fakeClient);

      fakeClient.postMultipartResponse = {
        'success': true,
        'message': 'Đã tải tệp lên.',
        'data': {
          'token': 'b83a1130671e0b1f5b75592494186ea5',
          'name': 'test.png',
          'ext': 'png',
          'size': 1024,
          'mime': 'image/png',
          'url': '/dms/form-photos/public/b83a1130671e0b1f5b75592494186ea5',
        }
      };

      // Tạo file tạm để test
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/test_upload.png');
      await tempFile.writeAsBytes([1, 2, 3, 4]);

      try {
        final res = await apiService.uploadPhoto(tempFile);
        expect(res.token, 'b83a1130671e0b1f5b75592494186ea5');
        expect(res.url, contains('/dms/form-photos/public/'));
        expect(fakeClient.lastMultipartPath, '/dms/form-photos');
        expect(fakeClient.lastFormData, isNotNull);
      } finally {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    });
  });

  group('§3. Nộp phiếu — Giá trị ô ảnh là MẢNG TOKEN & Duplicate handling', () {
    test('LUÔN gửi mảng token, kể cả khi ô chỉ cho 1 ảnh; ô không điền thì bỏ hẳn khoá', () {
      final raw = {
        'dms_so_ke': 3,
        'dms_test_cc_anh_bien_hieu': ['b83a1130671e0b1f5b75592494186ea5'],
        'anh_chua_chup': [],
        'anh_string_don': 'c72b1130671e0b1f5b75592494186ea6', // Truyền nhầm chuỗi đơn
      };

      final sanitized = MarketFormSubmissionModel.sanitizeAnswers(
        raw,
        imageCodes: {'dms_test_cc_anh_bien_hieu', 'anh_chua_chup', 'anh_string_don'},
      );

      // Ô số kệ giữ nguyên
      expect(sanitized['dms_so_ke'], 3);
      // Ô ảnh có 1 token là mảng 1 phần tử
      expect(sanitized['dms_test_cc_anh_bien_hieu'], ['b83a1130671e0b1f5b75592494186ea5']);
      expect(sanitized['dms_test_cc_anh_bien_hieu'], isA<List>());
      // Ô ảnh rỗng bị BỎ HẲN KHOÁ
      expect(sanitized.containsKey('anh_chua_chup'), isFalse);
      // Chuỗi đơn cho ô ảnh được tự động bọc thành mảng
      expect(sanitized['anh_string_don'], ['c72b1130671e0b1f5b75592494186ea6']);
      expect(sanitized['anh_string_don'], isA<List>());
    });

    test('client_uuid là UUID v4 hợp lệ', () {
      final submission = MarketFormSubmissionModel(
        configId: 435,
        answers: {
          'dms_test_cc_anh_bien_hieu': ['b83a1130671e0b1f5b75592494186ea5']
        },
      );

      final json = submission.toJson();
      final clientUuid = json['client_uuid'] as String;
      // UUID v4 format regex
      final uuidRegex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          caseSensitive: false);
      expect(uuidRegex.hasMatch(clientUuid), isTrue);
    });

    test('Hiểu duplicate: true là thành công (§3 & §9)', () {
      final duplicateResponse = {
        'success': true,
        'message': 'Phiếu này đã được ghi nhận trước đó, không thêm gì thêm.',
        'data': {
          'id': 952,
          'duplicate': true,
        }
      };

      final result = MarketFormSubmitResult.fromJson(duplicateResponse);
      expect(result.success, isTrue);
      expect(result.submissionId, 952);
      expect(result.isDuplicate, isTrue);
    });
  });

  group('§4.3 & §9. Xem lại ảnh của phiếu đã nộp & Phát hiện ảnh đã mất', () {
    test('Xử lý answer_photos và phát hiện token thiếu báo "ảnh không còn trên hệ thống"', () {
      final submissionJson = {
        'id': 950,
        'config_id': 435,
        'answers': {
          'dms_test_cc_anh_bien_hieu': ['token_con_ton_tai', 'token_da_bi_xoa'],
        },
        'answer_photos': {
          'token_con_ton_tai': '/dms/form-photos/public/token_con_ton_tai',
          // 'token_da_bi_xoa' vắng mặt trong answer_photos
        },
        'created_at': '2026-10-09 08:30:00',
      };

      final detail = MarketFormSubmissionDetailModel.fromJson(submissionJson);

      expect(detail.id, 950);
      expect(detail.getPhotoUrl('token_con_ton_tai'), '/dms/form-photos/public/token_con_ton_tai');
      expect(detail.isPhotoMissing('token_con_ton_tai'), isFalse);

      // Token đã bị xóa / dọn rác
      expect(detail.getPhotoUrl('token_da_bi_xoa'), isNull);
      expect(detail.isPhotoMissing('token_da_bi_xoa'), isTrue);
    });
  });

  group('§5. Hàng đợi ngoại tuyến — Lưu trữ đường dẫn ảnh cục bộ', () {
    test('MarketFormSubmissionModel lưu và nạp _local_photo_paths an toàn', () {
      final submission = MarketFormSubmissionModel(
        configId: 435,
        answers: {
          'dms_test_cc_anh_bien_hieu': ['b83a1130671e0b1f5b75592494186ea5']
        },
        localPhotoPaths: {
          'dms_test_cc_anh_bien_hieu': ['/data/user/0/app/cache/photo_1.jpg']
        },
      );

      // Khi gửi API thông thường (includeInternal = false): KHÔNG gửi _local_photo_paths
      final apiJson = submission.toJson(includeInternal: false);
      expect(apiJson.containsKey('_local_photo_paths'), isFalse);

      // Khi lưu vào SQLite offline sync queue (includeInternal = true): LƯU _local_photo_paths
      final offlineJson = submission.toJson(includeInternal: true);
      expect(offlineJson.containsKey('_local_photo_paths'), isTrue);
      expect(offlineJson['_local_photo_paths']['dms_test_cc_anh_bien_hieu'],
          ['/data/user/0/app/cache/photo_1.jpg']);

      // Nạp lại từ offline queue
      final restored = MarketFormSubmissionModel.fromJson(offlineJson);
      expect(restored.localPhotoPaths?['dms_test_cc_anh_bien_hieu'],
          ['/data/user/0/app/cache/photo_1.jpg']);
    });
  });

  group('§9. Widget máy ảnh trong MarketFormRenderer', () {
    final blocks = [
      const MarketFormBlockEntity(
        ref: 'dms_test_cc_anh_bien_hieu',
        type: 'field',
        required: true, // BẮT BUỘC
        colSpan: 12,
        resolved: MarketFormResolvedEntity(
          code: 'dms_test_cc_anh_bien_hieu',
          label: 'Ảnh biển hiệu',
          inputType: 'image',
          maxFiles: 3,
        ),
      ),
    ];

    testWidgets('Vẽ widget ô ảnh với nhãn, số lượng ảnh (0/3), và nút Chụp ảnh', (tester) async {
      final key = GlobalKey<MarketFormRendererState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MarketFormRenderer(
                key: key,
                blocks: blocks,
              ),
            ),
          ),
        ),
      );

      // Verify Label hiển thị
      expect(find.textContaining('Ảnh biển hiệu'), findsOneWidget);
      // Verify hiển thị số lượng "0/3 ảnh"
      expect(find.text('0/3 ảnh'), findsOneWidget);
      // Verify nút Chụp ảnh xuất hiện
      expect(find.textContaining('Chụp ảnh'), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);
    });

    testWidgets('Kiểm tra bắt buộc (required) cho ô ảnh: Chưa có ảnh nào thì chặn nộp', (tester) async {
      final key = GlobalKey<MarketFormRendererState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MarketFormRenderer(
                key: key,
                blocks: blocks,
              ),
            ),
          ),
        ),
      );

      final answers = key.currentState?.validateAndGetAnswers();
      await tester.pump();

      // Bị lỗi vì ô ảnh là bắt buộc nhưng chưa có ảnh nào
      expect(answers, isNull);
      expect(find.text('Ảnh biển hiệu không được để trống.'), findsOneWidget);
    });

    testWidgets('Khi đã có ảnh tải lên, validate trả về mảng token ["token_1"] và bỏ qua lỗi', (tester) async {
      final key = GlobalKey<MarketFormRendererState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MarketFormRenderer(
                key: key,
                blocks: blocks,
                initialAnswers: const {
                  'dms_test_cc_anh_bien_hieu': ['b83a1130671e0b1f5b75592494186ea5'],
                },
              ),
            ),
          ),
        ),
      );

      final answers = key.currentState?.validateAndGetAnswers();
      await tester.pump();

      expect(answers, isNotNull);
      expect(answers!['dms_test_cc_anh_bien_hieu'], ['b83a1130671e0b1f5b75592494186ea5']);
      expect(answers['dms_test_cc_anh_bien_hieu'], isA<List>());
      expect(find.text('1/3 ảnh'), findsOneWidget);
    });

    testWidgets('Khi schema có config: [] (không có max_files), UI hiển thị "0/10 ảnh" theo cấu hình hệ thống', (tester) async {
      final defaultBlocks = [
        MarketFormBlockModel.fromJson({
          'type': 'field',
          'ref': 'dms_anh_mat_dinh',
          'required': false,
          'col_span': 12,
          'resolved': {
            'code': 'dms_anh_mat_dinh',
            'label': 'Ảnh mặc định',
            'input_type': 'image',
            'config': [],
          }
        }).toEntity(),
      ];

      final key = GlobalKey<MarketFormRendererState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MarketFormRenderer(
                key: key,
                blocks: defaultBlocks,
              ),
            ),
          ),
        ),
      );

      // Verify UI hiển thị "0/10 ảnh" thay vì "0/1 ảnh"
      expect(find.text('0/10 ảnh'), findsOneWidget);
    });
  });
}
