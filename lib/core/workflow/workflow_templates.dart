/// ============================================================================
/// 小酥 AI 助手 — 工作流模板库
/// ============================================================================
/// 预设 10+ 个工作流模板，覆盖新闻简报、内容发布、竞品监控、论文追踪、
/// 邮件回复、会议纪要、代码审查、数据报表、客户服务、漫剧制作等场景。
/// ============================================================================

import 'workflow_engine.dart';

/// 工作流模板分类
enum TemplateCategory {
  content, monitoring, productivity, development, data, entertainment,
}

/// 工作流模板元数据
class WorkflowTemplateInfo {
  final String id;
  final String name;
  final String description;
  final String category;
  final List<String> tags;
  final String difficulty; // easy / medium / advanced
  final int estimatedNodes;
  final String usage;

  const WorkflowTemplateInfo({
    required this.id, required this.name, required this.description,
    required this.category, this.tags = const [], this.difficulty = 'medium',
    this.estimatedNodes = 0, this.usage = '',
  });
}

/// 工作流模板库
class WorkflowTemplates {
  WorkflowTemplates._();
  static final instance = WorkflowTemplates._();

  /// 获取所有模板信息列表
  List<WorkflowTemplateInfo> listTemplates({String? category}) {
    final all = [
      const WorkflowTemplateInfo(id: 'daily_news', name: '每日新闻简报',
          description: '定时搜索热点新闻，LLM 生成摘要，自动发送邮件简报',
          category: 'content', tags: ['新闻', '自动化', '邮件'],
          difficulty: 'easy', estimatedNodes: 5,
          usage: '配置新闻关键词和收件人邮箱，设置定时触发周期'),
      const WorkflowTemplateInfo(id: 'multi_platform_publish', name: '内容多平台发布',
          description: '输入一篇文案，自动适配各平台格式，违禁词检查后批量发布',
          category: 'content', tags: ['发布', '多平台', '违禁词检查'],
          difficulty: 'medium', estimatedNodes: 7,
          usage: '输入原始文案，配置目标平台账号，一键发布'),
      const WorkflowTemplateInfo(id: 'competitor_monitor', name: '竞品监控',
          description: '定时搜索竞品动态，LLM 对比分析，自动生成竞品报告',
          category: 'monitoring', tags: ['竞品', '监控', '报告'],
          difficulty: 'medium', estimatedNodes: 5,
          usage: '配置竞品关键词列表和监控频率，自动生成对比分析报告'),
      const WorkflowTemplateInfo(id: 'paper_tracker', name: '论文追踪',
          description: '根据关键词搜索 arXiv 新论文，提取摘要，推送通知',
          category: 'monitoring', tags: ['论文', 'arXiv', '学术'],
          difficulty: 'easy', estimatedNodes: 4,
          usage: '设置研究关键词，系统自动追踪最新论文并推送摘要'),
      const WorkflowTemplateInfo(id: 'auto_reply', name: '邮件自动回复',
          description: '收到邮件后分析意图，LLM 生成回复草稿，确认后发送',
          category: 'productivity', tags: ['邮件', '自动回复', 'LLM'],
          difficulty: 'medium', estimatedNodes: 5,
          usage: '绑定邮箱，配置回复风格和自动回复规则'),
      const WorkflowTemplateInfo(id: 'meeting_notes', name: '会议纪要生成',
          description: '输入录音或文字，提取要点，生成结构化纪要，创建待办任务',
          category: 'productivity', tags: ['会议', '纪要', '任务'],
          difficulty: 'medium', estimatedNodes: 5,
          usage: '输入会议录音转写文本或手动输入，自动生成纪要并创建任务'),
      const WorkflowTemplateInfo(id: 'code_review', name: '代码审查',
          description: '输入代码，静态分析，LLM Review，生成审查报告',
          category: 'development', tags: ['代码', '审查', '开发'],
          difficulty: 'advanced', estimatedNodes: 5,
          usage: '粘贴代码或指定文件路径，自动进行代码审查'),
      const WorkflowTemplateInfo(id: 'data_report', name: '数据报表生成',
          description: '定时获取数据源，生成可视化图表，导出 PDF 报告',
          category: 'data', tags: ['数据', '报表', '图表'],
          difficulty: 'medium', estimatedNodes: 5,
          usage: '配置数据源和报表模板，定时自动生成数据报告'),
      const WorkflowTemplateInfo(id: 'customer_service', name: '智能客服',
          description: '收到客户消息，意图识别，知识库检索，生成回复',
          category: 'productivity', tags: ['客服', '知识库', '意图识别'],
          difficulty: 'advanced', estimatedNodes: 6,
          usage: '配置知识库和服务规则，自动处理客户咨询'),
      const WorkflowTemplateInfo(id: 'anime_pipeline', name: '漫剧制作流水线',
          description: '输入剧本，角色生成，分镜生成，图片生成，视频合成',
          category: 'entertainment', tags: ['漫剧', 'AI绘画', '视频'],
          difficulty: 'advanced', estimatedNodes: 7,
          usage: '输入完整剧本，系统自动完成角色设计、分镜、画面生成'),
      const WorkflowTemplateInfo(id: 'social_media_analytics', name: '社媒数据分析',
          description: '采集社交媒体数据，分析趋势，生成运营建议',
          category: 'data', tags: ['社媒', '分析', '运营'],
          difficulty: 'medium', estimatedNodes: 5,
          usage: '配置社交媒体账号和采集周期，自动生成运营分析报告'),
      const WorkflowTemplateInfo(id: 'knowledge_qa', name: '知识库问答',
          description: '接收用户问题，语义检索知识库，LLM 生成回答',
          category: 'productivity', tags: ['知识库', 'RAG', '问答'],
          difficulty: 'medium', estimatedNodes: 4,
          usage: '导入知识文档，配置回答风格，即可进行知识库问答'),
    ];
    if (category != null) return all.where((t) => t.category == category).toList();
    return all;
  }

