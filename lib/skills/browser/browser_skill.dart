// ============================================================================
// 小酥 AI 助手 - 浏览器自动化技能
// ============================================================================
// 提供完整的浏览器自动化能力
// 支持页面导航、元素交互、截图、数据提取、反爬处理等
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../../core/skill/skill.dart';

// ============================================================================
// 浏览器引擎抽象层
// ============================================================================

/// 浏览器引擎类型
enum BrowserEngineType {
  /// 内置 WebView（移动端）
  webView('webview'),

  /// Puppeteer / CDP 协议（桌面端/服务端）
  puppeteer('puppeteer'),

  /// Playwright 协议
  playwright('playwright');

  final String value;
  const BrowserEngineType(this.value);
}

/// 元素定位策略
enum LocatorStrategy {
  css('css'),
  xpath('xpath'),
  text('text'),
  attribute('attribute'),
  id('id'),
  className('class_name'),
  tagName('tag_name');

  final String value;
  const LocatorStrategy(this.value);
}

/// 等待条件类型
enum WaitCondition {
  elementVisible('element_visible'),
  elementClickable('element_clickable'),
  pageLoaded('page_loaded'),
  networkIdle('network_idle'),
  textPresent('text_present'),
  elementHidden('element_hidden');

  final String value;
  const WaitCondition(this.value);
}

/// 鼠标按键
enum MouseButton {
  left('left'),
  right('right'),
  middle('middle');

  final String value;
  const MouseButton(this.value);
}

// ============================================================================
// 页面元素模型
// ============================================================================

/// 浏览器页面元素
class PageElement {
  /// 元素标签名
  final String tagName;

  /// 元素文本内容
  final String? text;

  /// 元素属性
  final Map<String, String> attributes;

  /// 元素在页面中的位置
  final ElementRect? rect;

  /// 是否可见
  final bool visible;

  /// 是否可交互
  final bool enabled;

  /// 是否被选中（checkbox / radio / option）
  final bool selected;

  /// 子元素
  final List<PageElement> children;

  /// 元素唯一标识（内部使用）
  final String nodeId;

  const PageElement({
    required this.tagName,
    this.text,
    this.attributes = const {},
    this.rect,
    this.visible = true,
    this.enabled = true,
    this.selected = false,
    this.children = const [],
    required this.nodeId,
  });

  /// 获取指定属性值
  String? attr(String name) => attributes[name];

  /// 获取元素的 id 属性
  String? get id => attributes['id'];

  /// 获取元素的 class 属性
  String? get className => attributes['class'];

  /// 获取元素的 href 属性
  String? get href => attributes['href'];

  /// 获取元素的 src 属性
  String? get src => attributes['src'];

  /// 获取元素的 value（input / textarea）
  String? get value => attributes['value'];

  Map<String, dynamic> toJson() => {
        'tag_name': tagName,
        if (text != null) 'text': text,
        'attributes': attributes,
        if (rect != null) 'rect': rect!.toJson(),
        'visible': visible,
        'enabled': enabled,
        'selected': selected,
        'node_id': nodeId,
        if (children.isNotEmpty)
          'children': children.map((c) => c.toJson()).toList(),
      };
}

/// 元素矩形区域
class ElementRect {
  final double x;
  final double y;
  final double width;
  final double height;

  const ElementRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  double get centerX => x + width / 2;
  double get centerY => y + height / 2;

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      };
}

// ============================================================================
// 浏览器会话模型
// ============================================================================

/// 浏览器会话（一个标签页 / 一个 context）
class BrowserSession {
  /// 会话 ID
  final String sessionId;

  /// 当前页面 URL
  String currentUrl;

  /// 页面标题
  String title;

  /// Cookie 存储
  final Map<String, Map<String, String>> cookies = {};

  /// 本地存储
  final Map<String, String> localStorage = {};

  /// 会话创建时间
  final DateTime createdAt;

  /// 最后活动时间
  DateTime lastActiveAt;

  /// 是否保持登录态
  bool keepLoginState;

  /// User-Agent
  String userAgent;

  BrowserSession({
    required this.sessionId,
    this.currentUrl = 'about:blank',
    this.title = '',
    this.createdAt,
    this.lastActiveAt,
    this.keepLoginState = false,
    this.userAgent = '',
  })  : createdAt = createdAt ?? DateTime.now(),
        lastActiveAt = lastActiveAt ?? DateTime.now();

  /// 设置 Cookie
  void setCookie(String domain, String name, String value) {
    cookies.putIfAbsent(domain, () => {});
    cookies[domain]![name] = value;
    lastActiveAt = DateTime.now();
  }

  /// 获取 Cookie
  String? getCookie(String domain, String name) {
    return cookies[domain]?[name];
  }

  /// 获取某域名下所有 Cookie 字符串
  String getCookiesString(String domain) {
    final domainCookies = cookies[domain];
    if (domainCookies == null) return '';
    return domainCookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'current_url': currentUrl,
        'title': title,
        'created_at': createdAt.toIso8601String(),
        'last_active_at': lastActiveAt.toIso8601String(),
        'keep_login_state': keepLoginState,
      };
}

// ============================================================================
// 反爬策略
// ============================================================================

/// 反爬处理配置
class AntiDetectionConfig {
  /// 是否启用随机延迟
  final bool enableRandomDelay;

  /// 最小延迟毫秒
  final int minDelayMs;

  /// 最大延迟毫秒
  final int maxDelayMs;

  /// 是否轮换 User-Agent
  final bool rotateUserAgent;

  /// 代理地址列表
  final List<String> proxyUrls;

  /// 是否禁用 Webdriver 标识
  final bool hideWebdriverFlag;

  /// 是否模拟人类鼠标轨迹
  final bool simulateHumanMouse;

  /// 请求间隔基数（毫秒）
  final int requestIntervalMs;

  const AntiDetectionConfig({
    this.enableRandomDelay = true,
    this.minDelayMs = 500,
    this.maxDelayMs = 3000,
    this.rotateUserAgent = true,
    this.proxyUrls = const [],
    this.hideWebdriverFlag = true,
    this.simulateHumanMouse = true,
    this.requestIntervalMs = 1000,
  });
}

/// 常用 User-Agent 池
class _UserAgentPool {
  static const List<String> _agents = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_4) AppleWebKit/605.1.15 '
        '(KHTML, like Gecko) Version/17.4 Safari/605.1.15',
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:125.0) '
        'Gecko/20100101 Firefox/125.0',
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 '
        'Mobile/15E148 Safari/604.1',
  ];

  static String get random =>
      _agents[Random().nextInt(_agents.length)];
}

// ============================================================================
// 数据提取模型
// ============================================================================

/// 提取的表格数据
class ExtractedTable {
  final String? caption;
  final List<String> headers;
  final List<List<String>> rows;

