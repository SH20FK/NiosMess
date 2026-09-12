import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/utils/file_type_detector.dart';

void main() {
  group('Shared Media Classification & Filtering', () {
    test('Pure images are correctly identified', () {
      expect(
        FileTypeDetector.isPureImage(
          mediaType: 'image/png',
          msgType: 'image',
          fileName: 'photo.png',
          url: 'https://example.com/photo.png',
        ),
        isTrue,
      );

      expect(
        FileTypeDetector.isPureImage(
          mediaType: '',
          msgType: 'file',
          fileName: 'vacation.jpg',
          url: 'https://example.com/vacation.jpg',
        ),
        isTrue,
      );

      expect(
        FileTypeDetector.isPureImage(
          mediaType: '',
          msgType: 'media',
          fileName: 'artwork.webp',
          url: 'https://example.com/artwork.webp',
        ),
        isTrue,
      );
    });

    test('Pure videos are correctly identified', () {
      expect(
        FileTypeDetector.isPureVideo(
          mediaType: 'video/mp4',
          msgType: 'video',
          fileName: 'clip.mp4',
          url: 'https://example.com/clip.mp4',
        ),
        isTrue,
      );

      expect(
        FileTypeDetector.isPureVideo(
          mediaType: '',
          msgType: 'file',
          fileName: 'screencast.mov',
          url: 'https://example.com/screencast.mov',
        ),
        isTrue,
      );
    });

    test('Executable and non-media files are strictly rejected from media tab', () {
      // EXE files must NEVER be classified as pure images or videos
      expect(
        FileTypeDetector.isPureImage(
          mediaType: 'application/x-msdownload',
          msgType: 'file',
          fileName: 'setup.exe',
          url: 'https://example.com/setup.exe',
        ),
        isFalse,
      );
      expect(
        FileTypeDetector.isPureVideo(
          mediaType: 'application/x-msdownload',
          msgType: 'file',
          fileName: 'setup.exe',
          url: 'https://example.com/setup.exe',
        ),
        isFalse,
      );

      // MSI installer
      expect(
        FileTypeDetector.isPureImage(
          mediaType: 'application/x-msi',
          msgType: 'file',
          fileName: 'installer.msi',
          url: 'https://example.com/installer.msi',
        ),
        isFalse,
      );

      // Archives
      expect(
        FileTypeDetector.isPureImage(
          mediaType: 'application/zip',
          msgType: 'file',
          fileName: 'archive.zip',
          url: 'https://example.com/archive.zip',
        ),
        isFalse,
      );

      // Documents (PDF, DOCX, MD)
      expect(
        FileTypeDetector.isPureImage(
          mediaType: 'application/pdf',
          msgType: 'document',
          fileName: 'contract.pdf',
          url: 'https://example.com/contract.pdf',
        ),
        isFalse,
      );
      expect(
        FileTypeDetector.isPureImage(
          mediaType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          msgType: 'document',
          fileName: 'resume.docx',
          url: 'https://example.com/resume.docx',
        ),
        isFalse,
      );
    });

    test('FileTypeDetector correctly classifies exe as executable and not previewable media', () {
      final exeInfo = FileTypeDetector.detectFromFileName('game.exe');
      expect(exeInfo.isExe, isTrue);
      expect(exeInfo.isExecutable, isTrue);
      expect(exeInfo.isImage, isFalse);
      expect(exeInfo.isVideo, isFalse);
      expect(exeInfo.category, FileTypeCategory.exe);

      final docxInfo = FileTypeDetector.detectFromFileName('project.docx');
      expect(docxInfo.isDocument, isTrue);
      expect(docxInfo.category, FileTypeCategory.document);
      expect(docxInfo.canPreview, isTrue);

      final mdInfo = FileTypeDetector.detectFromFileName('README.md');
      expect(mdInfo.category, FileTypeCategory.text);
      expect(mdInfo.canPreview, isTrue);
    });
  });
}
