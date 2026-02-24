import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:pdfx/pdfx.dart';

import '../../app/center_notice.dart';
import '../../app/l10n.dart';
import '../../app/safety_limits.dart';
import '../../app/theme.dart';

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

  String _t(String ko, String en) => context.tr(ko, en);

  String _tagLabel(String tag) {
    switch (tag) {
      case 'Exam':
        return _t('시험', 'Exam');
      case 'Important':
        return _t('중요', 'Important');
      case 'Memorize':
        return _t('암기', 'Memorize');
      case 'Assignment':
        return _t('과제', 'Assignment');
      case 'Question':
        return _t('질문', 'Question');
      default:
        return tag;
    }
  }

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

      final anchorY = data.anchorY?.clamp(0.0, 1.0).toDouble();
      out[page] = _PageMemoData(text: text, tags: tags, anchorY: anchorY);
      if (out.length >= SafetyLimits.maxPageMemosPerMaterial) break;
    }

    return out;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    CenterNotice.show(context, message: message);
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
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

        final anchorRaw = value['anchorY'];
        double? anchorY;
        if (anchorRaw is num) {
          anchorY = anchorRaw.toDouble();
        } else if (anchorRaw is String) {
          anchorY = double.tryParse(anchorRaw);
        }

        if (text.isNotEmpty || tags.isNotEmpty) {
          out[page] = _PageMemoData(text: text, tags: tags, anchorY: anchorY);
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
      final map = <String, dynamic>{};
      for (final e in safeMemos.entries) {
        final payload = <String, dynamic>{
          'text': e.value.text,
          'tags': e.value.tags,
        };
        if (e.value.anchorY != null) {
          payload['anchorY'] = e.value.anchorY;
        }
        map[e.key.toString()] = payload;
      }

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
        _t(
          '페이지 메모 저장 용량 한도를 넘어 안정성을 위해 초기화했습니다.',
          'Page memos exceeded safe storage size and were reset for stability.',
        ),
      );
    }

    await _pageMemoBox.put(_pageMemoKey(), encoded);
    _pageMemos = safeMemos;
  }

  double? _captureAnchorYForPage(int page) {
    final controller = _controller;
    if (controller == null || page <= 0) return null;

    try {
      final pageRect = controller.getPageRect(page);
      if (pageRect == null || pageRect.height <= 0) return null;
      final viewRect = controller.viewRect;
      final focusY = viewRect.top + (viewRect.height * 0.42);
      final anchor = ((focusY - pageRect.top) / pageRect.height).clamp(
        0.0,
        1.0,
      );
      return anchor.toDouble();
    } catch (_) {
      return null;
    }
  }

  String _anchorPositionLabel(double anchorY) {
    if (anchorY < 0.33) return _t('상단', 'Top');
    if (anchorY < 0.66) return _t('중간', 'Middle');
    return _t('하단', 'Bottom');
  }

  Future<void> _goToPage(int page) async {
    final controller = _controller;
    if (controller == null || page <= 0) return;
    await controller.animateToPage(
      pageNumber: page,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _goToPageWithAnchor(int page, {double? anchorY}) async {
    await _goToPage(page);
    if (anchorY == null) return;

    final controller = _controller;
    if (controller == null) return;

    await Future<void>.delayed(const Duration(milliseconds: 80));
    try {
      final pageRect = controller.getPageRect(page);
      if (pageRect == null || pageRect.height <= 0) return;

      final viewRect = controller.viewRect;
      final maxTop = pageRect.bottom - viewRect.height;
      final rawTop =
          pageRect.top +
          (pageRect.height * anchorY.clamp(0.0, 1.0).toDouble()) -
          (viewRect.height * 0.35);
      final targetTop = maxTop <= pageRect.top
          ? pageRect.top
          : rawTop.clamp(pageRect.top, maxTop).toDouble();

      final matrix = controller.value.clone();
      matrix.setEntry(1, 3, -targetTop);
      await controller.goTo(
        destination: matrix,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    } catch (_) {
      // Ignore if viewer metrics are not ready.
    }
  }

  Future<void> _editOverallNote() async {
    final current = _noteBox.get(_noteKey()) ?? '';
    final controller = TextEditingController(text: current);
    final cm = context.cmColors;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: cm.scaffoldBg,
      builder: (sheetContext) {
        final mq = MediaQuery.of(sheetContext);
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: mq.viewInsets.bottom + mq.viewPadding.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _t('PDF 노트', 'PDF note'),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: cm.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLines: 6,
                  maxLength: SafetyLimits.maxOverallNoteChars,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: cm.inputBg,
                    hintText: _t(
                      '이 PDF 전체에 대한 메모를 작성하세요',
                      'Write overall notes for this PDF',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: cm.navActive,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.of(sheetContext).pop(true),
                        child: Text(_t('저장', 'Save')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
    final currentAnchorY = _captureAnchorYForPage(page) ?? current.anchorY;
    final cm = context.cmColors;

    final textController = TextEditingController(text: current.text);
    final tagInputController = TextEditingController();

    final result = await showModalBottomSheet<_PageMemoResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: cm.scaffoldBg,
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
              _t(
                '페이지 메모당 태그는 최대 ${SafetyLimits.maxTagsPerPageMemo}개까지 추가할 수 있습니다.',
                'You can add up to ${SafetyLimits.maxTagsPerPageMemo} tags per page memo.',
              ),
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
              _t(
                '페이지 메모당 태그는 최대 ${SafetyLimits.maxTagsPerPageMemo}개까지 추가할 수 있습니다.',
                'You can add up to ${SafetyLimits.maxTagsPerPageMemo} tags per page memo.',
              ),
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

            final mq = MediaQuery.of(context);
            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _dismissKeyboard,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: mq.viewInsets.bottom + mq.viewPadding.bottom + 16,
                  ),
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t('페이지 메모 (p.$page)', 'Page memo (p.$page)'),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: cm.textPrimary,
                          ),
                        ),
                        if (currentAnchorY != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _t(
                              '기준 위치: ${_anchorPositionLabel(currentAnchorY)}',
                              'Anchor: ${_anchorPositionLabel(currentAnchorY)}',
                            ),
                            style: TextStyle(fontSize: 12, color: cm.textHint),
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextField(
                          controller: textController,
                          maxLines: 5,
                          maxLength: SafetyLimits.maxPageMemoTextChars,
                          onTapOutside: (_) => _dismissKeyboard(),
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: cm.inputBg,
                            hintText: _t(
                              '이 페이지의 핵심 내용을 메모하세요',
                              'Write key points for this page',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _t('태그', 'Tags'),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: cm.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final t in _presetTags)
                              FilterChip(
                                label: Text(_tagLabel(t)),
                                labelStyle: TextStyle(color: cm.textPrimary),
                                selected: selectedTags.contains(t),
                                selectedColor: cm.navActive.withValues(
                                  alpha: 0.18,
                                ),
                                checkmarkColor: cm.textPrimary,
                                backgroundColor: cm.inputBg,
                                side: BorderSide(color: cm.cardBorder),
                                onSelected: (_) => setLocal(() => toggleTag(t)),
                              ),
                            for (final t in customTags)
                              FilterChip(
                                label: Text(t),
                                labelStyle: TextStyle(color: cm.textPrimary),
                                selected: true,
                                selectedColor: cm.navActive.withValues(
                                  alpha: 0.18,
                                ),
                                checkmarkColor: cm.textPrimary,
                                backgroundColor: cm.inputBg,
                                side: BorderSide(color: cm.cardBorder),
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
                                onTapOutside: (_) => _dismissKeyboard(),
                                decoration: InputDecoration(
                                  border: const OutlineInputBorder(),
                                  filled: true,
                                  fillColor: cm.inputBg,
                                  hintText: _t(
                                    '태그 추가 (예: 중간고사)',
                                    'Add tag (example: midterm)',
                                  ),
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
                              style: FilledButton.styleFrom(
                                backgroundColor: cm.navActive,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () {
                                setLocal(() {
                                  addCustomTag(tagInputController.text);
                                  tagInputController.clear();
                                });
                              },
                              child: Text(_t('추가', 'Add')),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: cm.deleteBg,
                                side: BorderSide(color: cm.deleteBg),
                              ),
                              onPressed: () => Navigator.of(
                                context,
                              ).pop(_PageMemoResult.delete),
                              child: Text(_t('삭제', 'Delete')),
                            ),
                            const Spacer(),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: cm.navActive,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => Navigator.of(
                                context,
                              ).pop(_PageMemoResult.saveWith(selectedTags)),
                              child: Text(_t('저장', 'Save')),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
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
            _t(
              '페이지 메모 한도에 도달했습니다 (${SafetyLimits.maxPageMemosPerMaterial}개).',
              'Page memo limit reached (${SafetyLimits.maxPageMemosPerMaterial}).',
            ),
          );
          return;
        }
        memos[page] = _PageMemoData(
          text: text,
          tags: tags,
          anchorY: _captureAnchorYForPage(page) ?? currentAnchorY,
        );
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

  void _openPageMemoList() {
    final memos = Map<int, _PageMemoData>.from(_pageMemos);
    final pagesAll = memos.keys.toList()..sort();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.cmColors.scaffoldBg,
      builder: (_) {
        final cm = context.cmColors;
        if (pagesAll.isEmpty) {
          final mq = MediaQuery.of(context);
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              mq.viewPadding.bottom + 20,
            ),
            child: Text(
              _t('아직 페이지 메모가 없습니다.', 'No page memos yet.'),
              style: TextStyle(color: cm.textSecondary),
            ),
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
                  bottom:
                      MediaQuery.of(context).viewInsets.bottom +
                      MediaQuery.of(context).viewPadding.bottom +
                      20,
                ),
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: cm.inputBg,
                        hintText: _t('메모 내용/태그 검색', 'Search memo content/tags'),
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
                                label: Text(_t('전체', 'All')),
                                labelStyle: TextStyle(color: cm.textPrimary),
                                selected: tagFilter == null,
                                selectedColor: cm.navActive.withValues(
                                  alpha: 0.18,
                                ),
                                backgroundColor: cm.inputBg,
                                side: BorderSide(color: cm.cardBorder),
                                onSelected: (_) =>
                                    setLocal(() => tagFilter = null),
                              ),
                              const SizedBox(width: 8),
                              for (final t in tagList) ...[
                                ChoiceChip(
                                  label: Text(t),
                                  labelStyle: TextStyle(color: cm.textPrimary),
                                  selected: tagFilter == t,
                                  selectedColor: cm.navActive.withValues(
                                    alpha: 0.18,
                                  ),
                                  backgroundColor: cm.inputBg,
                                  side: BorderSide(color: cm.cardBorder),
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
                          ? Center(
                              child: Text(
                                _t(
                                  '필터에 맞는 메모가 없습니다.',
                                  'No memo matches the filter.',
                                ),
                              ),
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
                                      if (data.anchorY != null)
                                        Text(
                                          _t(
                                            '위치: ${_anchorPositionLabel(data.anchorY!)}',
                                            'Position: ${_anchorPositionLabel(data.anchorY!)}',
                                          ),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: cm.textHint,
                                          ),
                                        ),
                                      if (data.tags.isNotEmpty)
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: -8,
                                          children: [
                                            for (final t in data.tags.take(6))
                                              Chip(
                                                label: Text(t),
                                                labelStyle: TextStyle(
                                                  color: cm.textPrimary,
                                                ),
                                                backgroundColor: cm.inputBg,
                                                side: BorderSide(
                                                  color: cm.cardBorder,
                                                ),
                                                visualDensity:
                                                    VisualDensity.compact,
                                              ),
                                          ],
                                        ),
                                    ],
                                  ),
                                  onTap: () async {
                                    Navigator.of(context).pop();
                                    await _goToPageWithAnchor(
                                      page,
                                      anchorY: data.anchorY,
                                    );
                                  },
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: _t('수정', 'Edit'),
                                        icon: const Icon(Icons.edit_outlined),
                                        onPressed: () async {
                                          Navigator.of(context).pop();
                                          await _goToPageWithAnchor(
                                            page,
                                            anchorY: data.anchorY,
                                          );
                                          await _editPageMemo(page);
                                        },
                                      ),
                                      IconButton(
                                        tooltip: _t('삭제', 'Delete'),
                                        icon: Icon(
                                          Icons.delete_outline,
                                          color: cm.deleteBg,
                                        ),
                                        onPressed: () async {
                                          memos.remove(page);
                                          pagesAll.remove(page);
                                          await _savePageMemos(memos);
                                          if (!mounted) return;
                                          setState(() {});
                                          setLocal(() {});
                                        },
                                      ),
                                    ],
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
      return Scaffold(
        body: Center(
          child: Text(
            _t(
              '파일을 찾을 수 없습니다. 다시 업로드해주세요.',
              'Cannot find file. Please re-upload it.',
            ),
          ),
        ),
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
            tooltip: _t('PDF 노트', 'PDF note'),
            icon: Icon(
              _hasOverallNote
                  ? Icons.sticky_note_2
                  : Icons.sticky_note_2_outlined,
            ),
            onPressed: _editOverallNote,
          ),
          IconButton(
            tooltip: _t('페이지 메모 목록', 'Page memo list'),
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
            label: Text(_t('p.$page 메모', 'p.$page memo')),
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
                        if (hasPageMemo) Text(_t('메모 있음', 'Memo exists')),
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
                  _showMessage(
                    _t('이 PDF 파일을 열 수 없습니다.', 'Failed to open this PDF file.'),
                  );
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
  final double? anchorY;

  const _PageMemoData({required this.text, required this.tags, this.anchorY});

  factory _PageMemoData.empty() =>
      const _PageMemoData(text: '', tags: [], anchorY: null);
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
