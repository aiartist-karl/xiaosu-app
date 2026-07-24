// ============================================================================
// 小酥 AI 助手 - 专业领域技能（股票/法律/学术/行业调研/健康医疗）
// ============================================================================
// 覆盖金融、法律、学术、行业调研、公司尽调、健康医疗六大子模块
// 每个子模块拥有独立的 API 调用与数据处理逻辑
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../../core/skill/skill.dart';

class ProDomainSkill extends Skill {
  final ProDomainConfig _config;
  final Map<String, DateTime> _throttleMap = {};
  static const _throttleInterval = Duration(seconds: 2);

  ProDomainSkill({ProDomainConfig? config})
      : _config = config ?? const ProDomainConfig();

  @override
  SkillManifest get manifest => const SkillManifest(
        id: 'pro_domain', name: '专业领域',
        description: '覆盖金融股票、法律咨询、学术研究、行业调研、'
            '公司尽调、健康医疗六大领域的深度分析能力。',
        version: '1.0.0', author: '小酥',
        permissions: [SkillPermission.networkAccess, SkillPermission.fileRead],
        loadStrategy: SkillLoadStrategy.lazy,
      );

  @override
  List<SkillTool> get tools => [
        // 金融
        _stockAnalysisTool, _stockRealtimeTool,
        // 法律
        _legalConsultTool, _caseSearchTool, _contractReviewTool,
        // 学术
        _paperSearchTool, _citationTraceTool,
        // 行业 / 公司
        _industryResearchTool, _companyResearchTool,
        // 医疗
        _medicalReportInterpretTool, _drugQueryTool, _healthAdviceTool,
      ];

  // ===================== 金融模块 =====================

  late final _stockAnalysisTool = SkillTool(
    name: 'stock_analysis',
    description: '个股深度分析：基本面（PE/PB/ROE/营收增速/净利润率）+'
        '技术面（MA/MACD/KDJ/RSI/布林带），综合给出投资建议。',
    parameters: [
      ToolParameter(name: 'symbol', description: '股票代码，如 AAPL、600519.SH',
          type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'market', description: '市场',
          type: ToolParameterType.stringType,
          enumValues: ['us', 'cn_sh', 'cn_sz', 'hk'], defaultValue: 'cn_sh'),
      ToolParameter(name: 'depth', description: '分析深度',
          type: ToolParameterType.stringType,
          enumValues: ['brief', 'standard', 'deep'], defaultValue: 'standard'),
      ToolParameter(name: 'include_technical', description: '包含技术面',
          type: ToolParameterType.boolType, defaultValue: true),
      ToolParameter(name: 'include_fundamental', description: '包含基本面',
          type: ToolParameterType.boolType, defaultValue: true),
    ],
    timeoutMs: 45000, execute: _execStockAnalysis,
  );

  late final _stockRealtimeTool = SkillTool(
    name: 'stock_realtime',
    description: '查询实时行情：当前价、涨跌幅、成交量、换手率、五档盘口，支持批量。',
    parameters: [
      ToolParameter(name: 'symbols', description: '股票代码（逗号分隔）',
          type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'market', description: '市场',
          type: ToolParameterType.stringType,
          enumValues: ['us', 'cn_sh', 'cn_sz', 'hk'], defaultValue: 'cn_sh'),
      ToolParameter(name: 'include_kline', description: '返回近期K线',
          type: ToolParameterType.boolType, defaultValue: false),
      ToolParameter(name: 'kline_period', description: 'K线周期',
          type: ToolParameterType.stringType,
          enumValues: ['1min','5min','15min','30min','60min','daily','weekly'],
          defaultValue: 'daily'),
    ],
    timeoutMs: 15000, execute: _execStockRealtime,
  );

  // ===================== 法律模块 =====================

  late final _legalConsultTool = SkillTool(
    name: 'legal_consult',
    description: '法律咨询问答，覆盖合同法/劳动法/公司法/知识产权/房产/婚姻等，自动引用法条。',
    parameters: [
      ToolParameter(name: 'question', description: '法律问题',
          type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'domain', description: '法律领域',
          type: ToolParameterType.stringType,
          enumValues: ['contract','labor','company','ip','real_estate','marriage','traffic','criminal','general'],
          defaultValue: 'general'),
      ToolParameter(name: 'jurisdiction', description: '管辖区域',
          type: ToolParameterType.stringType, defaultValue: '中国大陆'),
      ToolParameter(name: 'include_articles', description: '引用法条',
          type: ToolParameterType.boolType, defaultValue: true),
    ],
    timeoutMs: 60000, execute: _execLegalConsult,
  );

  late final _caseSearchTool = SkillTool(
    name: 'case_search',
    description: '类案检索：按案由/法院/时间筛选相似判决案例，辅助了解裁判趋势。',
    parameters: [
      ToolParameter(name: 'cause_of_action', description: '案由关键词',
          type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'court', description: '法院名称',
          type: ToolParameterType.stringType),
      ToolParameter(name: 'court_level', description: '法院级别',
          type: ToolParameterType.stringType,
          enumValues: ['supreme','high','intermediate','basic']),
      ToolParameter(name: 'start_date', description: '起始日期 YYYY-MM-DD',
          type: ToolParameterType.stringType),
      ToolParameter(name: 'end_date', description: '截止日期 YYYY-MM-DD',
          type: ToolParameterType.stringType),
      ToolParameter(name: 'max_results', description: '最大返回数',
          type: ToolParameterType.intType, minValue: 1, maxValue: 50, defaultValue: 10),
      ToolParameter(name: 'keyword', description: '全文检索关键词',
          type: ToolParameterType.stringType),
    ],
    timeoutMs: 30000, execute: _execCaseSearch,
  );

