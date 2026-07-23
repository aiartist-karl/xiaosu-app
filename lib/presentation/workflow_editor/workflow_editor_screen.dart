import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/workflow/workflow_engine.dart';
import '../../core/workflow/workflow_templates.dart';

/// ============================================================
/// WorkflowEditorScreen — 可视化工作流编辑器
/// 支持无限画布、节点拖拽、贝塞尔连线、属性编辑、执行调试
/// ============================================================

class WorkflowEditorScreen extends StatefulWidget {
  final WorkflowEngine engine;
  final String? workflowId;
  const WorkflowEditorScreen({super.key, required this.engine, this.workflowId});
  @override
  State<WorkflowEditorScreen> createState() => _WorkflowEditorScreenState();
}

class _WorkflowEditorScreenState extends State<WorkflowEditorScreen> {
  late WorkflowEngine _engine;
  Workflow? _workflow;
  final TransformationController _tCtrl = TransformationController();
  final Set<String> _selIds = {};
  String? _selId;
  double _scale = 1.0;
  final List<Map<String, dynamic>> _undo = [], _redo = [];
  String? _dragSrc;
  Offset? _dragEnd;
  WorkflowExecutionRecord? _exec;
  final Map<String, NodeExecutionStatus> _nodeSt = {};
  final List<String> _logs = [];
  final ScrollController _logSc = ScrollController();
  bool _showLib = true, _showProp = true, _showExec = false;
  String _searchKey = '';

  @override
  void initState() {
    super.initState();
    _engine = widget.engine;
    _workflow = widget.workflowId != null ? _engine.getWorkflow(widget.workflowId!) : null;
    _workflow ??= Workflow(id: 'wf_${DateTime.now().millisecondsSinceEpoch}', name: '未命名工作流');
    _engine.onNodeStatusChanged = (id, st) { if (mounted) setState(() => _nodeSt[id] = st); };
    _engine.onLog = (m) { if (mounted) setState(() { _logs.add('[${DateTime.now().toString().substring(11,19)}] $m'); if (_logs.length > 200) _logs.removeAt(0); }); };
    _engine.onExecutionChanged = (r) { if (mounted) setState(() => _exec = r); };
  }
  @override
  void dispose() { _tCtrl.dispose(); _logSc.dispose(); super.dispose(); }

  void _pushUndo() { if (_workflow == null) return; _undo.add(_workflow!.toJson()); _redo.clear(); if (_undo.length > 50) _undo.removeAt(0); }
  void _undo() { if (_undo.isEmpty || _workflow == null) return; _redo.add(_workflow!.toJson()); setState(() => _workflow = Workflow.fromJson(_undo.removeLast())); }
  void _redoFn() { if (_redo.isEmpty || _workflow == null) return; _undo.add(_workflow!.toJson()); setState(() => _workflow = Workflow.fromJson(_redo.removeLast())); }

  void _addNode(WorkflowNodeType type, Offset pos) { if (_workflow == null) return; _pushUndo(); setState(() => _workflow!.nodes.add(WorkflowNode(id: 'n_${DateTime.now().millisecondsSinceEpoch}', type: type, x: pos.dx, y: pos.dy, label: type.label))); }
  void _delSelected() { if (_workflow == null || _selIds.isEmpty) return; _pushUndo(); setState(() { _workflow!.nodes.removeWhere((n) => _selIds.contains(n.id)); _workflow!.edges.removeWhere((e) => _selIds.contains(e.source) || _selIds.contains(e.target)); _selIds.clear(); _selId = null; }); }
  void _select(String? id) { setState(() { _selId = id; _selIds.clear(); if (id != null) _selIds.add(id); }); }
  void _upCfg(String nid, String k, dynamic v) { if (_workflow == null) return; _pushUndo(); _workflow!.nodes.firstWhere((n) => n.id == nid).config[k] = v; setState(() {}); }

  void _startEdge(String src, Offset p) { setState(() { _dragSrc = src; _dragEnd = p; }); }
  void _moveEdge(Offset p) { if (_dragSrc != null) setState(() => _dragEnd = p); }
  void _endEdge(String tgt) { if (_workflow == null || _dragSrc == null || _dragSrc == tgt) { _cancelEdge(); return; } _pushUndo(); if (!_workflow!.edges.any((e) => e.source == _dragSrc && e.target == tgt)) { setState(() { _workflow!.edges.add(WorkflowEdge(source: _dragSrc!, target: tgt)); _cancelEdge(); }); } else _cancelEdge(); }
  void _cancelEdge() { setState(() { _dragSrc = null; _dragEnd = null; }); }

  void _autoLayout() {
    if (_workflow == null || _workflow!.nodes.isEmpty) return;
    _pushUndo();
    try {
      final sorted = DagSorter.sort(_workflow!.nodes, _workflow!.edges);
      final nm = {for (final n in _workflow!.nodes) n.id: n};
      final lvl = <String, int>{};
      for (final id in sorted) { final ei = _workflow!.edges.where((e) => e.target == id); lvl[id] = ei.isEmpty ? 0 : ei.map((e) => (lvl[e.source] ?? 0) + 1).reduce(math.max); }
      final groups = <int, List<String>>{};
      lvl.forEach((id, l) => groups.putIfAbsent(l, () => []).add(id));
      setState(() => groups.forEach((l, ids) { for (int i = 0; i < ids.length; i++) { final n = nm[ids[i]]; if (n != null) { n.x = 100 + l * 250.0; n.y = 200 + i * 120.0; } } }));
    } catch (_) {}
  }

  void _align(String d) {
    if (_workflow == null || _selIds.length < 2) return; _pushUndo();
    final ns = _workflow!.nodes.where((n) => _selIds.contains(n.id)).toList();
    setState(() { switch (d) {
      case 'l': final v = ns.map((n) => n.x).reduce(math.min); ns.forEach((n) => n.x = v);
      case 'r': final v = ns.map((n) => n.x).reduce(math.max); ns.forEach((n) => n.x = v);
      case 't': final v = ns.map((n) => n.y).reduce(math.min); ns.forEach((n) => n.y = v);
      case 'b': final v = ns.map((n) => n.y).reduce(math.max); ns.forEach((n) => n.y = v);
      case 'hc': final v = ns.map((n) => n.x).reduce((a,b)=>a+b)/ns.length; ns.forEach((n) => n.x = v);
      case 'vc': final v = ns.map((n) => n.y).reduce((a,b)=>a+b)/ns.length; ns.forEach((n) => n.y = v);
    }});
  }