  const ExtractedTable({
    this.caption,
    required this.headers,
    required this.rows,
  });

  int get rowCount => rows.length;
  int get colCount => headers.length;

  /// 转为 CSV 格式
  String toCsv() {
    final buffer = StringBuffer();
    buffer.writeln(headers.join(','));
    for (final row in rows) {
      buffer.writeln(row.map((cell) {
        if (cell.contains(',') || cell.contains('"')) {
          return '"${cell.replaceAll('"', '""')}"';
        }
        return cell;
      }).join(','));
    }
    return buffer.toString();
  }

  /// 转为 JSON
  List<Map<String, String>> toJsonList() {
    return rows.map((row) {
      final map = <String, String>{};
      for (int i = 0; i < headers.length && i < row.length; i++) {
        map[headers[i]] = row[i];
      }
      return map;
    }).toList();
  }
}

/// 提取的列表数据
class ExtractedList {
  final List<String> items;
  final String? listType;

  const ExtractedList({
    required this.items,
    this.listType,
  });
}

// ============================================================================
// 浏览器自动化技能
// ============================================================================

/// 浏览器自动化技能
/// 提供 open_url, click_element, fill_form, take_screenshot 等 13 个工具
class BrowserSkill extends Skill {
  /// 技能配置
  final BrowserSkillConfig _config;

  /// 活跃会话列表
  final Map<String, BrowserSession> _sessions = {};

  /// 默认会话 ID
  String? _defaultSessionId;

  /// 反爬配置
  late final AntiDetectionConfig _antiDetection;

  /// 截图计数器
  int _screenshotCounter = 0;

  BrowserSkill({BrowserSkillConfig? config})
      : _config = config ?? const BrowserSkillConfig(),
        _antiDetection = config?.antiDetection ?? const AntiDetectionConfig();

  // ============================================================================
  // 技能元数据
  // ============================================================================

  @override
  SkillManifest get manifest => const SkillManifest(
        id: 'browser',
        name: '浏览器自动化',
        description: '控制浏览器执行自动化操作。支持打开网页、点击元素、填写表单、'
            '截图、提取文本、滚动、等待条件、选择下拉、上传文件、执行 JS、'
            '获取页面内容、登录网站、下载文件等操作。',
        version: '1.0.0',
        author: '小酥',
        permissions: [
          SkillPermission.networkAccess,
          SkillPermission.fileRead,
          SkillPermission.fileWrite,
          SkillPermission.mediaAccess,
        ],
        loadStrategy: SkillLoadStrategy.lazy,
      );

  @override
  List<SkillTool> get tools => [
        _openUrlTool,
        _clickElementTool,
        _fillFormTool,
        _takeScreenshotTool,
        _extractTextTool,
        _scrollPageTool,
        _waitForTool,
        _selectOptionTool,
        _uploadFileTool,
        _executeJsTool,
        _getPageContentTool,
        _loginSiteTool,
        _downloadFileTool,
      ];

  // ============================================================================
  // 工具定义
  // ============================================================================

  /// open_url - 打开指定 URL
  late final SkillTool _openUrlTool = SkillTool(
    name: 'open_url',
    description: '在浏览器中打开指定 URL。支持设置等待策略和页面加载超时。',
    parameters: [
      ToolParameter(
        name: 'url',
        description: '要打开的网页地址',
        type: ToolParameterType.stringType,
        required: true,
      ),
      ToolParameter(
        name: 'wait_until',
        description: '页面加载完成条件',
        type: ToolParameterType.stringType,
        enumValues: ['load', 'dom_content_loaded', 'network_idle', 'complete'],
        defaultValue: 'load',
      ),
      ToolParameter(
        name: 'timeout_ms',
        description: '页面加载超时（毫秒）',
        type: ToolParameterType.intType,
        minValue: 1000,
        maxValue: 120000,
        defaultValue: 30000,
      ),
      ToolParameter(
        name: 'new_session',
        description: '是否在新会话中打开',
        type: ToolParameterType.boolType,
        defaultValue: false,
      ),
    ],
    timeoutMs: 120000,
    execute: _executeOpenUrl,
  );

  /// click_element - 点击页面元素
  late final SkillTool _clickElementTool = SkillTool(
    name: 'click_element',
    description: '点击页面中的指定元素。支持 CSS 选择器、XPath、文本匹配等定位方式。'
        '支持单击、双击、右键等操作。',
    parameters: [
      ToolParameter(
        name: 'selector',
        description: '元素定位表达式',
        type: ToolParameterType.stringType,
        required: true,
      ),
      ToolParameter(
        name: 'strategy',
        description: '元素定位策略',
        type: ToolParameterType.stringType,
        enumValues: ['css', 'xpath', 'text', 'attribute', 'id'],
        defaultValue: 'css',
      ),
      ToolParameter(
        name: 'button',
        description: '鼠标按键',
        type: ToolParameterType.stringType,
        enumValues: ['left', 'right', 'middle'],
        defaultValue: 'left',
      ),
      ToolParameter(
        name: 'click_count',
        description: '点击次数（2 表示双击）',
        type: ToolParameterType.intType,
        minValue: 1,
        maxValue: 3,
        defaultValue: 1,
      ),
      ToolParameter(
        name: 'force',
        description: '是否强制点击（忽略可交互性检查）',
        type: ToolParameterType.boolType,
        defaultValue: false,
      ),
      ToolParameter(
        name: 'session_id',
        description: '浏览器会话 ID',
        type: ToolParameterType.stringType,
      ),
    ],
    timeoutMs: 15000,
    execute: _executeClickElement,
  );

  /// fill_form - 填写表单
  late final SkillTool _fillFormTool = SkillTool(
    name: 'fill_form',
    description: '填写表单字段。支持 input、textarea、contenteditable 等元素。'
        '可一次填写多个字段。',
    parameters: [
      ToolParameter(
        name: 'fields',
        description: '表单字段列表，每个字段包含 selector 和 value',
        type: ToolParameterType.arrayType,
        required: true,
      ),
      ToolParameter(
        name: 'clear_first',
        description: '填写前是否先清空',
        type: ToolParameterType.boolType,
        defaultValue: true,
      ),
      ToolParameter(
        name: 'type_delay_ms',
        description: '每个字符输入间隔（毫秒），0 表示立即填入',
        type: ToolParameterType.intType,
        minValue: 0,
        maxValue: 500,
        defaultValue: 0,
      ),
      ToolParameter(
        name: 'session_id',
        description: '浏览器会话 ID',
        type: ToolParameterType.stringType,
      ),
    ],
    timeoutMs: 30000,
    execute: _executeFillForm,
  );

