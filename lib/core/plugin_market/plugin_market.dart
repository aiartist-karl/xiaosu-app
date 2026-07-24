import 'dart:async';
import 'dart:convert';
import 'dart:math';

// ── 枚举 ──────────────────────────────────────────────────────────────────

enum PluginCategory {
  productivity, content, development, data,
  communication, automation, media, professional,
}

enum PluginPermission {
  network, storage, camera, location, notification, contacts, calendar,
}

enum PluginInstallState { notInstalled, installing, installed, updateAvailable, disabled, error }
enum PluginSourceType { official, thirdParty, local }
enum AuditSeverity { info, warning, critical }
enum PluginSortBy { relevance, rating, downloads, newest, name }

// ── 数据模型 ──────────────────────────────────────────────────────────────

class PluginAuthor {
  final String id, name, avatar, homepage, bio;
  final int publishedPlugins, totalDownloads;
  final double averageRating;
  final bool isVerified;
  const PluginAuthor({required this.id, required this.name, this.avatar = '', this.homepage = '',
      this.bio = '', this.publishedPlugins = 0, this.totalDownloads = 0,
      this.averageRating = 0.0, this.isVerified = false});
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'avatar': avatar,
      'homepage': homepage, 'bio': bio, 'publishedPlugins': publishedPlugins,
      'totalDownloads': totalDownloads, 'averageRating': averageRating, 'isVerified': isVerified};
  factory PluginAuthor.fromJson(Map<String, dynamic> j) => PluginAuthor(
      id: j['id'] as String, name: j['name'] as String, avatar: j['avatar'] as String? ?? '',
      homepage: j['homepage'] as String? ?? '', bio: j['bio'] as String? ?? '',
      publishedPlugins: j['publishedPlugins'] as int? ?? 0,
      totalDownloads: j['totalDownloads'] as int? ?? 0,
      averageRating: (j['averageRating'] as num?)?.toDouble() ?? 0.0,
      isVerified: j['isVerified'] as bool? ?? false);
}

class PluginUpdate {
  final String version, changelog;
  final DateTime publishedAt;
  final int downloadSize;
  final bool isMandatory;
  final List<String> bugFixes, newFeatures;
  const PluginUpdate({required this.version, required this.changelog, required this.publishedAt,
      required this.downloadSize, this.isMandatory = false,
      this.bugFixes = const [], this.newFeatures = const []});
  Map<String, dynamic> toJson() => {'version': version, 'changelog': changelog,
      'publishedAt': publishedAt.toIso8601String(), 'downloadSize': downloadSize,
      'isMandatory': isMandatory, 'bugFixes': bugFixes, 'newFeatures': newFeatures};
  factory PluginUpdate.fromJson(Map<String, dynamic> j) => PluginUpdate(
      version: j['version'] as String, changelog: j['changelog'] as String,
      publishedAt: DateTime.parse(j['publishedAt'] as String),
      downloadSize: j['downloadSize'] as int, isMandatory: j['isMandatory'] as bool? ?? false,
      bugFixes: List<String>.from(j['bugFixes'] as List? ?? []),
      newFeatures: List<String>.from(j['newFeatures'] as List? ?? []));
}

class PluginReview {
  final String id, pluginId, userId, userName, userAvatar, comment;
  final int rating, helpfulCount;
  final DateTime createdAt;
  final bool isDeveloperReply;
  final String? developerReply;
  final DateTime? developerReplyAt;
  const PluginReview({required this.id, required this.pluginId, required this.userId,
      required this.userName, this.userAvatar = '', required this.rating,
      required this.comment, required this.createdAt, this.helpfulCount = 0,
      this.isDeveloperReply = false, this.developerReply, this.developerReplyAt});
  Map<String, dynamic> toJson() => {'id': id, 'pluginId': pluginId, 'userId': userId,
      'userName': userName, 'rating': rating, 'comment': comment,
      'createdAt': createdAt.toIso8601String(), 'helpfulCount': helpfulCount};
  factory PluginReview.fromJson(Map<String, dynamic> j) => PluginReview(
      id: j['id'] as String, pluginId: j['pluginId'] as String, userId: j['userId'] as String,
      userName: j['userName'] as String, userAvatar: j['userAvatar'] as String? ?? '',
      rating: j['rating'] as int, comment: j['comment'] as String,
      createdAt: DateTime.parse(j['createdAt'] as String), helpfulCount: j['helpfulCount'] as int? ?? 0);
}

