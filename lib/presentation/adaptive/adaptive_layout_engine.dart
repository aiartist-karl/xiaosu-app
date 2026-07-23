// ============================================================================
// 小酥 (XiaoSu) - 多端自适应布局引擎
//
// 职责：
// 根据设备类型（手机/平板/桌面/折叠屏）和窗口尺寸，
// 自动选择最优布局策略，提供响应式组件体系
//
// 核心能力：
// - 设备类型检测与折叠屏动态切换
// - 自适应 Scaffold / Navigation / ChatLayout / Dialog / Grid
// - 窗口管理（桌面端）
// - 输入适配（触控/鼠标/键盘）
// - 快捷键绑定与右键菜单
// ============================================================================

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ============================================================================
// 数据模型
// ============================================================================

/// 设备类型
enum DeviceType {
  /// 手机 (< 600dp)
  phone,

  /// 平板 (600-1024dp)
  tablet,

  /// 桌面 (> 1024dp)
  desktop,

  /// 折叠屏（动态切换）
  foldable,
}

/// 布局配置
class LayoutConfig {
  /// 设备类型
  final DeviceType deviceType;

  /// 可用宽度
  final double width;

  /// 可用高度
  final double height;

  /// 设备像素比
  final double devicePixelRatio;

  /// 导航栏类型
  final NavigationType navigationType;

  /// 是否显示侧边栏
  final bool showSidebar;

  /// 侧边栏宽度
  final double sidebarWidth;

  /// 聊天布局模式
  final ChatLayoutMode chatMode;

  /// 弹窗模式
  final DialogMode dialogMode;

  /// 网格列数
  final int gridColumns;

  /// 是否紧凑模式
  final bool isCompact;

  /// 安全区域
  final EdgeInsets safeArea;

  const LayoutConfig({
    required this.deviceType,
    required this.width,
    required this.height,
    this.devicePixelRatio = 1.0,
    required this.navigationType,
    required this.showSidebar,
    this.sidebarWidth = 280,
    required this.chatMode,
    required this.dialogMode,
    required this.gridColumns,
    this.isCompact = false,
    this.safeArea = EdgeInsets.zero,
  });

  /// 是否为宽屏布局
  bool get isWideLayout => width >= 800;

  /// 是否为超宽屏
  bool get isUltraWide => width >= 1400;

  /// 内容区域最大宽度
  double get maxContentWidth => math.min(width - (showSidebar ? sidebarWidth : 0), 900);

  @override
  String toString() =>
      'LayoutConfig(${deviceType.name}, ${width.toInt()}x${height.toInt()}, nav=${navigationType.name}, chat=${chatMode.name})';
}

/// 导航栏类型
enum NavigationType {
  /// 底部导航栏（手机）
  bottomBar,

  /// 侧边导航栏（平板/桌面）
  sideBar,

  /// 顶部导航栏（桌面）
  topBar,

  /// 无导航栏
  none,
}

/// 聊天布局模式
enum ChatLayoutMode {
  /// 全屏聊天（手机）
  fullScreen,

  /// 分屏：会话列表 + 聊天窗口（平板）
  splitView,

  /// 多窗格：导航 + 列表 + 详情（桌面）
  multiPane,
}

/// 弹窗模式
enum DialogMode {
  /// 底部弹窗（手机）
  bottomSheet,

  /// 居中弹窗（平板/桌面）
  centered,
}

/// 窗口配置
class WindowConfig {
  /// 最小宽度
  final double minWidth;

  /// 最小高度
  final double minHeight;

  /// 默认宽度
  final double defaultWidth;

  /// 默认高度
  final double defaultHeight;

  /// 是否自定义标题栏
  final bool customTitleBar;

  /// 标题栏高度
  final double titleBarHeight;

  /// 是否启用系统托盘
  final bool enableTray;

  /// 全局快捷键列表
  final List<WindowShortcut> shortcuts;

  const WindowConfig({
    this.minWidth = 800,
    this.minHeight = 600,
    this.defaultWidth = 1280,
    this.defaultHeight = 800,
    this.customTitleBar = true,
    this.titleBarHeight = 32,
    this.enableTray = true,
    this.shortcuts = const [],
  });
}

