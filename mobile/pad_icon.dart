import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final imagePath = 'assets/images/logo_3547.png';
  final outPath = 'assets/images/logo_padded.png';
  
  final file = File(imagePath);
  if (!file.existsSync()) {
    print('Error: $imagePath not found.');
    return;
  }
  
  final bytes = file.readAsBytesSync();
  final image = img.decodeImage(bytes);
  if (image == null) {
    print('Error decoding image.');
    return;
  }

  // Create a new image of the same size with a transparent background
  final newImage = img.Image(width: image.width, height: image.height);
  img.fill(newImage, color: img.ColorRgba8(0, 0, 0, 0));

  // Scale the original image down to 60% of its size to add padding
  final scaleFactor = 0.6;
  final newWidth = (image.width * scaleFactor).round();
  final newHeight = (image.height * scaleFactor).round();
  final resizedOriginal = img.copyResize(image, width: newWidth, height: newHeight, interpolation: img.Interpolation.linear);

  // Paste the resized image into the center of the transparent canvas
  final dstX = (image.width - newWidth) ~/ 2;
  final dstY = (image.height - newHeight) ~/ 2;
  
  img.compositeImage(newImage, resizedOriginal, dstX: dstX, dstY: dstY);

  File(outPath).writeAsBytesSync(img.encodePng(newImage));
  print('Success: Padded image saved to $outPath');
}