  /// take_screenshot - 页面截图
  late final SkillTool _takeScreenshotTool = SkillTool(
    name: 'take_screenshot',
    description: '对当前页面进行截图。支持全页截图和指定元素截图。',
    parameters: [
      ToolParameter(
        name: 'full_page',
        description: '是否全页截图',
        type: ToolParameterType.boolType,
        defaultValue: false,
      ),
      ToolParameter(
        name: 'selector',
        description: '指定元素截图（CSS 选择器）',
        type: ToolParameterType.stringType,
      ),
      ToolParameter(
        name: 'format',
        description: '图片格式',
        type: ToolParameterType.stringType,
        enumValues: ['png', 'jpeg', 'webp'],
        defaultValue: 'png',
      ),
      ToolParameter(
        name: 'quality',
        description: '图片质量（1-100，仅 jpeg/webp）',
        type: ToolParameterType.intType,
        minValue: 1,
        maxValue: 100,
        defaultValue: 80,
      ),
      ToolParameter(
        name: 'save_path',
        description: '保存路径',
        type: ToolParameterType.stringType,
      ),
      ToolParameter(
        name: 'session_id',
        description: '浏览器会话 ID',
        type: ToolParameterType.stringType,
      ),
    ],
    timeoutMs: 15000,
    execute: _executeTakeScreenshot,
  );

  /// extract_text - 提取页面文本
  late final SkillTool _extractTextTool = SkillTool(
    name: 'extract_text',
    description: '从页面中提取文本内容。支持提取表格、列表、纯文本等结构化数据。',
    parameters: [
      ToolParameter(
        name: 'selector',
        description: '要提取文本的元素选择器',
        type: ToolParameterType.stringType,
        required: true,
      ),
      ToolParameter(
        name: 'strategy',
        description: '定位策略',
        type: ToolParameterType.stringType,
        enumValues: ['css', 'xpath', 'text', 'attribute', 'id'],
        defaultValue: 'css',
      ),
      ToolParameter(
        name: 'extract_type',
        description: '提取类型',
        type: ToolParameterType.stringType,
        enumValues: ['text', 'table', 'list', 'html', 'attribute'],
        defaultValue: 'text',
      ),
      ToolParameter(
        name: 'attribute_name',
        description: '要提取的属性名（extract_type 为 attribute 时必填）',
        type: ToolParameterType.stringType,
      ),
      ToolParameter(
        name: 'session_id',
        description: '浏览器会话 ID',
        type: ToolParameterType.stringType,
      ),
    ],
    timeoutMs: 15000,
    execute: _executeExtractText,
  );

  /// scroll_page - 滚动页面
  late final SkillTool _scrollPageTool = SkillTool(
    name: 'scroll_page',
    description: '滚动页面或指定元素。支持滚动到顶部、底部、指定位置或指定元素。',
    parameters: [
      ToolParameter(
        name: 'direction',
        description: '滚动方向',
        type: ToolParameterType.stringType,
        enumValues: ['up', 'down', 'left', 'right'],
        defaultValue: 'down',
      ),
      ToolParameter(
        name: 'amount',
        description: '滚动距离（像素）',
        type: ToolParameterType.intType,
        minValue: 1,
        defaultValue: 500,
      ),
      ToolParameter(
        name: 'to_element',
        description: '滚动到指定元素（CSS 选择器）',
        type: ToolParameterType.stringType,
      ),
      ToolParameter(
        name: 'to_position',
        description: '滚动到指定位置：top / bottom',
        type: ToolParameterType.stringType,
        enumValues: ['top', 'bottom'],
      ),
      ToolParameter(
        name: 'smooth',
        description: '是否平滑滚动',
        type: ToolParameterType.boolType,
        defaultValue: true,
      ),
      ToolParameter(
        name: 'session_id',
        description: '浏览器会话 ID',
        type: ToolParameterType.stringType,
      ),
    ],
    timeoutMs: 10000,
    execute: _executeScrollPage,
  );

  /// wait_for - 等待条件满足
  late final SkillTool _waitForTool = SkillTool(
    name: 'wait_for',
    description: '等待页面满足指定条件。支持等待元素出现、页面加载完成、'
        '网络空闲、文本出现等。',
    parameters: [
      ToolParameter(
        name: 'condition',
        description: '等待条件类型',
        type: ToolParameterType.stringType,
        required: true,
        enumValues: [
          'element_visible',
          'element_clickable',
          'page_loaded',
          'network_idle',
          'text_present',
          'element_hidden',
        ],
      ),
      ToolParameter(
        name: 'selector',
        description: '元素选择器（element_visible / element_clickable / element_hidden 时必填）',
        type: ToolParameterType.stringType,
      ),
      ToolParameter(
        name: 'text',
        description: '等待出现的文本（text_present 时必填）',
        type: ToolParameterType.stringType,
      ),
      ToolParameter(
        name: 'timeout_ms',
        description: '等待超时（毫秒）',
        type: ToolParameterType.intType,
        minValue: 100,
        maxValue: 120000,
        defaultValue: 10000,
      ),
      ToolParameter(
        name: 'session_id',
        description: '浏览器会话 ID',
        type: ToolParameterType.stringType,
      ),
    ],
    timeoutMs: 120000,
    execute: _executeWaitFor,
  );

  /// select_option - 下拉选择
  late final SkillTool _selectOptionTool = SkillTool(
    name: 'select_option',
    description: '在下拉列表（select）中选择选项。支持按 value、文本、索引选择。',
    parameters: [
      ToolParameter(
        name: 'selector',
        description: 'select 元素选择器',
        type: ToolParameterType.stringType,
        required: true,
      ),
      ToolParameter(
        name: 'by',
        description: '选择方式',
        type: ToolParameterType.stringType,
        enumValues: ['value', 'text', 'index'],
        defaultValue: 'value',
      ),
      ToolParameter(
        name: 'value',
        description: '选项值（by=value 时）或文本（by=text 时）',
        type: ToolParameterType.stringType,
      ),
      ToolParameter(
        name: 'index',
        description: '选项索引（by=index 时，从 0 开始）',
        type: ToolParameterType.intType,
        minValue: 0,
      ),
      ToolParameter(
        name: 'session_id',
        description: '浏览器会话 ID',
        type: ToolParameterType.stringType,
      ),
    ],
    timeoutMs: 10000,
    execute: _executeSelectOption,
  );

  /// upload_file - 文件上传
  late final SkillTool _uploadFileTool = SkillTool(
    name: 'upload_file',
    description: '上传文件到文件输入元素。支持 input[type=file] 元素。',
    parameters: [
      ToolParameter(
        name: 'selector',
        description: '文件输入元素选择器',
        type: ToolParameterType.stringType,
        required: true,
      ),
      ToolParameter(
        name: 'file_path',
        description: '要上传的文件本地路径',
        type: ToolParameterType.stringType,
        required: true,
      ),
      ToolParameter(
        name: 'session_id',
        description: '浏览器会话 ID',
        type: ToolParameterType.stringType,
      ),
    ],
    timeoutMs: 30000,
    execute: _executeUploadFile,
  );