  /// 根据 ID 获取完整模板工作流
  Workflow getTemplate(String id) {
    switch (id) {
      case 'daily_news': return _dailyNews();
      case 'multi_platform_publish': return _multiPlatformPublish();
      case 'competitor_monitor': return _competitorMonitor();
      case 'paper_tracker': return _paperTracker();
      case 'auto_reply': return _autoReply();
      case 'meeting_notes': return _meetingNotes();
      case 'code_review': return _codeReview();
      case 'data_report': return _dataReport();
      case 'customer_service': return _customerService();
      case 'anime_pipeline': return _animePipeline();
      case 'social_media_analytics': return _socialMediaAnalytics();
      case 'knowledge_qa': return _knowledgeQA();
      default: throw ArgumentError('未知模板 ID: $id');
    }
  }

  // ————————————————————————— 模板 1: 每日新闻简报 —————————————————————————
  // 定时触发 → 搜索新闻 → LLM 摘要 → 格式化 → 发送邮件
  Workflow _dailyNews() => Workflow(
    id: 'tpl_daily_news', name: '每日新闻简报',
    description: '定时搜索热点新闻，LLM 摘要，自动发送邮件简报',
    triggers: [const WorkflowTrigger(type: TriggerType.schedule, cronExpression: '0 8 * * *')],
    variables: {'keywords': '科技,AI,人工智能', 'recipientEmail': ''},
    nodes: [
      const WorkflowNode(id: 'n1', name: '定时触发', type: NodeType.triggerSchedule,
          config: {'cron': '0 8 * * *'}, description: '每天早上8点触发'),
      const WorkflowNode(id: 'n2', name: '搜索新闻', type: NodeType.tool,
          config: {'toolName': 'web_search', 'arguments': {'query': '{{keywords}}', 'count': 10}}),
      const WorkflowNode(id: 'n3', name: 'LLM 摘要', type: NodeType.llm,
          config: {'prompt': '请将以下新闻标题和摘要整理成一份简洁的每日新闻简报：\n{{in}}', 'model': 'default', 'temperature': 0.3}),
      const WorkflowNode(id: 'n4', name: '格式化邮件', type: NodeType.transform,
          config: {'template': '<h2>📰 每日新闻简报</h2>\n\n{{input}}\n\n---\n<small>由小酥 AI 自动生成</small>'}),
      const WorkflowNode(id: 'n5', name: '发送邮件', type: NodeType.tool,
          config: {'toolName': 'send_email', 'arguments': {'to': '{{recipientEmail}}', 'subject': '每日新闻简报', 'body': '{{in}}'}}),
    ],
    edges: const [
      WorkflowEdge(id: 'e1', sourceNodeId: 'n1', targetNodeId: 'n2'),
      WorkflowEdge(id: 'e2', sourceNodeId: 'n2', targetNodeId: 'n3'),
      WorkflowEdge(id: 'e3', sourceNodeId: 'n3', targetNodeId: 'n4'),
      WorkflowEdge(id: 'e4', sourceNodeId: 'n4', targetNodeId: 'n5'),
    ],
  );