  void _distribute(String d) {
    if (_workflow == null || _selIds.length < 3) return; _pushUndo();
    final ns = _workflow!.nodes.where((n) => _selIds.contains(n.id)).toList();
    if (d == 'h') { ns.sort((a,b) => a.x.compareTo(b.x)); final s = (ns.last.x - ns.first.x) / (ns.length - 1); setState(() { for (int i=1; i<ns.length-1; i++) ns[i].x = ns.first.x + s * i; }); }
    else { ns.sort((a,b) => a.y.compareTo(b.y)); final s = (ns.last.y - ns.first.y) / (ns.length - 1); setState(() { for (int i=1; i<ns.length-1; i++) ns[i].y = ns.first.y + s * i; }); }
  }

  Future<void> _run() async { if (_workflow == null) return; _engine.updateWorkflow(_workflow!); setState(() { _showExec = true; _logs.clear(); _nodeSt.clear(); }); await _engine.executeWorkflow(_workflow!.id); }
  void _stop() { if (_exec != null) _engine.stopExecution(_exec!.id); }
  void _loadTpl(WorkflowTemplateInfo t) { _pushUndo(); setState(() => _workflow = t.builder()); }
  void _save() { if (_workflow == null) return; _engine.workflowExists(_workflow!.id) ? _engine.updateWorkflow(_workflow!) : _engine.createWorkflow(_workflow!); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('工作流已保存'))); }
  void _zoom(double d) { final ns = (_scale + d).clamp(0.2, 3.0); _tCtrl.value = Matrix4.identity()..scale(ns, ns); setState(() => _scale = ns); }

  // ─── 导入/导出/校验对话框 ───────────────────────────────

  Future<void> _showImportDialog() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF2D2D3F), title: const Text('导入工作流 JSON', style: TextStyle(color: Colors.white)),
      content: SizedBox(width: 500, height: 300, child: TextField(controller: ctrl, maxLines: null, expands: true,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
        decoration: InputDecoration(filled: true, fillColor: const Color(0xFF1E1E2E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF3D3D5C))), hintText: '粘贴 JSON...', hintStyle: const TextStyle(color: Colors.white24)))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: Colors.white54))), TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('导入', style: TextStyle(color: Colors.blue)))]));
    if (result != null && result.isNotEmpty) {
      try { _pushUndo(); final imp = _engine.importWorkflow(result); setState(() => _workflow = imp); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已导入: ${imp.name}'))); }
      catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导入失败: $e'))); }
    }
  }

  void _showExportDialog() {
    if (_workflow == null) return;
    final json = _workflow!.exportJson();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF2D2D3F), title: const Text('导出工作流 JSON', style: TextStyle(color: Colors.white)),
      content: SizedBox(width: 500, height: 300, child: SelectableText(json, style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭', style: TextStyle(color: Colors.white54))), TextButton(onPressed: () { Clipboard.setData(ClipboardData(text: json)); Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制到剪贴板'))); }, child: const Text('复制', style: TextStyle(color: Colors.blue)))]));
  }

  void _validateAndShowErrors() {
    if (_workflow == null) return;
    _engine.updateWorkflow(_workflow!);
    final errors = _engine.validateWorkflow(_workflow!.id);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF2D2D3F),
      title: Text(errors.isEmpty ? '✓ 校验通过' : '⚠ 发现问题', style: TextStyle(color: errors.isEmpty ? Colors.green : Colors.orange)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        if (errors.isEmpty) const Text('工作流结构完整，可以正常运行。', style: TextStyle(color: Colors.white70)),
        ...errors.map((e) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [const Icon(Icons.error_outline, size: 14, color: Colors.redAccent), const SizedBox(width: 8), Expanded(child: Text(e, style: const TextStyle(color: Colors.white70, fontSize: 12)))]))),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('确定', style: TextStyle(color: Colors.blue)))]));
  }

  // ─── 节点类型特定配置编辑器 ────────────────────────────

  Widget _nodeCfgEditor(WorkflowNode n) {
    switch (n.type) {
      case WorkflowNodeType.triggerSchedule: return _pf('Cron 表达式', n.config['cron']?.toString() ?? '0 8 * * *', (v) => _upCfg(n.id, 'cron', v));
      case WorkflowNodeType.triggerWebhook: return _pf('Webhook 路径', n.config['path']?.toString() ?? '', (v) => _upCfg(n.id, 'path', v));
      case WorkflowNodeType.triggerEvent: return _pf('事件名称', n.config['event_name']?.toString() ?? '', (v) => _upCfg(n.id, 'event_name', v));
      case WorkflowNodeType.actionLlm: return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_pf('Prompt', n.config['prompt']?.toString() ?? '', (v) => _upCfg(n.id, 'prompt', v)), _pf('Model', n.config['model']?.toString() ?? 'gpt-4', (v) => _upCfg(n.id, 'model', v)), _pnf('Temperature', (n.config['temperature'] ?? 0.7) as num, (v) => _upCfg(n.id, 'temperature', v.toDouble())), _pnf('Max Tokens', (n.config['max_tokens'] ?? 2048) as num, (v) => _upCfg(n.id, 'max_tokens', v.toInt()))]);
      case WorkflowNodeType.actionApi: return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_pf('URL', n.config['url']?.toString() ?? '', (v) => _upCfg(n.id, 'url', v)), _pf('Method', n.config['method']?.toString() ?? 'GET', (v) => _upCfg(n.id, 'method', v)), _pf('Body', n.config['body']?.toString() ?? '', (v) => _upCfg(n.id, 'body', v)), _pnf('Timeout(ms)', (n.config['timeout_ms'] ?? 30000) as num, (v) => _upCfg(n.id, 'timeout_ms', v.toInt()))]);
      case WorkflowNodeType.actionSkill: return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_pf('技能名称', n.config['skill_name']?.toString() ?? '', (v) => _upCfg(n.id, 'skill_name', v)), _pf('参数 (JSON)', n.config['params']?.toString() ?? '{}', (v) => _upCfg(n.id, 'params', v))]);
      case WorkflowNodeType.actionCode: return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_pf('语言', n.config['language']?.toString() ?? 'javascript', (v) => _upCfg(n.id, 'language', v)), _pf('代码', n.config['code']?.toString() ?? '', (v) => _upCfg(n.id, 'code', v))]);
      case WorkflowNodeType.actionCondition: return _pf('条件表达式', n.config['condition']?.toString() ?? 'true', (v) => _upCfg(n.id, 'condition', v));
      case WorkflowNodeType.actionLoop: return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_pf('集合路径', n.config['collection']?.toString() ?? '', (v) => _upCfg(n.id, 'collection', v)), _pnf('最大迭代', (n.config['max_iterations'] ?? 1000) as num, (v) => _upCfg(n.id, 'max_iterations', v.toInt()))]);
      case WorkflowNodeType.actionParallel: return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_pf('分支 (JSON)', n.config['branches']?.toString() ?? '[]', (v) => _upCfg(n.id, 'branches', v)), _pnf('最大并发', (n.config['max_concurrency'] ?? 5) as num, (v) => _upCfg(n.id, 'max_concurrency', v.toInt()))]);
      case WorkflowNodeType.actionDelay: return _pnf('延迟(ms)', (n.config['delay_ms'] ?? 1000) as num, (v) => _upCfg(n.id, 'delay_ms', v.toInt()));
      case WorkflowNodeType.actionTransform: return _pf('映射 (JSON)', n.config['mappings']?.toString() ?? '{}', (v) => _upCfg(n.id, 'mappings', v));
      case WorkflowNodeType.actionNotification: return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_pf('通道', n.config['channel']?.toString() ?? 'default', (v) => _upCfg(n.id, 'channel', v)), _pf('标题', n.config['title']?.toString() ?? '', (v) => _upCfg(n.id, 'title', v)), _pf('内容', n.config['body']?.toString() ?? '', (v) => _upCfg(n.id, 'body', v)), _pf('接收人', n.config['recipients']?.toString() ?? '[]', (v) => _upCfg(n.id, 'recipients', v))]);
      default: return const SizedBox.shrink();
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      body: KeyboardListener(
        focusNode: FocusNode(), autofocus: true,
        onKeyEvent: (e) {
          if (e is! KeyDownEvent) return;
          final ctrl = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
          if (ctrl && e.logicalKey == LogicalKeyboardKey.keyZ) HardwareKeyboard.instance.isShiftPressed ? _redoFn() : _undo();
          else if (ctrl && e.logicalKey == LogicalKeyboardKey.keyS) _save();
          else if (e.logicalKey == LogicalKeyboardKey.delete || e.logicalKey == LogicalKeyboardKey.backspace) _delSelected();
          else if (e.logicalKey == LogicalKeyboardKey.escape) { _cancelEdge(); _select(null); }
        },
        child: Column(children: [_toolbar(), _workflowInfoBar(), Expanded(child: Row(children: [if (_showLib) _nodeLibrary(), Expanded(child: _canvas()), if (_showProp) _propPanel()])), if (_showExec) _execPanel()]),
      ),
    );
  }

  Widget _tb(IconData ic, String tip, VoidCallback fn) => Tooltip(message: tip, child: IconButton(icon: Icon(ic, size: 18, color: Colors.white70), onPressed: fn, splashRadius: 16, constraints: const BoxConstraints(minWidth: 32, minHeight: 32), padding: EdgeInsets.zero));

  Widget _toolbar() => Container(height: 48, decoration: const BoxDecoration(color: Color(0xFF2D2D3F), border: Border(bottom: BorderSide(color: Color(0xFF3D3D5C)))), padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Row(children: [
      _tb(Icons.menu, '节点库', () => setState(() => _showLib = !_showLib)), const SizedBox(width: 8),
      _tb(Icons.save_outlined, '保存', _save), _tb(Icons.play_arrow, '运行', _run), _tb(Icons.stop, '停止', _stop), const SizedBox(width: 8),
      _tb(Icons.undo, '撤销', _undo), _tb(Icons.redo, '重做', _redoFn), const SizedBox(width: 8),
      _tb(Icons.align_horizontal_left, '左对齐', () => _align('l')), _tb(Icons.align_horizontal_center, '水平居中', () => _align('hc')), _tb(Icons.align_horizontal_right, '右对齐', () => _align('r')),
      _tb(Icons.align_vertical_top, '顶对齐', () => _align('t')), _tb(Icons.align_vertical_center, '垂直居中', () => _align('vc')), _tb(Icons.align_vertical_bottom, '底对齐', () => _align('b')),
      _tb(Icons.view_column, '水平分布', () => _distribute('h')), _tb(Icons.view_row, '垂直分布', () => _distribute('v')),
      _tb(Icons.auto_fix_high, '自动布局', _autoLayout), const Spacer(),
      _tb(Icons.zoom_out, '缩小', () => _zoom(-0.1)), Text('${(_scale*100).toInt()}%', style: const TextStyle(color: Colors.white70, fontSize: 12)), _tb(Icons.zoom_in, '放大', () => _zoom(0.1)),
      _tb(Icons.fit_screen, '适应', () { _tCtrl.value = Matrix4.identity(); setState(() => _scale = 1.0); }), const SizedBox(width: 8),
      _tb(Icons.file_upload, '导入', _showImportDialog), _tb(Icons.file_download, '导出', _showExportDialog), _tb(Icons.check_circle_outline, '校验', _validateAndShowErrors), const SizedBox(width: 8),
      _tb(Icons.terminal, '日志', () => setState(() => _showExec = !_showExec)), _tb(Icons.widgets, '属性', () => setState(() => _showProp = !_showProp)),
    ]));

  Widget _nodeLibrary() => Container(width: 240, decoration: const BoxDecoration(color: Color(0xFF252536), border: Border(right: BorderSide(color: Color(0xFF3D3D5C)))),
    child: Column(children: [
      Padding(padding: const EdgeInsets.all(8), child: TextField(style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(hintText: '搜索节点...', hintStyle: const TextStyle(color: Colors.white38), prefixIcon: const Icon(Icons.search, size: 16, color: Colors.white38), filled: true, fillColor: const Color(0xFF1E1E2E), contentPadding: const EdgeInsets.symmetric(vertical: 6), border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none), isDense: true),
        onChanged: (v) => setState(() => _searchKey = v))),
      Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 8), children: [
        _catHdr('触发器', Icons.flash_on), ..._filterNodes([WorkflowNodeType.triggerManual, WorkflowNodeType.triggerSchedule, WorkflowNodeType.triggerWebhook, WorkflowNodeType.triggerEvent]),
        const Divider(color: Color(0xFF3D3D5C), height: 24),
        _catHdr('动作', Icons.play_circle), ..._filterNodes([WorkflowNodeType.actionLlm, WorkflowNodeType.actionSkill, WorkflowNodeType.actionApi, WorkflowNodeType.actionCode, WorkflowNodeType.actionTransform, WorkflowNodeType.actionNotification, WorkflowNodeType.actionDelay]),
        const Divider(color: Color(0xFF3D3D5C), height: 24),
        _catHdr('逻辑', Icons.account_tree), ..._filterNodes([WorkflowNodeType.actionCondition, WorkflowNodeType.actionLoop, WorkflowNodeType.actionParallel]),
        const Divider(color: Color(0xFF3D3D5C), height: 24),
        _catHdr('终止', Icons.stop_circle), _libItem(WorkflowNodeType.terminator, _icon(WorkflowNodeType.terminator), '结束节点'),
        const Divider(color: Color(0xFF3D3D5C), height: 24),
        _catHdr('预设模板', Icons.auto_awesome), ...WorkflowTemplates.catalog.map((t) => _tplItem(t)),
      ])),
    ]));

  List<Widget> _filterNodes(List<WorkflowNodeType> types) {
    final f = _searchKey.isEmpty ? types : types.where((t) => t.label.contains(_searchKey)).toList();
    return f.map((t) => _libItem(t, _icon(t), t.label)).toList();
  }

  Widget _catHdr(String t, IconData ic) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Icon(ic, size: 14, color: Colors.white54), const SizedBox(width: 6), Text(t, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600))]));

  Widget _libItem(WorkflowNodeType type, IconData ic, String label) => Draggable<Map<String, dynamic>>(
    data: {'type': type, 'label': label},
    feedback: Material(color: Colors.transparent, child: _chip(ic, label, _color(type))),
    childWhenDragging: Opacity(opacity: 0.4, child: _chip(ic, label, _color(type))),
    child: _chip(ic, label, _color(type)));

  Widget _chip(IconData ic, String label, Color c) => Container(margin: const EdgeInsets.symmetric(vertical: 2), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: c.withOpacity(0.3))),
    child: Row(children: [Icon(ic, size: 14, color: c), const SizedBox(width: 8), Text(label, style: TextStyle(color: c.withOpacity(0.9), fontSize: 12))]));

  Widget _tplItem(WorkflowTemplateInfo t) => InkWell(onTap: () => _loadTpl(t), borderRadius: BorderRadius.circular(6),
    child: Container(margin: const EdgeInsets.symmetric(vertical: 2), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF1E1E2E), borderRadius: BorderRadius.circular(6)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Text(t.icon, style: const TextStyle(fontSize: 16)), const SizedBox(width: 6), Expanded(child: Text(t.name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)))]),
        const SizedBox(height: 4), Text(t.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        const SizedBox(height: 2), Wrap(spacing: 4, children: t.tags.take(3).map((tag) => Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: const Color(0xFF2D2D3F), borderRadius: BorderRadius.circular(3)), child: Text(tag, style: const TextStyle(color: Colors.white38, fontSize: 8)))).toList()),
      ])));

  Widget _canvas() => LayoutBuilder(builder: (ctx, c) => Container(color: const Color(0xFF1A1A2E),
    child: GestureDetector(onPanUpdate: (d) { if (_dragSrc != null) _moveEdge(d.localPosition); }, onPanEnd: (_) => _cancelEdge(), onTapUp: (_) { _select(null); _cancelEdge(); },
      child: InteractiveViewer(transformationController: _tCtrl, minScale: 0.2, maxScale: 3.0, boundaryMargin: const EdgeInsets.all(double.infinity), constrained: false,
        child: Stack(children: [
          CustomPaint(size: const Size(5000, 5000), painter: _GridP()),
          CustomPaint(size: const Size(5000, 5000), painter: _EdgeP(edges: _workflow?.edges ?? [], nodes: _workflow?.nodes ?? [], dragSrc: _dragSrc, dragEnd: _dragEnd)),
          ...(_workflow?.nodes ?? []).map(_buildNode),
          Positioned(right: 12, bottom: 12, child: _minimap()),
        ])),
    )));

  // ─── 右键菜单 ────────────────────────────────────────────

  void _showNodeContextMenu(BuildContext context, WorkflowNode node, Offset pos) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
      color: const Color(0xFF2D2D3F),
      items: [
        const PopupMenuItem(value: 'duplicate', child: Text('创建副本', style: TextStyle(color: Colors.white70, fontSize: 12))),
        const PopupMenuItem(value: 'breakpoint', child: Text('切换断点', style: TextStyle(color: Colors.white70, fontSize: 12))),
        const PopupMenuItem(value: 'view_exec', child: Text('查看执行结果', style: TextStyle(color: Colors.white70, fontSize: 12))),
        const PopupMenuDivider(height: 1),
        const PopupMenuItem(value: 'delete', child: Text('删除节点', style: TextStyle(color: Colors.redAccent, fontSize: 12))),
      ],
    ).then((val) {
      if (val == null || _workflow == null) return;
      switch (val) {
        case 'duplicate':
          _pushUndo();
          setState(() => _workflow!.nodes.add(WorkflowNode(
              id: 'n_${DateTime.now().millisecondsSinceEpoch}',
              type: node.type, config: Map.from(node.config),
              x: node.x + 30, y: node.y + 30,
              label: '${node.label} (副本)')));
        case 'breakpoint':
          final bps = _engine.getBreakpoints(_workflow!.id);
          if (bps.any((b) => b.nodeId == node.id)) {
            _engine.removeBreakpoint(_workflow!.id, node.id);
          } else {
            _engine.setBreakpoint(_workflow!.id, node.id);
          }
          setState(() {});
        case 'view_exec':
          final history = _engine.getExecutionHistory(_workflow!.id);
          if (history.isNotEmpty) {
            final record = history.first.nodeRecords.where((r) => r.nodeId == node.id);
            if (record.isNotEmpty) {
              _showExecResultDialog(record.first);
            }
          }
        case 'delete':
          _select(node.id);
          _delSelected();
      }
    });
  }

  void _showExecResultDialog(NodeExecutionRecord record) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF2D2D3F),
      title: Text('节点执行结果: ${record.nodeId}', style: const TextStyle(color: Colors.white, fontSize: 14)),
      content: SizedBox(width: 400, height: 300, child: SingleChildScrollView(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          _execInfoRow('状态', record.status.name,
              record.status == NodeExecutionStatus.completed ? Colors.green : Colors.red),
          if (record.duration != null) _execInfoRow('耗时', '${record.duration!.inMilliseconds}ms', Colors.white70),
          if (record.error != null) _execInfoRow('错误', record.error!, Colors.redAccent),
          const SizedBox(height: 8),
          const Text('输出数据:', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          ...record.outputData.entries.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text('${e.key}: ${e.value}', style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace')))),
        ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭', style: TextStyle(color: Colors.blue)))]));
  }

  Widget _execInfoRow(String label, String value, Color color) =>
      Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [
        Text('$label: ', style: const TextStyle(color: Colors.white54, fontSize: 11)),
        Text(value, style: TextStyle(color: color, fontSize: 11)),
      ]));

  // ─── 工作流信息面板 ──────────────────────────────────────

  Widget _workflowInfoBar() {
    if (_workflow == null) return const SizedBox.shrink();
    final nodeCount = _workflow!.nodes.length;
    final edgeCount = _workflow!.edges.length;
    final varCount = _workflow!.variables.length;
    final errors = _engine.validateWorkflow(_workflow!.id);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: const BoxDecoration(color: Color(0xFF252536), border: Border(bottom: BorderSide(color: Color(0xFF3D3D5C)))),
      child: Row(children: [
        Icon(Icons.work_outline, size: 14, color: Colors.white54),
        const SizedBox(width: 6),
        Text(_workflow!.name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(width: 16),
        _infoBadge('节点', '$nodeCount'),
        const SizedBox(width: 8),
        _infoBadge('连线', '$edgeCount'),
        const SizedBox(width: 8),
        _infoBadge('变量', '$varCount'),
        if (errors.isNotEmpty) ...[const SizedBox(width: 8), _infoBadge('问题', '${errors.length}', Colors.orange)],
        const Spacer(),
        Text('ID: ${_workflow!.id}', style: const TextStyle(color: Colors.white24, fontSize: 10)),
      ]),
    );
  }

  Widget _infoBadge(String label, String value, [Color? color]) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: const Color(0xFF1E1E2E), borderRadius: BorderRadius.circular(4)),
    child: Text('$label: $value', style: TextStyle(color: color ?? Colors.white54, fontSize: 10)),
  );

  Widget _buildNode(WorkflowNode n) {
    final sel = _selIds.contains(n.id);
    final st = _nodeSt[n.id];
    final c = _color(n.type);
    final hasBreakpoint = _engine.getBreakpoints(_workflow!.id).any((b) => b.nodeId == n.id);
    return Positioned(left: n.x, top: n.y, child: GestureDetector(
      onTap: () => _select(n.id),
      onSecondaryTapUp: (d) => _showNodeContextMenu(context, n, d.globalPosition),
      onPanUpdate: (d) { if (_dragSrc == null) setState(() { n.x += d.delta.dx / _scale; n.y += d.delta.dy / _scale; }); },
      onPanEnd: (_) { if (_dragSrc == null) _pushUndo(); },
      onLongPressStart: (d) => _startEdge(n.id, d.globalPosition),
      onLongPressMoveUpdate: (d) => _moveEdge(d.globalPosition),
      onLongPressEnd: (d) {
        final tgt = (_workflow?.nodes ?? []).where((nn) => Rect.fromLTWH(nn.x, nn.y, 180, 60).contains(d.globalPosition)).firstOrNull;
        tgt != null ? _endEdge(tgt.id) : _cancelEdge();
      },
      child: AnimatedContainer(duration: const Duration(milliseconds: 150), width: 180, padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFF2D2D3F), borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? c : c.withOpacity(0.3), width: sel ? 2 : 1),
          boxShadow: [if (sel) BoxShadow(color: c.withOpacity(0.3), blurRadius: 12),
            if (st == NodeExecutionStatus.running) BoxShadow(color: Colors.blue.withOpacity(0.4), blurRadius: 16),
            if (st == NodeExecutionStatus.completed) BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 12),
            if (st == NodeExecutionStatus.failed) BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 16)]),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(_icon(n.type), size: 14, color: c),
            const SizedBox(width: 6),
            Expanded(child: Text(n.label ?? n.type.label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
            if (hasBreakpoint) const Icon(Icons.circle, size: 6, color: Colors.orange),
            if (st != null) Container(width: 8, height: 8, decoration: BoxDecoration(
                color: {NodeExecutionStatus.running: Colors.blue, NodeExecutionStatus.completed: Colors.green,
                  NodeExecutionStatus.failed: Colors.red, NodeExecutionStatus.retrying: Colors.orange,
                  NodeExecutionStatus.skipped: Colors.grey}[st] ?? Colors.grey, shape: BoxShape.circle)),
          ]),
          const SizedBox(height: 4),
          Text(n.type.label, style: const TextStyle(color: Colors.white38, fontSize: 9)),
          if (n.config.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(_configSummary(n), maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white24, fontSize: 8)),
          ],
        ])),
    ));
  }

  /// 生成节点配置摘要
  String _configSummary(WorkflowNode n) {
    switch (n.type) {
      case WorkflowNodeType.triggerSchedule: return n.config['cron']?.toString() ?? '';
      case WorkflowNodeType.actionLlm: return n.config['model']?.toString() ?? 'gpt-4';
      case WorkflowNodeType.actionApi: return '${n.config['method'] ?? 'GET'} ${n.config['url']?.toString().split('/').take(3).join('/') ?? ''}';
      case WorkflowNodeType.actionCode: return n.config['language']?.toString() ?? 'js';
      case WorkflowNodeType.actionDelay: return '${n.config['delay_ms'] ?? 1000}ms';
      case WorkflowNodeType.actionNotification: return n.config['channel']?.toString() ?? 'push';
      default: return '';
    }
  }

  Widget _minimap() {
    final ns = _workflow?.nodes ?? []; if (ns.isEmpty) return const SizedBox.shrink();
    double minX = double.infinity, minY = double.infinity, maxX = 0.0, maxY = 0.0;
    for (final n in ns) { if (n.x < minX) minX = n.x; if (n.y < minY) minY = n.y; if (n.x+180 > maxX) maxX = n.x+180; if (n.y+60 > maxY) maxY = n.y+60; }
    final s = math.min(160/(maxX-minX+100), 120/(maxY-minY+100));
    return Container(width: 170, height: 130, decoration: BoxDecoration(color: const Color(0xFF1E1E2E).withOpacity(0.9), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF3D3D5C))),
      child: CustomPaint(painter: _MiniP(nodes: ns, scale: s, offX: minX-50, offY: minY-50)));
  }

  Widget _propPanel() {
    final n = _selId != null ? _workflow?.nodes.where((nn) => nn.id == _selId).firstOrNull : null;
    return Container(width: 300, decoration: const BoxDecoration(color: Color(0xFF252536), border: Border(left: BorderSide(color: Color(0xFF3D3D5C)))),
      child: n == null ? const Center(child: Text('选择节点编辑属性', style: TextStyle(color: Colors.white38, fontSize: 12)))
        : ListView(padding: const EdgeInsets.all(12), children: [
            _ph('节点属性'), _pf('名称', n.label ?? '', (v) { _pushUndo(); setState(() => n.label = v); }), _pf('描述', n.description ?? '', (v) { _pushUndo(); setState(() => n.description = v); }),
            const SizedBox(height: 8), _ph('类型配置'), _nodeCfgEditor(n),
            const SizedBox(height: 8), _ph('重试设置'),
            _pnf('最大重试次数', (n.config['max_retries'] ?? 0) as num, (v) => _upCfg(n.id, 'max_retries', v.toInt())),
            _pnf('重试间隔(ms)', (n.config['retry_delay_ms'] ?? 1000) as num, (v) => _upCfg(n.id, 'retry_delay_ms', v.toInt())),
            const Divider(color: Color(0xFF3D3D5C), height: 24), _ph('断点调试'),
            SwitchListTile(title: const Text('启用断点', style: TextStyle(color: Colors.white70, fontSize: 12)), value: _engine.getBreakpoints(_workflow!.id).any((b) => b.nodeId == n.id), activeColor: Colors.blue, contentPadding: EdgeInsets.zero,
              onChanged: (v) { v ? _engine.setBreakpoint(_workflow!.id, n.id) : _engine.removeBreakpoint(_workflow!.id, n.id); setState(() {}); }),
            const Divider(color: Color(0xFF3D3D5C), height: 24), _ph('变量'),
            ...(_workflow?.variables ?? []).map((v) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Expanded(child: Text('${v.name} (${v.type.value})', style: const TextStyle(color: Colors.white70, fontSize: 11))), IconButton(icon: const Icon(Icons.delete_outline, size: 14, color: Colors.redAccent), onPressed: () { _pushUndo(); setState(() => _workflow!.variables.remove(v)); })]))),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: () { _pushUndo(); setState(() => _workflow!.variables.add(WorkflowVariable(name: 'var_${_workflow!.variables.length}', type: WorkflowVariableType.string))); },
              icon: const Icon(Icons.add, size: 14), label: const Text('添加变量', style: TextStyle(fontSize: 11)), style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: Color(0xFF3D3D5C)))),
          ]));
  }

  Widget _execPanel() => Container(height: 200, decoration: const BoxDecoration(color: Color(0xFF1E1E2E), border: Border(top: BorderSide(color: Color(0xFF3D3D5C)))),
    child: Column(children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: Row(children: [
        const Text('执行日志', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)), const Spacer(),
        if (_exec != null) ...[_badge('状态', _exec!.status.name), const SizedBox(width: 8), _badge('节点', '${_exec!.nodeRecords.length}'), if (_exec!.finishedAt != null) ...[const SizedBox(width: 8), _badge('耗时', '${_exec!.finishedAt!.difference(_exec!.startedAt).inMilliseconds}ms')]],
        const SizedBox(width: 8), IconButton(icon: const Icon(Icons.close, size: 16, color: Colors.white38), onPressed: () => setState(() => _showExec = false)),
      ])),
      Expanded(child: ListView.builder(controller: _logSc, padding: const EdgeInsets.symmetric(horizontal: 12), itemCount: _logs.length,
        itemBuilder: (_, i) => Text(_logs[i], style: TextStyle(color: _logs[i].contains('[错误]') ? Colors.redAccent : _logs[i].contains('[断点]') ? Colors.orange : Colors.white54, fontSize: 11, fontFamily: 'monospace')))),
    ]));

  Widget _badge(String l, String v) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: const Color(0xFF2D2D3F), borderRadius: BorderRadius.circular(4)), child: Text('$l: $v', style: const TextStyle(color: Colors.white54, fontSize: 10)));
  Widget _ph(String t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(t, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)));

  Widget _pf(String l, String v, ValueChanged<String> fn) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(l, style: const TextStyle(color: Colors.white38, fontSize: 10)), const SizedBox(height: 2),
    TextField(controller: TextEditingController(text: v), style: const TextStyle(color: Colors.white, fontSize: 12), decoration: InputDecoration(filled: true, fillColor: const Color(0xFF1E1E2E), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFF3D3D5C))), isDense: true), onChanged: fn)]));

  Widget _pnf(String l, num v, ValueChanged<num> fn) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(l, style: const TextStyle(color: Colors.white38, fontSize: 10)), const SizedBox(height: 2),
    TextField(controller: TextEditingController(text: v.toString()), keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white, fontSize: 12), decoration: InputDecoration(filled: true, fillColor: const Color(0xFF1E1E2E), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFF3D3D5C))), isDense: true),
      onChanged: (s) { final n = num.tryParse(s); if (n != null) fn(n); })]));

  Color _color(WorkflowNodeType t) { switch (t) {
    case WorkflowNodeType.triggerManual: case WorkflowNodeType.triggerSchedule: case WorkflowNodeType.triggerWebhook: case WorkflowNodeType.triggerEvent: return const Color(0xFF4FC3F7);
    case WorkflowNodeType.actionLlm: return const Color(0xFFAB47BC);
    case WorkflowNodeType.actionSkill: return const Color(0xFF7E57C2);
    case WorkflowNodeType.actionApi: return const Color(0xFF26A69A);
    case WorkflowNodeType.actionCode: return const Color(0xFFFF7043);
    case WorkflowNodeType.actionCondition: return const Color(0xFFFFA726);
    case WorkflowNodeType.actionLoop: return const Color(0xFFFFCA28);
    case WorkflowNodeType.actionParallel: return const Color(0xFF66BB6A);
    case WorkflowNodeType.actionDelay: return const Color(0xFF8D6E63);
    case WorkflowNodeType.actionTransform: return const Color(0xFF42A5F5);
    case WorkflowNodeType.actionNotification: return const Color(0xFFEC407A);
    case WorkflowNodeType.terminator: return const Color(0xFFEF5350);
  }}

  IconData _icon(WorkflowNodeType t) { switch (t) {
    case WorkflowNodeType.triggerManual: return Icons.touch_app; case WorkflowNodeType.triggerSchedule: return Icons.schedule;
    case WorkflowNodeType.triggerWebhook: return Icons.webhook; case WorkflowNodeType.triggerEvent: return Icons.bolt;
    case WorkflowNodeType.actionLlm: return Icons.smart_toy; case WorkflowNodeType.actionSkill: return Icons.extension;
    case WorkflowNodeType.actionApi: return Icons.http; case WorkflowNodeType.actionCode: return Icons.code;
    case WorkflowNodeType.actionCondition: return Icons.call_split; case WorkflowNodeType.actionLoop: return Icons.repeat;
    case WorkflowNodeType.actionParallel: return Icons.call_merge; case WorkflowNodeType.actionDelay: return Icons.timer;
    case WorkflowNodeType.actionTransform: return Icons.transform; case WorkflowNodeType.actionNotification: return Icons.notifications;
    case WorkflowNodeType.terminator: return Icons.check_circle;
  }}

  // ─── 执行历史面板 ────────────────────────────────────────

  Widget _execHistoryPanel() {
    if (_workflow == null) return const SizedBox.shrink();
    final history = _engine.getExecutionHistory(_workflow!.id);
    if (history.isEmpty) {
      return Container(padding: const EdgeInsets.all(16),
        child: const Text('暂无执行记录', style: TextStyle(color: Colors.white38, fontSize: 12)));
    }
    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: const BoxDecoration(
        color: Color(0xFF252536),
        border: Border(top: BorderSide(color: Color(0xFF3D3D5C))),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.all(8),
          child: Row(children: [
            const Text('执行历史', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${history.length} 次执行', style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ])),
        Flexible(child: ListView.builder(
          shrinkWrap: true,
          itemCount: history.length.clamp(0, 20),
          itemBuilder: (ctx, i) {
            final rec = history[i];
            final statusColor = {
              WorkflowExecutionStatus.completed: Colors.green,
              WorkflowExecutionStatus.failed: Colors.red,
              WorkflowExecutionStatus.cancelled: Colors.orange,
              WorkflowExecutionStatus.running: Colors.blue,
              WorkflowExecutionStatus.paused: Colors.yellow,
              WorkflowExecutionStatus.idle: Colors.grey,
            }[rec.status] ?? Colors.grey;
            final dur = rec.finishedAt?.difference(rec.startedAt).inMilliseconds ?? 0;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(rec.status.name, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Text('${rec.nodeRecords.length} 节点', style: const TextStyle(color: Colors.white38, fontSize: 9)),
                  ]),
                  const SizedBox(height: 2),
                  Text('${rec.startedAt.toString().substring(0, 19)} · ${dur}ms',
                      style: const TextStyle(color: Colors.white24, fontSize: 9)),
                  if (rec.error != null) Text(rec.error!.length > 50 ? '${rec.error!.substring(0, 50)}...' : rec.error!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 9)),
                ])),
              ]),
            );
          },
        )),
      ]),
    );
  }

  // ─── 变量类型选择器 ──────────────────────────────────────

  Widget _varTypeSelector(WorkflowVariable v) {
    return PopupMenuButton<WorkflowVariableType>(
      onSelected: (type) {
        _pushUndo();
        final idx = _workflow!.variables.indexOf(v);
        if (idx >= 0) {
          setState(() => _workflow!.variables[idx] = WorkflowVariable(
              name: v.name, type: type, defaultValue: v.defaultValue, value: v.value));
        }
      },
      color: const Color(0xFF2D2D3F),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF3D3D5C)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(v.type.value, style: const TextStyle(color: Colors.white54, fontSize: 10)),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down, size: 14, color: Colors.white38),
        ]),
      ),
      itemBuilder: (ctx) => WorkflowVariableType.values.map((t) =>
          PopupMenuItem(value: t, child: Text(t.value, style: TextStyle(
              color: t == v.type ? Colors.blue : Colors.white70, fontSize: 11)))).toList(),
    );
  }

  // ─── 节点库项（带描述）─────────────────────────────────

  Widget _libItemWithDesc(WorkflowNodeType type, IconData ic, String label, String desc) {
    final c = _color(type);
    return Draggable<Map<String, dynamic>>(
      data: {'type': type, 'label': label},
      feedback: Material(color: Colors.transparent, child: _chip(ic, label, c)),
      childWhenDragging: Opacity(opacity: 0.4, child: _chip(ic, label, c)),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: c.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: c.withOpacity(0.2)),
        ),
        child: Row(children: [
          Container(width: 28, height: 28, decoration: BoxDecoration(
              color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
              child: Icon(ic, size: 14, color: c)),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: c.withOpacity(0.9), fontSize: 11, fontWeight: FontWeight.w500)),
            Text(desc, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white24, fontSize: 9)),
          ])),
        ]),
      ),
    );
  }

  /// 带描述的节点类型映射
  static const Map<WorkflowNodeType, String> _nodeDescs = {
    WorkflowNodeType.triggerManual: '点击按钮手动启动工作流',
    WorkflowNodeType.triggerSchedule: '按 cron 表达式定时执行',
    WorkflowNodeType.triggerWebhook: '通过 HTTP 端点接收外部请求',
    WorkflowNodeType.triggerEvent: '监听系统事件自动触发',
    WorkflowNodeType.actionLlm: '调用大语言模型处理文本',
    WorkflowNodeType.actionSkill: '调用已安装的技能或插件',
    WorkflowNodeType.actionApi: '发送 HTTP 请求调用外部 API',
    WorkflowNodeType.actionCode: '执行自定义 JavaScript/Dart 代码',
    WorkflowNodeType.actionCondition: '根据条件走不同分支',
    WorkflowNodeType.actionLoop: '遍历集合逐元素处理',
    WorkflowNodeType.actionParallel: '多路并行同时执行',
    WorkflowNodeType.actionDelay: '等待指定时间后继续',
    WorkflowNodeType.actionTransform: '映射和转换数据结构',
    WorkflowNodeType.actionNotification: '向用户推送通知消息',
    WorkflowNodeType.terminator: '标记工作流执行结束',
  };
}