  /// execute_js - 执行 JavaScript
  late final SkillTool _executeJsTool = SkillTool(
    name: 'execute_js',
    description: '在页面上下文中执行 JavaScript 代码。'
        '可获取页面信息、操作 DOM、调用页面函数等。',
    parameters: [
      ToolParameter(
        name: 'script',
        description: '要执行的 JavaScript 代码',
        type: ToolParameterType.stringType,
        required: true,
      ),
      ToolParameter(
        name: 'args',
        description: '传递给脚本的参数列表',
        type: ToolParameterType.arrayType,
      ),
      ToolParameter(
        name: 'return_by',
        description: '返回值获取方式',
        type: ToolParameterType.stringType,
        enumValues: ['promise', 'value'],
        defaultValue: 'value',
      ),
      ToolParameter(
        name: 'session_id',
        description: '浏览器会话 ID',
        type: ToolParameterType.stringType,
      ),
    ],
    timeoutMs: 30000,
    execute: _executeExecuteJs,
  );

  /// get_page_content - 获取页面内容
  late final SkillTool _getPageContentTool = SkillTool(
    name: 'get_page_content',
    description: '获取当前页面的完整内容。支持获取 HTML、纯文本、Markdown 等格式。',
    parameters: [
      ToolParameter(
        name: 'format',
        description: '内容格式',
        type: ToolParameterType.stringType,
        enumValues: ['html', 'text', 'markdown'],
        defaultValue: 'markdown',
      ),
      ToolParameter(
        name: 'max_length',
        description: '最大内容长度（字符数）',
        type: ToolParameterType.intType,
        minValue: 100,
        maxValue: 100000,
        defaultValue: 10000,
      ),
      ToolParameter(
        name: 'include_metadata',
        description: '是否包含页面元信息（title / description / keywords）',
        type: ToolParameterType.boolType,
        defaultValue: true,
      ),
      ToolParameter(
        name: 'session_id',
        description: '浏览器会话 ID',
        type: ToolParameterType.stringType,
      ),
    ],
    timeoutMs: 15000,
    execute: _executeGetPageContent,
  );

  /// login_site - 网站登录
  late final SkillTool _loginSiteTool = SkillTool(
    name: 'login_site',
    description: '自动登录网站。提供用户名密码，技能自动定位登录表单并完成登录。'
        '登录后可保持会话状态。',
    parameters: [
      ToolParameter(
        name: 'url',
        description: '登录页面 URL',
        type: ToolParameterType.stringType,
        required: true,
      ),
      ToolParameter(
        name: 'username',
        description: '用户名 / 邮箱',
        type: ToolParameterType.stringType,
        required: true,
      ),
      ToolParameter(
        name: 'password',
        description: '密码',
        type: ToolParameterType.stringType,
        required: true,
      ),
      ToolParameter(
        name: 'username_selector',
        description: '用户名输入框选择器',
        type: ToolParameterType.stringType,
      ),
      ToolParameter(
        name: 'password_selector',
        description: '密码输入框选择器',
        type: ToolParameterType.stringType,
      ),
      ToolParameter(
        name: 'submit_selector',
        description: '提交按钮选择器',
        type: ToolParameterType.stringType,
      ),
      ToolParameter(
        name: 'keep_login',
        description: '是否保持登录状态',
        type: ToolParameterType.boolType,
        defaultValue: true,
      ),
      ToolParameter(
        name: 'success_check',
        description: '登录成功判断条件（URL 包含的文本或 CSS 选择器）',
        type: ToolParameterType.stringType,
      ),
    ],
    timeoutMs: 60000,
    execute: _executeLoginSite,
  );

  /// download_file - 下载文件
  late final SkillTool _downloadFileTool = SkillTool(
    name: 'download_file',
    description: '从网页下载文件。支持触发下载链接和保存 Blob 数据。',
    parameters: [
      ToolParameter(
        name: 'url',
        description: '文件下载地址',
        type: ToolParameterType.stringType,
      ),
      ToolParameter(
        name: 'click_selector',
        description: '点击下载按钮/链接的选择器（与 url 二选一）',
        type: ToolParameterType.stringType,
      ),
      ToolParameter(
        name: 'save_path',
        description: '文件保存路径',
        type: ToolParameterType.stringType,
        required: true,
      ),
      ToolParameter(
        name: 'filename',
        description: '指定保存的文件名',
        type: ToolParameterType.stringType,
      ),
      ToolParameter(
        name: 'wait_ms',
        description: '等待下载完成的时间（毫秒）',
        type: ToolParameterType.intType,
        minValue: 1000,
        maxValue: 120000,
        defaultValue: 30000,
      ),
      ToolParameter(
        name: 'session_id',
        description: '浏览器会话 ID',
        type: ToolParameterType.stringType,
      ),
    ],
    timeoutMs: 120000,
    execute: _executeDownloadFile,
  );

  // ============================================================================
  // 生命周期
  // ============================================================================

  @override
  Future<void> onInitialize(SkillContext context) async {
    context.logger.info('浏览器自动化技能初始化完成');
    context.logger.info('引擎类型: ${_config.engineType.value}');
    context.logger.info(
        '反爬策略: delay=${_antiDetection.enableRandomDelay}, '
        'ua_rotate=${_antiDetection.rotateUserAgent}');
  }

  @override
  Future<void> onDispose() async {
    // 关闭所有会话
    for (final session in _sessions.values) {
      session.cookies.clear();
      session.localStorage.clear();
    }
    _sessions.clear();
    _defaultSessionId = null;
  }

  // ============================================================================
  // 会话管理
  // ============================================================================

  /// 获取或创建默认会话
  BrowserSession _getOrCreateSession(String? sessionId) {
    if (sessionId != null && _sessions.containsKey(sessionId)) {
      return _sessions[sessionId]!;
    }
    if (_defaultSessionId != null && _sessions.containsKey(_defaultSessionId)) {
      return _sessions[_defaultSessionId]!;
    }
    final newSession = _createSession();
    _defaultSessionId = newSession.sessionId;
    return newSession;
  }

  /// 创建新会话
  BrowserSession _createSession() {
    final id = 'bs_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    final ua = _antiDetection.rotateUserAgent
        ? _UserAgentPool.random
        : _config.defaultUserAgent;
    final session = BrowserSession(
      sessionId: id,
      userAgent: ua,
    );
    _sessions[id] = session;
    return session;
  }

  // ============================================================================
  // 工具实现
  // ============================================================================

