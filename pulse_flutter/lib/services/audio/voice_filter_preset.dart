/// Voice effect presets shared across voice messages and calls.
enum VoiceFilterPreset {
  none('none', 'Обычный', 'Без эффекта'),
  robot('robot', 'Робот', 'Металлический вокодер'),
  radio('radio', 'Рация', 'Эффект мегафона и радио'),
  deep('deep', 'Демон', 'Глубокий низкий голос'),
  helium('helium', 'Бурундук', 'Высокий мультяшный голос'),
  echo('echo', 'Эхо', 'Эффект большого зала'),
  anonymous('anonymous', 'Анонимус', 'Искажение тембра');

  const VoiceFilterPreset(this.id, this.title, this.subtitle);

  final String id;
  final String title;
  final String subtitle;

  static VoiceFilterPreset fromId(String? raw) {
    if (raw == null || raw.isEmpty) return VoiceFilterPreset.none;
    for (final preset in VoiceFilterPreset.values) {
      if (preset.id == raw) return preset;
    }
    return VoiceFilterPreset.none;
  }
}