  late final _contractReviewTool = SkillTool(
    name: 'contract_review',
    description: '合同审核：逐条审查合同，标记风险条款（违约不对等/管辖不利/权属模糊），给出修改建议。',
    parameters: [
      ToolParameter(name: 'contract_text', description: '合同文本',
          type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'contract_type', description: '合同类型',
          type: ToolParameterType.stringType,
          enumValues: ['sales','lease','employment','nda','service','partnership','loan','license','other'],
          defaultValue: 'other'),
      ToolParameter(name: 'my_role', description: '我方角色',
          type: ToolParameterType.stringType,
          enumValues: ['party_a','party_b'], defaultValue: 'party_a'),
      ToolParameter(name: 'focus_areas', description: '重点审查领域',
          type: ToolParameterType.stringType),
    ],
    timeoutMs: 90000, execute: _execContractReview,
  );

  // ===================== 学术模块 =====================

  late final _paperSearchTool = SkillTool(
    name: 'paper_search',
    description: '学术论文搜索（arXiv/Semantic Scholar/PubMed），按关键词/作者/机构/年份检索。',
    parameters: [
      ToolParameter(name: 'query', description: '搜索关键词',
          type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'source', description: '数据来源',
          type: ToolParameterType.stringType,
          enumValues: ['arxiv','semantic_scholar','pubmed','ieee','all'], defaultValue: 'all'),
      ToolParameter(name: 'author', description: '作者',
          type: ToolParameterType.stringType),
      ToolParameter(name: 'institution', description: '机构',
          type: ToolParameterType.stringType),
      ToolParameter(name: 'year_from', description: '起始年份',
          type: ToolParameterType.intType, minValue: 1950, maxValue: 2099),
      ToolParameter(name: 'year_to', description: '截止年份',
          type: ToolParameterType.intType, minValue: 1950, maxValue: 2099),
      ToolParameter(name: 'max_results', description: '最大数量',
          type: ToolParameterType.intType, minValue: 1, maxValue: 50, defaultValue: 10),
      ToolParameter(name: 'sort_by', description: '排序',
          type: ToolParameterType.stringType,
          enumValues: ['relevance','date','citations'], defaultValue: 'relevance'),
    ],
    timeoutMs: 30000, execute: _execPaperSearch,
  );

  late final _citationTraceTool = SkillTool(
    name: 'citation_trace',
    description: '引用链追溯：从一篇论文出发追踪参考文献与被引文献，构建知识演进图谱。',
    parameters: [
      ToolParameter(name: 'paper_id', description: '论文ID（DOI/arXiv ID/S2 ID）',
          type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'direction', description: '追溯方向',
          type: ToolParameterType.stringType,
          enumValues: ['references','citations','both'], defaultValue: 'both'),
      ToolParameter(name: 'max_depth', description: '追溯深度',
          type: ToolParameterType.intType, minValue: 1, maxValue: 5, defaultValue: 2),
      ToolParameter(name: 'max_per_level', description: '每层最大数',
          type: ToolParameterType.intType, minValue: 1, maxValue: 30, defaultValue: 10),
    ],
    timeoutMs: 60000, execute: _execCitationTrace,
  );

  // ===================== 行业调研 / 公司尽调 =====================

  late final _industryResearchTool = SkillTool(
    name: 'industry_research',
    description: '行业调研：市场规模、增长率、竞争格局、产业链、技术趋势、政策环境。',
    parameters: [
      ToolParameter(name: 'industry', description: '行业名称',
          type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'region', description: '地区',
          type: ToolParameterType.stringType, defaultValue: '全球'),
      ToolParameter(name: 'report_depth', description: '深度',
          type: ToolParameterType.stringType,
          enumValues: ['overview','standard','comprehensive'], defaultValue: 'standard'),
      ToolParameter(name: 'focus', description: '重点关注（逗号分隔）',
          type: ToolParameterType.stringType),
    ],
    timeoutMs: 90000, execute: _execIndustryResearch,
  );

  late final _companyResearchTool = SkillTool(
    name: 'company_research',
    description: '公司尽调：工商信息/股权结构/财务数据/董监高/诉讼记录/行政处罚/风险提示。',
    parameters: [
      ToolParameter(name: 'company_name', description: '公司名称',
          type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'credit_code', description: '统一社会信用代码',
          type: ToolParameterType.stringType),
      ToolParameter(name: 'modules', description: '模块（逗号分隔）',
          type: ToolParameterType.stringType, defaultValue: 'basic,finance,shareholders,risk'),
    ],
    timeoutMs: 60000, execute: _execCompanyResearch,
  );

  // ===================== 健康医疗 =====================

  late final _medicalReportInterpretTool = SkillTool(
    name: 'medical_report_interpret',
    description: '医学报告解读：解读体检/化验/影像报告中的指标含义（仅供参考，非医疗诊断）。',
    parameters: [
      ToolParameter(name: 'report_text', description: '报告文本',
          type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'report_type', description: '类型',
          type: ToolParameterType.stringType,
          enumValues: ['physical_exam','blood_test','imaging','pathology','urine_test','other'],
          defaultValue: 'physical_exam'),
      ToolParameter(name: 'patient_age', description: '年龄',
          type: ToolParameterType.intType),
      ToolParameter(name: 'patient_gender', description: '性别',
          type: ToolParameterType.stringType, enumValues: ['male','female']),
    ],
    timeoutMs: 60000, execute: _execMedicalReport,
  );

  late final _drugQueryTool = SkillTool(
    name: 'drug_query',
    description: '药品查询：适应症/用法用量/不良反应/禁忌/药物相互作用。',
    parameters: [
      ToolParameter(name: 'drug_name', description: '药品名称',
          type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'query_type', description: '查询类型',
          type: ToolParameterType.stringType,
          enumValues: ['full','indication','dosage','side_effects','interaction'],
          defaultValue: 'full'),
      ToolParameter(name: 'include_herbal', description: '含中草药',
          type: ToolParameterType.boolType, defaultValue: false),
    ],
    timeoutMs: 30000, execute: _execDrugQuery,
  );