/// 窗口快捷键
class WindowShortcut {
  final String key;
  final String description;
  final LogicalKeyboardKey logicalKey;
  final Set<LogicalKeyboardKey> modifiers;

  const WindowShortcut({
    required this.key,
    required this.description,
    required this.logicalKey,
    this.modifiers = const {},
  });
}

/// 输入模式
enum InputMode {
  /// 触控
  touch,

  /// 鼠标
  mouse,

  /// 键盘
  keyboard,

  /// 触控笔/手写笔
  stylus,

  /// 手柄/遥控器
  gamepad,
}

/// 折叠屏状态
enum FoldableState {
  /// 折叠（合拢）
  folded,

  /// 展开
  unfolded,

  /// 半折叠（桌面模式）
  halfFolded,
}

/// 拖拽数据
class DragData {
  final String id;
  final String type;
  final dynamic payload;

  const DragData({
    required this.id,
    required this.type,
    this.payload,
  });
}

// ============================================================================
// 自适应布局引擎
// ============================================================================

/// 自适应布局引擎
///
/// 根据当前窗口尺寸和设备类型，自动计算最优布局配置。
/// 提供 ChangeNotifier 以便 UI 层监听布局变化。
class AdaptiveLayoutEngine extends ChangeNotifier {
  /// 当前布局配置
  LayoutConfig? _currentConfig;
  LayoutConfig get currentConfig => _currentConfig!;

  /// 当前输入模式
  InputMode _inputMode = InputMode.touch;
  InputMode get inputMode => _inputMode;

  /// 折叠屏状态
  FoldableState _foldableState = FoldableState.unfolded;
  FoldableState get foldableState => _foldableState;

  /// 折叠屏状态变化流
  final StreamController<FoldableState> _foldableStream =
      StreamController<FoldableState>.broadcast();
  Stream<FoldableState> get onFoldableStateChanged => _foldableStream.stream;

  /// 窗口配置
  final WindowConfig windowConfig;

  /// 侧边栏是否展开（平板端可折叠）
  bool _sidebarExpanded = true;
  bool get sidebarExpanded => _sidebarExpanded;
  set sidebarExpanded(bool value) {
    _sidebarExpanded = value;
    notifyListeners();
  }

  /// 快捷键绑定
  final Map<String, void Function()> _shortcuts = {};

  /// 拖拽排序状态
  DragData? _currentDragData;
  DragData? get currentDragData => _currentDragData;

  /// 右键菜单状态
  bool _contextMenuVisible = false;
  bool get contextMenuVisible => _contextMenuVisible;

  AdaptiveLayoutEngine({
    this.windowConfig = const WindowConfig(),
  });

  // ==========================================================================
  // 设备类型检测
  // ==========================================================================

  /// 根据宽度计算设备类型
  static DeviceType detectDeviceType(double width) {
    if (width < 600) return DeviceType.phone;
    if (width <= 1024) return DeviceType.tablet;
    return DeviceType.desktop;
  }

  /// 根据上下文计算布局配置
  LayoutConfig computeLayout(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final width = size.width;
    final height = size.height;

    // 检测设备类型
    DeviceType deviceType;
    if (_foldableState != FoldableState.unfolded && _foldableState != FoldableState.folded) {
      // 折叠屏半折叠时使用平板布局
      deviceType = DeviceType.foldable;
    } else {
      deviceType = detectDeviceType(width);
    }

    // 导航栏类型
    final navType = _computeNavigationType(deviceType, width);

    // 聊天布局模式
    final chatMode = _computeChatMode(deviceType, width);

    // 弹窗模式
    final dialogMode = _computeDialogMode(deviceType);

    // 网格列数
    final gridColumns = _computeGridColumns(width);

    // 侧边栏
    final showSidebar = deviceType != DeviceType.phone && _sidebarExpanded;
    final sidebarWidth = deviceType == DeviceType.desktop ? 300.0 : 260.0;

    // 紧凑模式
    final isCompact = width < 600;

    _currentConfig = LayoutConfig(
      deviceType: deviceType,
      width: width,
      height: height,
      devicePixelRatio: dpr,
      navigationType: navType,
      showSidebar: showSidebar,
      sidebarWidth: sidebarWidth,
      chatMode: chatMode,
      dialogMode: dialogMode,
      gridColumns: gridColumns,
      isCompact: isCompact,
      safeArea: padding,
    );

    return _currentConfig!;
  }