class Plugin {
  final String id, name, version, description, icon;
  final PluginAuthor author;
  final PluginCategory category;
  final List<String> tags, screenshots, supportedPlatforms;
  final List<PluginPermission> permissions;
  final List<PluginUpdate> changelog;
  final double rating;
  final int ratingCount, downloads, size;
  final DateTime publishedAt, updatedAt;
  final String? homepage, repository, license;
  final bool isOfficial;
  const Plugin({required this.id, required this.name, required this.version,
      required this.author, required this.description, this.icon = '',
      required this.category, this.tags = const [], this.rating = 0.0,
      this.ratingCount = 0, this.downloads = 0, this.size = 0,
      this.permissions = const [], this.changelog = const [],
      this.screenshots = const [], required this.publishedAt, required this.updatedAt,
      this.homepage, this.repository, this.license, this.isOfficial = false,
      this.supportedPlatforms = const ['android', 'ios']});
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'version': version,
      'author': author.toJson(), 'description': description, 'category': category.name,
      'tags': tags, 'rating': rating, 'downloads': downloads, 'size': size,
      'permissions': permissions.map((p) => p.name).toList(), 'isOfficial': isOfficial,
      'publishedAt': publishedAt.toIso8601String(), 'updatedAt': updatedAt.toIso8601String()};
  factory Plugin.fromJson(Map<String, dynamic> j) => Plugin(
      id: j['id'] as String, name: j['name'] as String, version: j['version'] as String,
      author: PluginAuthor.fromJson(j['author'] as Map<String, dynamic>),
      description: j['description'] as String, icon: j['icon'] as String? ?? '',
      category: PluginCategory.values.firstWhere((c) => c.name == j['category'],
          orElse: () => PluginCategory.productivity),
      tags: List<String>.from(j['tags'] as List? ?? []),
      rating: (j['rating'] as num?)?.toDouble() ?? 0.0,
      downloads: j['downloads'] as int? ?? 0, size: j['size'] as int? ?? 0,
      permissions: (j['permissions'] as List? ?? []).map((p) =>
          PluginPermission.values.firstWhere((e) => e.name == p,
              orElse: () => PluginPermission.network)).toList(),
      screenshots: List<String>.from(j['screenshots'] as List? ?? []),
      publishedAt: DateTime.parse(j['publishedAt'] as String),
      updatedAt: DateTime.parse(j['updatedAt'] as String),
      isOfficial: j['isOfficial'] as bool? ?? false);
}

class SecurityAuditLog {
  final String id, pluginId, action, description;
  final AuditSeverity severity;
  final DateTime timestamp;
  const SecurityAuditLog({required this.id, required this.pluginId, required this.action,
      required this.severity, required this.description, required this.timestamp});
}

class ResourceLimits {
  final int maxMemoryMB, maxNetworkKBPerSec, maxDiskMB;
  final double maxCpuPercent;
  const ResourceLimits({this.maxMemoryMB = 128, this.maxCpuPercent = 20.0,
      this.maxNetworkKBPerSec = 512, this.maxDiskMB = 50});
}

class PluginSource {
  final String id, name, url;
  final PluginSourceType type;
  final bool isEnabled;
  final DateTime? lastSyncedAt;
  final int pluginCount;
  const PluginSource({required this.id, required this.name, required this.url,
      required this.type, this.isEnabled = true, this.lastSyncedAt, this.pluginCount = 0});
  PluginSource copyWith({String? name, String? url, bool? isEnabled,
      DateTime? lastSyncedAt, int? pluginCount}) => PluginSource(
      id: id, name: name ?? this.name, url: url ?? this.url, type: type,
      isEnabled: isEnabled ?? this.isEnabled, lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      pluginCount: pluginCount ?? this.pluginCount);
}