  /// open_url 实现
  Future<ToolResult> _executeOpenUrl(
    Map<String, dynamic> args,
    SkillContext context,
  ) async {
    final url = args['url'] as String;
    final waitUntil = args['wait_until'] as String? ?? 'load';
    final newSession = args['new_session'] as bool? ?? false;

    if (!_isValidUrl(url)) {
      return ToolResult.failure(error: '无效的 URL: $url', errorCode: 'INVALID_URL');
    }

    final session = newSession ? _createSession() : _getOrCreateSession(null);
    if (newSession && _defaultSessionId == null) {
      _defaultSessionId = session.sessionId;
    }

    context.logger.info('打开页面: $url (会话: ${session.sessionId})');

    // 反爬：应用随机延迟
    if (_antiDetection.enableRandomDelay) {
      final delay = _randomDelay();
      context.logger.debug('反爬延迟: ${delay.inMilliseconds}ms');
      await Future.delayed(delay);
    }

    // 通过 API 协议打开页面
    final startTime = Stopwatch()..start();
    try {
      final requestBody = {
        'action': 'navigate',
        'url': url,
        'wait_until': waitUntil,
        'session_id': session.sessionId,
        'user_agent': session.userAgent,
      };

      final response = await context.http.post(
        '${_config.engineEndpoint}/navigate',
        headers: _buildHeaders(session),
        body: requestBody,
      );

      final data = jsonDecode(response) as Map<String, dynamic>;
      session.currentUrl = data['url'] as String? ?? url;
      session.title = data['title'] as String? ?? '';

      startTime.stop();
      return ToolResult.success(
        content: '已打开页面: ${session.title}\nURL: ${session.currentUrl}',
        data: {
          'session_id': session.sessionId,
          'url': session.currentUrl,
          'title': session.title,
          'duration_ms': startTime.elapsedMilliseconds,
        },
        durationMs: startTime.elapsedMilliseconds,
      );
    } catch (e) {
      startTime.stop();
      context.logger.error('页面加载失败', e);
      return ToolResult.failure(
        error: '页面加载失败: $e',
        errorCode: 'NAVIGATION_FAILED',
        durationMs: startTime.elapsedMilliseconds,
      );
    }
  }

  /// click_element 实现
  Future<ToolResult> _executeClickElement(
    Map<String, dynamic> args,
    SkillContext context,
  ) async {
    final selector = args['selector'] as String;
    final strategy = args['strategy'] as String? ?? 'css';
    final button = args['button'] as String? ?? 'left';
    final clickCount = args['click_count'] as int? ?? 1;
    final force = args['force'] as bool? ?? false;
    final sessionId = args['session_id'] as String?;

    final session = _getOrCreateSession(sessionId);
    context.logger.info('点击元素: [$strategy] $selector');

    // 反爬：模拟人类操作延迟
    if (_antiDetection.simulateHumanMouse) {
      await Future.delayed(Duration(milliseconds: 100 + Random().nextInt(300)));
    }

    final locatorPayload = _buildLocatorPayload(strategy, selector);

    try {
      final response = await context.http.post(
        '${_config.engineEndpoint}/click',
        headers: _buildHeaders(session),
        body: {
          'session_id': session.sessionId,
          'locator': locatorPayload,
          'button': button,
          'click_count': clickCount,
          'force': force,
        },
      );

      final data = jsonDecode(response) as Map<String, dynamic>;
      final elementInfo = data['element'] as Map<String, dynamic>?;

      return ToolResult.success(
        content: '已点击元素: $selector ($strategy)',
        data: {
          'session_id': session.sessionId,
          'selector': selector,
          'strategy': strategy,
          'button': button,
          'click_count': clickCount,
          if (elementInfo != null) 'element': elementInfo,
        },
      );
    } catch (e) {
      context.logger.error('点击失败', e);
      return ToolResult.failure(
        error: '点击元素失败: $e',
        errorCode: 'CLICK_FAILED',
      );
    }
  }

  /// fill_form 实现
  Future<ToolResult> _executeFillForm(
    Map<String, dynamic> args,
    SkillContext context,
  ) async {
    final fields = args['fields'] as List;
    final clearFirst = args['clear_first'] as bool? ?? true;
    final typeDelay = args['type_delay_ms'] as int? ?? 0;
    final sessionId = args['session_id'] as String?;

    final session = _getOrCreateSession(sessionId);
    context.logger.info('填写表单: ${fields.length} 个字段');

    final filledFields = <String>[];

    try {
      for (final field in fields) {
        final fieldMap = field as Map<String, dynamic>;
        final fieldSelector = fieldMap['selector'] as String;
        final fieldValue = fieldMap['value']?.toString() ?? '';
        final fieldStrategy = fieldMap['strategy'] as String? ?? 'css';

        final locatorPayload = _buildLocatorPayload(fieldStrategy, fieldSelector);

        await context.http.post(
          '${_config.engineEndpoint}/fill',
          headers: _buildHeaders(session),
          body: {
            'session_id': session.sessionId,
            'locator': locatorPayload,
            'value': fieldValue,
            'clear_first': clearFirst,
            'type_delay_ms': typeDelay,
          },
        );

        filledFields.add(fieldSelector);

        // 字段间延迟，模拟人类输入节奏
        if (typeDelay > 0 && fields.indexOf(field) < fields.length - 1) {
          await Future.delayed(Duration(milliseconds: 200 + Random().nextInt(300)));
        }
      }

      return ToolResult.success(
        content: '已填写 ${filledFields.length} 个表单字段',
        data: {
          'session_id': session.sessionId,
          'filled_fields': filledFields,
          'field_count': filledFields.length,
        },
      );
    } catch (e) {
      context.logger.error('表单填写失败', e);
      return ToolResult.failure(
        error: '表单填写失败: $e（已填写: ${filledFields.join(", ")}）',
        errorCode: 'FILL_FAILED',
      );
    }
  }