  /// 计算导航栏类型
  NavigationType _computeNavigationType(DeviceType deviceType, double width) {
    switch (deviceType) {
      case DeviceType.phone:
        return NavigationType.bottomBar;
      case DeviceType.tablet:
        return width >= 800 ? NavigationType.sideBar : NavigationType.bottomBar;
      case DeviceType.desktop:
        return NavigationType.sideBar;
      case DeviceType.foldable:
        return _foldableState == FoldableState.folded
            ? NavigationType.bottomBar
            : NavigationType.sideBar;
    }
  }

  /// 计算聊天布局模式
  ChatLayoutMode _computeChatMode(DeviceType deviceType, double width) {
    switch (deviceType) {
      case DeviceType.phone:
        return ChatLayoutMode.fullScreen;
      case DeviceType.tablet:
        return width >= 800 ? ChatLayoutMode.splitView : ChatLayoutMode.fullScreen;
      case DeviceType.desktop:
        return ChatLayoutMode.multiPane;
      case DeviceType.foldable:
        return _foldableState == FoldableState.folded
            ? ChatLayoutMode.fullScreen
            : ChatLayoutMode.splitView;
    }
  }

  /// 计算弹窗模式
  DialogMode _computeDialogMode(DeviceType deviceType) {
    switch (deviceType) {
      case DeviceType.phone:
        return DialogMode.bottomSheet;
      case DeviceType.tablet:
      case DeviceType.desktop:
      case DeviceType.foldable:
        return DialogMode.centered;
    }
  }

  /// 计算网格列数
  int _computeGridColumns(double width) {
    if (width < 600) return 1;
    if (width < 900) return 2;
    if (width < 1200) return 3;
    if (width < 1600) return 4;
    return 5;
  }

  // ==========================================================================
  // 折叠屏支持
  // ==========================================================================

  /// 更新折叠屏状态（由原生层回调触发）
  void updateFoldableState(FoldableState state) {
    if (_foldableState != state) {
      _foldableState = state;
      _foldableStream.add(state);
      notifyListeners();
    }
  }

  // ==========================================================================
  // 输入适配
  // ==========================================================================

  /// 更新输入模式
  void updateInputMode(InputMode mode) {
    if (_inputMode != mode) {
      _inputMode = mode;
      notifyListeners();
    }
  }

  /// 获取当前输入模式的悬停反馈
  bool get showHoverEffects => _inputMode == InputMode.mouse || _inputMode == InputMode.stylus;

  /// 获取合适的触摸目标大小
  double get minTouchTarget {
    switch (_inputMode) {
      case InputMode.touch:
      case InputMode.stylus:
        return 48.0;
      case InputMode.mouse:
        return 36.0;
      case InputMode.keyboard:
      case InputMode.gamepad:
        return 40.0;
    }
  }

  /// 获取拖拽排序灵敏度
  double get dragSensitivity {
    switch (_inputMode) {
      case InputMode.touch:
        return 1.0;
      case InputMode.mouse:
        return 0.8;
      case InputMode.stylus:
        return 1.2;
      case InputMode.keyboard:
      case InputMode.gamepad:
        return 0.5;
    }
  }

  // ==========================================================================
  // 快捷键系统
  // ==========================================================================

  /// 注册快捷键
  void registerShortcut(String key, void Function() callback) {
    _shortcuts[key] = callback;
  }

  /// 取消注册快捷键
  void unregisterShortcut(String key) {
    _shortcuts.remove(key);
  }

  /// 处理键盘事件
  KeyEventResult handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = _buildShortcutKey(event);
    final callback = _shortcuts[key];