class InstalledPluginRecord {
  final String pluginId, installedVersion;
  final DateTime installedAt;
  final bool isEnabled;
  final Set<PluginPermission> grantedPermissions;
  final String? sourceId;
  const InstalledPluginRecord({required this.pluginId, required this.installedVersion,
      required this.installedAt, this.isEnabled = true,
      this.grantedPermissions = const {}, this.sourceId});
  InstalledPluginRecord copyWith({String? installedVersion, bool? isEnabled,
      Set<PluginPermission>? grantedPermissions}) => InstalledPluginRecord(
      pluginId: pluginId, installedVersion: installedVersion ?? this.installedVersion,
      installedAt: installedAt, isEnabled: isEnabled ?? this.isEnabled,
      grantedPermissions: grantedPermissions ?? this.grantedPermissions, sourceId: sourceId);
}

class PluginSearchFilter {
  final String? query;
  final PluginCategory? category;
  final double? minRating;
  final bool? isOfficialOnly;
  final PluginSortBy sortBy;
  final int page, pageSize;
  const PluginSearchFilter({this.query, this.category, this.minRating,
      this.isOfficialOnly, this.sortBy = PluginSortBy.relevance,
      this.page = 1, this.pageSize = 20});
}

class PluginSearchResult {
  final List<Plugin> plugins;
  final int totalCount;
  final bool hasMore;
  const PluginSearchResult({required this.plugins, required this.totalCount, required this.hasMore});
}

// ── 事件总线 ──────────────────────────────────────────────────────────────

typedef PluginEventCallback = void Function(PluginEvent event);

class PluginEvent {
  final String type, sourcePluginId;
  final Map<String, dynamic> payload;
  final DateTime timestamp;
  const PluginEvent({required this.type, required this.sourcePluginId,
      this.payload = const {}, required this.timestamp});
}

class PluginEventBus {
  final Map<String, List<PluginEventCallback>> _listeners = {};
  final List<PluginEvent> _history = [];

  void subscribe(String type, PluginEventCallback cb) {
    _listeners.putIfAbsent(type, () => []);
    _listeners[type]!.add(cb);
  }
  void unsubscribe(String type, PluginEventCallback cb) => _listeners[type]?.remove(cb);
  void publish(PluginEvent event) {
    _history.add(event);
    if (_history.length > 1000) _history.removeRange(0, _history.length - 1000);
    final cbs = _listeners[event.type];
    if (cbs != null) for (final cb in cbs) { try { cb(event); } catch (_) {} }
  }
  List<PluginEvent> getHistory({String? type, int limit = 100}) {
    var events = type != null ? _history.where((e) => e.type == type).toList() : [..._history];
    return events.reversed.take(limit).toList();
  }
}

// ── 插件 SDK ──────────────────────────────────────────────────────────────

class PluginLifecycleCallbacks {
  Future<void> Function(String pluginId)? onInstall, onEnable, onDisable, onUninstall, onDataChanged;
  Future<void> Function(String id, String oldVer, String newVer)? onUpdate;
}

class PluginHostApi {
  final String pluginId;
  final PluginEventBus _eventBus;
  final Map<String, dynamic> _caps = {};
  final Map<String, String> _storage = {};

  PluginHostApi({required this.pluginId, required PluginEventBus eventBus}) : _eventBus = eventBus {
    _caps['storage.get'] = (Map<String, dynamic> p) async => _storage[p['key'] ?? ''];
    _caps['storage.set'] = (Map<String, dynamic> p) async { _storage[p['key'] ?? ''] = p['value'] ?? ''; };
    _caps['storage.delete'] = (Map<String, dynamic> p) async { _storage.remove(p['key'] ?? ''); };
    _caps['ui.showToast'] = (Map<String, dynamic> p) async {};
    _caps['net.httpGet'] = (Map<String, dynamic> p) async => {'status': 200, 'body': ''};
    _caps['net.httpPost'] = (Map<String, dynamic> p) async => {'status': 200, 'body': ''};
    _caps['device.getInfo'] = (Map<String, dynamic> p) async => {'platform': 'flutter'};
    _caps['event.emit'] = (Map<String, dynamic> p) async {
      _eventBus.publish(PluginEvent(type: p['type'] ?? 'custom',
          sourcePluginId: pluginId, payload: p['payload'] ?? {}, timestamp: DateTime.now()));
    };
  }

