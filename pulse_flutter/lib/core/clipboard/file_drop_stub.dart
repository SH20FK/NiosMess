import 'package:flutter/painting.dart';
import 'pasted_image.dart';

void Function() listenForFileDrop({
  required Rect? Function() bounds,
  required bool Function() canHandle,
  required void Function(bool) onHover,
  required void Function(List<PastedImage>) onFiles,
  required void Function(Object) onError,
}) => () {};