    if (callback != null) {
      callback();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// 构建快捷键标识字符串
  String _buildShortcutKey(KeyEvent event) {
    final modifiers = <String>[];
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;

    if (pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight)) {
      modifiers.add('Ctrl');
    }
    if (pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight)) {
      modifiers.add('Meta');
    }
    if (pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight)) {
      modifiers.add('Shift');
    }
    if (pressed.contains(LogicalKeyboardKey.altLeft) ||
        pressed.contains(LogicalKeyboardKey.altRight)) {
      modifiers.add('Alt');
    }

    final keyName = event.logicalKey.keyLabel;
    modifiers.add(keyName);
    return modifiers.join('+');
  }

  // ==========================================================================
  // 拖拽排序
  // ==========================================================================

  /// 开始拖拽
  void startDrag(DragData data) {
    _currentDragData = data;
    notifyListeners();
  }

  /// 结束拖拽
  void endDrag() {
    _currentDragData = null;
    notifyListeners();
  }

  // ==========================================================================
  // 右键菜单
  // ==========================================================================

  /// 显示右键菜单
  void showContextMenu() {
    _contextMenuVisible = true;
    notifyListeners();
  }

  /// 隐藏右键菜单
  void hideContextMenu() {
    _contextMenuVisible = false;
    notifyListeners();
  }

  // ==========================================================================
  // 释放资源
  // ==========================================================================

  @override
  void dispose() {
    _foldableStream.close();
    _shortcuts.clear();
    super.dispose();
  }
}

// ============================================================================
// 响应式组件
// ============================================================================

/// 自适应 Scaffold
///
/// 根据设备类型自动选择布局：
/// - 手机：单列 + 底部导航
/// - 平板：可折叠侧边栏 + 主内容
/// - 桌面：三列（导航 + 列表 + 详情）
class AdaptiveScaffold extends StatelessWidget {
  final Widget? body;
  final Widget? sidebar;
  final Widget? detailPane;
  final AdaptiveNavigation? navigation;
  final Widget? floatingActionButton;
  final Widget? appBar;
  final bool extendBodyBehindAppBar;
  final Color? backgroundColor;