  // ————————————————————————— 模板 2: 内容多平台发布 —————————————————————————
  Workflow _multiPlatformPublish() => Workflow(
    id: 'tpl_multi_platform', name: '内容多平台发布',
    description: '输入文案 → 适配各平台格式 → 违禁词检查 → 批量发布',
    nodes: [
      const WorkflowNode(id: 'n1', name: '输入文案', type: NodeType.triggerManual),
      const WorkflowNode(id: 'n2', name: '适配小红书', type: NodeType.llm,
          config: {'prompt': '将以下内容改写为小红书风格（加入emoji、口语化、标签）：\n{{in}}'}),
      const WorkflowNode(id: 'n3', name: '适配公众号', type: NodeType.llm,
          config: {'prompt': '将以下内容改写为微信公众号风格（正式、结构化、有深度）：\n{{in}}'}),
      const WorkflowNode(id: 'n4', name: '适配抖音', type: NodeType.llm,
          config: {'prompt': '将以下内容改写为抖音文案风格（短句、吸引眼球、带话题标签）：\n{{in}}'}),
      const WorkflowNode(id: 'n5', name: '违禁词检查', type: NodeType.tool,
          config: {'toolName': 'prohibited_word_check', 'arguments': {'platforms': ['xiaohongshu', 'wechat', 'douyin']}}),
      const WorkflowNode(id: 'n6', name: '条件判断', type: NodeType.condition,
          config: {'expression': '{{checkResult}} == passed'}),
      const WorkflowNode(id: 'n7', name: '批量发布', type: NodeType.tool,
          config: {'toolName': 'multi_publish', 'arguments': {'platforms': 'all'}}),
      const WorkflowNode(id: 'n8', name: '输出警告', type: NodeType.output,
          config: {'message': '内容包含违禁词，请修改后重试'}),
    ],
    edges: const [
      WorkflowEdge(id: 'e1', sourceNodeId: 'n1', targetNodeId: 'n2'),
      WorkflowEdge(id: 'e2', sourceNodeId: 'n1', targetNodeId: 'n3'),
      WorkflowEdge(id: 'e3', sourceNodeId: 'n1', targetNodeId: 'n4'),
      WorkflowEdge(id: 'e4', sourceNodeId: 'n2', targetNodeId: 'n5'),
      WorkflowEdge(id: 'e5', sourceNodeId: 'n3', targetNodeId: 'n5'),
      WorkflowEdge(id: 'e6', sourceNodeId: 'n4', targetNodeId: 'n5'),
      WorkflowEdge(id: 'e7', sourceNodeId: 'n5', targetNodeId: 'n6'),
      WorkflowEdge(id: 'e8', sourceNodeId: 'n6', targetNodeId: 'n7', condition: 'true'),
      WorkflowEdge(id: 'e9', sourceNodeId: 'n6', targetNodeId: 'n8', condition: 'false'),
    ],
  );

