import 'pasted_image.dart';

void Function() listenForImagePaste({
  required bool Function() canHandle,
  required void Function(List<PastedImage>) onImages,
  required void Function(Object) onError,
}) => () {};