  late final _healthAdviceTool = SkillTool(
    name: 'health_advice',
    description: '健康问答：营养/运动/睡眠/心理/慢病管理等科普建议（仅供参考）。',
    parameters: [
      ToolParameter(name: 'question', description: '健康问题',
          type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'category', description: '类别',
          type: ToolParameterType.stringType,
          enumValues: ['nutrition','exercise','sleep','mental','chronic_disease','symptom','prevention','general'],
          defaultValue: 'general'),
    ],
    timeoutMs: 30000, execute: _execHealthAdvice,
  );

  // ============================================================================
  // 生命周期
  // ============================================================================

  @override
  Future<void> onInitialize(SkillContext context) async {
    context.logger.info('专业领域技能初始化完成，${tools.length} 个工具就绪');
  }

  @override
  Future<void> onDispose() async {
    _throttleMap.clear();
  }

  // ============================================================================
  // 金融模块执行
  // ============================================================================

  Future<ToolResult> _execStockAnalysis(
    Map<String, dynamic> args, SkillContext ctx,
  ) async {
    final symbol = args['symbol'] as String;
    final market = args['market'] as String? ?? 'cn_sh';
    final depth = args['depth'] as String? ?? 'standard';
    final incTech = args['include_technical'] as bool? ?? true;
    final incFund = args['include_fundamental'] as bool? ?? true;
    if (!_throttleOk('stock|$symbol')) {
      return ToolResult.failure(error: '请求过于频繁', errorCode: 'RATE_LIMITED');
    }
    ctx.logger.info('个股分析: $symbol ($market)');
    try {
      ctx.onProgress?.call(0.1, '获取行情...');
      final quote = await _apiPost(ctx, _config.financeUrl, '/quote',
          {'symbol': symbol, 'market': market});
      ctx.onProgress?.call(0.35, '基本面分析...');
      String fundReport = '';
      if (incFund) {
        final fin = await _apiPost(ctx, _config.financeUrl, '/financials',
            {'symbol': symbol, 'market': market, 'depth': depth});
        fundReport = _buildFundamentalReport(fin);
      }
      ctx.onProgress?.call(0.65, '技术面分析...');
      String techReport = '';
      if (incTech) {
        final kl = await _apiPost(ctx, _config.financeUrl, '/kline',
            {'symbol': symbol, 'market': market, 'period': 'daily', 'count': 120});
        final klines = (kl['klines'] as List? ?? []).cast<Map<String, dynamic>>();
        techReport = _buildTechnicalReport(klines);
      }
      ctx.onProgress?.call(0.9, '生成建议...');
      final buf = StringBuffer()
        ..writeln('## 📊 $symbol 分析报告')
        ..writeln()
        ..writeln('**现价**: ${quote['price'] ?? '-'} | '
            '**涨跌幅**: ${quote['change_pct'] ?? '-'}% | '
            '**成交量**: ${_fmtVol(quote['volume'])}')
        ..writeln();
      if (fundReport.isNotEmpty) { buf.writeln(fundReport); buf.writeln(); }
      if (techReport.isNotEmpty) { buf.writeln(techReport); buf.writeln(); }
      buf.writeln('### 💡 综合建议');
      final trend = techReport.contains('多头') ? '上升' : (techReport.contains('空头') ? '下降' : '震荡');
      buf.writeln('$symbol 当前技术面呈 **$trend** 态势，${incFund ? '基本面指标详见上方表格。' : '建议结合基本面进一步确认。'}');
      buf.writeln();
      buf.writeln('> ⚠️ 以上仅供参考，不构成投资建议。股市有风险，投资需谨慎。');
      return ToolResult.success(content: buf.toString().trim(),
          data: {'symbol': symbol, 'quote': quote});
    } catch (e) {
      return ToolResult.failure(error: '分析失败: $e', errorCode: 'ANALYSIS_FAILED');
    }
  }

  Future<ToolResult> _execStockRealtime(
    Map<String, dynamic> args, SkillContext ctx,
  ) async {
    final syms = (args['symbols'] as String)
        .split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (syms.isEmpty || syms.length > 20) {
      return ToolResult.failure(error: '需提供1-20个股票代码', errorCode: 'INVALID');
    }
    final market = args['market'] as String? ?? 'cn_sh';
    final incKl = args['include_kline'] as bool? ?? false;
    final klPeriod = args['kline_period'] as String? ?? 'daily';
    try {
      final data = await _apiPost(ctx, _config.financeUrl, '/quote/batch',
          {'symbols': syms, 'market': market, 'include_kline': incKl, 'kline_period': klPeriod});
      final quotes = data['quotes'] as List? ?? [];
      final buf = StringBuffer()..writeln('## 📈 实时行情')..writeln();
      for (final q in quotes) {
        final m = q as Map<String, dynamic>;
        buf.writeln('**${m['name'] ?? m['symbol']}** 现价:${m['price']} '
            '涨跌:${m['change_pct']}% 最高:${m['high']} 最低:${m['low']} '
            '成交量:${_fmtVol(m['volume'])} 换手:${m['turnover_rate'] ?? '-'}%');
        if (incKl && m['kline'] != null) {
          for (final k in (m['kline'] as List).take(5)) {
            final kl = k as Map<String, dynamic>;
            buf.writeln('  ${kl['date']} O:${kl['open']} H:${kl['high']} L:${kl['low']} C:${kl['close']}');
          }
        }
        buf.writeln();
      }
      return ToolResult.success(content: buf.toString().trim(),
          data: {'quotes': quotes, 'count': quotes.length});
    } catch (e) {
      return ToolResult.failure(error: '行情查询失败: $e', errorCode: 'QUOTE_FAILED');
    }
  }

  // ============================================================================
  // 法律模块执行
  // ============================================================================