// ═══ Painters ════════════════════════════════════════════════

class _GridP extends CustomPainter {
  @override void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0xFF2A2A3E)..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 40) canvas.drawLine(Offset(x,0), Offset(x,size.height), p);
    for (double y = 0; y < size.height; y += 40) canvas.drawLine(Offset(0,y), Offset(size.width,y), p);
    final tp = Paint()..color = const Color(0xFF33334A)..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 200) canvas.drawLine(Offset(x,0), Offset(x,size.height), tp);
    for (double y = 0; y < size.height; y += 200) canvas.drawLine(Offset(0,y), Offset(size.width,y), tp);
  }
  @override bool shouldRepaint(covariant CustomPainter d) => false;
}

class _EdgeP extends CustomPainter {
  final List<WorkflowEdge> edges; final List<WorkflowNode> nodes; final String? dragSrc; final Offset? dragEnd;
  _EdgeP({required this.edges, required this.nodes, this.dragSrc, this.dragEnd});
  @override void paint(Canvas canvas, Size size) {
    final nm = {for (final n in nodes) n.id: n};
    for (final e in edges) { final s = nm[e.source], t = nm[e.target]; if (s == null || t == null) continue; _bezier(canvas, Offset(s.x+180, s.y+30), Offset(t.x, t.y+30), const Color(0xFF5C6BC0));
      if (e.condition != null || e.label != null) { final mid = Offset((s.x+180+t.x)/2, (s.y+30+t.y+30)/2); final tp = TextPainter(text: TextSpan(text: e.condition ?? e.label ?? '', style: const TextStyle(color: Colors.white54, fontSize: 9)), textDirection: TextDirection.ltr)..layout(); tp.paint(canvas, mid - Offset(tp.width/2, tp.height/2+10)); }
    }
    if (dragSrc != null && dragEnd != null) { final s = nm[dragSrc]; if (s != null) _bezier(canvas, Offset(s.x+180, s.y+30), dragEnd!, const Color(0xFF66BB6A)); }
  }
  void _bezier(Canvas c, Offset s, Offset e, Color col) {
    final p = Paint()..color = col..strokeWidth = 2..style = PaintingStyle.stroke; final dx = (e.dx-s.dx).abs()*0.5;
    c.drawPath(Path()..moveTo(s.dx,s.dy)..cubicTo(s.dx+dx,s.dy,e.dx-dx,e.dy,e.dx,e.dy), p);
    c.drawPath(Path()..moveTo(e.dx,e.dy)..lineTo(e.dx-6,e.dy-3)..lineTo(e.dx-6,e.dy+3)..close(), Paint()..color = col..style = PaintingStyle.fill);
  }
  @override bool shouldRepaint(covariant _EdgeP o) => o.edges != edges || o.dragSrc != dragSrc || o.dragEnd != dragEnd;
}

class _MiniP extends CustomPainter {
  final List<WorkflowNode> nodes; final double scale, offX, offY;
  _MiniP({required this.nodes, required this.scale, required this.offX, required this.offY});
  @override void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0xFF4FC3F7)..style = PaintingStyle.fill;
    final bp = Paint()..color = const Color(0xFF4FC3F7).withOpacity(0.5)..style = PaintingStyle.stroke..strokeWidth = 0.5;
    for (final n in nodes) { final r = RRect.fromRectAndRadius(Rect.fromLTWH((n.x-offX)*scale, (n.y-offY)*scale, 180*scale, 50*scale), const Radius.circular(2)); canvas.drawRRect(r, p); canvas.drawRRect(r, bp); }
  }
  @override bool shouldRepaint(covariant _MiniP o) => o.nodes != nodes || o.scale != scale;
}
