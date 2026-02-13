import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:pdfx/pdfx.dart';

import '../../app/center_notice.dart';
import '../../app/safety_limits.dart';

class PdfViewerScreen extends StatefulWidget {
  final int materialKey;
  final String filePath;
  final String fileName;

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
  PdfControllerPinch? _controller;
  late final Box<String> _noteBox;
  late final Box<String> _pageMemoBox;
  late final bool _fileExists;

  final ValueNotifier<int> _currentPageListenable = ValueNotifier<int>(1);
  final ValueNotifier<int> _pageCountListenable = ValueNotifier<int>(0);

  Map<int, _PageMemoData> _pageMemos = const {};
  bool _hasOverallNote = false;

  String _noteKey() => 'm:${widget.materialKey}';
  String _pageMemoKey() => 'm:${widget.materialKey}:pages';

  static const List<String> _presetTags = [
    'Exam',
    'Important',
    'Memorize',
    'Assignment',
    'Question',
  ];

  @override
  void initState() {
    super.initState();
    _noteBox = Hive.box<String>('material_notes');
    _pageMemoBox = Hive.box<String>('material_page_memos');
    _fileExists = File(widget.filePath).existsSync();
    _refreshMemoCache();

    if (_fileExists) {
      _controller = PdfControllerPinch(
        document: PdfDocument.openFile(widget.filePath),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _currentPageListenable.dispose();
    _pageCountListenable.dispose();
    super.dispose();
  }

  String _clampText(String raw, int maxChars) {
    final text = raw.trim();
    if (text.length <= maxChars) return text;
    return text.substring(0, maxChars);
  }

  List<String> _sanitizeTags(Iterable<String> rawTags) {
    final out = <String>[];
    final seen = <String>{};

    for (final raw in rawTags) {
      final tag = _clampText(raw, SafetyLimits.maxPageMemoTagChars);
      if (tag.isEmpty) continue;
      if (!seen.add(tag)) continue;

      out.add(tag);
      if (out.length >= SafetyLimits.maxTagsPerPageMemo) break;
    }

    out.sort();
    return out;
  }

  Map<int, _PageMemoData> _sanitizeMemoMap(Map<int, _PageMemoData> memos) {
    final pages = memos.keys.where((page) => page > 0).toList()..sort();
    final out = <int, _PageMemoData>{};

    for (final page in pages) {
      final data = memos[page];
      if (data == null) continue;

      final text = _clampText(data.text, SafetyLimits.maxPageMemoTextChars);
      final tags = _sanitizeTags(data.tags);
      if (text.isEmpty && tags.isEmpty) continue;

      out[page] = _PageMemoData(text: text, tags: tags);
      if (out.length >= SafetyLimits.maxPageMemosPerMaterial) break;
    }

    return out;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    CenterNotice.show(context, message: message);
  }

  void _refreshMemoCache() {
    final note = _noteBox.get(_noteKey()) ?? '';
    _hasOverallNote = note.trim().isNotEmpty;
    _pageMemos = _loadPageMemos();
  }

  Map<int, _PageMemoData> _loadPageMemos() {
    final raw = _pageMemoBox.get(_pageMemoKey());
    if (raw == null || raw.trim().isEmpty) return {};
    if (raw.length > SafetyLimits.maxPageMemoPayloadChars) return {};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};

      final out = <int, _PageMemoData>{};
      for (final entry in decoded.entries) {
        if (out.length >= SafetyLimits.maxPageMemosPerMaterial) break;

        final page = int.tryParse(entry.key.toString());
        if (page == null || page <= 0) continue;

        final value = entry.value;
        if (value is String) {
          final text = _clampText(value, SafetyLimits.maxPageMemoTextChars);
          if (text.isNotEmpty) {
            out[page] = _PageMemoData(text: text, tags: const []);
          }
          continue;
        }

        if (value is! Map) continue;

        final text = value['text'] is String
            ? _clampText(
                value['text'] as String,
                SafetyLimits.maxPageMemoTextChars,
              )
            : '';

        final tagsRaw = value['tags'];
        final tags = tagsRaw is List
            ? _sanitizeTags(tagsRaw.whereType<String>())
            : const <String>[];

        if (text.isNotEmpty || tags.isNotEmpty) {
          out[page] = _PageMemoData(text: text, tags: tags);
        }
      }

      return _sanitizeMemoMap(out);
    } catch (_) {
      return {};
    }
  }