  Future<dynamic> call(String cap, [Map<String, dynamic>? params]) async {
    final handler = _caps[cap];
    if (handler == null) throw UnsupportedError('宿主能力不存在: $cap');
    return await handler(params ?? {});
  }
  bool hasCapability(String cap) => _caps.containsKey(cap);
  List<String> listCapabilities() => _caps.keys.toList();
}

class PluginDevKit {
  final String pluginId;
  final PluginHostApi hostApi;
  final PluginEventBus eventBus;
  final PluginLifecycleCallbacks lifecycle;

  PluginDevKit({required this.pluginId, required PluginEventBus eventBus})
      : eventBus = eventBus,
        hostApi = PluginHostApi(pluginId: pluginId, eventBus: eventBus),
        lifecycle = PluginLifecycleCallbacks();

  Future<void> initialize() async { await lifecycle.onInstall?.call(pluginId); }
  Future<void> dispose() async { await lifecycle.onUninstall?.call(pluginId); }
  void emitEvent(String type, [Map<String, dynamic>? payload]) =>
      eventBus.publish(PluginEvent(type: type, sourcePluginId: pluginId,
          payload: payload ?? {}, timestamp: DateTime.now()));
  void onEvent(String type, PluginEventCallback cb) => eventBus.subscribe(type, cb);
  Future<dynamic> callHost(String api, [Map<String, dynamic>? p]) => hostApi.call(api, p);
}

// ── 插件沙箱 ──────────────────────────────────────────────────────────────

class PluginSandbox {
  final String pluginId;
  final ResourceLimits limits;
  final Set<PluginPermission> grantedPermissions;
  final List<SecurityAuditLog> auditLogs = [];
  bool _isRunning = false;
  int _memoryUsedMB = 0;
  double _cpuUsage = 0.0;

  PluginSandbox({required this.pluginId, this.limits = const ResourceLimits(),
      this.grantedPermissions = const {}});

  bool get isRunning => _isRunning;

  Future<bool> start() async {
    if (_isRunning) return false;
    _isRunning = true;
    auditLogs.add(SecurityAuditLog(id: 'a_${DateTime.now().millisecondsSinceEpoch}',
        pluginId: pluginId, action: 'sandbox_start', severity: AuditSeverity.info,
        description: '沙箱启动', timestamp: DateTime.now()));
    return true;
  }

  Future<void> stop() async {
    _isRunning = false;
    _memoryUsedMB = 0;
    _cpuUsage = 0.0;
  }

  bool hasPermission(PluginPermission p) => grantedPermissions.contains(p);

  Future<bool> requestPermission(PluginPermission p) async {
    grantedPermissions.add(p);
    return true;
  }

  Future<void> revokePermission(PluginPermission p) async => grantedPermissions.remove(p);

  bool checkResourceLimits() {
    if (_memoryUsedMB > limits.maxMemoryMB) {
      auditLogs.add(SecurityAuditLog(id: 'a_${DateTime.now().millisecondsSinceEpoch}',
          pluginId: pluginId, action: 'resource_exceeded', severity: AuditSeverity.critical,
          description: '内存超限: ${_memoryUsedMB}MB', timestamp: DateTime.now()));
      return false;
    }
    return true;
  }

  void updateResourceUsage({int? memoryMB, double? cpu}) {
    if (memoryMB != null) _memoryUsedMB = memoryMB;
    if (cpu != null) _cpuUsage = cpu;
    checkResourceLimits();
  }
}

// ── 市场事件 ──────────────────────────────────────────────────────────────

enum PluginMarketEventType {
  installStarted, installCompleted, installFailed,
  uninstallCompleted, updateCompleted, pluginEnabled, pluginDisabled, reviewAdded,
}

class PluginMarketEvent {
  final PluginMarketEventType type;
  final String pluginId;
  final String? message, extra;
  const PluginMarketEvent._(this.type, this.pluginId, {this.message, this.extra});

