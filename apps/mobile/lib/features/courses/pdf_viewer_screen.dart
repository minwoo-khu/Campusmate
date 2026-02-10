import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:pdfx/pdfx.dart';

class PdfViewerScreen extends StatefulWidget {
  final int materialKey; // CourseMaterial Hive key
  final String filePath; // localPath
  final String fileName; // 표시용

  const PdfViewerScreen({
    super.key,
    required this.materialKey,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late final PdfControllerPinch _controller;

  int _currentPage = 1;
  int _pageCount = 0;

  String _noteKey() => 'm:${widget.materialKey}';
  String _pageMemoKey() => 'm:${widget.materialKey}:pages'; // JSON map page -> {text,tags}

  static const List<String> _presetTags = ['시험', '중요', '암기', '과제', '질문'];

  @override
  void initState() {
    super.initState();
    _controller = PdfControllerPinch(
      document: PdfDocument.openFile(widget.filePath),
    );
    _initDoc();
  }

  Future<void> _initDoc() async {
    try {
      final doc = await PdfDocument.openFile(widget.filePath);
      setState(() => _pageCount = doc.pagesCount);
      await doc.close();
    } catch (_) {
      // ignore
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ====== Page memo data helpers ======
  Map<int, _PageMemoData> _loadPageMemos() {
    final box = Hive.box<String>('material_page_memos');
    final raw = box.get(_pageMemoKey());
    if (raw == null || raw.trim().isEmpty) return {};

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final out = <int, _PageMemoData>{};

      for (final e in map.entries) {
        final p = int.tryParse(e.key);
        if (p == null) continue;

        final v = e.value;

        // ✅ 구버전 호환: {"3":"텍스트"}
        if (v is String) {
          final text = v.trim();
          if (text.isNotEmpty) out[p] = _PageMemoData(text: text, tags: const []);
          continue;
        }

        // ✅ 신버전: {"3":{"text":"...","tags":["시험"]}}
        if (v is Map) {
          final text = (v['text'] is String) ? (v['text'] as String).trim() : '';
          final tagsRaw = v['tags'];
          final tags = <String>[];

          if (tagsRaw is List) {
            for (final t in tagsRaw) {
              if (t is String) {
                final tt = t.trim();
                if (tt.isNotEmpty) tags.add(tt);
              }
            }
          }

          if (text.isNotEmpty || tags.isNotEmpty) {
            out[p] = _PageMemoData(text: text, tags: tags);
          }
        }
      }

      return out;
    } catch (_) {
      return {};
    }
  }

  Future<void> _savePageMemos(Map<int, _PageMemoData> memos) async {
    final box = Hive.box<String>('material_page_memos');
    final map = <String, dynamic>{};

    for (final e in memos.entries) {
      map[e.key.toString()] = {
        'text': e.value.text,
        'tags': e.value.tags,
      };
    }

    await box.put(_pageMemoKey(), jsonEncode(map));
  }

  // ====== Overall note ======
  Future<void> _editOverallNote() async {
    final box = Hive.box<String>('material_notes');
    final current = box.get(_noteKey()) ?? '';

    final controller = TextEditingController(text: current);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('PDF 메모', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 6,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '이 자료 전체에 대한 메모를 적어둬',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('저장'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (saved == true) {
      await box.put(_noteKey(), controller.text.trim());
      if (mounted) setState(() {});
    }
  }

  // ====== Page memo editor with tags ======
  Future<void> _editPageMemo(int page) async {
    final memos = _loadPageMemos();
    final current = memos[page] ?? _PageMemoData.empty();

    final textController = TextEditingController(text: current.text);
    final tagInputController = TextEditingController();

    final result = await showModalBottomSheet<_PageMemoResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        // bottom sheet 내부 상태만 관리
        var selectedTags = current.tags.toList();

        void toggleTag(String t) {
          if (selectedTags.contains(t)) {
            selectedTags.remove(t);
          } else {
            selectedTags.add(t);
          }
        }

        void addCustomTag(String raw) {
          final t = raw.trim();
          if (t.isEmpty) return;
          if (!selectedTags.contains(t)) selectedTags.add(t);
        }

        // 현재 페이지에서 사용 중인 커스텀 태그도 보여주기 위해
        List<String> currentCustomTags() {
          final out = <String>[];
          for (final t in selectedTags) {
            if (!_presetTags.contains(t)) out.add(t);
          }
          out.sort();
          return out;
        }

        return StatefulBuilder(
          builder: (context, setLocal) {
            final customTags = currentCustomTags();

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('페이지 메모 (p.$page)',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: textController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: '이 페이지 핵심/시험 포인트를 적어둬',
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text('태그', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in _presetTags)
                        FilterChip(
                          label: Text(t),
                          selected: selectedTags.contains(t),
                          onSelected: (_) => setLocal(() => toggleTag(t)),
                        ),
                      for (final t in customTags)
                        FilterChip(
                          label: Text(t),
                          selected: true,
                          onSelected: (_) => setLocal(() => toggleTag(t)),
                        ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: tagInputController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: '태그 추가 (예: 기말, 교수님)',
                          ),
                          onSubmitted: (v) {
                            setLocal(() {
                              addCustomTag(v);
                              tagInputController.clear();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          setLocal(() {
                            addCustomTag(tagInputController.text);
                            tagInputController.clear();
                          });
                        },
                        child: const Text('추가'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(_PageMemoResult.delete),
                        child: const Text('삭제'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () {
                          // 현재 선택 태그를 result에 담아서 저장하도록
                          Navigator.of(context).pop(
                            _PageMemoResult.saveWith(selectedTags),
                          );
                        },
                        child: const Text('저장'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result == null) return;

    if (result.kind == _PageMemoResultKind.save) {
      final text = textController.text.trim();
      final tags = result.tags.map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
        ..sort();

      // 텍스트도 태그도 없으면 제거
      if (text.isEmpty && tags.isEmpty) {
        memos.remove(page);
      } else {
        memos[page] = _PageMemoData(text: text, tags: tags);
      }

      await _savePageMemos(memos);
      if (mounted) setState(() {});
    } else if (result.kind == _PageMemoResultKind.delete) {
      memos.remove(page);
      await _savePageMemos(memos);
      if (mounted) setState(() {});
    }
  }

  // ====== Memo list with search + tag filter ======
  void _openPageMemoList() {
    final memos = _loadPageMemos();
    final pagesAll = memos.keys.toList()..sort();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        if (pagesAll.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('페이지 메모가 아직 없어.'),
          );
        }

        // 모든 태그 집계
        final allTags = <String>{};
        for (final d in memos.values) {
          allTags.addAll(d.tags);
        }
        final tagList = allTags.toList()..sort();

        String query = '';
        String? tagFilter; // null = 전체

        List<int> filteredPages() {
          final q = query.trim().toLowerCase();
          final out = <int>[];

          for (final p in pagesAll) {
            final d = memos[p]!;
            final text = d.text;

            if (tagFilter != null && !d.tags.contains(tagFilter)) continue;

            if (q.isNotEmpty) {
              final hitText = text.toLowerCase().contains(q);
              final hitTag = d.tags.any((t) => t.toLowerCase().contains(q));
              if (!hitText && !hitTag) continue;
            }

            out.add(p);
          }

          return out;
        }

        return StatefulBuilder(
          builder: (context, setLocal) {
            final pages = filteredPages();

            return Padding(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 검색
                  TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      hintText: '검색 (메모 내용/태그)',
                    ),
                    onChanged: (v) => setLocal(() => query = v),
                  ),
                  const SizedBox(height: 10),

                  // 태그 필터
                  if (tagList.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: const Text('전체'),
                              selected: tagFilter == null,
                              onSelected: (_) => setLocal(() => tagFilter = null),
                            ),
                            const SizedBox(width: 8),
                            for (final t in tagList) ...[
                              ChoiceChip(
                                label: Text(t),
                                selected: tagFilter == t,
                                onSelected: (_) => setLocal(() => tagFilter = t),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 10),
                  Expanded(
                    child: pages.isEmpty
                        ? const Center(child: Text('조건에 맞는 메모가 없어.'))
                        : ListView.separated(
                            itemCount: pages.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final p = pages[i];
                              final d = memos[p]!;
                              final preview = d.text.length > 48
                                  ? '${d.text.substring(0, 48)}…'
                                  : d.text;

                              return ListTile(
                                title: Text('p.$p'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (preview.trim().isNotEmpty) Text(preview),
                                    if (d.tags.isNotEmpty)
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: -8,
                                        children: [
                                          for (final t in d.tags.take(6))
                                            Chip(
                                              label: Text(t),
                                              visualDensity: VisualDensity.compact,
                                            ),
                                        ],
                                      ),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  _controller.jumpToPage(p);
                                  setState(() => _currentPage = p);
                                },
                                trailing: IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () async {
                                    Navigator.of(context).pop();
                                    _controller.jumpToPage(p);
                                    setState(() => _currentPage = p);
                                    await _editPageMemo(p);
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!File(widget.filePath).existsSync()) {
      return const Scaffold(
        body: Center(child: Text('파일을 찾을 수 없어. 다시 업로드해줘.')),
      );
    }

    final noteBox = Hive.box<String>('material_notes');
    final overallNote = noteBox.get(_noteKey()) ?? '';
    final hasOverallNote = overallNote.trim().isNotEmpty;

    final pageMemos = _loadPageMemos();
    final hasPageMemo = pageMemos.containsKey(_currentPage);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
        actions: [
          IconButton(
            tooltip: 'PDF 메모',
            icon: Icon(hasOverallNote ? Icons.sticky_note_2 : Icons.sticky_note_2_outlined),
            onPressed: _editOverallNote,
          ),
          IconButton(
            tooltip: '페이지 메모 목록',
            icon: const Icon(Icons.list_alt),
            onPressed: _openPageMemoList,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editPageMemo(_currentPage),
        icon: Icon(hasPageMemo ? Icons.edit_note : Icons.note_add_outlined),
        label: Text('p.$_currentPage 메모'),
      ),
      body: Column(
        children: [
          if (_pageCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Text('$_currentPage / $_pageCount'),
                  const Spacer(),
                  if (hasPageMemo) const Text('메모 있음'),
                ],
              ),
            ),
          Expanded(
            child: PdfViewPinch(
              controller: _controller,
              onPageChanged: (page) {
                setState(() => _currentPage = page);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ====== Small helper types ======
class _PageMemoData {
  final String text;
  final List<String> tags;

  const _PageMemoData({
    required this.text,
    required this.tags,
  });

  factory _PageMemoData.empty() => const _PageMemoData(text: '', tags: []);
}

enum _PageMemoResultKind { save, delete }

class _PageMemoResult {
  final _PageMemoResultKind kind;
  final List<String> tags;

  const _PageMemoResult._(this.kind, this.tags);

  factory _PageMemoResult.saveWith(List<String> tags) =>
      _PageMemoResult._(_PageMemoResultKind.save, tags);

  static const _PageMemoResult delete = _PageMemoResult._(_PageMemoResultKind.delete, []);
}
