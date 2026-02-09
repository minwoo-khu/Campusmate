import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:pdfx/pdfx.dart';

class PdfViewerScreen extends StatefulWidget {
  final int materialKey;      // CourseMaterial Hive key
  final String filePath;      // localPath
  final String fileName;      // 표시용

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
  String _pageMemoKey() => 'm:${widget.materialKey}:pages'; // JSON map page->memo

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

  Map<int, String> _loadPageMemos() {
    final box = Hive.box<String>('material_page_memos');
    final raw = box.get(_pageMemoKey());
    if (raw == null || raw.trim().isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final out = <int, String>{};
      for (final e in map.entries) {
        final p = int.tryParse(e.key);
        final v = e.value;
        if (p != null && v is String) out[p] = v;
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  Future<void> _savePageMemos(Map<int, String> memos) async {
    final box = Hive.box<String>('material_page_memos');
    final map = <String, dynamic>{};
    for (final e in memos.entries) {
      map[e.key.toString()] = e.value;
    }
    await box.put(_pageMemoKey(), jsonEncode(map));
  }

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

  Future<void> _editPageMemo(int page) async {
    final memos = _loadPageMemos();
    final current = memos[page] ?? '';
    final controller = TextEditingController(text: current);

    final result = await showModalBottomSheet<_PageMemoResult>(
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
              Text('페이지 메모 (p.$page)', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 5,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '이 페이지 핵심/시험 포인트를 적어둬',
                ),
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
                    onPressed: () => Navigator.of(context).pop(_PageMemoResult.save),
                    child: const Text('저장'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (result == null) return;

    if (result == _PageMemoResult.save) {
      final text = controller.text.trim();
      if (text.isEmpty) {
        memos.remove(page);
      } else {
        memos[page] = text;
      }
      await _savePageMemos(memos);
      if (mounted) setState(() {});
    } else if (result == _PageMemoResult.delete) {
      memos.remove(page);
      await _savePageMemos(memos);
      if (mounted) setState(() {});
    }
  }

  void _openPageMemoList() {
    final memos = _loadPageMemos();
    final pages = memos.keys.toList()..sort();

    showModalBottomSheet(
      context: context,
      builder: (_) {
        if (pages.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('페이지 메모가 아직 없어.'),
          );
        }

        return ListView.separated(
          itemCount: pages.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final p = pages[i];
            final text = memos[p] ?? '';
            final preview = text.length > 40 ? '${text.substring(0, 40)}…' : text;

            return ListTile(
              title: Text('p.$p'),
              subtitle: Text(preview),
              onTap: () async {
                Navigator.of(context).pop();
                await _controller.animateToPage(
                  pageNumber: p,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                );
                setState(() => _currentPage = p);
              },
              trailing: IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () async {
                    Navigator.of(context).pop();
                    await _controller.animateToPage(
                      pageNumber: p,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                    );
                    setState(() => _currentPage = p);
                    await _editPageMemo(p);
                },
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

enum _PageMemoResult { save, delete }