  factory PluginMarketEvent.installStarted(String id) =>
      PluginMarketEvent._(PluginMarketEventType.installStarted, id);
  factory PluginMarketEvent.installCompleted(String id) =>
      PluginMarketEvent._(PluginMarketEventType.installCompleted, id);
  factory PluginMarketEvent.installFailed(String id, String reason) =>
      PluginMarketEvent._(PluginMarketEventType.installFailed, id, message: reason);
  factory PluginMarketEvent.uninstallCompleted(String id) =>
      PluginMarketEvent._(PluginMarketEventType.uninstallCompleted, id);
  factory PluginMarketEvent.updateCompleted(String id, String ov, String nv) =>
      PluginMarketEvent._(PluginMarketEventType.updateCompleted, id, extra: '$ov->$nv');
  factory PluginMarketEvent.pluginEnabled(String id) =>
      PluginMarketEvent._(PluginMarketEventType.pluginEnabled, id);
  factory PluginMarketEvent.pluginDisabled(String id) =>
      PluginMarketEvent._(PluginMarketEventType.pluginDisabled, id);
  factory PluginMarketEvent.reviewAdded(String id, String rid) =>
      PluginMarketEvent._(PluginMarketEventType.reviewAdded, id, extra: rid);
}

// ── PluginMarket 主体 ─────────────────────────────────────────────────────

class PluginMarket {
  static PluginMarket? _inst;
  factory PluginMarket() => _inst ??= PluginMarket._();
  PluginMarket._();

  final List<Plugin> _plugins = [];
  final Map<String, InstalledPluginRecord> _installed = {};
  final Map<String, PluginSandbox> _sandboxes = {};
  final Map<String, PluginDevKit> _devKits = {};
  final List<PluginSource> _sources = [];
  final List<PluginReview> _reviews = [];
  final PluginEventBus _eventBus = PluginEventBus();
  final List<SecurityAuditLog> _auditLogs = [];
  final StreamController<PluginMarketEvent> _evtCtrl =
      StreamController<PluginMarketEvent>.broadcast();

  Stream<PluginMarketEvent> get eventStream => _evtCtrl.stream;
  PluginEventBus get eventBus => _eventBus;
  List<PluginSource> get sources => List.unmodifiable(_sources);
  int get installedCount => _installed.length;
  int get totalPlugins => _plugins.length;

  // ── 插件源 ──
  void addSource(PluginSource s) { _sources.add(s); _log('source_add', '添加插件源: ${s.name}'); }
  void removeSource(String id) { _sources.removeWhere((s) => s.id == id); }
  void enableSource(String id, bool on) {
    final i = _sources.indexWhere((s) => s.id == id);
    if (i != -1) _sources[i] = _sources[i].copyWith(isEnabled: on);
  }
  Future<void> syncSource(String id) async {
    final i = _sources.indexWhere((s) => s.id == id);
    if (i != -1) _sources[i] = _sources[i].copyWith(lastSyncedAt: DateTime.now());
  }

  // ── 浏览/搜索/分类 ──
  List<Plugin> getPopularPlugins({int limit = 10}) {
    final s = [..._plugins]..sort((a, b) => b.downloads.compareTo(a.downloads));
    return s.take(limit).toList();
  }
  List<Plugin> getTopRatedPlugins({int limit = 10}) {
    final s = [..._plugins]..sort((a, b) => b.rating.compareTo(a.rating));
    return s.take(limit).toList();
  }
  List<Plugin> getNewestPlugins({int limit = 10}) {
    final s = [..._plugins]..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return s.take(limit).toList();
  }
  List<Plugin> getRecommendedPlugins({int limit = 10}) {
    final now = DateTime.now();
    final scored = _plugins.map((p) {
      final days = now.difference(p.updatedAt).inDays;
      final recency = max(0.0, 1.0 - days / 365);
      return MapEntry(p, p.rating * 0.4 + log(p.downloads + 1) / log(1e6) * 0.3 + recency * 0.3);
    }).toList();
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(limit).map((e) => e.key).toList();
  }
  List<Plugin> getPluginsByCategory(PluginCategory c) => _plugins.where((p) => p.category == c).toList();
  Map<PluginCategory, int> getCategoryCounts() {
    final m = <PluginCategory, int>{};
    for (final p in _plugins) { m[p.category] = (m[p.category] ?? 0) + 1; }
    return m;
  }