  Future<void> _savePageMemos(Map<int, _PageMemoData> memos) async {
    var safeMemos = _sanitizeMemoMap(memos);
    String encoded = '{}';

    while (true) {
      final map = <String, dynamic>{
        for (final e in safeMemos.entries)
          e.key.toString(): {'text': e.value.text, 'tags': e.value.tags},
      };

      encoded = jsonEncode(map);
      if (encoded.length <= SafetyLimits.maxPageMemoPayloadChars ||
          safeMemos.length <= 1) {
        break;
      }

      final keepCount = (safeMemos.length * 0.8).floor().clamp(
        1,
        safeMemos.length,
      );
      safeMemos = Map<int, _PageMemoData>.fromEntries(
        safeMemos.entries.take(keepCount),
      );
    }

    if (encoded.length > SafetyLimits.maxPageMemoPayloadChars) {
      encoded = '{}';
      safeMemos = const {};
      _showMessage(
        'Page memos exceeded safe storage size and were reset for stability.',
      );
    }

    await _pageMemoBox.put(_pageMemoKey(), encoded);
    _pageMemos = safeMemos;
  }

  Future<void> _editOverallNote() async {
    final current = _noteBox.get(_noteKey()) ?? '';
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
              const Text(
                'PDF note',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 6,
                maxLength: SafetyLimits.maxOverallNoteChars,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Write overall notes for this PDF',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (saved != true || !mounted) return;

    final safeNote = _clampText(
      controller.text,
      SafetyLimits.maxOverallNoteChars,
    );
    await _noteBox.put(_noteKey(), safeNote);

    if (!mounted) return;
    setState(() {
      _hasOverallNote = safeNote.isNotEmpty;
    });
  }

  Future<void> _editPageMemo(int page) async {
    final memos = Map<int, _PageMemoData>.from(_pageMemos);
    final current = memos[page] ?? _PageMemoData.empty();

    final textController = TextEditingController(text: current.text);
    final tagInputController = TextEditingController();

    final result = await showModalBottomSheet<_PageMemoResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        var selectedTags = _sanitizeTags(current.tags);

        void toggleTag(String raw) {
          final tag = _clampText(raw, SafetyLimits.maxPageMemoTagChars);
          if (tag.isEmpty) return;

          if (selectedTags.contains(tag)) {
            selectedTags.remove(tag);
            return;
          }

          if (selectedTags.length >= SafetyLimits.maxTagsPerPageMemo) {
            _showMessage(
              'You can add up to ${SafetyLimits.maxTagsPerPageMemo} tags per page memo.',
            );
            return;
          }

          selectedTags.add(tag);
        }

        void addCustomTag(String raw) {
          final tag = _clampText(raw, SafetyLimits.maxPageMemoTagChars);
          if (tag.isEmpty || selectedTags.contains(tag)) return;

          if (selectedTags.length >= SafetyLimits.maxTagsPerPageMemo) {
            _showMessage(
              'You can add up to ${SafetyLimits.maxTagsPerPageMemo} tags per page memo.',
            );
            return;
          }

          selectedTags.add(tag);
        }

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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Page memo (p.$page)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: textController,
                      maxLines: 5,
                      maxLength: SafetyLimits.maxPageMemoTextChars,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Write key points for this page',
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Tags',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
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
                            maxLength: SafetyLimits.maxPageMemoTagChars,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Add tag (example: midterm)',
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
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: () =>
                              Navigator.of(context).pop(_PageMemoResult.delete),
                          child: const Text('Delete'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () => Navigator.of(
                            context,
                          ).pop(_PageMemoResult.saveWith(selectedTags)),
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null) return;

    if (result.kind == _PageMemoResultKind.save) {
      final text = _clampText(
        textController.text,
        SafetyLimits.maxPageMemoTextChars,
      );
      final tags = _sanitizeTags(result.tags);

      if (text.isEmpty && tags.isEmpty) {
        memos.remove(page);
      } else {
        final isNewPage = !memos.containsKey(page);
        if (isNewPage && memos.length >= SafetyLimits.maxPageMemosPerMaterial) {
          _showMessage(
            'Page memo limit reached (${SafetyLimits.maxPageMemosPerMaterial}).',
          );
          return;
        }
        memos[page] = _PageMemoData(text: text, tags: tags);
      }

      await _savePageMemos(memos);
      if (!mounted) return;
      setState(() {});
      return;
    }

    if (result.kind == _PageMemoResultKind.delete) {
      memos.remove(page);
      await _savePageMemos(memos);
      if (!mounted) return;
      setState(() {});
    }
  }

  void _goToPage(int page) {
    final controller = _controller;
    if (controller == null || page <= 0) return;
    controller.animateToPage(
      pageNumber: page,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  void _openPageMemoList() {
    final memos = _pageMemos;
    final pagesAll = memos.keys.toList()..sort();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        if (pagesAll.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No page memos yet.'),
          );
        }

        final allTags = <String>{};
        for (final data in memos.values) {
          allTags.addAll(data.tags);
        }
        final tagList = allTags.toList()..sort();

        String query = '';
        String? tagFilter;

        List<int> filteredPages() {
          final q = query.trim().toLowerCase();
          final out = <int>[];

          for (final p in pagesAll) {
            final data = memos[p]!;

            if (tagFilter != null && !data.tags.contains(tagFilter)) continue;

            if (q.isNotEmpty) {
              final hitText = data.text.toLowerCase().contains(q);
              final hitTag = data.tags.any((t) => t.toLowerCase().contains(q));
              if (!hitText && !hitTag) continue;
            }

            out.add(p);
          }

          return out;
        }

        return StatefulBuilder(
          builder: (context, setLocal) {
            final pages = filteredPages();

            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.78,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  top: 12,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                ),
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        hintText: 'Search memo content/tags',
                      ),
                      onChanged: (v) => setLocal(() => query = v),
                    ),
                    const SizedBox(height: 10),
                    if (tagList.isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ChoiceChip(
                                label: const Text('All'),
                                selected: tagFilter == null,
                                onSelected: (_) =>
                                    setLocal(() => tagFilter = null),
                              ),
                              const SizedBox(width: 8),
                              for (final t in tagList) ...[
                                ChoiceChip(
                                  label: Text(t),
                                  selected: tagFilter == t,
                                  onSelected: (_) =>
                                      setLocal(() => tagFilter = t),
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
                          ? const Center(
                              child: Text('No memo matches the filter.'),
                            )
                          : ListView.separated(
                              itemCount: pages.length,
                              separatorBuilder: (_, separatorIndex) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final page = pages[i];
                                final data = memos[page]!;
                                final preview = data.text.length > 48
                                    ? '${data.text.substring(0, 48)}...'
                                    : data.text;

                                return ListTile(
                                  title: Text('p.$page'),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (preview.isNotEmpty) Text(preview),
                                      if (data.tags.isNotEmpty)
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: -8,
                                          children: [
                                            for (final t in data.tags.take(6))
                                              Chip(
                                                label: Text(t),
                                                visualDensity:
                                                    VisualDensity.compact,
                                              ),
                                          ],
                                        ),
                                    ],
                                  ),
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    _goToPage(page);
                                  },
                                  trailing: IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () async {
                                      Navigator.of(context).pop();
                                      _goToPage(page);
                                      await _editPageMemo(page);
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_fileExists) {
      return const Scaffold(
        body: Center(child: Text('Cannot find file. Please re-upload it.')),
      );
    }

    final controller = _controller;
    if (controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
        actions: [
          IconButton(
            tooltip: 'PDF note',
            icon: Icon(
              _hasOverallNote
                  ? Icons.sticky_note_2
                  : Icons.sticky_note_2_outlined,
            ),
            onPressed: _editOverallNote,
          ),
          IconButton(
            tooltip: 'Page memo list',
            icon: const Icon(Icons.list_alt),
            onPressed: _openPageMemoList,
          ),
        ],
      ),
      floatingActionButton: ValueListenableBuilder<int>(
        valueListenable: _currentPageListenable,
        builder: (context, page, _) {
          final hasPageMemo = _pageMemos.containsKey(page);
          return FloatingActionButton.extended(
            onPressed: () => _editPageMemo(page),
            icon: Icon(hasPageMemo ? Icons.edit_note : Icons.note_add_outlined),
            label: Text('p.$page memo'),
          );
        },
      ),
      body: Column(
        children: [
          ValueListenableBuilder<int>(
            valueListenable: _pageCountListenable,
            builder: (context, pageCount, _) {
              if (pageCount <= 0) return const SizedBox.shrink();
              return ValueListenableBuilder<int>(
                valueListenable: _currentPageListenable,
                builder: (context, page, _) {
                  final hasPageMemo = _pageMemos.containsKey(page);
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Text('$page / $pageCount'),
                        const Spacer(),
                        if (hasPageMemo) const Text('Memo exists'),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          Expanded(
            child: RepaintBoundary(
              child: PdfViewPinch(
                controller: controller,
                padding: 6,
                maxScale: 8,
                backgroundDecoration: const BoxDecoration(color: Colors.white),
                onDocumentLoaded: (document) {
                  final pagesCount = document.pagesCount;
                  if (_pageCountListenable.value == pagesCount) return;
                  _pageCountListenable.value = pagesCount;
                },
                onDocumentError: (_) {
                  _showMessage('Failed to open this PDF file.');
                },
                onPageChanged: (page) {
                  if (_currentPageListenable.value == page) return;
                  _currentPageListenable.value = page;
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageMemoData {
  final String text;
  final List<String> tags;

  const _PageMemoData({required this.text, required this.tags});

  factory _PageMemoData.empty() => const _PageMemoData(text: '', tags: []);
}

enum _PageMemoResultKind { save, delete }

class _PageMemoResult {
  final _PageMemoResultKind kind;
  final List<String> tags;

  const _PageMemoResult._(this.kind, this.tags);

  factory _PageMemoResult.saveWith(List<String> tags) {
    return _PageMemoResult._(_PageMemoResultKind.save, tags);
  }

  static const _PageMemoResult delete = _PageMemoResult._(
    _PageMemoResultKind.delete,
    [],
  );
}