  Future<ToolResult> _execLegalConsult(
    Map<String, dynamic> args, SkillContext ctx,
  ) async {
    final question = args['question'] as String;
    final domain = args['domain'] as String? ?? 'general';
    final jur = args['jurisdiction'] as String? ?? '中国大陆';
    final incArt = args['include_articles'] as bool? ?? true;
    ctx.logger.info('法律咨询: [$domain] $question');
    try {
      final data = await _apiPost(ctx, _config.legalUrl, '/consult',
          {'question': question, 'domain': domain, 'jurisdiction': jur, 'include_articles': incArt});
      final buf = StringBuffer()
        ..writeln('## ⚖️ 法律咨询')
        ..writeln('**领域**: ${_domainLabel(domain)} | **管辖**: $jur | **风险**: ${data['risk_level'] ?? '中'}')
        ..writeln()..writeln(data['answer'] ?? '');
      if (incArt && data['articles'] != null) {
        buf.writeln()..writeln('### 相关法条');
        for (final a in data['articles'] as List) {
          final m = a as Map<String, dynamic>;
          buf.writeln('- **${m['law_name']}** ${m['article_number']}: ${m['content']}');
        }
      }
      buf.writeln()..writeln('> ⚠️ 仅供参考，不构成法律意见。具体请咨询执业律师。');
      return ToolResult.success(content: buf.toString().trim());
    } catch (e) {
      return ToolResult.failure(error: '法律咨询失败: $e', errorCode: 'LEGAL_FAILED');
    }
  }

  Future<ToolResult> _execCaseSearch(
    Map<String, dynamic> args, SkillContext ctx,
  ) async {
    final cause = args['cause_of_action'] as String;
    ctx.logger.info('类案检索: $cause');
    try {
      final body = <String, dynamic>{'cause_of_action': cause};
      for (final k in ['court','court_level','start_date','end_date','keyword']) {
        if (args[k] != null) body[k] = args[k];
      }
      body['max_results'] = args['max_results'] ?? 10;
      final data = await _apiPost(ctx, _config.legalUrl, '/cases/search', body);
      final cases = data['cases'] as List? ?? [];
      final buf = StringBuffer()
        ..writeln('## 🔍 类案检索 — $cause（共 ${data['total'] ?? cases.length} 条）')..writeln();
      for (int i = 0; i < cases.length; i++) {
        final c = cases[i] as Map<String, dynamic>;
        buf.writeln('**${i+1}. ${c['title'] ?? '未命名'}**');
        buf.writeln('  案号: ${c['case_number'] ?? '-'} | 法院: ${c['court'] ?? '-'} | 日期: ${c['judgment_date'] ?? '-'}');
        if (c['summary'] != null) buf.writeln('  摘要: ${c['summary']}');
        if (c['judgment_result'] != null) buf.writeln('  结果: ${c['judgment_result']}');
        buf.writeln();
      }
      return ToolResult.success(content: buf.toString().trim(),
          data: {'cause': cause, 'total': data['total']});
    } catch (e) {
      return ToolResult.failure(error: '类案检索失败: $e', errorCode: 'CASE_FAILED');
    }
  }

  Future<ToolResult> _execContractReview(
    Map<String, dynamic> args, SkillContext ctx,
  ) async {
    final text = args['contract_text'] as String;
    if (text.length < 50) return ToolResult.failure(error: '合同文本过短', errorCode: 'TOO_SHORT');
    if (text.length > 100000) return ToolResult.failure(error: '超过10万字限制', errorCode: 'TOO_LONG');
    final ctype = args['contract_type'] as String? ?? 'other';
    final role = args['my_role'] as String? ?? 'party_a';
    ctx.logger.info('合同审核: $ctype, ${text.length}字');
    try {
      final body = <String, dynamic>{'contract_text': text, 'contract_type': ctype, 'my_role': role};
      if (args['focus_areas'] != null) {
        body['focus_areas'] = (args['focus_areas'] as String).split(',').map((s) => s.trim()).toList();
      }
      final data = await _apiPost(ctx, _config.legalUrl, '/contract/review', body);
      final risks = data['risks'] as List? ?? [];
      final buf = StringBuffer()
        ..writeln('## 📋 合同审核报告')
        ..writeln('**类型**: ${_ctypeLabel(ctype)} | **我方**: ${role == 'party_a' ? '甲方' : '乙方'} | '
            '**风险**: ${data['overall_risk'] ?? '中'} | **问题条款**: ${risks.length}项')
        ..writeln();
      if (data['summary'] != null) { buf.writeln(data['summary']); buf.writeln(); }
      for (int i = 0; i < risks.length; i++) {
        final r = risks[i] as Map<String, dynamic>;
        final lv = r['risk_level'] ?? '中';
        final emoji = lv == '高' ? '🔴' : (lv == '中' ? '🟡' : '🟢');
        buf.writeln('$emoji **风险${i+1}** [$lv]');
        buf.writeln('  原文: "${r['original_text'] ?? '-'}"');
        buf.writeln('  说明: ${r['description'] ?? '-'}');
        buf.writeln('  建议: ${r['suggestion'] ?? '-'}');
        buf.writeln();
      }
      if (risks.isEmpty) buf.writeln('✅ 未发现明显风险条款。')..writeln();
      buf.writeln('> ⚠️ 仅供参考，建议由执业律师最终确认。');
      return ToolResult.success(content: buf.toString().trim(),
          data: {'overall_risk': data['overall_risk'], 'risk_count': risks.length});
    } catch (e) {
      return ToolResult.failure(error: '合同审核失败: $e', errorCode: 'REVIEW_FAILED');
    }
  }

  // ============================================================================
  // 学术模块执行
  // ============================================================================