  PluginSearchResult search(PluginSearchFilter f) {
    var r = List<Plugin>.from(_plugins);
    if (f.query != null && f.query!.isNotEmpty) {
      final q = f.query!.toLowerCase();
      r = r.where((p) => p.name.toLowerCase().contains(q) ||
          p.description.toLowerCase().contains(q) ||
          p.author.name.toLowerCase().contains(q) ||
          p.tags.any((t) => t.toLowerCase().contains(q))).toList();
    }
    if (f.category != null) r = r.where((p) => p.category == f.category).toList();
    if (f.minRating != null) r = r.where((p) => p.rating >= f.minRating!).toList();
    if (f.isOfficialOnly == true) r = r.where((p) => p.isOfficial).toList();
    switch (f.sortBy) {
      case PluginSortBy.rating: r.sort((a, b) => b.rating.compareTo(a.rating));
      case PluginSortBy.downloads: r.sort((a, b) => b.downloads.compareTo(a.downloads));
      case PluginSortBy.newest: r.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      case PluginSortBy.name: r.sort((a, b) => a.name.compareTo(b.name));
      case PluginSortBy.relevance: break;
    }
    final total = r.length;
    final start = (f.page - 1) * f.pageSize;
    return PluginSearchResult(plugins: r.skip(start).take(f.pageSize).toList(),
        totalCount: total, hasMore: start + f.pageSize < total);
  }

  // ── 安装/卸载/更新 ──
  Future<bool> installPlugin(String id, {String? sourceId}) async {
    final p = _find(id);
    if (p == null || _installed.containsKey(id)) return false;
    _emit(PluginMarketEvent.installStarted(id));
    final ok = await _reviewPermissions(p);
    if (!ok) { _emit(PluginMarketEvent.installFailed(id, '用户拒绝权限')); return false; }
    final sb = PluginSandbox(pluginId: id, grantedPermissions: p.permissions.toSet());
    await sb.start();
    _sandboxes[id] = sb;
    final dk = PluginDevKit(pluginId: id, eventBus: _eventBus);
    await dk.initialize();
    _devKits[id] = dk;
    _installed[id] = InstalledPluginRecord(pluginId: id, installedVersion: p.version,
        installedAt: DateTime.now(), grantedPermissions: p.permissions.toSet(), sourceId: sourceId);
    _log('plugin_install', '安装: ${p.name} v${p.version}');
    _emit(PluginMarketEvent.installCompleted(id));
    return true;
  }

  Future<bool> uninstallPlugin(String id) async {
    if (!_installed.containsKey(id)) return false;
    await _sandboxes[id]?.stop();
    _sandboxes.remove(id);
    await _devKits[id]?.dispose();
    _devKits.remove(id);
    _installed.remove(id);
    _log('plugin_uninstall', '卸载: $id');
    _emit(PluginMarketEvent.uninstallCompleted(id));
    return true;
  }

  Future<bool> updatePlugin(String id) async {
    final rec = _installed[id];
    final p = _find(id);
    if (rec == null || p == null || p.version == rec.installedVersion) return false;
    final old = rec.installedVersion;
    _installed[id] = rec.copyWith(installedVersion: p.version);
    await _devKits[id]?.lifecycle.onUpdate?.call(id, old, p.version);
    _log('plugin_update', '更新: $id $old -> ${p.version}');
    _emit(PluginMarketEvent.updateCompleted(id, old, p.version));
    return true;
  }

  Future<bool> enablePlugin(String id) async {
    final r = _installed[id]; if (r == null || r.isEnabled) return false;
    _installed[id] = r.copyWith(isEnabled: true);
    await _sandboxes[id]?.start();
    await _devKits[id]?.lifecycle.onEnable?.call(id);
    _emit(PluginMarketEvent.pluginEnabled(id));
    return true;
  }

