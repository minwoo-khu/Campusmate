import 'package:flutter/material.dart';

class CourseScreen extends StatelessWidget {
  const CourseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final courses = const [
      _Course(
        name: '운영체제',
        note: 'PDF 업로드 → 요약/퀴즈 (2차)',
      ),
      _Course(
        name: '컴퓨터네트워크',
        note: '강의자료 정리/퀴즈 생성 (2차)',
      ),
      _Course(
        name: '소프트웨어공학',
        note: '과제/일정 연동 (추후)',
      ),
    ];

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Courses',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: courses.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final c = courses[i];
                  return ListTile(
                    leading: const Icon(Icons.menu_book),
                    title: Text(c.name),
                    subtitle: Text(c.note),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CourseDetailScreen(courseName: c.name),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('강의 추가 기능은 2차에서!')),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Add course (coming soon)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CourseDetailScreen extends StatelessWidget {
  final String courseName;
  const CourseDetailScreen({super.key, required this.courseName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(courseName)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Materials',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // 자료 리스트(더미)
            const _MaterialCard(
              title: 'Week 1 - Intro.pdf',
              status: 'ready',
            ),
            const _MaterialCard(
              title: 'Week 2 - Process.pdf',
              status: 'processing (coming soon)',
            ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PDF 업로드는 2차에서 연결!')),
                  );
                },
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload PDF (coming soon)'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('요약/퀴즈는 2차에서 연결!')),
                  );
                },
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generate summary & quiz (coming soon)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaterialCard extends StatelessWidget {
  final String title;
  final String status;
  const _MaterialCard({required this.title, required this.status});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.picture_as_pdf),
        title: Text(title),
        subtitle: Text(status),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('상세 뷰는 2차에서!')),
          );
        },
      ),
    );
  }
}

class _Course {
  final String name;
  final String note;
  const _Course({required this.name, required this.note});
}