  Future<ToolResult> _execPaperSearch(
    Map<String, dynamic> args, SkillContext ctx,
  ) async {
    final query = args['query'] as String;
    final source = args['source'] as String? ?? 'all';
    ctx.logger.info('论文搜索: "$query" ($source)');
    try {
      final body = <String, dynamic>{'query': query, 'source': source};
      for (final k in ['author','institution','year_from','year_to','sort_by']) {
        if (args[k] != null) body[k] = args[k];
      }
      body['max_results'] = args['max_results'] ?? 10;
      final data = await _apiPost(ctx, _config.academicUrl, '/papers/search', body);
      final papers = data['papers'] as List? ?? [];
      final buf = StringBuffer()
        ..writeln('## 📚 论文检索 — "$query"（${data['total'] ?? papers.length} 篇）')..writeln();
      for (int i = 0; i < papers.length; i++) {
        final p = papers[i] as Map<String, dynamic>;
        buf.writeln('**${i+1}. ${p['title'] ?? '-'}**');
        buf.writeln('  ${(p['authors'] as List? ?? []).join(', ')} | ${p['year'] ?? '-'} | '
            '引用:${p['citation_count'] ?? 0} | DOI:${p['doi'] ?? '-'}');
        final abs = p['abstract'] as String? ?? '';
        if (abs.isNotEmpty) buf.writeln('  ${abs.length > 250 ? '${abs.substring(0,250)}...' : abs}');
        buf.writeln();
      }
      return ToolResult.success(content: buf.toString().trim(),
          data: {'query': query, 'total': data['total']});
    } catch (e) {
      return ToolResult.failure(error: '论文搜索失败: $e', errorCode: 'PAPER_FAILED');
    }
  }

  Future<ToolResult> _execCitationTrace(
    Map<String, dynamic> args, SkillContext ctx,
  ) async {
    final pid = args['paper_id'] as String;
    final dir = args['direction'] as String? ?? 'both';
    ctx.logger.info('引用追溯: $pid ($dir)');
    try {
      final data = await _apiPost(ctx, _config.academicUrl, '/citation/trace', {
        'paper_id': pid, 'direction': dir,
        'max_depth': args['max_depth'] ?? 2, 'max_per_level': args['max_per_level'] ?? 10,
      });
      final root = data['root_paper'] as Map<String, dynamic>? ?? {};
      final refs = data['references'] as List? ?? [];
      final cites = data['citations'] as List? ?? [];
      final buf = StringBuffer()
        ..writeln('## 🔗 引用追溯报告')
        ..writeln('### 核心论文: ${root['title'] ?? '-'} (${root['year'] ?? '-'})')
        ..writeln('被引 ${root['citation_count'] ?? 0} 次')..writeln();
      if (dir != 'citations') {
        buf.writeln('### 参考文献 (${refs.length} 篇)');
        for (int i = 0; i < refs.length; i++) {
          final r = refs[i] as Map<String, dynamic>;
          buf.writeln('${i+1}. ${r['title'] ?? '-'} (${r['year'] ?? '-'}) 引用${r['citation_count'] ?? 0}');
        }
        buf.writeln();
      }
      if (dir != 'references') {
        buf.writeln('### 被引文献 (${cites.length} 篇)');
        for (int i = 0; i < cites.length; i++) {
          final c = cites[i] as Map<String, dynamic>;
          buf.writeln('${i+1}. ${c['title'] ?? '-'} (${c['year'] ?? '-'}) 引用${c['citation_count'] ?? 0}');
        }
        buf.writeln();
      }
      return ToolResult.success(content: buf.toString().trim());
    } catch (e) {
      return ToolResult.failure(error: '引用追溯失败: $e', errorCode: 'CITE_FAILED');
    }
  }

  // ============================================================================
  // 行业调研 / 公司尽调执行
  // ============================================================================

  Future<ToolResult> _execIndustryResearch(
    Map<String, dynamic> args, SkillContext ctx,
  ) async {
    final industry = args['industry'] as String;
    final region = args['region'] as String? ?? '全球';
    ctx.logger.info('行业调研: $industry ($region)');
    try {
      final body = <String, dynamic>{
        'industry': industry, 'region': region, 'depth': args['report_depth'] ?? 'standard',
      };
      if (args['focus'] != null) body['focus'] = (args['focus'] as String).split(',').map((s) => s.trim()).toList();
      final data = await _apiPost(ctx, _config.industryUrl, '/research', body);
      final buf = StringBuffer()..writeln('## 🏭 行业调研 — $industry ($region)')..writeln();
      final ms = data['market_size'] as Map<String, dynamic>?;
      if (ms != null) {
        buf.writeln('**市场规模**: ${ms['current'] ?? '-'} | 增长率: ${ms['growth_rate'] ?? '-'} | '
            'CAGR: ${ms['cagr'] ?? '-'} | ${ms['forecast_year']}预测: ${ms['forecast'] ?? '-'}');
        buf.writeln();
      }
      final comp = data['competition'] as Map<String, dynamic>?;
      if (comp != null) {
        buf.writeln('**竞争格局**: CR5=${comp['cr5'] ?? '-'} | 头部: ${(comp['top_players'] as List? ?? []).join('、')}');
        buf.writeln('态势: ${comp['landscape'] ?? '-'}');
        buf.writeln();
      }
      final trends = data['trends'] as List? ?? [];
      if (trends.isNotEmpty) {
        buf.writeln('### 发展趋势');
        for (final t in trends) { final m = t as Map<String, dynamic>; buf.writeln('- **${m['title']}**: ${m['description']}'); }
        buf.writeln();
      }
      if (data['policy'] != null) { buf.writeln('### 政策环境'); buf.writeln(data['policy']); buf.writeln(); }
      final risks = data['risk_factors'] as List? ?? [];
      if (risks.isNotEmpty) { buf.writeln('### 风险因素'); for (final r in risks) buf.writeln('- $r'); buf.writeln(); }
      return ToolResult.success(content: buf.toString().trim(), data: {'industry': industry});
    } catch (e) {
      return ToolResult.failure(error: '调研失败: $e', errorCode: 'RESEARCH_FAILED');
    }
  }