  Future<bool> disablePlugin(String id) async {
    final r = _installed[id]; if (r == null || !r.isEnabled) return false;
    _installed[id] = r.copyWith(isEnabled: false);
    await _sandboxes[id]?.stop();
    await _devKits[id]?.lifecycle.onDisable?.call(id);
    _emit(PluginMarketEvent.pluginDisabled(id));
    return true;
  }

  // ── 权限 ──
  Future<bool> _reviewPermissions(Plugin p) async {
    if (p.permissions.isEmpty) return true;
    _log('permission_review', '${p.name} 请求 ${p.permissions.length} 项权限');
    return true;
  }
  Future<bool> grantPermission(String id, PluginPermission p) async {
    final sb = _sandboxes[id]; if (sb == null) return false;
    return await sb.requestPermission(p);
  }
  Future<bool> revokePermission(String id, PluginPermission p) async {
    final sb = _sandboxes[id]; if (sb == null) return false;
    await sb.revokePermission(p);
    return true;
  }

  // ── 评论 ──
  Future<PluginReview> addReview({required String pluginId, required String userId,
      required String userName, required int rating, required String comment}) async {
    final rev = PluginReview(id: 'r_${DateTime.now().millisecondsSinceEpoch}',
        pluginId: pluginId, userId: userId, userName: userName,
        rating: rating.clamp(1, 5), comment: comment, createdAt: DateTime.now());
    _reviews.add(rev);
    _emit(PluginMarketEvent.reviewAdded(pluginId, rev.id));
    return rev;
  }
  List<PluginReview> getReviews(String pid, {int limit = 20, int offset = 0}) {
    final f = _reviews.where((r) => r.pluginId == pid).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return f.skip(offset).take(limit).toList();
  }
  Map<int, int> getRatingDistribution(String pid) {
    final d = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (final r in _reviews) { if (r.pluginId == pid) d[r.rating] = (d[r.rating] ?? 0) + 1; }
    return d;
  }

  // ── 开发者 ──
  List<Plugin> getPluginsByAuthor(String aid) => _plugins.where((p) => p.author.id == aid).toList();
  PluginAuthor? getAuthorInfo(String aid) {
    final match = _plugins.where((p) => p.author.id == aid).toList();
    return match.isEmpty ? null : match.first.author;
  }

  // ── 本地安装 ──
  Future<bool> installFromLocalFile(String path) async {
    _log('local_install', '本地安装: $path');
    return true;
  }

  // ── 数据管理 ──
  void loadPlugins(List<Plugin> ps) { _plugins.clear(); _plugins.addAll(ps); }
  void addPlugin(Plugin p) => _plugins.add(p);
  Plugin? getPlugin(String id) => _find(id);
  InstalledPluginRecord? getInstalledRecord(String id) => _installed[id];
  List<InstalledPluginRecord> getAllInstalledRecords() => _installed.values.toList();
  PluginSandbox? getSandbox(String id) => _sandboxes[id];
  PluginDevKit? getDevKit(String id) => _devKits[id];
  List<SecurityAuditLog> getAuditLogs({int limit = 100}) {
    final s = [..._auditLogs]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return s.take(limit).toList();
  }
  Plugin? _find(String id) { try { return _plugins.firstWhere((p) => p.id == id); } catch (_) { return null; } }
  void _log(String action, String desc) {
    _auditLogs.add(SecurityAuditLog(id: 'la_${DateTime.now().millisecondsSinceEpoch}',
        pluginId: 'market', action: action, severity: AuditSeverity.info,
        description: desc, timestamp: DateTime.now()));
  }
  void _emit(PluginMarketEvent e) => _evtCtrl.add(e);

  // ── 沙箱状态查询 ──

  /// 获取指定插件的沙箱运行状态摘要
  Map<String, dynamic> getSandboxStatus(String pluginId) {
    final sb = _sandboxes[pluginId];
    if (sb == null) return {'running': false, 'pluginId': pluginId};
    return {
      'pluginId': pluginId,
      'running': sb.isRunning,
      'grantedPermissions': sb.grantedPermissions.map((p) => p.name).toList(),
      'auditLogCount': sb.auditLogs.length,
      'resourceCheck': sb.checkResourceLimits(),
    };
  }