  const AdaptiveScaffold({
    super.key,
    this.body,
    this.sidebar,
    this.detailPane,
    this.navigation,
    this.floatingActionButton,
    this.appBar,
    this.extendBodyBehindAppBar = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final engine = AdaptiveLayoutScope.of(context);
    final config = engine.currentConfig;

    switch (config.deviceType) {
      case DeviceType.phone:
        return _buildPhoneLayout(context, config);
      case DeviceType.tablet:
        return _buildTabletLayout(context, config);
      case DeviceType.desktop:
        return _buildDesktopLayout(context, config);
      case DeviceType.foldable:
        return _buildFoldableLayout(context, config);
    }
  }

  Widget _buildPhoneLayout(BuildContext context, LayoutConfig config) {
    return Scaffold(
      appBar: appBar is PreferredSizeWidget ? appBar as PreferredSizeWidget : null,
      body: body,
      bottomNavigationBar: navigation,
      floatingActionButton: floatingActionButton,
      backgroundColor: backgroundColor,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
    );
  }

  Widget _buildTabletLayout(BuildContext context, LayoutConfig config) {
    return Scaffold(
      appBar: appBar is PreferredSizeWidget ? appBar as PreferredSizeWidget : null,
      backgroundColor: backgroundColor,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      body: Row(
        children: [
          if (sidebar != null)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: engine_sidebarWidth(context),
              child: sidebar,
            ),
          const VerticalDivider(width: 1),
          Expanded(child: body ?? const SizedBox.shrink()),
          if (detailPane != null && config.width > 900) ...[
            const VerticalDivider(width: 1),
            SizedBox(
              width: math.min(config.width * 0.35, 480),
              child: detailPane!,
            ),
          ],
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }

  Widget _buildDesktopLayout(BuildContext context, LayoutConfig config) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Row(
        children: [
          // 导航列
          if (navigation != null)
            SizedBox(
              width: 72,
              child: navigation,
            ),
          const VerticalDivider(width: 1),
          // 列表列
          if (sidebar != null) ...[
            SizedBox(
              width: config.sidebarWidth,
              child: sidebar!,
            ),
            const VerticalDivider(width: 1),
          ],
          // 详情列
          Expanded(
            child: body ?? const SizedBox.shrink(),
          ),
          // 额外详情面板
          if (detailPane != null) ...[
            const VerticalDivider(width: 1),
            SizedBox(
              width: math.min(config.width * 0.3, 480),
              child: detailPane!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFoldableLayout(BuildContext context, LayoutConfig config) {
    final engine = AdaptiveLayoutScope.of(context);
    if (engine.foldableState == FoldableState.folded) {
      return _buildPhoneLayout(context, config);
    }
    return _buildTabletLayout(context, config);
  }

  double engine_sidebarWidth(BuildContext context) {
    final engine = AdaptiveLayoutScope.of(context);
    return engine.sidebarExpanded
        ? engine.currentConfig.sidebarWidth
        : 0;
  }
}

/// AnimatedContainer 辅助（简化版）
class AnimatedContainer extends AnimatedWidget {
  final Widget? child;
  final Duration duration;
  final double width;

  const AnimatedContainer({
    super.key,
    required this.duration,
    required this.width,
    this.child,
  }) : super(listenable: const AlwaysStoppedAnimation(1.0));

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: duration,
      child: SizedBox(width: width, child: child),
    );
  }
}

/// 自适应导航
///
/// 根据设备类型自动选择导航形式：
/// - 手机：底部导航栏
/// - 平板/折叠屏：侧边导航或底部导航
/// - 桌面：垂直侧边栏（图标 + 标签）
class AdaptiveNavigation extends StatelessWidget {
  final List<NavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int>? onDestinationSelected;
  final NavigationType? forceType;

  const AdaptiveNavigation({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    this.onDestinationSelected,
    this.forceType,
  });

  @override
  Widget build(BuildContext context) {
    final engine = AdaptiveLayoutScope.of(context);
    final navType = forceType ?? engine.currentConfig.navigationType;

    switch (navType) {
      case NavigationType.bottomBar:
        return _buildBottomBar();
      case NavigationType.sideBar:
        return _buildSideBar(engine);
      case NavigationType.topBar:
        return _buildTopBar();
      case NavigationType.none:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBottomBar() {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: destinations.map((d) => NavigationDestination(
        icon: d.icon,
        selectedIcon: d.selectedIcon ?? d.icon,
        label: d.label,
      )).toList(),
    );
  }

  Widget _buildSideBar(AdaptiveLayoutEngine engine) {
    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      extended: engine.currentConfig.width > 1200,
      labelType: engine.currentConfig.width > 1200
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.selected,
      destinations: destinations.map((d) => NavigationRailDestination(
        icon: d.icon,
        selectedIcon: d.selectedIcon ?? d.icon,
        label: Text(d.label),
      )).toList(),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: Row(
        children: [
          for (int i = 0; i < destinations.length; i++)
            InkWell(
              onTap: () => onDestinationSelected?.call(i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: i == selectedIndex
                      ? const Border(bottom: BorderSide(width: 2, color: Colors.blue))
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    selectedIndex == i
                        ? (destinations[i].selectedIcon ?? destinations[i].icon)
                        : destinations[i].icon,
                    const SizedBox(width: 8),
                    Text(
                      destinations[i].label,
                      style: TextStyle(
                        fontWeight: i == selectedIndex ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 导航目标数据
class NavigationDestination {
  final Widget icon;
  final Widget? selectedIcon;
  final String label;

  const NavigationDestination({
    required this.icon,
    this.selectedIcon,
    required this.label,
  });
}

/// 自适应聊天布局
///
/// 根据设备类型自动切换聊天界面布局：
/// - 手机：全屏聊天
/// - 平板：会话列表 + 聊天窗口
/// - 桌面：导航 + 列表 + 聊天 + 详情面板
class AdaptiveChatLayout extends StatelessWidget {
  final Widget chatView;
  final Widget? conversationList;
  final Widget? infoPanel;
  final Widget? header;
  final double? conversationListWidth;
  final double? infoPanelWidth;

  const AdaptiveChatLayout({
    super.key,
    required this.chatView,
    this.conversationList,
    this.infoPanel,
    this.header,
    this.conversationListWidth,
    this.infoPanelWidth,
  });

  @override
  Widget build(BuildContext context) {
    final engine = AdaptiveLayoutScope.of(context);
    final chatMode = engine.currentConfig.chatMode;

    switch (chatMode) {
      case ChatLayoutMode.fullScreen:
        return _buildFullScreen();
      case ChatLayoutMode.splitView:
        return _buildSplitView(engine);
      case ChatLayoutMode.multiPane:
        return _buildMultiPane(engine);
    }
  }

  Widget _buildFullScreen() {
    return Column(
      children: [
        if (header != null) header!,
        Expanded(child: chatView),
      ],
    );
  }

  Widget _buildSplitView(AdaptiveLayoutEngine engine) {
    final listWidth = conversationListWidth ?? 320;

    return Row(
      children: [
        if (conversationList != null)
          SizedBox(
            width: listWidth,
            child: conversationList!,
          ),
        if (conversationList != null) const VerticalDivider(width: 1),
        Expanded(
          child: Column(
            children: [
              if (header != null) header!,
              Expanded(child: chatView),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMultiPane(AdaptiveLayoutEngine engine) {
    final listWidth = conversationListWidth ?? 300;
    final infoWidth = infoPanelWidth ?? 320;
    final config = engine.currentConfig;

    return Row(
      children: [
        // 会话列表
        if (conversationList != null) ...[
          SizedBox(
            width: listWidth,
            child: conversationList!,
          ),
          const VerticalDivider(width: 1),
        ],
        // 聊天主区域
        Expanded(
          child: Column(
            children: [
              if (header != null) header!,
              Expanded(child: chatView),
            ],
          ),
        ),
        // 信息面板
        if (infoPanel != null && config.width > 1200) ...[
          const VerticalDivider(width: 1),
          SizedBox(
            width: math.min(infoWidth, config.width * 0.25),
            child: infoPanel!,
          ),
        ],
      ],
    );
  }
}

/// 自适应弹窗
///
/// 根据设备类型自动选择弹窗形式：
/// - 手机：底部弹窗（BottomSheet）
/// - 平板/桌面：居中弹窗（Dialog）
class AdaptiveDialog extends StatelessWidget {
  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final bool isDismissible;
  final bool showDragHandle;
  final double? maxSheetHeight;
  final double? dialogWidth;

  const AdaptiveDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.isDismissible = true,
    this.showDragHandle = true,
    this.maxSheetHeight,
    this.dialogWidth,
  });

  /// 显示自适应弹窗
  static Future<T?> show<T>({
    required BuildContext context,
    Widget? title,
    Widget? content,
    List<Widget>? actions,
    bool isDismissible = true,
  }) {
    final engine = AdaptiveLayoutScope.of(context);
    final config = engine.currentConfig;

    if (config.dialogMode == DialogMode.bottomSheet) {
      return showModalBottomSheet<T>(
        context: context,
        isDismissible: isDismissible,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: AdaptiveDialog(
            title: title,
            content: content,
            actions: actions,
          ),
        ),
      );
    } else {
      return showDialog<T>(
        context: context,
        barrierDismissible: isDismissible,
        builder: (ctx) => AlertDialog(
          title: title,
          content: SizedBox(
            width: 480,
            child: content,
          ),
          actions: actions,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DefaultTextStyle(
                  style: Theme.of(context).textTheme.titleLarge!,
                  child: title!,
                ),
              ),
            if (content != null) Flexible(child: content!),
            if (actions != null && actions!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 自适应网格
///
/// 根据可用宽度自动计算列数
class AdaptiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final int minColumns;
  final int maxColumns;
  final double minItemWidth;
  final double maxItemWidth;

  const AdaptiveGrid({
    super.key,
    required this.children,
    this.spacing = 12,
    this.runSpacing = 12,
    this.minColumns = 1,
    this.maxColumns = 6,
    this.minItemWidth = 280,
    this.maxItemWidth = 480,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _calculateColumns(constraints.maxWidth);
        final itemWidth = (constraints.maxWidth - (columns - 1) * spacing) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: children.map((child) => SizedBox(
            width: itemWidth.clamp(minItemWidth, maxItemWidth),
            child: child,
          )).toList(),
        );
      },
    );
  }

  int _calculateColumns(double width) {
    final cols = (width / (minItemWidth + spacing)).floor();
    return cols.clamp(minColumns, maxColumns);
  }
}

// ============================================================================
// InheritedWidget - 布局引擎注入
// ============================================================================

/// 将 [AdaptiveLayoutEngine] 注入到 Widget 树中
class AdaptiveLayoutScope extends StatefulWidget {
  final AdaptiveLayoutEngine engine;
  final Widget child;

  const AdaptiveLayoutScope({
    super.key,
    required this.engine,
    required this.child,
  });

  /// 从 Widget 树中获取引擎
  static AdaptiveLayoutEngine of(BuildContext context) {
    final inherited = context.dependOnInheritedWidgetOfExactType<_AdaptiveLayoutInherited>();
    assert(inherited != null, 'AdaptiveLayoutScope not found in widget tree');
    return inherited!.engine;
  }

  /// 可选获取
  static AdaptiveLayoutEngine? maybeOf(BuildContext context) {
    final inherited = context.dependOnInheritedWidgetOfExactType<_AdaptiveLayoutInherited>();
    return inherited?.engine;
  }

  @override
  State<AdaptiveLayoutScope> createState() => _AdaptiveLayoutScopeState();
}

class _AdaptiveLayoutScopeState extends State<AdaptiveLayoutScope> {
  @override
  void initState() {
    super.initState();
    widget.engine.addListener(_onEngineChanged);
  }

  @override
  void didUpdateWidget(AdaptiveLayoutScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.engine != widget.engine) {
      oldWidget.engine.removeListener(_onEngineChanged);
      widget.engine.addListener(_onEngineChanged);
    }
  }

  @override
  void dispose() {
    widget.engine.removeListener(_onEngineChanged);
    super.dispose();
  }

  void _onEngineChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return _AdaptiveLayoutInherited(
      engine: widget.engine,
      child: widget.child,
    );
  }
}

/// InheritedWidget 传递引擎
class _AdaptiveLayoutInherited extends InheritedWidget {
  final AdaptiveLayoutEngine engine;

  const _AdaptiveLayoutInherited({
    required this.engine,
    required super.child,
  });

  @override
  bool updateShouldNotify(_AdaptiveLayoutInherited oldWidget) {
    return engine != oldWidget.engine;
  }
}

// ============================================================================
// 辅助组件
// ============================================================================

/// 右键菜单检测组件
///
/// 在桌面端监听右键点击，在移动端长按
class ContextMenuDetector extends StatelessWidget {
  final Widget child;
  final void Function(Offset position) onContextMenu;
  final Duration longPressDuration;

  const ContextMenuDetector({
    super.key,
    required this.child,
    required this.onContextMenu,
    this.longPressDuration = const Duration(milliseconds: 500),
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        if (event.buttons == kSecondaryMouseButton) {
          onContextMenu(event.position);
        }
      },
      child: GestureDetector(
        onLongPressStart: (details) {
          onContextMenu(details.globalPosition);
        },
        child: child,
      ),
    );
  }
}

/// 自适应间距组件
///
/// 根据布局紧凑度自动调整间距
class AdaptiveSpacing extends StatelessWidget {
  final double compactSpacing;
  final double normalSpacing;
  final double wideSpacing;
  final Axis direction;

  const AdaptiveSpacing({
    super.key,
    this.compactSpacing = 8,
    this.normalSpacing = 16,
    this.wideSpacing = 24,
    this.direction = Axis.vertical,
  });

  @override
  Widget build(BuildContext context) {
    final engine = AdaptiveLayoutScope.maybeOf(context);
    if (engine == null) return _buildSpacer(normalSpacing);

    final config = engine.currentConfig;
    double space;
    if (config.isCompact) {
      space = compactSpacing;
    } else if (config.isWideLayout) {
      space = wideSpacing;
    } else {
      space = normalSpacing;
    }

    return _buildSpacer(space);
  }

  Widget _buildSpacer(double size) {
    return SizedBox(
      width: direction == Axis.horizontal ? size : 0,
      height: direction == Axis.vertical ? size : 0,
    );
  }
}
