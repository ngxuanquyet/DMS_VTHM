import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/widgets/note_field_widget.dart';

/// Luật nhận diện HTML trình soạn — PHẢI khớp server (RichTextHelper::EDITOR_HTML_RE) và SPA (lib/richtext.ts), #24753.
void main() {
  test('thẻ của trình soạn là HTML', () {
    for (final s in ['<p>a</p>', '<P>a</P>', 'x<br/>y', '<img data-token="abc">', '<a href="https://x">l</a>', '<p x=1>a</p>']) {
      expect(NoteFieldWidget.looksLikeHtml(s), isTrue, reason: s);
    }
  });

  test('chữ thường có dấu < > KHÔNG phải HTML', () {
    for (final s in ['Nhập theo mẫu <Họ tên> - <SĐT>', '<Sữa tươi 180ml>', '<b 2 thùng>', 'a < b & c > d', '<abc>', '<p x=1>a']) {
      expect(NoteFieldWidget.looksLikeHtml(s), isFalse, reason: s);
    }
  });
}
