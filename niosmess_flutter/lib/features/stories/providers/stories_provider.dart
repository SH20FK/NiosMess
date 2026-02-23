import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/story.dart';
import '../../../core/repositories/api_repository.dart';
import '../../../core/session_provider.dart';
import '../../../core/utils/error_handler.dart';

/// Провайдер для Stories
final storiesProvider = StateNotifierProvider<StoriesController, StoriesState>((ref) {
  return StoriesController(ref);
});

/// Состояние Stories
class StoriesState {
  final List<Story> stories;
  final bool isLoading;
  final String? error;
  final DateTime? lastFetch;

  const StoriesState({
    this.stories = const [],
    this.isLoading = false,
    this.error,
    this.lastFetch,
  });

  StoriesState copyWith({
    List<Story>? stories,
    bool? isLoading,
    String? error,
    DateTime? lastFetch,
  }) {
    return StoriesState(
      stories: stories ?? this.stories,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastFetch: lastFetch ?? this.lastFetch,
    );
  }

  /// Получить истории, сгруппированные по пользователям
  Map<String, List<Story>> get groupedByUser {
    final map = <String, List<Story>>{};
    for (final story in stories) {
      if (!map.containsKey(story.userId)) {
        map[story.userId] = [];
      }
      map[story.userId]!.add(story);
    }
    return map;
  }

  /// Получить только непросмотренные истории
  List<Story> get unviewedStories {
    return stories.where((s) => !s.isViewed && !s.isExpired).toList();
  }

  /// Получить просмотренные истории
  List<Story> get viewedStories {
    return stories.where((s) => s.isViewed && !s.isExpired).toList();
  }
}

/// Контроллер для управления Stories
class StoriesController extends StateNotifier<StoriesState> {
  StoriesController(this.ref) : super(const StoriesState()) {
    _loadStories();
    _startAutoRefresh();
  }

  final Ref ref;
  final _api = ApiRepository();

  /// Загрузить истории
  Future<void> _loadStories() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final session = ref.read(sessionProvider);
      if (!session.isAuthed) return;

      // TODO: Заменить на реальный API эндпоинт
      // final response = await _api.getStories(
      //   username: session.username!,
      //   token: session.token!,
      // );

      // Моковые данные для демонстрации
      final mockStories = <Story>[
        Story(
          id: '1',
          userId: 'user1',
          username: 'john_doe',
          avatarUrl: null,
          media: [
            StoryMedia(
              id: 'm1',
              type: StoryMediaType.image,
              url: 'https://picsum.photos/400/600',
              text: 'Привет! 👋',
            ),
          ],
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          expiresAt: DateTime.now().add(const Duration(hours: 22)),
          viewsCount: 15,
          isViewed: false,
        ),
        Story(
          id: '2',
          userId: 'user2',
          username: 'alice_wonder',
          avatarUrl: null,
          media: [
            StoryMedia(
              id: 'm2',
              type: StoryMediaType.image,
              url: 'https://picsum.photos/400/601',
            ),
          ],
          createdAt: DateTime.now().subtract(const Duration(hours: 5)),
          expiresAt: DateTime.now().add(const Duration(hours: 19)),
          viewsCount: 42,
          isViewed: true,
        ),
      ];

      // Удалить истекшие истории
      final validStories = mockStories.where((s) => !s.isExpired).toList();

      state = state.copyWith(
        stories: validStories,
        isLoading: false,
        lastFetch: DateTime.now(),
      );
    } catch (e, stack) {
      ErrorHandler.handle(e, stackTrace: stack, context: 'LoadStories');
      state = state.copyWith(
        isLoading: false,
        error: ErrorHandler.getUserMessage(e),
      );
    }
  }

  /// Автообновление каждые 5 минут
  void _startAutoRefresh() {
    Future.delayed(const Duration(minutes: 5), () {
      if (mounted) {
        _loadStories();
        _startAutoRefresh();
      }
    });
  }

  /// Обновить истории вручную
  Future<void> refresh() => _loadStories();

  /// Отметить историю как просмотренную
  Future<void> markAsViewed(String storyId) async {
    try {
      final session = ref.read(sessionProvider);
      if (!session.isAuthed) return;

      // TODO: API вызов
      // await _api.markStoryViewed(
      //   storyId: storyId,
      //   username: session.username!,
      //   token: session.token!,
      // );

      // Обновить локальное состояние
      final updatedStories = state.stories.map((story) {
        if (story.id == storyId) {
          return story.copyWith(
            isViewed: true,
            viewedBy: [...story.viewedBy, session.username!],
            viewsCount: story.viewsCount + 1,
          );
        }
        return story;
      }).toList();

      state = state.copyWith(stories: updatedStories);
    } catch (e, stack) {
      ErrorHandler.handle(e, stackTrace: stack, context: 'MarkStoryViewed');
    }
  }

  /// Удалить свою историю
  Future<void> deleteStory(String storyId) async {
    try {
      final session = ref.read(sessionProvider);
      if (!session.isAuthed) return;

      // TODO: API вызов
      // await _api.deleteStory(
      //   storyId: storyId,
      //   username: session.username!,
      //   token: session.token!,
      // );

      final updatedStories = state.stories.where((s) => s.id != storyId).toList();
      state = state.copyWith(stories: updatedStories);
    } catch (e, stack) {
      ErrorHandler.handle(e, stackTrace: stack, context: 'DeleteStory');
      rethrow;
    }
  }

  /// Создать новую историю
  Future<void> createStory({
    required List<StoryMedia> media,
  }) async {
    try {
      final session = ref.read(sessionProvider);
      if (!session.isAuthed) return;

      // TODO: API вызов
      // final newStory = await _api.createStory(
      //   media: media,
      //   username: session.username!,
      //   token: session.token!,
      // );

      // Моковая история
      final newStory = Story(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: session.username!,
        username: session.username!,
        media: media,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
        viewsCount: 0,
      );

      state = state.copyWith(
        stories: [newStory, ...state.stories],
      );
    } catch (e, stack) {
      ErrorHandler.handle(e, stackTrace: stack, context: 'CreateStory');
      rethrow;
    }
  }
}
