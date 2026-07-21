import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/utils/vietnamese_text_utils.dart';

void main() {
  test('removes all lowercase Vietnamese diacritics', () {
    expect(
      removeVietnameseDiacritics(
        'àáạảã âầấậẩẫ ăằắặẳẵ '
        'èéẹẻẽ êềếệểễ ìíịỉĩ '
        'òóọỏõ ôồốộổỗ ơờớợởỡ '
        'ùúụủũ ưừứựửữ ỳýỵỷỹ đ',
      ),
      'aaaaa aaaaaa aaaaaa '
      'eeeee eeeeee iiiii '
      'ooooo oooooo oooooo '
      'uuuuu uuuuuu yyyyy d',
    );
  });

  test('removes all uppercase Vietnamese diacritics', () {
    expect(
      removeVietnameseDiacritics(
        'ÀÁẠẢÃ ÂẦẤẬẨẪ ĂẰẮẶẲẴ '
        'ÈÉẸẺẼ ÊỀẾỆỂỄ ÌÍỊỈĨ '
        'ÒÓỌỎÕ ÔỒỐỘỔỖ ƠỜỚỢỞỠ '
        'ÙÚỤỦŨ ƯỪỨỰỬỮ ỲÝỴỶỸ Đ',
      ),
      'AAAAA AAAAAA AAAAAA '
      'EEEEE EEEEEE IIIII '
      'OOOOO OOOOOO OOOOOO '
      'UUUUU UUUUUU YYYYY D',
    );
  });

  test('preserves whitespace, punctuation, casing, and word structure', () {
    expect(
      removeVietnameseDiacritics('Đà Nẵng - Thành phố Hồ Chí Minh!'),
      'Da Nang - Thanh pho Ho Chi Minh!',
    );
  });
}
