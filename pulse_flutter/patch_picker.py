import re

with open(r"E:\Niosmess V2\pulse_flutter\lib\screens\profile_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace("import 'package:image_picker/image_picker.dart';", "import 'package:file_picker/file_picker.dart';")

old_upload = """    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (image == null) return;

    if (!mounted) return;
    setState(() => _uploadingAvatar = true);

    try {
      final List<int> bytes = await image.readAsBytes();
      await ref.read(authRepositoryProvider).uploadAvatar(bytes);"""

new_upload = """    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    if (!mounted) return;
    setState(() => _uploadingAvatar = true);

    try {
      final PlatformFile file = result.files.first;
      await ref.read(authRepositoryProvider).uploadAvatar(file.name, file.bytes!);"""

content = content.replace(old_upload, new_upload)

content = content.replace("context.l10n.profileAvatarUpdated", "'Avatar updated'")
content = content.replace("context.l10n.profileAvatarError('$e')", "'Error: $e'")
content = content.replace("context.l10n.profileSettingsTitle", "'Settings'")
content = content.replace("context.l10n.settingsAppearanceTitle", "'Appearance'")
content = content.replace("context.l10n.settingsAppearanceSubtitle", "'Theme, colors'")
content = content.replace("context.l10n.settingsLanguageTitle", "'Language'")
content = content.replace("context.l10n.settingsLanguageSubtitle", "'App language'")
content = content.replace("name: nameController.text.trim(),", "displayName: nameController.text.trim(),")
content = content.replace("context.l10n.commonError('$e')", "'Error: $e'")
content = content.replace("context.l10n.profileEditTitle", "'Edit Profile'")

with open(r"E:\Niosmess V2\pulse_flutter\lib\screens\profile_screen.dart", "w", encoding="utf-8") as f:
    f.write(content)