  /// 获取所有运行中沙箱的汇总信息
  List<Map<String, dynamic>> getAllSandboxStatus() {
    return _sandboxes.entries.map((e) => getSandboxStatus(e.key)).toList();
  }

  // ── 开发者主页扩展 ──

  /// 获取开发者的所有插件及其统计
  Map<String, dynamic> getDeveloperDashboard(String authorId) {
    final plugins = getPluginsByAuthor(authorId);
    final author = getAuthorInfo(authorId);
    final totalDownloads = plugins.fold<int>(0, (s, p) => s + p.downloads);
    final avgRating = plugins.isNotEmpty
        ? plugins.map((p) => p.rating).reduce((a, b) => a + b) / plugins.length
        : 0.0;
    return {
      'author': author?.toJson(),
      'pluginCount': plugins.length,
      'totalDownloads': totalDownloads,
      'averageRating': avgRating.toStringAsFixed(2),
      'plugins': plugins.map((p) => {
        'id': p.id, 'name': p.name, 'version': p.version,
        'downloads': p.downloads, 'rating': p.rating,
      }).toList(),
    };
  }

  // ── 插件批量操作 ──

  /// 批量安装插件
  Future<Map<String, bool>> batchInstall(List<String> pluginIds, {String? sourceId}) async {
    final results = <String, bool>{};
    for (final id in pluginIds) {
      results[id] = await installPlugin(id, sourceId: sourceId);
    }
    _log('batch_install', '批量安装 ${pluginIds.length} 个插件, 成功 ${results.values.where((v) => v).length} 个');
    return results;
  }

  /// 批量卸载插件
  Future<Map<String, bool>> batchUninstall(List<String> pluginIds) async {
    final results = <String, bool>{};
    for (final id in pluginIds) {
      results[id] = await uninstallPlugin(id);
    }
    _log('batch_uninstall', '批量卸载 ${pluginIds.length} 个插件');
    return results;
  }

  /// 检查所有已安装插件的更新
  List<Map<String, dynamic>> checkAllUpdates() {
    final updates = <Map<String, dynamic>>[];
    for (final rec in _installed.values) {
      final plugin = _find(rec.pluginId);
      if (plugin != null && plugin.version != rec.installedVersion) {
        updates.add({
          'pluginId': rec.pluginId,
          'name': plugin.name,
          'currentVersion': rec.installedVersion,
          'latestVersion': plugin.version,
          'size': plugin.size,
          'changelog': plugin.changelog.isNotEmpty ? plugin.changelog.first.changelog : '',
        });
      }
    }
    return updates;
  }

  /// 获取插件使用统计
  Map<String, dynamic> getPluginUsageStats(String pluginId) {
    final rec = _installed[pluginId];
    final sb = _sandboxes[pluginId];
    return {
      'pluginId': pluginId,
      'installed': rec != null,
      'installedVersion': rec?.installedVersion,
      'installedAt': rec?.installedAt.toIso8601String(),
      'isEnabled': rec?.isEnabled ?? false,
      'grantedPermissions': rec?.grantedPermissions.map((p) => p.name).toList() ?? [],
      'sandboxRunning': sb?.isRunning ?? false,
      'auditLogCount': sb?.auditLogs.length ?? 0,
    };
  }

  /// 导出插件市场数据快照
  Map<String, dynamic> exportSnapshot() {
    return {
      'totalPlugins': _plugins.length,
      'installedCount': _installed.length,
      'sourceCount': _sources.length,
      'reviewCount': _reviews.length,
      'auditLogCount': _auditLogs.length,
      'timestamp': DateTime.now().toIso8601String(),
      'installedPlugins': _installed.values.map((r) => {
        'pluginId': r.pluginId, 'version': r.installedVersion,
        'enabled': r.isEnabled,
        'permissions': r.grantedPermissions.map((p) => p.name).toList(),
      }).toList(),
    };
  }

  Future<void> dispose() async {
    for (final sb in _sandboxes.values) await sb.stop();
    _sandboxes.clear(); _devKits.clear(); await _evtCtrl.close();
  }
}
