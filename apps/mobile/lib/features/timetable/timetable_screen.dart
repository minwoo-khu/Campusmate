import 'package:flutter/material.dart';

class TimetableScreen extends StatelessWidget {
  const TimetableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Timetable',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              child: SizedBox(
                height: 260,
                width: double.infinity,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.image_outlined, size: 44),
                      SizedBox(height: 8),
                      Text('No timetable image yet'),
                      SizedBox(height: 4),
                      Text('Upload an image to display here'),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('이미지 업로드 기능은 다음 단계에서 추가!'),
                    ),
                  );
                },
                icon: const Icon(Icons.upload),
                label: const Text('Upload timetable image'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('편집 기능은 2차에 추가 예정'),
                    ),
                  );
                },
                icon: const Icon(Icons.edit),
                label: const Text('Edit (coming soon)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