  // ————————————————————————— 模板 3: 竞品监控 —————————————————————————
  Workflow _competitorMonitor() => Workflow(
    id: 'tpl_competitor', name: '竞品监控',
    description: '定时搜索竞品动态，LLM 对比分析，生成竞品报告',
    triggers: [const WorkflowTrigger(type: TriggerType.schedule, cronExpression: '0 9 * * 1')],
    variables: {'competitors': '产品A,产品B,产品C'},
    nodes: [
      const WorkflowNode(id: 'n1', name: '定时触发', type: NodeType.triggerSchedule,
          config: {'cron': '0 9 * * 1'}),
      const WorkflowNode(id: 'n2', name: '搜索竞品A', type: NodeType.tool,
          config: {'toolName': 'web_search', 'arguments': {'query': '{{competitors}} 最新动态'}}),
      const WorkflowNode(id: 'n3', name: '搜索行业资讯', type: NodeType.tool,
          config: {'toolName': 'web_search', 'arguments': {'query': '行业动态 市场趋势'}}),
      const WorkflowNode(id: 'n4', name: '合并数据', type: NodeType.merge),
      const WorkflowNode(id: 'n5', name: 'LLM 对比分析', type: NodeType.llm,
          config: {'prompt': '基于以下信息，生成一份详细的竞品分析报告，包括各产品优劣势对比、市场趋势分析、建议策略：\n{{in}}'}),
      const WorkflowNode(id: 'n6', name: '输出报告', type: NodeType.output),
    ],
    edges: const [
      WorkflowEdge(id: 'e1', sourceNodeId: 'n1', targetNodeId: 'n2'),
      WorkflowEdge(id: 'e2', sourceNodeId: 'n1', targetNodeId: 'n3'),
      WorkflowEdge(id: 'e3', sourceNodeId: 'n2', targetNodeId: 'n4'),
      WorkflowEdge(id: 'e4', sourceNodeId: 'n3', targetNodeId: 'n4'),
      WorkflowEdge(id: 'e5', sourceNodeId: 'n4', targetNodeId: 'n5'),
      WorkflowEdge(id: 'e6', sourceNodeId: 'n5', targetNodeId: 'n6'),
    ],
  );

  // ————————————————————————— 模板 4: 论文追踪 —————————————————————————
  Workflow _paperTracker() => Workflow(
    id: 'tpl_paper', name: '论文追踪',
    description: '关键词搜索 arXiv 新论文，摘要提取，推送通知',
    triggers: [const WorkflowTrigger(type: TriggerType.schedule, cronExpression: '0 10 * * *')],
    variables: {'keywords': 'large language model, transformer', 'maxResults': '5'},
    nodes: [
      const WorkflowNode(id: 'n1', name: '定时触发', type: NodeType.triggerSchedule,
          config: {'cron': '0 10 * * *'}),
      const WorkflowNode(id: 'n2', name: '搜索 arXiv', type: NodeType.tool,
          config: {'toolName': 'arxiv_search', 'arguments': {'query': '{{keywords}}', 'maxResults': '{{maxResults}}'}}),
      const WorkflowNode(id: 'n3', name: '提取摘要', type: NodeType.llm,
          config: {'prompt': '请为以下论文列表生成中文摘要和关键发现：\n{{in}}', 'temperature': 0.2}),
      const WorkflowNode(id: 'n4', name: '推送通知', type: NodeType.tool,
          config: {'toolName': 'send_notification', 'arguments': {'title': '论文追踪更新', 'content': '{{in}}'}}),
    ],
    edges: const [
      WorkflowEdge(id: 'e1', sourceNodeId: 'n1', targetNodeId: 'n2'),
      WorkflowEdge(id: 'e2', sourceNodeId: 'n2', targetNodeId: 'n3'),
      WorkflowEdge(id: 'e3', sourceNodeId: 'n3', targetNodeId: 'n4'),
    ],
  );

