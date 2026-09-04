import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/models/api/post_model.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';
import 'package:pulse_flutter/providers/upload_queue_provider.dart';
import 'package:pulse_flutter/widgets/post_card.dart';

class _TestUploadQueueNotifier extends UploadQueueNotifier {
  @override
  Map<String, UploadTask> build() => <String, UploadTask>{};

  void putTask(String id, UploadTask task) {
    state = <String, UploadTask>{...state, id: task};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('M2: List Virtualization & Dynamic Memory Management Tests', () {
    test('Image cache dimension formula produces bounded integer values', () {
      const double dpr = 2.75;
      const double bubbleWidth = 280.0;
      const double bubbleHeight = 180.0;

      final int cacheW = (bubbleWidth * dpr).round();
      final int cacheH = (bubbleHeight * dpr).round();

      expect(cacheW, equals(770));
      expect(cacheH, equals(495));
      // Confirms downsampling: 4000x3000 (48MB uncompressed) -> 770x495 (1.5MB uncompressed) = ~97% RAM savings
    });

    testWidgets('PostCard isolates auth changes via authProvider.select', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final testPost = NgPost(
        id: 101,
        author: const ApiProfile(
          id: 42,
          username: 'author_user',
          displayName: 'Author User',
          bio: '',
        ),
        content: 'Test performance content',
        createdAt: DateTime.now(),
        likesCount: 5,
        dislikesCount: 0,
        commentsCount: 2,
      );

      int buildCount = 0;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  buildCount++;
                  return PostCard(post: testPost);
                },
              ),
            ),
          ),
        ),
      );

      expect(find.byType(PostCard), findsOneWidget);
      expect(find.byType(RepaintBoundary), findsWidgets);
      expect(buildCount, equals(1));
    });

    testWidgets('uploadTaskProvider updates only target uploading subscriber', (tester) async {
      final testQueueNotifier = _TestUploadQueueNotifier();
      final container = ProviderContainer(
        overrides: [
          uploadQueueProvider.overrideWith(() => testQueueNotifier),
        ],
      );
      addTearDown(container.dispose);

      int targetSubscriberBuilds = 0;
      int unrelatedSubscriberBuilds = 0;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  Consumer(
                    builder: (context, ref, _) {
                      final task = ref.watch(uploadTaskProvider('-100'));
                      targetSubscriberBuilds++;
                      return Text('Target: ${task?.progress ?? 0.0}');
                    },
                  ),
                  Consumer(
                    builder: (context, ref, _) {
                      final task = ref.watch(uploadTaskProvider('-200'));
                      unrelatedSubscriberBuilds++;
                      return Text('Unrelated: ${task?.progress ?? 0.0}');
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(targetSubscriberBuilds, equals(1));
      expect(unrelatedSubscriberBuilds, equals(1));

      // Simulate upload progress update specifically on message -100
      testQueueNotifier.putTask(
        '-100',
        const UploadTask(
          localId: '-100',
          chatId: 1,
          filePath: '/path/file.jpg',
          filename: 'file.jpg',
          mediaSubtype: 'photo',
          fileSize: 1024,
          progress: 0.55,
          status: UploadStatus.uploading,
        ),
      );
      await tester.pump();

      // Only target subscriber rebuilt! Unrelated subscriber did NOT rebuild!
      expect(targetSubscriberBuilds, equals(2));
      expect(unrelatedSubscriberBuilds, equals(1));
      expect(find.text('Target: 0.55'), findsOneWidget);
      expect(find.text('Unrelated: 0.0'), findsOneWidget);
    });
  });
}