  /// take_screenshot 实现
  Future<ToolResult> _executeTakeScreenshot(
    Map<String, dynamic> args,
    SkillContext context,
  ) async {
    final fullPage = args['full_page'] as bool? ?? false;
    final selector = args['selector'] as String?;
    final format = args['format'] as String? ?? 'png';
    final quality = args['quality'] as int? ?? 80;
    final savePath = args['save_path'] as String?;
    final sessionId = args['session_id'] as String?;

    final session = _getOrCreateSession(sessionId);
    _screenshotCounter++;

    final fileName = savePath ?? 'screenshot_${_screenshotCounter}_${DateTime.now().millisecondsSinceEpoch}.$format';

    context.logger.info('截图: 全页=$fullPage, 格式=$format');

    try {
      final response = await context.http.post(
        '${_config.engineEndpoint}/screenshot',
        headers: _buildHeaders(session),
        body: {
          'session_id': session.sessionId,
          'full_page': fullPage,
          if (selector != null) 'selector': selector,
          'format': format,
          'quality': quality,
        },
      );

      final data = jsonDecode(response) as Map<String, dynamic>;
      final base64Image = data['image_base64'] as String?;
      final imageUrl = data['image_url'] as String?;

      final attachments = <ToolAttachment>[];
      if (base64Image != null) {
        attachments.add(ToolAttachment(
          type: AttachmentType.image,
          uri: fileName,
          description: '页面截图',
          mimeType: 'image/$format',
        ));
      }

      return ToolResult.success(
        content: '截图已保存: $fileName',
        data: {
          'session_id': session.sessionId,
          'file_path': fileName,
          'format': format,
          'full_page': fullPage,
          if (imageUrl != null) 'image_url': imageUrl,
        },
        attachments: attachments.isNotEmpty ? attachments : null,
      );
    } catch (e) {
      context.logger.error('截图失败', e);
      return ToolResult.failure(error: '截图失败: $e', errorCode: 'SCREENSHOT_FAILED');
    }
  }