  Future<ToolResult> _execCompanyResearch(
    Map<String, dynamic> args, SkillContext ctx,
  ) async {
    final name = args['company_name'] as String;
    final mods = (args['modules'] as String? ?? 'basic,finance,shareholders,risk')
        .split(',').map((s) => s.trim()).toList();
    ctx.logger.info('公司尽调: $name');
    try {
      final body = <String, dynamic>{'company_name': name, 'modules': mods};
      if (args['credit_code'] != null) body['credit_code'] = args['credit_code'];
      final data = await _apiPost(ctx, _config.industryUrl, '/company/research', body);
      final buf = StringBuffer()..writeln('## 🏢 尽调报告 — $name')..writeln();
      if (mods.contains('basic') && data['basic_info'] != null) {
        final b = data['basic_info'] as Map<String, dynamic>;
        buf.writeln('**法人**: ${b['legal_representative'] ?? '-'} | '
            '**注册资本**: ${b['registered_capital'] ?? '-'} | '
            '**成立**: ${b['establish_date'] ?? '-'} | **状态**: ${b['status'] ?? '-'}');
        buf.writeln('地址: ${b['address'] ?? '-'}');
        buf.writeln('范围: ${b['business_scope'] ?? '-'}');
        buf.writeln();
      }
      if (mods.contains('finance') && data['finance'] != null) {
        final f = data['finance'] as Map<String, dynamic>;
        buf.writeln('**营收**: ${f['revenue'] ?? '-'} | **净利润**: ${f['net_profit'] ?? '-'} | '
            '**总资产**: ${f['total_assets'] ?? '-'} | **负债率**: ${f['debt_ratio'] ?? '-'}');
        buf.writeln();
      }
      if (mods.contains('shareholders') && data['shareholders'] != null) {
        buf.writeln('### 股东');
        for (final sh in data['shareholders'] as List) {
          final s = sh as Map<String, dynamic>;
          buf.writeln('- ${s['name']}: ${s['ratio']}%');
        }
        buf.writeln();
      }
      if (mods.contains('risk') && data['risks'] != null) {
        final r = data['risks'] as Map<String, dynamic>;
        buf.writeln('**诉讼**: ${r['lawsuits'] ?? 0}条 | **处罚**: ${r['penalties'] ?? 0}条 | '
            '**异常**: ${r['abnormal_records'] ?? 0}条');
        if (r['summary'] != null) buf.writeln('评估: ${r['summary']}');
        buf.writeln();
      }
      return ToolResult.success(content: buf.toString().trim());
    } catch (e) {
      return ToolResult.failure(error: '尽调失败: $e', errorCode: 'COMPANY_FAILED');
    }
  }

  // ============================================================================
  // 健康医疗执行
  // ============================================================================

  Future<ToolResult> _execMedicalReport(
    Map<String, dynamic> args, SkillContext ctx,
  ) async {
    final text = args['report_text'] as String;
    if (text.length < 10) return ToolResult.failure(error: '报告内容过短', errorCode: 'TOO_SHORT');
    final rtype = args['report_type'] as String? ?? 'physical_exam';
    ctx.logger.info('报告解读: $rtype, ${text.length}字');
    try {
      final body = <String, dynamic>{'report_text': text, 'report_type': rtype};
      for (final k in ['patient_age','patient_gender']) { if (args[k] != null) body[k] = args[k]; }
      final data = await _apiPost(ctx, _config.medicalUrl, '/report/interpret', body);
      final inds = data['indicators'] as List? ?? [];
      final buf = StringBuffer()
        ..writeln('## 🏥 报告解读 — ${_rtypeLabel(rtype)}')..writeln();
      if (data['summary'] != null) { buf.writeln(data['summary']); buf.writeln(); }
      for (final ind in inds) {
        final m = ind as Map<String, dynamic>;
        final st = m['status'] ?? '正常';
        buf.writeln('${(st == '偏高' || st == '异常') ? '⚠️' : '✅'} **${m['name']}**');
        buf.writeln('  值: ${m['value']} ${m['unit'] ?? ''} | 参考: ${m['ref_range'] ?? '-'} | 状态: $st');
        if (m['explanation'] != null) buf.writeln('  ${m['explanation']}');
        buf.writeln();
      }
      final sugg = data['suggestions'] as List? ?? [];
      if (sugg.isNotEmpty) { buf.writeln('### 建议'); for (final s in sugg) buf.writeln('- $s'); buf.writeln(); }
      buf.writeln('> ⚠️ 仅供参考，不构成医疗诊断。如有疑虑请及时就医。');
      return ToolResult.success(content: buf.toString().trim());
    } catch (e) {
      return ToolResult.failure(error: '解读失败: $e', errorCode: 'REPORT_FAILED');
    }
  }

  Future<ToolResult> _execDrugQuery(
    Map<String, dynamic> args, SkillContext ctx,
  ) async {
    final name = args['drug_name'] as String;
    final qt = args['query_type'] as String? ?? 'full';
    ctx.logger.info('药品查询: $name ($qt)');
    try {
      final data = await _apiPost(ctx, _config.medicalUrl, '/drug/query',
          {'drug_name': name, 'query_type': qt, 'include_herbal': args['include_herbal'] ?? false});
      final info = data['drug_info'] as Map<String, dynamic>? ?? {};
      final buf = StringBuffer()..writeln('## 💊 $name')..writeln();
      buf.writeln('**通用名**: ${info['generic_name'] ?? '-'} | **商品名**: ${info['brand_name'] ?? '-'}');
      buf.writeln('**批准文号**: ${info['approval_number'] ?? '-'} | **剂型**: ${info['dosage_form'] ?? '-'}');
      buf.writeln('**厂商**: ${info['manufacturer'] ?? '-'}')..writeln();
      if (qt == 'full' || qt == 'indication') { buf.writeln('**适应症**: ${info['indications'] ?? '-'}')..writeln(); }
      if (qt == 'full' || qt == 'dosage') { buf.writeln('**用法用量**: ${info['dosage'] ?? '-'}')..writeln(); }
      if (qt == 'full' || qt == 'side_effects') {
        buf.writeln('**不良反应**: ${info['side_effects'] ?? '-'}');
        buf.writeln('**禁忌**: ${info['contraindications'] ?? '-'}')..writeln();
      }
      if (qt == 'full' || qt == 'interaction') {
        buf.writeln('**相互作用**: ${info['interactions'] ?? '-'}');
        buf.writeln('**注意事项**: ${info['precautions'] ?? '-'}')..writeln();
      }
      buf.writeln('> ⚠️ 信息仅供参考，用药请遵医嘱。');
      return ToolResult.success(content: buf.toString().trim());
    } catch (e) {
      return ToolResult.failure(error: '查询失败: $e', errorCode: 'DRUG_FAILED');
    }
  }