  // ————————————————————————— 模板 5: 邮件自动回复 —————————————————————————
  Workflow _autoReply() => Workflow(
    id: 'tpl_auto_reply', name: '邮件自动回复',
    description: '收到邮件 → LLM 分析意图 → 生成回复 → 审批 → 发送',
    triggers: [const WorkflowTrigger(type: TriggerType.event, eventName: 'new_email')],
    nodes: [
      const WorkflowNode(id: 'n1', name: '收到邮件', type: NodeType.triggerEvent,
          config: {'event': 'new_email'}),
      const WorkflowNode(id: 'n2', name: '分析意图', type: NodeType.llm,
          config: {'prompt': '分析以下邮件的意图和关键信息，返回 JSON 格式：{intent, keyPoints, urgency}：\n{{in}}'}),
      const WorkflowNode(id: 'n3', name: '生成回复', type: NodeType.llm,
          config: {'prompt': '根据以下邮件内容和分析结果，生成一封专业得体的回复邮件：\n原始邮件：{{originalEmail}}\n分析结果：{{in}}'}),
      const WorkflowNode(id: 'n4', name: '审批确认', type: NodeType.approval,
          config: {'message': '请确认以下邮件回复是否合适', 'autoApprove': false}),
      const WorkflowNode(id: 'n5', name: '发送回复', type: NodeType.tool,
          config: {'toolName': 'send_email', 'arguments': {'reply': true}}),
    ],
    edges: const [
      WorkflowEdge(id: 'e1', sourceNodeId: 'n1', targetNodeId: 'n2'),
      WorkflowEdge(id: 'e2', sourceNodeId: 'n2', targetNodeId: 'n3'),
      WorkflowEdge(id: 'e3', sourceNodeId: 'n3', targetNodeId: 'n4'),
      WorkflowEdge(id: 'e4', sourceNodeId: 'n4', targetNodeId: 'n5'),
    ],
  );

  // ————————————————————————— 模板 6: 会议纪要生成 —————————————————————————
  Workflow _meetingNotes() => Workflow(
    id: 'tpl_meeting', name: '会议纪要生成',
    description: '输入录音/文字 → 提取要点 → 生成纪要 → 创建任务',
    nodes: [
      const WorkflowNode(id: 'n1', name: '输入会议内容', type: NodeType.triggerManual),
      const WorkflowNode(id: 'n2', name: '提取要点', type: NodeType.llm,
          config: {'prompt': '请从以下会议内容中提取：1.关键讨论点 2.决策结论 3.待办事项（含负责人和截止日期）：\n{{in}}'}),
      const WorkflowNode(id: 'n3', name: '生成纪要', type: NodeType.transform,
          config: {'template': '# 会议纪要\n\n## 关键讨论点\n{{keyPoints}}\n\n## 决策结论\n{{decisions}}\n\n## 待办事项\n{{actionItems}}'}),
      const WorkflowNode(id: 'n4', name: '拆分待办', type: NodeType.split),
      const WorkflowNode(id: 'n5', name: '创建任务', type: NodeType.loop,
          config: {'loopType': 'forEach', 'items': '{{actionItems}}'}),
      const WorkflowNode(id: 'n6', name: '保存任务', type: NodeType.tool,
          config: {'toolName': 'create_task', 'arguments': {'title': '{{_loopItem}}'}}),
      const WorkflowNode(id: 'n7', name: '输出纪要', type: NodeType.output),
    ],
    edges: const [
      WorkflowEdge(id: 'e1', sourceNodeId: 'n1', targetNodeId: 'n2'),
      WorkflowEdge(id: 'e2', sourceNodeId: 'n2', targetNodeId: 'n3'),
      WorkflowEdge(id: 'e3', sourceNodeId: 'n3', targetNodeId: 'n7'),
      WorkflowEdge(id: 'e4', sourceNodeId: 'n3', targetNodeId: 'n4'),
      WorkflowEdge(id: 'e5', sourceNodeId: 'n4', targetNodeId: 'n5'),
      WorkflowEdge(id: 'e6', sourceNodeId: 'n5', targetNodeId: 'n6'),
    ],
  );