  /// extract_text 实现
  Future<ToolResult> _executeExtractText(
    Map<String, dynamic> args,
    SkillContext context,
  ) async {
    final selector = args['selector'] as String;
    final strategy = args['strategy'] as String? ?? 'css';
    final extractType = args['extract_type'] as String? ?? 'text';
    final attributeName = args['attribute_name'] as String?;
    final sessionId = args['session_id'] as String?;

    final session = _getOrCreateSession(sessionId);
    context.logger.info('提取内容: [$strategy] $selector (类型: $extractType)');

    final locatorPayload = _buildLocatorPayload(strategy, selector);

    try {
      final response = await context.http.post(
        '${_config.engineEndpoint}/extract',
        headers: _buildHeaders(session),
        body: {
          'session_id': session.sessionId,
          'locator': locatorPayload,
          'extract_type': extractType,
          if (attributeName != null) 'attribute_name': attributeName,
        },
      );

      final data = jsonDecode(response) as Map<String, dynamic>;
      final content = data['content'] ?? '';

      String resultContent;
      Map<String, dynamic>? resultData;

      switch (extractType) {
        case 'table':
          final tables = (data['tables'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          if (tables.isEmpty) {
            resultContent = '未找到表格数据';
          } else {
            final buffer = StringBuffer();
            for (int i = 0; i < tables.length; i++) {
              final table = tables[i];
              final headers = (table['headers'] as List?)?.cast<String>() ?? [];
              final rows = (table['rows'] as List?)?.cast<List>() ?? [];
              buffer.writeln('### 表格 ${i + 1}');
              buffer.writeln('| ${headers.join(" | ")} |');
              buffer.writeln('| ${headers.map((_) => '---').join(" | ")} |');
              for (final row in rows) {
                buffer.writeln('| ${row.map((c) => c.toString()).join(" | ")} |');
              }
              buffer.writeln();
            }
            resultContent = buffer.toString().trim();
            resultData = {'table_count': tables.length};
          }

        case 'list':
          final items = (data['items'] as List?)?.cast<String>() ?? [];
          resultContent = items.map((item) => '• $item').join('\n');
          resultData = {'item_count': items.length};

        case 'attribute':
          resultContent = data['attribute_value']?.toString() ?? '';
          resultData = {'attribute_name': attributeName, 'value': resultContent};

        case 'html':
          resultContent = content.toString();
          resultData = {'html_length': resultContent.length};

        default:
          resultContent = content.toString();
          resultData = {'text_length': resultContent.length};
      }

      return ToolResult.success(
        content: resultContent.isEmpty ? '未提取到内容' : resultContent,
        data: {
          'session_id': session.sessionId,
          'selector': selector,
          'extract_type': extractType,
          ...?resultData,
        },
      );
    } catch (e) {
      context.logger.error('内容提取失败', e);
      return ToolResult.failure(
        error: '内容提取失败: $e',
        errorCode: 'EXTRACT_FAILED',
      );
    }
  }

  /// scroll_page 实现
  Future<ToolResult> _executeScrollPage(
    Map<String, dynamic> args,
    SkillContext context,
  ) async {
    final direction = args['direction'] as String? ?? 'down';
    final amount = args['amount'] as int? ?? 500;
    final toElement = args['to_element'] as String?;
    final toPosition = args['to_position'] as String?;
    final smooth = args['smooth'] as bool? ?? true;
    final sessionId = args['session_id'] as String?;

    final session = _getOrCreateSession(sessionId);

    try {
      String script;
      if (toElement != null) {
        final behavior = smooth ? 'smooth' : 'auto';
        script = 'document.querySelector("$toElement")'
            '.scrollIntoView({behavior: "$behavior", block: "center"})';
      } else if (toPosition != null) {
        final y = toPosition == 'top' ? 0 : 'document.body.scrollHeight';
        final behavior = smooth ? 'smooth' : 'auto';
        script = 'window.scrollTo({top: $y, behavior: "$behavior"})';
      } else {
        final delta = direction == 'up' || direction == 'left' ? -$amount : $amount;
        final behavior = smooth ? 'smooth' : 'auto';
        if (direction == 'up' || direction == 'down') {
          script = 'window.scrollBy({top: $delta, behavior: "$behavior"})';
        } else {
          script = 'window.scrollBy({left: $delta, behavior: "$behavior"})';
        }
      }

      await context.http.post(
        '${_config.engineEndpoint}/evaluate',
        headers: _buildHeaders(session),
        body: {
          'session_id': session.sessionId,
          'expression': script,
        },
      );

      return ToolResult.success(
        content: toElement != null
            ? '已滚动到元素: $toElement'
            : toPosition != null
                ? '已滚动到: $toPosition'
                : '已滚动: $direction ${amount}px',
        data: {'session_id': session.sessionId, 'direction': direction, 'amount': amount},
      );
    } catch (e) {
      context.logger.error('滚动失败', e);
      return ToolResult.failure(error: '页面滚动失败: $e', errorCode: 'SCROLL_FAILED');
    }
  }

  /// wait_for 实现
  Future<ToolResult> _executeWaitFor(
    Map<String, dynamic> args,
    SkillContext context,
  ) async {
    final condition = args['condition'] as String;
    final selector = args['selector'] as String?;
    final text = args['text'] as String?;
    final timeoutMs = args['timeout_ms'] as int? ?? 10000;
    final sessionId = args['session_id'] as String?;

    final session = _getOrCreateSession(sessionId);
    context.logger.info('等待条件: $condition (超时: ${timeoutMs}ms)');

    final stopwatch = Stopwatch()..start();

    try {
      final response = await context.http.post(
        '${_config.engineEndpoint}/wait_for',
        headers: _buildHeaders(session),
        body: {
          'session_id': session.sessionId,
          'condition': condition,
          if (selector != null) 'selector': selector,
          if (text != null) 'text': text,
          'timeout_ms': timeoutMs,
        },
      );

      stopwatch.stop();
      final data = jsonDecode(response) as Map<String, dynamic>;

      return ToolResult.success(
        content: '等待条件已满足: $condition (耗时: ${stopwatch.elapsedMilliseconds}ms)',
        data: {
          'session_id': session.sessionId,
          'condition': condition,
          'waited_ms': stopwatch.elapsedMilliseconds,
          'fulfilled': true,
        },
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } on TimeoutException {
      stopwatch.stop();
      return ToolResult.failure(
        error: '等待超时 (${timeoutMs}ms): $condition',
        errorCode: 'WAIT_TIMEOUT',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      return ToolResult.failure(
        error: '等待条件失败: $e',
        errorCode: 'WAIT_FAILED',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  /// select_option 实现
  Future<ToolResult> _executeSelectOption(
    Map<String, dynamic> args,
    SkillContext context,
  ) async {
    final selector = args['selector'] as String;
    final by = args['by'] as String? ?? 'value';
    final value = args['value'] as String?;
    final index = args['index'] as int?;
    final sessionId = args['session_id'] as String?;

    final session = _getOrCreateSession(sessionId);

    try {
      final response = await context.http.post(
        '${_config.engineEndpoint}/select',
        headers: _buildHeaders(session),
        body: {
          'session_id': session.sessionId,
          'selector': selector,
          'by': by,
          if (value != null) 'value': value,
          if (index != null) 'index': index,
        },
      );

      return ToolResult.success(
        content: '已选择选项: $selector (方式: $by)',
        data: {'session_id': session.sessionId, 'selector': selector, 'by': by},
      );
    } catch (e) {
      context.logger.error('选项选择失败', e);
      return ToolResult.failure(
        error: '下拉选择失败: $e',
        errorCode: 'SELECT_FAILED',
      );
    }
  }

  /// upload_file 实现
  Future<ToolResult> _executeUploadFile(
    Map<String, dynamic> args,
    SkillContext context,
  ) async {
    final selector = args['selector'] as String;
    final filePath = args['file_path'] as String;
    final sessionId = args['session_id'] as String?;

    final session = _getOrCreateSession(sessionId);
    context.logger.info('上传文件: $filePath -> $selector');

    try {
      await context.http.post(
        '${_config.engineEndpoint}/upload',
        headers: _buildHeaders(session),
        body: {
          'session_id': session.sessionId,
          'selector': selector,
          'file_path': filePath,
        },
      );

      return ToolResult.success(
        content: '文件已上传: $filePath',
        data: {'session_id': session.sessionId, 'selector': selector, 'file_path': filePath},
      );
    } catch (e) {
      context.logger.error('文件上传失败', e);
      return ToolResult.failure(
        error: '文件上传失败: $e',
        errorCode: 'UPLOAD_FAILED',
      );
    }
  }

  /// execute_js 实现
  Future<ToolResult> _executeExecuteJs(
    Map<String, dynamic> args,
    SkillContext context,
  ) async {
    final script = args['script'] as String;
    final scriptArgs = args['args'] as List?;
    final returnBy = args['return_by'] as String? ?? 'value';
    final sessionId = args['session_id'] as String?;

    final session = _getOrCreateSession(sessionId);
    context.logger.info('执行 JS: ${script.length > 80 ? "${script.substring(0, 80)}..." : script}');

    try {
      final response = await context.http.post(
        '${_config.engineEndpoint}/evaluate',
        headers: _buildHeaders(session),
        body: {
          'session_id': session.sessionId,
          'expression': script,
          if (scriptArgs != null) 'args': scriptArgs,
          'return_by': returnBy,
        },
      );

      final data = jsonDecode(response) as Map<String, dynamic>;
      final result = data['result'];

      return ToolResult.success(
        content: 'JS 执行结果: ${result ?? "undefined"}',
        data: {
          'session_id': session.sessionId,
          'result': result,
          'type': data['type'],
        },
      );
    } catch (e) {
      context.logger.error('JS 执行失败', e);
      return ToolResult.failure(
        error: 'JavaScript 执行失败: $e',
        errorCode: 'JS_EVAL_FAILED',
      );
    }
  }

  /// get_page_content 实现
  Future<ToolResult> _executeGetPageContent(
    Map<String, dynamic> args,
    SkillContext context,
  ) async {
    final format = args['format'] as String? ?? 'markdown';
    final maxLength = args['max_length'] as int? ?? 10000;
    final includeMetadata = args['include_metadata'] as bool? ?? true;
    final sessionId = args['session_id'] as String?;

    final session = _getOrCreateSession(sessionId);

    try {
      final response = await context.http.post(
        '${_config.engineEndpoint}/content',
        headers: _buildHeaders(session),
        body: {
          'session_id': session.sessionId,
          'format': format,
          'include_metadata': includeMetadata,
        },
      );

      final data = jsonDecode(response) as Map<String, dynamic>;
      var content = data['content'] as String? ?? '';

      final metadata = <String, dynamic>{
        'session_id': session.sessionId,
        'url': session.currentUrl,
        'title': session.title,
        'format': format,
        'content_length': content.length,
      };

      if (includeMetadata) {
        metadata['meta_description'] = data['meta_description'];
        metadata['meta_keywords'] = data['meta_keywords'];
      }

      // 截断过长内容
      if (content.length > maxLength) {
        content = '${content.substring(0, maxLength)}\n\n'
            '[内容已截断，原始长度: ${content.length} 字符]';
      }

      final buffer = StringBuffer();
      if (includeMetadata && session.title.isNotEmpty) {
        buffer.writeln('# ${session.title}');
        buffer.writeln('> URL: ${session.currentUrl}');
        if (data['meta_description'] != null) {
          buffer.writeln('> ${(data['meta_description'])}');
        }
        buffer.writeln();
      }
      buffer.write(content);

      return ToolResult.success(
        content: buffer.toString().trim(),
        data: metadata,
      );
    } catch (e) {
      context.logger.error('获取页面内容失败', e);
      return ToolResult.failure(
        error: '获取页面内容失败: $e',
        errorCode: 'CONTENT_FAILED',
      );
    }
  }

  /// login_site 实现
  Future<ToolResult> _executeLoginSite(
    Map<String, dynamic> args,
    SkillContext context,
  ) async {
    final url = args['url'] as String;
    final username = args['username'] as String;
    final password = args['password'] as String;
    final usernameSelector = args['username_selector'] as String? ?? 'input[type="text"], input[type="email"], input[name*="user"], input[name*="email"], input[name*="account"], #username, #email';
    final passwordSelector = args['password_selector'] as String? ?? 'input[type="password"], #password';
    final submitSelector = args['submit_selector'] as String? ?? 'button[type="submit"], input[type="submit"], .login-btn, .btn-login, #loginBtn';
    final keepLogin = args['keep_login'] as bool? ?? true;
    final successCheck = args['success_check'] as String?;

    context.logger.info('登录网站: $url (用户: $username)');

    // Step 1: 打开登录页面
    final navResult = await _executeOpenUrl({
      'url': url,
      'wait_until': 'network_idle',
      'new_session': true,
    }, context);

    if (!navResult.success) {
      return ToolResult.failure(
        error: '无法打开登录页面: ${navResult.error}',
        errorCode: 'LOGIN_NAV_FAILED',
      );
    }

    final sessionId = navResult.data?['session_id'] as String?;
    final session = _getOrCreateSession(sessionId);
    session.keepLoginState = keepLogin;

    // Step 2: 填写用户名
    final fillResult = await _executeFillForm({
      'fields': [
        {'selector': usernameSelector, 'value': username, 'strategy': 'css'},
        {'selector': passwordSelector, 'value': password, 'strategy': 'css'},
      ],
      'clear_first': true,
      'type_delay_ms': _antiDetection.simulateHumanMouse ? 50 : 0,
      'session_id': session.sessionId,
    }, context);

    if (!fillResult.success) {
      return ToolResult.failure(
        error: '填写登录表单失败: ${fillResult.error}',
        errorCode: 'LOGIN_FILL_FAILED',
      );
    }

    // Step 3: 点击提交
    await Future.delayed(const Duration(milliseconds: 500));
    final clickResult = await _executeClickElement({
      'selector': submitSelector,
      'strategy': 'css',
      'session_id': session.sessionId,
    }, context);

    if (!clickResult.success) {
      return ToolResult.failure(
        error: '点击登录按钮失败: ${clickResult.error}',
        errorCode: 'LOGIN_SUBMIT_FAILED',
      );
    }

    // Step 4: 等待导航完成
    await Future.delayed(const Duration(seconds: 3));

    // Step 5: 验证登录结果
    if (successCheck != null) {
      final currentUrl = session.currentUrl;
      if (!currentUrl.contains(successCheck)) {
        return ToolResult.failure(
          error: '登录可能未成功：页面 URL 未包含 "$successCheck"',
          errorCode: 'LOGIN_VERIFY_FAILED',
        );
      }
    }

    return ToolResult.success(
      content: '登录成功: $url\n当前页面: ${session.currentUrl}',
      data: {
        'session_id': session.sessionId,
        'url': url,
        'current_url': session.currentUrl,
        'keep_login': keepLogin,
      },
    );
  }

  /// download_file 实现
  Future<ToolResult> _executeDownloadFile(
    Map<String, dynamic> args,
    SkillContext context,
  ) async {
    final url = args['url'] as String?;
    final clickSelector = args['click_selector'] as String?;
    final savePath = args['save_path'] as String;
    final filename = args['filename'] as String?;
    final waitMs = args['wait_ms'] as int? ?? 30000;
    final sessionId = args['session_id'] as String?;

    final session = _getOrCreateSession(sessionId);

    if (url == null && clickSelector == null) {
      return ToolResult.failure(
        error: '必须提供 url 或 click_selector',
        errorCode: 'MISSING_PARAM',
      );
    }

    context.logger.info('下载文件: ${url ?? "via click: $clickSelector"}');

    try {
      final body = <String, dynamic>{
        'session_id': session.sessionId,
        'save_path': savePath,
        if (filename != null) 'filename': filename,
        'wait_ms': waitMs,
      };

      if (url != null) {
        body['url'] = url;
        body['method'] = 'direct';
      } else {
        body['selector'] = clickSelector;
        body['method'] = 'click';
      }

      final response = await context.http.post(
        '${_config.engineEndpoint}/download',
        headers: _buildHeaders(session),
        body: body,
      );

      final data = jsonDecode(response) as Map<String, dynamic>;
      final savedPath = data['saved_path'] as String? ?? savePath;
      final fileSize = data['file_size'] as int?;

      return ToolResult.success(
        content: '文件已下载: $savedPath${fileSize != null ? " (${(fileSize / 1024).toStringAsFixed(1)} KB)" : ""}',
        data: {
          'session_id': session.sessionId,
          'saved_path': savedPath,
          if (fileSize != null) 'file_size': fileSize,
          'filename': filename ?? data['filename'],
        },
      );
    } catch (e) {
      context.logger.error('文件下载失败', e);
      return ToolResult.failure(
        error: '文件下载失败: $e',
        errorCode: 'DOWNLOAD_FAILED',
      );
    }
  }

  // ============================================================================
  // 辅助方法
  // ============================================================================

  /// 构建请求头
  Map<String, String> _buildHeaders(BrowserSession session) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${_config.apiKey}',
      'User-Agent': session.userAgent,
      'X-Session-Id': session.sessionId,
      if (_antiDetection.hideWebdriverFlag)
        'X-Hide-Webdriver': 'true',
    };
  }

  /// 构建定位器 payload
  Map<String, dynamic> _buildLocatorPayload(String strategy, String selector) {
    return {
      'strategy': strategy,
      'value': selector,
    };
  }

  /// 生成随机延迟
  Duration _randomDelay() {
    final range = _antiDetection.maxDelayMs - _antiDetection.minDelayMs;
    final delay = _antiDetection.minDelayMs + Random().nextInt(range + 1);
    return Duration(milliseconds: delay);
  }

  /// 验证 URL 格式
  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.scheme == 'http' || uri.scheme == 'https';
    } catch (_) {
      return false;
    }
  }
}

// ============================================================================
// 配置
// ============================================================================

/// 浏览器技能配置
class BrowserSkillConfig {
  /// 浏览器引擎类型
  final BrowserEngineType engineType;

  /// 引擎服务端地址
  final String engineEndpoint;

  /// API 密钥
  final String apiKey;

  /// 默认 User-Agent
  final String defaultUserAgent;

  /// 反爬配置
  final AntiDetectionConfig antiDetection;

  /// 默认超时（毫秒）
  final int defaultTimeoutMs;

  /// 是否自动关闭闲置会话
  final bool autoCloseIdleSessions;

  /// 闲置会话超时时间
  final Duration idleSessionTimeout;

  const BrowserSkillConfig({
    this.engineType = BrowserEngineType.puppeteer,
    this.engineEndpoint = 'http://localhost:9222',
    this.apiKey = '',
    this.defaultUserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    this.antiDetection = const AntiDetectionConfig(),
    this.defaultTimeoutMs = 30000,
    this.autoCloseIdleSessions = true,
    this.idleSessionTimeout = const Duration(minutes: 30),
  });
}