  Future<ToolResult> _execHealthAdvice(
    Map<String, dynamic> args, SkillContext ctx,
  ) async {
    final q = args['question'] as String;
    final cat = args['category'] as String? ?? 'general';
    try {
      final data = await _apiPost(ctx, _config.medicalUrl, '/health/advice',
          {'question': q, 'category': cat});
      final buf = StringBuffer()
        ..writeln('## 🏃 健康问答 — ${_catLabel(cat)}')..writeln()
        ..writeln(data['answer'] ?? '');
      final refs = data['references'] as List? ?? [];
      if (refs.isNotEmpty) { buf.writeln()..writeln('**参考**:'); for (final r in refs) { final m = r as Map; buf.writeln('- ${m['title']} — ${m['source']}'); } }
      buf.writeln()..writeln('> ⚠️ 仅供参考，不替代专业医疗建议。');
      return ToolResult.success(content: buf.toString().trim());
    } catch (e) {
      return ToolResult.failure(error: '问答失败: $e', errorCode: 'HEALTH_FAILED');
    }
  }

  // ============================================================================
  // 技术指标计算
  // ============================================================================

  String _buildFundamentalReport(Map<String, dynamic> f) {
    final buf = StringBuffer()..writeln('### 基本面')..writeln('| 指标 | 数值 |')..writeln('|---|---|');
    buf.writeln('| PE | ${f['pe_ratio'] ?? '-'} |');
    buf.writeln('| PB | ${f['pb_ratio'] ?? '-'} |');
    buf.writeln('| ROE | ${f['roe'] ?? '-'} |');
    buf.writeln('| 营收增速 | ${f['revenue_growth'] ?? '-'} |');
    buf.writeln('| 净利润率 | ${f['net_profit_margin'] ?? '-'} |');
    buf.writeln('| 负债率 | ${f['debt_ratio'] ?? '-'} |');
    if (f['comment'] != null) { buf.writeln(); buf.writeln(f['comment']); }
    return buf.toString();
  }

  String _buildTechnicalReport(List<Map<String, dynamic>> klines) {
    if (klines.isEmpty) return '';
    final closes = klines.map((k) => (k['close'] as num?)?.toDouble() ?? 0).toList();
    final highs = klines.map((k) => (k['high'] as num?)?.toDouble() ?? 0).toList();
    final lows = klines.map((k) => (k['low'] as num?)?.toDouble() ?? 0).toList();
    final buf = StringBuffer()..writeln('### 技术面')..writeln();

    // 均线系统
    buf.writeln('**均线系统**');
    buf.writeln('MA5: ${_ma(closes, 5).toStringAsFixed(2)}');
    buf.writeln('MA10: ${_ma(closes, 10).toStringAsFixed(2)}');
    buf.writeln('MA20: ${_ma(closes, 20).toStringAsFixed(2)}');
    if (closes.length >= 60) buf.writeln('MA60: ${_ma(closes, 60).toStringAsFixed(2)}');
    buf.writeln();

    // MACD 指标
    final macdVal = _macd(closes);
    buf.writeln('**MACD 指标**');
    if (macdVal['dif'] != null) {
      buf.writeln('DIF: ${macdVal['dif']!.toStringAsFixed(4)}');
      buf.writeln('DEA: ${macdVal['dea']!.toStringAsFixed(4)}');
      final hist = (macdVal['dif']! - macdVal['dea']!) * 2;
      buf.writeln('MACD柱: ${hist.toStringAsFixed(4)}');
    }
    buf.writeln();

    // RSI 指标
    buf.writeln('**RSI 指标**');
    final rsi6 = _rsi(closes, 6);
    final rsi14 = _rsi(closes, 14);
    buf.writeln('RSI(6): ${rsi6.toStringAsFixed(1)} — ${_rsiLabel(rsi6)}');
    buf.writeln('RSI(14): ${rsi14.toStringAsFixed(1)} — ${_rsiLabel(rsi14)}');
    buf.writeln();

    // KDJ 指标
    if (closes.length >= 9) {
      final kdj = _kdj(closes, highs, lows);
      buf.writeln('**KDJ 指标**');
      buf.writeln('K: ${kdj['k']!.toStringAsFixed(1)} | D: ${kdj['d']!.toStringAsFixed(1)} | J: ${kdj['j']!.toStringAsFixed(1)}');
      buf.writeln();
    }

    // 布林带
    if (closes.length >= 20) {
      final boll = _bollinger(closes, 20);
      buf.writeln('**布林带 (20,2)**');
      buf.writeln('上轨: ${boll['upper']!.toStringAsFixed(2)}');
      buf.writeln('中轨: ${boll['middle']!.toStringAsFixed(2)}');
      buf.writeln('下轨: ${boll['lower']!.toStringAsFixed(2)}');
      buf.writeln();
    }

    // 综合趋势判断
    final m5 = _ma(closes, 5), m10 = _ma(closes, 10), m20 = _ma(closes, 20);
    String trend;
    if (m5 > m10 && m10 > m20) {
      trend = '多头排列（上升趋势）';
    } else if (m5 < m10 && m10 < m20) {
      trend = '空头排列（下降趋势）';
    } else {
      trend = '均线交织（震荡整理）';
    }
    buf.writeln('**趋势判断**: $trend');
    buf.writeln('**最新收盘价**: ${closes.last}');
    return buf.toString();
  }