  // ————————————————————————— 模板 7: 代码审查 —————————————————————————
  Workflow _codeReview() => Workflow(
    id: 'tpl_code_review', name: '代码审查',
    description: '输入代码 → 静态分析 → LLM Review → 生成报告',
    nodes: [
      const WorkflowNode(id: 'n1', name: '输入代码', type: NodeType.triggerManual),
      const WorkflowNode(id: 'n2', name: '静态分析', type: NodeType.code,
          config: {'code': '分析代码结构、复杂度、潜在bug'}),
      const WorkflowNode(id: 'n3', name: 'LLM Review', type: NodeType.llm,
          config: {'prompt': '你是一位资深代码审查员。请审查以下代码，指出：1.潜在Bug 2.性能问题 3.代码风格 4.安全漏洞 5.改进建议。\n代码：\n{{in}}', 'temperature': 0.2}),
      const WorkflowNode(id: 'n4', name: '格式化报告', type: NodeType.transform,
          config: {'template': '# 代码审查报告\n\n## 静态分析结果\n{{staticAnalysis}}\n\n## AI Review\n{{input}}'}),
      const WorkflowNode(id: 'n5', name: '输出报告', type: NodeType.output),
    ],
    edges: const [
      WorkflowEdge(id: 'e1', sourceNodeId: 'n1', targetNodeId: 'n2'),
      WorkflowEdge(id: 'e2', sourceNodeId: 'n1', targetNodeId: 'n3'),
      WorkflowEdge(id: 'e3', sourceNodeId: 'n2', targetNodeId: 'n4'),
      WorkflowEdge(id: 'e4', sourceNodeId: 'n3', targetNodeId: 'n4'),
      WorkflowEdge(id: 'e5', sourceNodeId: 'n4', targetNodeId: 'n5'),
    ],
  );

  // ————————————————————————— 模板 8: 数据报表 —————————————————————————
  Workflow _dataReport() => Workflow(
    id: 'tpl_data_report', name: '数据报表生成',
    description: '定时获取数据 → 生成图表 → 导出 PDF',
    triggers: [const WorkflowTrigger(type: TriggerType.schedule, cronExpression: '0 17 * * 5')],
    variables: {'dataSource': 'api_endpoint', 'reportTitle': '周数据报告'},
    nodes: [
      const WorkflowNode(id: 'n1', name: '定时触发', type: NodeType.triggerSchedule,
          config: {'cron': '0 17 * * 5'}),
      const WorkflowNode(id: 'n2', name: '获取数据', type: NodeType.http,
          config: {'url': '{{dataSource}}', 'method': 'GET'}),
      const WorkflowNode(id: 'n3', name: '生成图表', type: NodeType.tool,
          config: {'toolName': 'generate_chart', 'arguments': {'type': 'mixed', 'data': '{{in}}'}}),
      const WorkflowNode(id: 'n4', name: 'LLM 分析', type: NodeType.llm,
          config: {'prompt': '分析以下数据并给出趋势总结和建议：\n{{in}}'}),
      const WorkflowNode(id: 'n5', name: '导出 PDF', type: NodeType.tool,
          config: {'toolName': 'export_pdf', 'arguments': {'title': '{{reportTitle}}', 'content': '{{in}}'}}),
    ],
    edges: const [
      WorkflowEdge(id: 'e1', sourceNodeId: 'n1', targetNodeId: 'n2'),
      WorkflowEdge(id: 'e2', sourceNodeId: 'n2', targetNodeId: 'n3'),
      WorkflowEdge(id: 'e3', sourceNodeId: 'n2', targetNodeId: 'n4'),
      WorkflowEdge(id: 'e4', sourceNodeId: 'n3', targetNodeId: 'n5'),
      WorkflowEdge(id: 'e5', sourceNodeId: 'n4', targetNodeId: 'n5'),
    ],
  );

