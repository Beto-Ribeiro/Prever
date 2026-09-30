import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Logo renderiza o símbolo e as letras no Flutter', () async {
    final picture = await vg.loadPicture(
      const SvgAssetLoader('gfx/svg/Image/Prever_logo.svg'), null,
    );
    final image = await picture.picture.toImage(300, 197);
    final pixels = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    int pixelsVisiveis(int inicio, int fim) {
      var total = 0;
      for (var y = inicio; y < fim; y++) {
        for (var x = 0; x < 300; x++) {
          if (pixels.getUint8((y * 300 + x) * 4 + 3) > 30) total++;
        }
      }
      return total;
    }
    expect(pixelsVisiveis(0, 135), greaterThan(500));
    expect(pixelsVisiveis(150, 197), greaterThan(500));
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('build').create(recursive: true);
    await File('build/prever_logo_preview.png').writeAsBytes(png!.buffer.asUint8List());
    image.dispose();
    picture.picture.dispose();
  });
}