  /// RSI 状态标签
  String _rsiLabel(double rsi) {
    if (rsi >= 80) return '严重超买';
    if (rsi >= 70) return '超买';
    if (rsi <= 20) return '严重超卖';
    if (rsi <= 30) return '超卖';
    return '中性';
  }

  /// KDJ 计算
  Map<String, double?> _kdj(List<double> closes, List<double> highs, List<double> lows) {
    const period = 9;
    if (closes.length < period) return {'k': null, 'd': null, 'j': null};
    double kVal = 50, dVal = 50;
    for (int i = period - 1; i < closes.length; i++) {
      final hSlice = highs.sublist(i - period + 1, i + 1);
      final lSlice = lows.sublist(i - period + 1, i + 1);
      final hn = hSlice.reduce(max), ln = lSlice.reduce(min);
      final rsv = (hn == ln) ? 50.0 : ((closes[i] - ln) / (hn - ln) * 100);
      kVal = 2 / 3 * kVal + 1 / 3 * rsv;
      dVal = 2 / 3 * dVal + 1 / 3 * kVal;
    }
    return {'k': kVal, 'd': dVal, 'j': 3 * kVal - 2 * dVal};
  }

  /// 布林带计算
  Map<String, double?> _bollinger(List<double> closes, int period) {
    if (closes.length < period) return {'upper': null, 'middle': null, 'lower': null};
    final slice = closes.sublist(closes.length - period);
    final mean = slice.reduce((a, b) => a + b) / period;
    final variance = slice.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / period;
    final stdDev = sqrt(variance);
    return {'upper': mean + 2 * stdDev, 'middle': mean, 'lower': mean - 2 * stdDev};
  }

  double _ma(List<double> d, int p) {
    if (d.length < p) return d.isEmpty ? 0 : d.reduce((a,b) => a+b) / d.length;
    return d.sublist(d.length - p).reduce((a,b) => a+b) / p;
  }

  double _rsi(List<double> c, int p) {
    if (c.length < p + 1) return 50;
    double g = 0, l = 0;
    for (int i = c.length - p; i < c.length; i++) {
      final d = c[i] - c[i-1]; if (d > 0) g += d; if (d < 0) l += d.abs();
    }
    if (l == 0) return 100;
    final rs = (g / p) / (l / p); return 100 - 100 / (1 + rs);
  }

  Map<String, double?> _macd(List<double> c) {
    if (c.length < 26) return {'dif': null, 'dea': null};
    final e12 = _ema(c, 12), e26 = _ema(c, 26);
    final dif = e12 - e26;
    return {'dif': dif, 'dea': dif * 0.2};
  }

  double _ema(List<double> d, int p) {
    final m = 2.0 / (p + 1); double v = d.first;
    for (int i = 1; i < d.length; i++) v = (d[i] - v) * m + v;
    return v;
  }

  // ============================================================================
  // 公共辅助
  // ============================================================================

  bool _throttleOk(String key) {
    final now = DateTime.now();
    final last = _throttleMap[key];
    if (last != null && now.difference(last) < _throttleInterval) return false;
    _throttleMap[key] = now; return true;
  }

  Future<Map<String, dynamic>> _apiPost(
    SkillContext ctx, String base, String path, Map<String, dynamic> body,
  ) async {
    final resp = await ctx.http.post('$base$path',
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${_config.apiKey}'}, body: body);
    return jsonDecode(resp) as Map<String, dynamic>;
  }

  String _fmtVol(dynamic v) {
    if (v is num) {
      if (v >= 1e8) return '${(v/1e8).toStringAsFixed(2)}亿';
      if (v >= 1e4) return '${(v/1e4).toStringAsFixed(2)}万';
    }
    return v.toString();
  }

  String _domainLabel(String d) => switch(d) {
    'contract'=>'合同法','labor'=>'劳动法','company'=>'公司法','ip'=>'知识产权',
    'real_estate'=>'房产','marriage'=>'婚姻','traffic'=>'交通','criminal'=>'刑事', _=>'综合'};
  String _ctypeLabel(String t) => switch(t) {
    'sales'=>'买卖','lease'=>'租赁','employment'=>'劳动','nda'=>'保密',
    'service'=>'服务','partnership'=>'合伙','loan'=>'借贷','license'=>'许可', _=>'其他'};
  String _rtypeLabel(String t) => switch(t) {
    'physical_exam'=>'体检','blood_test'=>'血液','imaging'=>'影像',
    'pathology'=>'病理','urine_test'=>'尿检', _=>'其他'};
  String _catLabel(String c) => switch(c) {
    'nutrition'=>'营养','exercise'=>'运动','sleep'=>'睡眠','mental'=>'心理',
    'chronic_disease'=>'慢病','symptom'=>'症状','prevention'=>'预防', _=>'综合'};
}

// ============================================================================
// 配置
// ============================================================================

class ProDomainConfig {
  final String apiKey;
  final String financeUrl;
  final String legalUrl;
  final String academicUrl;
  final String industryUrl;
  final String medicalUrl;
  const ProDomainConfig({
    this.apiKey = '',
    this.financeUrl = 'https://api.xiaosu.ai/v1/finance',
    this.legalUrl = 'https://api.xiaosu.ai/v1/legal',
    this.academicUrl = 'https://api.xiaosu.ai/v1/academic',
    this.industryUrl = 'https://api.xiaosu.ai/v1/industry',
    this.medicalUrl = 'https://api.xiaosu.ai/v1/medical',
  });
}