  // ————————————————————————— 模板 9: 智能客服 —————————————————————————
  Workflow _customerService() => Workflow(
    id: 'tpl_customer_service', name: '智能客服',
    description: '收到消息 → 意图识别 → 知识库检索 → 生成回复',
    triggers: [const WorkflowTrigger(type: TriggerType.event, eventName: 'customer_message')],
    nodes: [
      const WorkflowNode(id: 'n1', name: '收到消息', type: NodeType.triggerEvent,
          config: {'event': 'customer_message'}),
      const WorkflowNode(id: 'n2', name: '意图识别', type: NodeType.llm,
          config: {'prompt': '分析以下客户消息的意图类别（咨询/投诉/建议/闲聊）：\n{{in}}'}),
      const WorkflowNode(id: 'n3', name: '条件路由', type: NodeType.condition,
          config: {'expression': '{{intent}} == 咨询'}),
      const WorkflowNode(id: 'n4', name: '知识库检索', type: NodeType.tool,
          config: {'toolName': 'knowledge_search', 'arguments': {'query': '{{in}}'}}),
      const WorkflowNode(id: 'n5', name: '生成回复', type: NodeType.llm,
          config: {'prompt': '基于以下知识库内容，用友好专业的语气回复客户问题：\n客户问题：{{originalMessage}}\n知识库：{{in}}'}),
      const WorkflowNode(id: 'n6', name: '转人工', type: NodeType.tool,
          config: {'toolName': 'transfer_to_human', 'arguments': {'reason': '非咨询类问题'}}),
      const WorkflowNode(id: 'n7', name: '发送回复', type: NodeType.output),
    ],
    edges: const [
      WorkflowEdge(id: 'e1', sourceNodeId: 'n1', targetNodeId: 'n2'),
      WorkflowEdge(id: 'e2', sourceNodeId: 'n2', targetNodeId: 'n3'),
      WorkflowEdge(id: 'e3', sourceNodeId: 'n3', targetNodeId: 'n4', condition: 'true'),
      WorkflowEdge(id: 'e4', sourceNodeId: 'n3', targetNodeId: 'n6', condition: 'false'),
      WorkflowEdge(id: 'e5', sourceNodeId: 'n4', targetNodeId: 'n5'),
      WorkflowEdge(id: 'e6', sourceNodeId: 'n5', targetNodeId: 'n7'),
    ],
  );

  // ————————————————————————— 模板 10: 漫剧制作流水线 —————————————————————————
  Workflow _animePipeline() => Workflow(
    id: 'tpl_anime', name: '漫剧制作流水线',
    description: '剧本输入 → 角色生成 → 分镜生成 → 图片生成 → 视频合成',
    nodes: [
      const WorkflowNode(id: 'n1', name: '输入剧本', type: NodeType.triggerManual),
      const WorkflowNode(id: 'n2', name: '角色设计', type: NodeType.llm,
          config: {'prompt': '根据以下剧本，设计主要角色的外貌描述（用于AI绘画提示词）：\n{{in}}'}),
      const WorkflowNode(id: 'n3', name: '生成分镜', type: NodeType.llm,
          config: {'prompt': '根据以下剧本和角色设定，生成详细的分镜脚本（含画面描述、对白、镜头角度）：\n剧本：{{originalScript}}\n角色：{{in}}'}),
      const WorkflowNode(id: 'n4', name: '循环生成画面', type: NodeType.loop,
          config: {'loopType': 'forEach', 'items': '{{storyboards}}'}),
      const WorkflowNode(id: 'n5', name: '生成图片', type: NodeType.tool,
          config: {'toolName': 'generate_image', 'arguments': {'prompt': '{{_loopItem}}', 'style': 'anime'}}),
      const WorkflowNode(id: 'n6', name: '延时(等待生成)', type: NodeType.delay,
          config: {'durationMs': 3000}),
      const WorkflowNode(id: 'n7', name: '合成视频', type: NodeType.tool,
          config: {'toolName': 'compose_video', 'arguments': {'images': '{{generatedImages}}', 'audio': '{{dialogues}}'}}),
    ],
    edges: const [
      WorkflowEdge(id: 'e1', sourceNodeId: 'n1', targetNodeId: 'n2'),
      WorkflowEdge(id: 'e2', sourceNodeId: 'n2', targetNodeId: 'n3'),
      WorkflowEdge(id: 'e3', sourceNodeId: 'n3', targetNodeId: 'n4'),
      WorkflowEdge(id: 'e4', sourceNodeId: 'n4', targetNodeId: 'n5'),
      WorkflowEdge(id: 'e5', sourceNodeId: 'n5', targetNodeId: 'n6'),
      WorkflowEdge(id: 'e6', sourceNodeId: 'n6', targetNodeId: 'n7'),
    ],
  );

  // ————————————————————————— 模板 11: 社媒数据分析 —————————————————————————
  Workflow _socialMediaAnalytics() => Workflow(
    id: 'tpl_social_analytics', name: '社媒数据分析',
    description: '采集社媒数据，分析趋势，生成运营建议',
    triggers: [const WorkflowTrigger(type: TriggerType.schedule, cronExpression: '0 20 * * *')],
    variables: {'platforms': '微博,抖音,小红书'},
    nodes: [
      const WorkflowNode(id: 'n1', name: '定时触发', type: NodeType.triggerSchedule),
      const WorkflowNode(id: 'n2', name: '采集数据', type: NodeType.tool,
          config: {'toolName': 'social_media_scrape', 'arguments': {'platforms': '{{platforms}}'}}),
      const WorkflowNode(id: 'n3', name: '数据分析', type: NodeType.llm,
          config: {'prompt': '分析以下社交媒体数据，给出：1.流量趋势 2.内容表现 3.用户画像 4.运营建议：\n{{in}}'}),
      const WorkflowNode(id: 'n4', name: '生成图表', type: NodeType.tool,
          config: {'toolName': 'generate_chart', 'arguments': {'data': '{{analysis}}'}}),
      const WorkflowNode(id: 'n5', name: '输出报告', type: NodeType.output),
    ],
    edges: const [
      WorkflowEdge(id: 'e1', sourceNodeId: 'n1', targetNodeId: 'n2'),
      WorkflowEdge(id: 'e2', sourceNodeId: 'n2', targetNodeId: 'n3'),
      WorkflowEdge(id: 'e3', sourceNodeId: 'n3', targetNodeId: 'n4'),
      WorkflowEdge(id: 'e4', sourceNodeId: 'n4', targetNodeId: 'n5'),
    ],
  );

  // ————————————————————————— 模板 12: 知识库问答 —————————————————————————
  Workflow _knowledgeQA() => Workflow(
    id: 'tpl_knowledge_qa', name: '知识库问答',
    description: '接收问题 → 语义检索知识库 → LLM 生成回答',
    nodes: [
      const WorkflowNode(id: 'n1', name: '接收问题', type: NodeType.triggerManual),
      const WorkflowNode(id: 'n2', name: '语义检索', type: NodeType.tool,
          config: {'toolName': 'vector_search', 'arguments': {'query': '{{in}}', 'topK': 5}}),
      const WorkflowNode(id: 'n3', name: '生成回答', type: NodeType.llm,
          config: {'prompt': '基于以下参考资料回答用户问题。如果资料中没有相关信息，请诚实说明。\n\n用户问题：{{originalQuestion}}\n参考资料：{{in}}', 'temperature': 0.3}),
      const WorkflowNode(id: 'n4', name: '输出回答', type: NodeType.output),
    ],
    edges: const [
      WorkflowEdge(id: 'e1', sourceNodeId: 'n1', targetNodeId: 'n2'),
      WorkflowEdge(id: 'e2', sourceNodeId: 'n2', targetNodeId: 'n3'),
      WorkflowEdge(id: 'e3', sourceNodeId: 'n3', targetNodeId: 'n4'),
    ],
  );
}
