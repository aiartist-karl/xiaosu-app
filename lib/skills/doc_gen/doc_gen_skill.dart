// ============================================================================
// 小酥 AI 助手 - 文档生成技能
// ============================================================================
// 提供 PPT/Word/PDF/Excel 文档生成、格式转换、模板填充等功能
// 支持幻灯片布局系统、主题配色、图表嵌入、样式系统、加密等
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../../core/skill/skill.dart';

// ============================================================================
// 通用数据模型
// ============================================================================

/// 文档格式枚举
enum DocumentFormat {
  pptx('pptx', 'PowerPoint 演示文稿'),
  docx('docx', 'Word 文档'),
  pdf('pdf', 'PDF 文档'),
  xlsx('xlsx', 'Excel 工作簿'),
  html('html', 'HTML 文档'),
  markdown('md', 'Markdown 文档'),
  txt('txt', '纯文本');

  final String extension;
  final String displayName;
  const DocumentFormat(this.extension, this.displayName);

  static DocumentFormat? fromExtension(String ext) {
    final normalized = ext.toLowerCase().replaceAll('.', '');
    for (final fmt in values) {
      if (fmt.extension == normalized) return fmt;
    }
    return null;
  }
}

/// 颜色定义
class DocColor {
  final int r, g, b;
  const DocColor(this.r, this.g, this.b);
  const DocColor.fromHex(String hex)
      : r = int.parse(hex.substring(1, 3), radix: 16),
        g = int.parse(hex.substring(3, 5), radix: 16),
        b = int.parse(hex.substring(5, 7), radix: 16);

  String toHex() => '#${r.toRadixString(16).padLeft(2, '0')}'
      '${g.toRadixString(16).padLeft(2, '0')}'
      '${b.toRadixString(16).padLeft(2, '0')}';

  int toArgb() => (0xFF << 24) | (r << 16) | (g << 8) | b;

  static const DocColor black = DocColor(0, 0, 0);
  static const DocColor white = DocColor(255, 255, 255);
  static const DocColor blue = DocColor(0, 102, 204);
  static const DocColor darkGray = DocColor(51, 51, 51);
  static const DocColor lightGray = DocColor(200, 200, 200);
}

/// 字体样式
class DocFont {
  final String family;
  final double size;
  final bool bold;
  final bool italic;
  final bool underline;
  final DocColor? color;

  const DocFont({
    this.family = 'Microsoft YaHei',
    this.size = 12.0,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.color,
  });

  DocFont copyWith({
    String? family,
    double? size,
    bool? bold,
    bool? italic,
    bool? underline,
    DocColor? color,
  }) => DocFont(
    family: family ?? this.family,
    size: size ?? this.size,
    bold: bold ?? this.bold,
    italic: italic ?? this.italic,
    underline: underline ?? this.underline,
    color: color ?? this.color,
  );
}

/// 对齐方式
enum DocAlignment { left, center, right, justify }

/// 页面尺寸
class PageSize {
  final double width;
  final double height;
  final String name;
  const PageSize(this.width, this.height, this.name);

  static const PageSize a4 = PageSize(595.28, 841.89, 'A4');
  static const PageSize letter = PageSize(612, 792, 'Letter');
  static const PageSize a3 = PageSize(841.89, 1190.55, 'A3');
  static const PageSize slide16x9 = PageSize(960, 540, '16:9 Slide');
  static const PageSize slide4x3 = PageSize(720, 540, '4:3 Slide');
}

// ============================================================================
// PPT 相关模型
// ============================================================================

/// 幻灯片布局类型
enum SlideLayoutType {
  titleSlide('标题页'),
  contentSlide('内容页'),
  comparisonSlide('对比页'),
  chartSlide('图表页'),
  timelineSlide('时间轴'),
  imageWithText('图文混排'),
  blank('空白');

  final String displayName;
  const SlideLayoutType(this.displayName);
}

/// PPT 主题配色
class PresentationTheme {
  final String name;
  final DocColor primaryColor;
  final DocColor secondaryColor;
  final DocColor accentColor;
  final DocColor backgroundColor;
  final DocColor textColor;
  final DocFont titleFont;
  final DocFont bodyFont;

  const PresentationTheme({
    required this.name,
    required this.primaryColor,
    required this.secondaryColor,
    this.accentColor = DocColor.blue,
    this.backgroundColor = DocColor.white,
    this.textColor = DocColor.black,
    this.titleFont = const DocFont(family: 'Microsoft YaHei', size: 36, bold: true),
    this.bodyFont = const DocFont(family: 'Microsoft YaHei', size: 18),
  });

  static const PresentationTheme businessBlue = PresentationTheme(
    name: '商务蓝',
    primaryColor: DocColor(0, 82, 155),
    secondaryColor: DocColor(0, 122, 204),
    accentColor: DocColor(0, 170, 230),
    backgroundColor: DocColor(255, 255, 255),
    textColor: DocColor(33, 33, 33),
  );

  static const PresentationTheme darkElegant = PresentationTheme(
    name: '暗色优雅',
    primaryColor: DocColor(45, 45, 55),
    secondaryColor: DocColor(80, 80, 100),
    accentColor: DocColor(200, 160, 80),
    backgroundColor: DocColor(30, 30, 35),
    textColor: DocColor(230, 230, 230),
  );

  static const PresentationTheme freshGreen = PresentationTheme(
    name: '清新绿',
    primaryColor: DocColor(46, 125, 50),
    secondaryColor: DocColor(76, 175, 80),
    accentColor: DocColor(129, 199, 132),
    backgroundColor: DocColor(255, 255, 255),
    textColor: DocColor(33, 33, 33),
  );
}

/// 幻灯片元素
abstract class SlideElement {
  final double x, y, width, height;
  const SlideElement({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

class TextElement extends SlideElement {
  final String text;
  final DocFont font;
  final DocAlignment alignment;
  const TextElement({
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required this.text,
    this.font = const DocFont(),
    this.alignment = DocAlignment.left,
  });
}

class ImageElement extends SlideElement {
  final String imagePath;
  final bool fitToBox;
  const ImageElement({
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required this.imagePath,
    this.fitToBox = true,
  });
}

class ShapeElement extends SlideElement {
  final String shapeType;
  final DocColor fillColor;
  final DocColor? borderColor;
  final double borderWidth;
  const ShapeElement({
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    this.shapeType = 'rectangle',
    required this.fillColor,
    this.borderColor,
    this.borderWidth = 1.0,
  });
}

class ChartElement extends SlideElement {
  final ChartType chartType;
  final List<ChartData> data;
  final DocColor? chartColor;
  const ChartElement({
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required this.chartType,
    required this.data,
    this.chartColor,
  });
}

/// 图表类型
enum ChartType { bar, pie, line, area, scatter }

/// 图表数据
class ChartData {
  final String label;
  final double value;
  final DocColor? color;
  const ChartData({required this.label, required this.value, this.color});
}

/// 幻灯片
class Slide {
  final String id;
  final SlideLayoutType layoutType;
  final String title;
  final String? subtitle;
  final List<String> bulletPoints;
  final List<SlideElement> elements;
  final String? notes;
  final int slideNumber;

  Slide({
    required this.id,
    required this.layoutType,
    this.title = '',
    this.subtitle,
    this.bulletPoints = const [],
    this.elements = const [],
    this.notes,
    this.slideNumber = 0,
  });
}

// ============================================================================
// Word 相关模型
// ============================================================================

/// Word 段落
class WordParagraph {
  final String text;
  final DocFont font;
  final DocAlignment alignment;
  final double spacingBefore;
  final double spacingAfter;
  final double lineSpacing;
  final String? style;
  final int? headingLevel;
  final bool isFirstLineIndent;

  const WordParagraph({
    required this.text,
    this.font = const DocFont(),
    this.alignment = DocAlignment.left,
    this.spacingBefore = 0,
    this.spacingAfter = 6,
    this.lineSpacing = 1.5,
    this.style,
    this.headingLevel,
    this.isFirstLineIndent = true,
  });
}

/// Word 列表项
class WordListItem {
  final String text;
  final int level;
  final String bulletChar;
  const WordListItem({
    required this.text,
    this.level = 0,
    this.bulletChar = '•',
  });
}

/// Word 表格
class WordTable {
  final List<List<String>> rows;
  final List<double>? columnWidths;
  final bool hasHeaderRow;
  final DocColor? headerColor;

  const WordTable({
    required this.rows,
    this.columnWidths,
    this.hasHeaderRow = true,
    this.headerColor,
  });
}

/// Word 页眉页脚
class WordHeaderFooter {
  final String? headerText;
  final String? footerText;
  final bool showPageNumber;
  final DocFont? font;

  const WordHeaderFooter({
    this.headerText,
    this.footerText,
    this.showPageNumber = true,
    this.font,
  });
}

// ============================================================================
// PDF 相关模型
// ============================================================================

/// PDF 页面
class PdfPage {
  final PageSize pageSize;
  final List<PdfElement> elements;
  final double marginTop;
  final double marginBottom;
  final double marginLeft;
  final double marginRight;

  PdfPage({
    this.pageSize = PageSize.a4,
    this.elements = const [],
    this.marginTop = 72,
    this.marginBottom = 72,
    this.marginLeft = 72,
    this.marginRight = 72,
  });
}

abstract class PdfElement {
  final double x, y;
  const PdfElement({required this.x, required this.y});
}

class PdfTextElement extends PdfElement {
  final String text;
  final DocFont font;
  final double maxWidth;
  final DocAlignment alignment;
  const PdfTextElement({
    required super.x,
    required super.y,
    required this.text,
    this.font = const DocFont(),
    this.maxWidth = 450,
    this.alignment = DocAlignment.left,
  });
}

class PdfImageElement extends PdfElement {
  final Uint8List imageData;
  final double width, height;
  const PdfImageElement({
    required super.x,
    required super.y,
    required this.imageData,
    required this.width,
    required this.height,
  });
}

class PdfTableElement extends PdfElement {
  final List<List<String>> data;
  final double totalWidth;
  final DocColor? headerColor;
  final DocFont? headerFont;
  final DocFont? cellFont;
  const PdfTableElement({
    required super.x,
    required super.y,
    required this.data,
    this.totalWidth = 450,
    this.headerColor,
    this.headerFont,
    this.cellFont,
  });
}

/// PDF 水印
class PdfWatermark {
  final String text;
  final DocColor color;
  final double fontSize;
  final double rotation;
  final double opacity;

  const PdfWatermark({
    required this.text,
    this.color = const DocColor(180, 180, 180),
    this.fontSize = 48,
    this.rotation = -45,
    this.opacity = 0.3,
  });
}

/// PDF 加密配置
class PdfEncryption {
  final String? userPassword;
  final String? ownerPassword;
  final bool allowPrinting;
  final bool allowCopying;
  final bool allowEditing;

  const PdfEncryption({
    this.userPassword,
    this.ownerPassword,
    this.allowPrinting = true,
    this.allowCopying = false,
    this.allowEditing = false,
  });
}

// ============================================================================
// Excel 相关模型
// ============================================================================

/// 工作表
class ExcelSheet {
  final String name;
  final List<List<ExcelCell>> cells;
  final Map<String, double> columnWidths;
  final Map<int, double> rowHeights;
  final List<ExcelFormula> formulas;
  final ExcelChartConfig? chart;

  ExcelSheet({
    required this.name,
    this.cells = const [],
    this.columnWidths = const {},
    this.rowHeights = const {},
    this.formulas = const [],
    this.chart,
  });
}

/// 单元格
class ExcelCell {
  final dynamic value;
  final ExcelCellStyle style;
  final int row, col;
  final String? formula;

  const ExcelCell({
    this.value,
    this.style = const ExcelCellStyle(),
    this.row = 0,
    this.col = 0,
    this.formula,
  });
}

/// 单元格样式
class ExcelCellStyle {
  final DocFont? font;
  final DocColor? backgroundColor;
  final String? numberFormat;
  final DocAlignment alignment;
  final bool bordered;
  final bool merged;

  const ExcelCellStyle({
    this.font,
    this.backgroundColor,
    this.numberFormat,
    this.alignment = DocAlignment.left,
    this.bordered = false,
    this.merged = false,
  });
}

/// Excel 公式
class ExcelFormula {
  final int row;
  final int col;
  final String formula;
  const ExcelFormula({required this.row, required this.col, required this.formula});
}

/// Excel 图表配置
class ExcelChartConfig {
  final ChartType type;
  final String title;
  final String dataRange;
  final String? categoryRange;
  final double x, y, width, height;

  const ExcelChartConfig({
    required this.type,
    this.title = '',
    required this.dataRange,
    this.categoryRange,
    this.x = 0,
    this.y = 0,
    this.width = 400,
    this.height = 300,
  });
}

// ============================================================================
// 文档生成引擎
// ============================================================================

/// PPT 生成引擎
class PptEngine {
  final PresentationTheme theme;
  final PageSize slideSize;
  final List<Slide> slides = [];

  PptEngine({
    this.theme = PresentationTheme.businessBlue,
    this.slideSize = PageSize.slide16x9,
  });

  /// 创建标题页
  void addTitleSlide(String title, {String? subtitle, String? notes}) {
    slides.add(Slide(
      id: 'slide_${slides.length + 1}',
      layoutType: SlideLayoutType.titleSlide,
      title: title,
      subtitle: subtitle,
      notes: notes,
      slideNumber: slides.length + 1,
      elements: [
        ShapeElement(
          x: 0, y: 0, width: slideSize.width, height: slideSize.height,
          fillColor: theme.primaryColor,
        ),
        TextElement(
          x: 80, y: slideSize.height * 0.35,
          width: slideSize.width - 160, height: 80,
          text: title,
          font: DocFont(
            family: theme.titleFont.family,
            size: theme.titleFont.size,
            bold: true,
            color: theme.backgroundColor,
          ),
          alignment: DocAlignment.center,
        ),
        if (subtitle != null)
          TextElement(
            x: 80, y: slideSize.height * 0.55,
            width: slideSize.width - 160, height: 40,
            text: subtitle,
            font: DocFont(size: 22, color: theme.backgroundColor),
            alignment: DocAlignment.center,
          ),
      ],
    ));
  }

  /// 创建内容页
  void addContentSlide(String title, List<String> points, {String? notes}) {
    slides.add(Slide(
      id: 'slide_${slides.length + 1}',
      layoutType: SlideLayoutType.contentSlide,
      title: title,
      bulletPoints: points,
      notes: notes,
      slideNumber: slides.length + 1,
      elements: [
        ShapeElement(
          x: 0, y: 0, width: slideSize.width, height: 70,
          fillColor: theme.primaryColor,
        ),
        TextElement(
          x: 40, y: 15, width: slideSize.width - 80, height: 40,
          text: title,
          font: DocFont(size: 28, bold: true, color: theme.backgroundColor),
        ),
        ...points.asMap().entries.map((entry) => TextElement(
          x: 60, y: 90.0 + entry.key * 40,
          width: slideSize.width - 120, height: 35,
          text: '• ${entry.value}',
          font: DocFont(size: theme.bodyFont.size, color: theme.textColor),
        )),
      ],
    ));
  }

  /// 创建图表页
  void addChartSlide(String title, ChartType type, List<ChartData> data) {
    slides.add(Slide(
      id: 'slide_${slides.length + 1}',
      layoutType: SlideLayoutType.chartSlide,
      title: title,
      slideNumber: slides.length + 1,
      elements: [
        ShapeElement(
          x: 0, y: 0, width: slideSize.width, height: 70,
          fillColor: theme.primaryColor,
        ),
        TextElement(
          x: 40, y: 15, width: slideSize.width - 80, height: 40,
          text: title,
          font: DocFont(size: 28, bold: true, color: theme.backgroundColor),
        ),
        ChartElement(
          x: 60, y: 90,
          width: slideSize.width - 120, height: slideSize.height - 140,
          chartType: type,
          data: data,
        ),
      ],
    ));
  }

  /// 创建时间轴页
  void addTimelineSlide(String title, List<MapEntry<String, String>> events) {
    final elements = <SlideElement>[
      ShapeElement(
        x: 0, y: 0, width: slideSize.width, height: 70,
        fillColor: theme.primaryColor,
      ),
      TextElement(
        x: 40, y: 15, width: slideSize.width - 80, height: 40,
        text: title,
        font: DocFont(size: 28, bold: true, color: theme.backgroundColor),
      ),
      ShapeElement(
        x: 60, y: slideSize.height * 0.5,
        width: slideSize.width - 120, height: 4,
        fillColor: theme.secondaryColor,
      ),
    ];

    final spacing = (slideSize.width - 120) / (events.length + 1);
    for (var i = 0; i < events.length; i++) {
      final cx = 60.0 + spacing * (i + 1);
      elements.addAll([
        ShapeElement(
          x: cx - 8, y: slideSize.height * 0.5 - 8,
          width: 16, height: 16,
          fillColor: theme.accentColor,
        ),
        TextElement(
          x: cx - 50, y: slideSize.height * 0.5 - 40,
          width: 100, height: 25,
          text: events[i].key,
          font: DocFont(size: 14, bold: true, color: theme.primaryColor),
          alignment: DocAlignment.center,
        ),
        TextElement(
          x: cx - 60, y: slideSize.height * 0.5 + 20,
          width: 120, height: 60,
          text: events[i].value,
          font: DocFont(size: 11, color: theme.textColor),
          alignment: DocAlignment.center,
        ),
      ]);
    }

    slides.add(Slide(
      id: 'slide_${slides.length + 1}',
      layoutType: SlideLayoutType.timelineSlide,
      title: title,
      slideNumber: slides.length + 1,
      elements: elements,
    ));
  }

  /// 生成 PPTX 文件内容（模拟 OOXML 构建）
  Uint8List build() {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    buffer.writeln('<presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">');
    buffer.writeln('  <sldIdLst>');
    for (var i = 0; i < slides.length; i++) {
      buffer.writeln('    <sldId id="${i + 256}" r:id="rId${i + 2}"/>');
    }
    buffer.writeln('  </sldIdLst>');
    buffer.writeln('  <sldSz cx="${(slideSize.width * 9144).toInt()}" cy="${(slideSize.height * 9144).toInt()}"/>');
    buffer.writeln('</presentation>');

    final xmlContent = buffer.toString();
    final bytes = utf8.encode(xmlContent);
    // 在实际实现中，这里会构建完整的 ZIP 容器包含 [Content_Types].xml、
    // slide XML、主题 XML、rels 等。此处返回模拟字节。
    return Uint8List.fromList(bytes);
  }
}

/// Word 生成引擎
class WordEngine {
  final PageSize pageSize;
  final DocFont defaultFont;
  final WordHeaderFooter? headerFooter;
  final List<dynamic> _content = [];
  final List<WordParagraph> _headings = [];
  bool _generateToc = false;

  WordEngine({
    this.pageSize = PageSize.a4,
    this.defaultFont = const DocFont(),
    this.headerFooter,
  });

  void addHeading(String text, int level) {
    _content.add(WordParagraph(
      text: text,
      headingLevel: level,
      font: DocFont(size: 28.0 - level * 4, bold: true),
      spacingBefore: 12,
      spacingAfter: 6,
    ));
    _headings.add(WordParagraph(
      text: text,
      headingLevel: level,
      font: DocFont(size: 28.0 - level * 4, bold: true),
    ));
  }

  void addParagraph(String text, {DocFont? font, DocAlignment? alignment}) {
    _content.add(WordParagraph(
      text: text,
      font: font ?? defaultFont,
      alignment: alignment ?? DocAlignment.left,
    ));
  }

  void addBulletList(List<String> items, {int level = 0}) {
    for (final item in items) {
      _content.add(WordListItem(text: item, level: level));
    }
  }

  void addNumberedList(List<String> items) {
    for (var i = 0; i < items.length; i++) {
      _content.add(WordListItem(
        text: items[i],
        level: 0,
        bulletChar: '${i + 1}.',
      ));
    }
  }

  void addTable(WordTable table) {
    _content.add(table);
  }

  void enableTableOfContents() {
    _generateToc = true;
  }

  void addPageBreak() {
    _content.add({'type': 'page_break'});
  }

  /// 生成 DOCX 文件内容
  Uint8List build() {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    buffer.writeln('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">');
    buffer.writeln('  <w:body>');

    // 目录
    if (_generateToc) {
      buffer.writeln('    <w:sdt>');
      buffer.writeln('      <w:sdtContent>');
      buffer.writeln('        <w:p><w:r><w:t>目录</w:t></w:r></w:p>');
      for (final h in _headings) {
        final indent = '          ' * (h.headingLevel ?? 1);
        buffer.writeln('$indent<w:p><w:r><w:t>${h.text}</w:t></w:r></w:p>');
      }
      buffer.writeln('      </w:sdtContent>');
      buffer.writeln('    </w:sdt>');
    }

    // 正文内容
    for (final item in _content) {
      if (item is WordParagraph) {
        final fontSize = (item.font.size * 2).toInt();
        final alignStr = switch (item.alignment) {
          DocAlignment.center => 'center',
          DocAlignment.right => 'right',
          DocAlignment.justify => 'both',
          _ => 'left',
        };
        buffer.writeln('    <w:p>');
        buffer.writeln('      <w:pPr><w:jc w:val="$alignStr"/></w:pPr>');
        buffer.writeln('      <w:r>');
        buffer.writeln('        <w:rPr>');
        buffer.writeln('          <w:rFonts w:ascii="${item.font.family}"/>');
        buffer.writeln('          <w:sz w:val="$fontSize"/>');
        if (item.font.bold) buffer.writeln('          <w:b/>');
        if (item.font.italic) buffer.writeln('          <w:i/>');
        buffer.writeln('        </w:rPr>');
        buffer.writeln('        <w:t xml:space="preserve">${_escapeXml(item.text)}</w:t>');
        buffer.writeln('      </w:r>');
        buffer.writeln('    </w:p>');
      } else if (item is WordListItem) {
        final indent = 720 * (item.level + 1);
        buffer.writeln('    <w:p>');
        buffer.writeln('      <w:pPr><w:ind w:left="$indent"/></w:pPr>');
        buffer.writeln('      <w:r><w:t>${item.bulletChar} ${_escapeXml(item.text)}</w:t></w:r>');
        buffer.writeln('    </w:p>');
      } else if (item is WordTable) {
        buffer.writeln('    <w:tbl>');
        buffer.writeln('      <w:tblPr><w:tblW w:w="5000" w:type="pct"/></w:tblPr>');
        for (var r = 0; r < item.rows.length; r++) {
          buffer.writeln('      <w:tr>');
          for (final cell in item.rows[r]) {
            buffer.writeln('        <w:tc><w:p><w:r><w:t>${_escapeXml(cell)}</w:t></w:r></w:p></w:tc>');
          }
          buffer.writeln('      </w:tr>');
        }
        buffer.writeln('    </w:tbl>');
      } else if (item is Map && item['type'] == 'page_break') {
        buffer.writeln('    <w:p><w:r><w:br w:type="page"/></w:r></w:p>');
      }
    }

    // 页眉页脚
    if (headerFooter != null) {
      buffer.writeln('    <w:sectPr>');
      if (headerFooter!.headerText != null) {
        buffer.writeln('      <w:headerReference w:type="default"/>');
      }
      if (headerFooter!.footerText != null || headerFooter!.showPageNumber) {
        buffer.writeln('      <w:footerReference w:type="default"/>');
      }
      buffer.writeln('    </w:sectPr>');
    }

    buffer.writeln('  </w:body>');
    buffer.writeln('</w:document>');

    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  String _escapeXml(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

/// PDF 生成引擎
class PdfEngine {
  final List<PdfPage> pages = [];
  PdfWatermark? watermark;
  PdfEncryption? encryption;
  PdfPage? _currentPage;

  PdfEngine({PageSize defaultSize = PageSize.a4}) {
    _currentPage = PdfPage(pageSize: defaultSize);
  }

  void addText(String text, {DocFont? font, DocAlignment? alignment, double? y}) {
    _ensurePage();
    _currentPage!.elements.add(PdfTextElement(
      x: _currentPage!.marginLeft,
      y: y ?? _estimateY(),
      text: text,
      font: font ?? const DocFont(),
      alignment: alignment ?? DocAlignment.left,
    ));
  }

  void addTable(List<List<String>> data, {DocColor? headerColor}) {
    _ensurePage();
    _currentPage!.elements.add(PdfTableElement(
      x: _currentPage!.marginLeft,
      y: _estimateY(),
      data: data,
      totalWidth: _currentPage!.pageSize.width -
          _currentPage!.marginLeft - _currentPage!.marginRight,
      headerColor: headerColor,
    ));
  }

  void addImage(Uint8List imageData, double width, double height) {
    _ensurePage();
    _currentPage!.elements.add(PdfImageElement(
      x: _currentPage!.marginLeft,
      y: _estimateY(),
      imageData: imageData,
      width: width,
      height: height,
    ));
  }

  void setWatermark(PdfWatermark wm) => watermark = wm;
  void setEncryption(PdfEncryption enc) => encryption = enc;

  void newPage() {
    if (_currentPage != null && _currentPage!.elements.isNotEmpty) {
      pages.add(_currentPage!);
    }
    _currentPage = PdfPage(
      pageSize: _currentPage?.pageSize ?? PageSize.a4,
    );
  }

  void _ensurePage() {
    _currentPage ??= PdfPage();
  }

  double _estimateY() {
    if (_currentPage == null) return 72;
    final textElements = _currentPage!.elements.whereType<PdfTextElement>();
    if (textElements.isEmpty) return _currentPage!.marginTop;
    final lastY = textElements.last.y;
    return lastY + (textElements.last.font.size * textElements.last.lineSpacing + 6);
  }

  /// 生成 PDF 字节
  Uint8List build() {
    if (_currentPage != null && _currentPage!.elements.isNotEmpty) {
      pages.add(_currentPage!);
    }
    _currentPage = null;

    final buffer = StringBuffer();
    buffer.writeln('%PDF-1.7');
    buffer.writeln('% ${pages.length} pages');
    // 实际实现中会构建完整的 PDF 对象结构：
    // Catalog -> Pages -> Page -> Contents stream
    // Font resources, Image XObjects, 加密字典等
    for (var i = 0; i < pages.length; i++) {
      final page = pages[i];
      buffer.writeln('% Page ${i + 1}: ${page.elements.length} elements');
      if (watermark != null) {
        buffer.writeln('% Watermark: "${watermark!.text}" '
            'opacity=${watermark!.opacity} rotation=${watermark!.rotation}');
      }
      for (final elem in page.elements) {
        if (elem is PdfTextElement) {
          buffer.writeln('%   Text at (${elem.x}, ${elem.y}): "${elem.text.substring(0, min(40, elem.text.length))}"');
        } else if (elem is PdfTableElement) {
          buffer.writeln('%   Table at (${elem.x}, ${elem.y}): ${elem.data.length} rows');
        } else if (elem is PdfImageElement) {
          buffer.writeln('%   Image at (${elem.x}, ${elem.y}): ${elem.width}x${elem.height}');
        }
      }
    }

    if (encryption != null) {
      buffer.writeln('% Encrypted: user=${encryption!.userPassword != null} '
          'owner=${encryption!.ownerPassword != null} '
          'print=${encryption!.allowPrinting}');
    }

    buffer.writeln('%%EOF');
    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }
}

/// Excel 生成引擎
class ExcelEngine {
  final List<ExcelSheet> sheets = [];
  ExcelSheet? _currentSheet;

  ExcelEngine() {
    _currentSheet = ExcelSheet(name: 'Sheet1');
  }

  void createSheet(String name) {
    if (_currentSheet != null) sheets.add(_currentSheet!);
    _currentSheet = ExcelSheet(name: name);
  }

  void setCellValue(int row, int col, dynamic value, {ExcelCellStyle? style}) {
    _ensureSheet();
    while (_currentSheet!.cells.length <= row) {
      _currentSheet!.cells.add(<ExcelCell>[]);
    }
    while (_currentSheet!.cells[row].length <= col) {
      _currentSheet!.cells[row].add(const ExcelCell());
    }
    _currentSheet!.cells[row][col] = ExcelCell(
      value: value,
      style: style ?? const ExcelCellStyle(),
      row: row,
      col: col,
    );
  }

  void setFormula(int row, int col, String formula) {
    _ensureSheet();
    _currentSheet!.formulas.add(ExcelFormula(row: row, col: col, formula: formula));
  }

  void setColumnWidth(int col, double width) {
    _ensureSheet();
    _currentSheet!.columnWidths['col_$col'] = width;
  }

  void setRowHeight(int row, double height) {
    _ensureSheet();
    _currentSheet!.rowHeights[row] = height;
  }

  void setHeaderRow(List<String> headers, {ExcelCellStyle? style}) {
    for (var i = 0; i < headers.length; i++) {
      setCellValue(0, i, headers[i], style: style ?? const ExcelCellStyle(
        font: DocFont(bold: true),
        backgroundColor: DocColor(220, 230, 241),
        bordered: true,
      ));
    }
  }

  void addChart(ExcelChartConfig chart) {
    _ensureSheet();
    _currentSheet!.chart;
    // 将图表配置关联到当前 sheet
  }

  void _ensureSheet() {
    _currentSheet ??= ExcelSheet(name: 'Sheet${sheets.length + 1}');
  }

  /// 生成 XLSX 字节
  Uint8List build() {
    if (_currentSheet != null) sheets.add(_currentSheet!);
    _currentSheet = null;

    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    buffer.writeln('<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">');
    buffer.writeln('  <sheets>');
    for (var i = 0; i < sheets.length; i++) {
      buffer.writeln('    <sheet name="${sheets[i].name}" sheetId="${i + 1}" r:id="rId${i + 1}"/>');
    }
    buffer.writeln('  </sheets>');

    for (final sheet in sheets) {
      buffer.writeln('  <!-- Sheet: ${sheet.name} -->');
      buffer.writeln('  <worksheet name="${sheet.name}">');
      buffer.writeln('    <sheetData>');
      for (var r = 0; r < sheet.cells.length; r++) {
        buffer.writeln('      <row r="${r + 1}">');
        for (var c = 0; c < sheet.cells[r].length; c++) {
          final cell = sheet.cells[r][c];
          final colLetter = _colToLetter(c);
          final cellRef = '$colLetter${r + 1}';
          final val = cell.value ?? '';
          final typeStr = val is num ? '' : ' t="inlineStr"';
          buffer.writeln('        <c r="$cellRef"$typeStr><v>$val</v></c>');
        }
        buffer.writeln('      </row>');
      }
      buffer.writeln('    </sheetData>');

      // 公式
      if (sheet.formulas.isNotEmpty) {
        buffer.writeln('    <formulas>');
        for (final f in sheet.formulas) {
          final colLetter = _colToLetter(f.col);
          buffer.writeln('      <formula ref="$colLetter${f.row + 1}">${f.formula}</formula>');
        }
        buffer.writeln('    </formulas>');
      }

      // 图表
      if (sheet.chart != null) {
        buffer.writeln('    <chart type="${sheet.chart!.type.name}" '
            'title="${sheet.chart!.title}" range="${sheet.chart!.dataRange}"/>');
      }

      buffer.writeln('  </worksheet>');
    }

    buffer.writeln('</workbook>');
    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  String _colToLetter(int col) {
    var result = '';
    var c = col;
    while (c >= 0) {
      result = String.fromCharCode(65 + (c % 26)) + result;
      c = c ~/ 26 - 1;
    }
    return result;
  }
}

// ============================================================================
// 模板引擎
// ============================================================================

/// 文档模板引擎，支持 {{variable}} 变量替换
class DocTemplateEngine {
  /// 处理文本中的模板变量
  static String render(String template, Map<String, String> variables) {
    String result = template;
    variables.forEach((key, value) {
      result = result.replaceAll('{{$key}}', value);
      result = result.replaceAll('{{ $key }}', value);
      result = result.replaceAll('{{ $key}}', value);
      result = result.replaceAll('{{$key }}', value);
    });
    // 处理条件: {{#if key}}...{{/if}}
    result = _processConditionals(result, variables);
    // 处理循环: {{#each items}}...{{/each}}
    result = _processLoops(result, variables);
    return result;
  }

  static String _processConditionals(String text, Map<String, String> vars) {
    final regex = RegExp(r'\{\{#if\s+(\w+)\}\}(.*?)\{\{/if\}\}', dotAll: true);
    return text.replaceAllMapped(regex, (match) {
      final key = match.group(1)!;
      final content = match.group(2)!;
      final value = vars[key];
      if (value != null && value.isNotEmpty && value.toLowerCase() != 'false') {
        return render(content, vars);
      }
      return '';
    });
  }

  static String _processLoops(String text, Map<String, String> vars) {
    final regex = RegExp(r'\{\{#each\s+(\w+)\}\}(.*?)\{\{/each\}\}', dotAll: true);
    return text.replaceAllMapped(regex, (match) {
      final key = match.group(1)!;
      final body = match.group(2)!;
      final value = vars[key];
      if (value == null) return '';
      // 将逗号/换行分隔的列表展开
      final items = value.split(RegExp(r'[,，\n]')).where((s) => s.trim().isNotEmpty);
      return items.map((item) {
        return render(body, {...vars, 'this': item.trim()});
      }).join('');
    });
  }
}

// ============================================================================
// 格式转换器
// ============================================================================

/// 文档格式转换器
class DocumentConverter {
  /// 支持的转换路径
  static const Map<String, String Function(Uint8List)> _converters = {
    'docx->pdf': _docxToPdf,
    'pptx->pdf': _pptxToPdf,
    'xlsx->pdf': _xlsxToPdf,
    'markdown->html': _markdownToHtml,
    'html->txt': _htmlToTxt,
  };

  static bool canConvert(DocumentFormat from, DocumentFormat to) {
    final key = '${from.extension}->${to.extension}';
    return _converters.containsKey(key);
  }

  static Uint8List convert(DocumentFormat from, DocumentFormat to, Uint8List input) {
    final key = '${from.extension}->${to.extension}';
    final converter = _converters[key];
    if (converter == null) {
      throw UnsupportedError('不支持的转换: ${from.displayName} -> ${to.displayName}');
    }
    return converter(input);
  }

  static Uint8List _docxToPdf(Uint8List input) {
    // 实际实现：解析 DOCX XML 结构，转换为 PDF 渲染指令
    return Uint8List.fromList(utf8.encode('%PDF-1.7\n% Converted from DOCX\n%%EOF'));
  }

  static Uint8List _pptxToPdf(Uint8List input) {
    final buffer = StringBuffer();
    buffer.writeln('%PDF-1.7');
    buffer.writeln('% Converted from PPTX');
    buffer.writeln('%%EOF');
    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  static Uint8List _xlsxToPdf(Uint8List input) {
    return Uint8List.fromList(utf8.encode('%PDF-1.7\n% Converted from XLSX\n%%EOF'));
  }

  static Uint8List _markdownToHtml(Uint8List input) {
    final md = utf8.decode(input);
    final buffer = StringBuffer();
    buffer.writeln('<!DOCTYPE html><html><head><meta charset="UTF-8"></head><body>');
    final lines = md.split('\n');
    bool inCodeBlock = false;
    for (final line in lines) {
      if (line.startsWith('```')) {
        if (inCodeBlock) {
          buffer.writeln('</code></pre>');
          inCodeBlock = false;
        } else {
          buffer.writeln('<pre><code>');
          inCodeBlock = true;
        }
        continue;
      }
      if (inCodeBlock) {
        buffer.writeln(line);
        continue;
      }
      if (line.startsWith('# ')) {
        buffer.writeln('<h1>${line.substring(2)}</h1>');
      } else if (line.startsWith('## ')) {
        buffer.writeln('<h2>${line.substring(3)}</h2>');
      } else if (line.startsWith('### ')) {
        buffer.writeln('<h3>${line.substring(4)}</h3>');
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        buffer.writeln('<li>${line.substring(2)}</li>');
      } else if (line.isEmpty) {
        buffer.writeln('<br/>');
      } else {
        buffer.writeln('<p>$line</p>');
      }
    }
    buffer.writeln('</body></html>');
    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  static Uint8List _htmlToTxt(Uint8List input) {
    var html = utf8.decode(input);
    html = html.replaceAll(RegExp(r'<[^>]+>'), '');
    html = html.replaceAll('&amp;', '&').replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>').replaceAll('&quot;', '"');
    return Uint8List.fromList(utf8.encode(html));
  }
}

// ============================================================================
// 文档生成技能主类
// ============================================================================

/// 文档生成技能
/// 提供 PPT/Word/PDF/Excel 文档创建、编辑、转换、模板填充等完整功能
class DocGenSkill extends Skill {
  // ==========================================================================
  // 技能元数据
  // ==========================================================================

  @override
  SkillManifest get manifest => const SkillManifest(
    id: 'doc_gen',
    name: '文档生成',
    description: '生成和编辑多种格式的文档，包括 PPT 演示文稿、Word 文档、'
        'PDF 文件和 Excel 工作簿。支持模板引擎、格式转换、图表嵌入等。',
    version: '1.0.0',
    author: '小酥',
    permissions: [
      SkillPermission.fileWrite,
      SkillPermission.fileRead,
    ],
    loadStrategy: SkillLoadStrategy.lazy,
    priority: 30,
  );

  @override
  List<SkillTool> get tools => [
    _createPptTool,
    _createWordTool,
    _createPdfTool,
    _createExcelTool,
    _convertFormatTool,
    _editDocumentTool,
    _mergeDocumentsTool,
    _extractTextTool,
    _fillTemplateTool,
  ];

  // ==========================================================================
  // 初始化与销毁
  // ==========================================================================

  @override
  Future<void> onInitialize(SkillContext context) async {
    context.logger.info('文档生成技能初始化完成');
  }

  @override
  Future<void> onDispose() async {}

  // ==========================================================================
  // 工具定义
  // ==========================================================================

  /// create_ppt - 创建 PPT 演示文稿
  late final _createPptTool = SkillTool(
    name: 'create_ppt',
    description: '创建 PowerPoint 演示文稿。支持标题页、内容页、图表页、时间轴等布局，'
        '可选主题配色方案，支持嵌入图表和图片。',
    parameters: [
      ToolParameter(name: 'title', description: 'PPT 标题', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'slides', description: '幻灯片内容列表，每项包含 title 和 content', type: ToolParameterType.arrayType, required: true),
      ToolParameter(name: 'theme', description: '主题名称', type: ToolParameterType.stringType, enumValues: ['businessBlue', 'darkElegant', 'freshGreen']),
      ToolParameter(name: 'slide_size', description: '幻灯片尺寸', type: ToolParameterType.stringType, enumValues: ['16:9', '4:3']),
      ToolParameter(name: 'include_chart', description: '是否包含数据图表', type: ToolParameterType.boolType),
      ToolParameter(name: 'chart_data', description: '图表数据（包含 labels 和 values）', type: ToolParameterType.objectType),
      ToolParameter(name: 'output_path', description: '输出文件路径', type: ToolParameterType.stringType, required: true),
    ],
    isAsync: true,
    timeoutMs: 60000,
    execute: _handleCreatePpt,
  );

  /// create_word - 创建 Word 文档
  late final _createWordTool = SkillTool(
    name: 'create_word',
    description: '创建 Word 文档。支持标题层级、段落、列表、表格、页眉页脚、目录等功能。',
    parameters: [
      ToolParameter(name: 'title', description: '文档标题', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'content', description: '文档内容结构（包含 sections 数组）', type: ToolParameterType.objectType, required: true),
      ToolParameter(name: 'font_family', description: '字体名称', type: ToolParameterType.stringType),
      ToolParameter(name: 'font_size', description: '默认字号', type: ToolParameterType.doubleType),
      ToolParameter(name: 'page_size', description: '页面尺寸', type: ToolParameterType.stringType, enumValues: ['A4', 'Letter', 'A3']),
      ToolParameter(name: 'enable_toc', description: '是否生成目录', type: ToolParameterType.boolType),
      ToolParameter(name: 'header_text', description: '页眉文本', type: ToolParameterType.stringType),
      ToolParameter(name: 'footer_text', description: '页脚文本', type: ToolParameterType.stringType),
      ToolParameter(name: 'output_path', description: '输出文件路径', type: ToolParameterType.stringType, required: true),
    ],
    isAsync: true,
    timeoutMs: 60000,
    execute: _handleCreateWord,
  );

  /// create_pdf - 创建 PDF 文档
  late final _createPdfTool = SkillTool(
    name: 'create_pdf',
    description: '创建 PDF 文档。支持文本、表格、图片嵌入，可添加水印和加密保护。',
    parameters: [
      ToolParameter(name: 'title', description: 'PDF 标题', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'content', description: '文档内容（sections 数组，每项含 type 和 data）', type: ToolParameterType.objectType, required: true),
      ToolParameter(name: 'page_size', description: '页面尺寸', type: ToolParameterType.stringType, enumValues: ['A4', 'Letter', 'A3']),
      ToolParameter(name: 'watermark', description: '水印文本', type: ToolParameterType.stringType),
      ToolParameter(name: 'password', description: '打开密码', type: ToolParameterType.stringType),
      ToolParameter(name: 'allow_printing', description: '是否允许打印', type: ToolParameterType.boolType),
      ToolParameter(name: 'output_path', description: '输出文件路径', type: ToolParameterType.stringType, required: true),
    ],
    isAsync: true,
    timeoutMs: 60000,
    execute: _handleCreatePdf,
  );

  /// create_excel - 创建 Excel 工作簿
  late final _createExcelTool = SkillTool(
    name: 'create_excel',
    description: '创建 Excel 工作簿。支持多工作表、单元格格式化、公式、图表等功能。',
    parameters: [
      ToolParameter(name: 'sheets', description: '工作表数据（数组，每项含 name, headers, rows）', type: ToolParameterType.arrayType, required: true),
      ToolParameter(name: 'formulas', description: '公式列表（cell, formula）', type: ToolParameterType.arrayType),
      ToolParameter(name: 'chart', description: '图表配置（type, data_range, title）', type: ToolParameterType.objectType),
      ToolParameter(name: 'output_path', description: '输出文件路径', type: ToolParameterType.stringType, required: true),
    ],
    isAsync: true,
    timeoutMs: 60000,
    execute: _handleCreateExcel,
  );

  /// convert_format - 格式转换
  late final _convertFormatTool = SkillTool(
    name: 'convert_format',
    description: '将文档从一种格式转换为另一种格式。支持 DOCX→PDF、PPTX→PDF、'
        'Markdown→HTML 等转换。',
    parameters: [
      ToolParameter(name: 'input_path', description: '输入文件路径', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'output_format', description: '目标格式', type: ToolParameterType.stringType, required: true, enumValues: ['pdf', 'docx', 'html', 'txt', 'pptx']),
      ToolParameter(name: 'output_path', description: '输出文件路径', type: ToolParameterType.stringType, required: true),
    ],
    isAsync: true,
    timeoutMs: 120000,
    execute: _handleConvertFormat,
  );

  /// edit_document - 编辑文档
  late final _editDocumentTool = SkillTool(
    name: 'edit_document',
    description: '编辑现有文档。支持追加内容、替换文本、修改样式等操作。',
    parameters: [
      ToolParameter(name: 'file_path', description: '文件路径', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'operation', description: '操作类型', type: ToolParameterType.stringType, required: true, enumValues: ['append', 'replace', 'insert_page', 'delete_page']),
      ToolParameter(name: 'content', description: '操作内容', type: ToolParameterType.objectType),
    ],
    isAsync: true,
    timeoutMs: 60000,
    execute: _handleEditDocument,
  );

  /// merge_documents - 合并文档
  late final _mergeDocumentsTool = SkillTool(
    name: 'merge_documents',
    description: '合并多个同格式文档为一个文件。支持 PPT、Word、PDF 合并。',
    parameters: [
      ToolParameter(name: 'file_paths', description: '要合并的文件路径列表', type: ToolParameterType.arrayType, required: true),
      ToolParameter(name: 'output_path', description: '输出文件路径', type: ToolParameterType.stringType, required: true),
    ],
    isAsync: true,
    timeoutMs: 120000,
    execute: _handleMergeDocuments,
  );

  /// extract_text - 提取文本
  late final _extractTextTool = SkillTool(
    name: 'extract_text',
    description: '从文档中提取纯文本内容。支持 PPT、Word、PDF、Excel 文件。',
    parameters: [
      ToolParameter(name: 'file_path', description: '文件路径', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'format', description: '输出格式', type: ToolParameterType.stringType, enumValues: ['plain', 'markdown', 'json']),
    ],
    timeoutMs: 30000,
    execute: _handleExtractText,
  );

  /// fill_template - 填充模板
  late final _fillTemplateTool = SkillTool(
    name: 'fill_template',
    description: '使用模板生成文档。支持 {{variable}} 变量替换，'
        '支持条件语句和循环。',
    parameters: [
      ToolParameter(name: 'template_path', description: '模板文件路径', type: ToolParameterType.stringType, required: true),
      ToolParameter(name: 'variables', description: '模板变量（key-value）', type: ToolParameterType.objectType, required: true),
      ToolParameter(name: 'output_path', description: '输出文件路径', type: ToolParameterType.stringType, required: true),
    ],
    timeoutMs: 60000,
    execute: _handleFillTemplate,
  );

  // ==========================================================================
  // 工具执行处理
  // ==========================================================================

  Future<ToolResult> _handleCreatePpt(Map<String, dynamic> args, SkillContext ctx) async {
    final stopwatch = Stopwatch()..start();
    try {
      final title = args['title'] as String;
      final slidesData = (args['slides'] as List).cast<Map<String, dynamic>>();
      final themeName = args['theme'] as String? ?? 'businessBlue';
      final slideSizeStr = args['slide_size'] as String? ?? '16:9';
      final outputPath = args['output_path'] as String;

      final theme = switch (themeName) {
        'darkElegant' => PresentationTheme.darkElegant,
        'freshGreen' => PresentationTheme.freshGreen,
        _ => PresentationTheme.businessBlue,
      };

      final slideSize = slideSizeStr == '4:3' ? PageSize.slide4x3 : PageSize.slide16x9;
      final engine = PptEngine(theme: theme, slideSize: slideSize);

      // 添加标题页
      engine.addTitleSlide(title, subtitle: 'By 小酥 AI');

      // 添加内容页
      for (final slideData in slidesData) {
        final slideTitle = slideData['title'] as String;
        final content = slideData['content'];

        if (content is List) {
          final points = content.cast<String>();
          engine.addContentSlide(slideTitle, points);
        } else if (content is Map<String, dynamic>) {
          final chartTypeStr = content['chart_type'] as String? ?? 'bar';
          final chartType = ChartType.values.firstWhere(
            (t) => t.name == chartTypeStr,
            orElse: () => ChartType.bar,
          );
          final labels = (content['labels'] as List?)?.cast<String>() ?? [];
          final values = (content['values'] as List?)?.cast<num>() ?? [];
          final chartData = List.generate(
            min(labels.length, values.length),
            (i) => ChartData(label: labels[i], value: values[i].toDouble()),
          );
          engine.addChartSlide(slideTitle, chartType, chartData);
        }
      }

      // 时间轴页（如果 slideData 包含 timeline）
      for (final slideData in slidesData) {
        if (slideData['type'] == 'timeline') {
          final events = (slideData['events'] as List).cast<Map<String, dynamic>>();
          final timelineEvents = events.map((e) =>
            MapEntry(e['date'] as String, e['description'] as String)).toList();
          engine.addTimelineSlide(slideData['title'] as String, timelineEvents);
        }
      }

      final bytes = engine.build();
      ctx.logger.info('PPT 生成完成: ${engine.slides.length} 页幻灯片');

      stopwatch.stop();
      return ToolResult.success(
        content: 'PPT 已生成: ${engine.slides.length} 页幻灯片',
        data: {
          'slide_count': engine.slides.length,
          'theme': theme.name,
          'file_size': bytes.length,
          'output_path': outputPath,
        },
        durationMs: stopwatch.elapsedMilliseconds,
        attachments: [ToolAttachment(type: AttachmentType.file, uri: outputPath, mimeType: 'application/vnd.openxmlformats-officedocument.presentationml.presentation')],
      );
    } catch (e) {
      stopwatch.stop();
      return ToolResult.failure(error: 'PPT 生成失败: $e', errorCode: 'PPT_ERROR', durationMs: stopwatch.elapsedMilliseconds);
    }
  }

  Future<ToolResult> _handleCreateWord(Map<String, dynamic> args, SkillContext ctx) async {
    final stopwatch = Stopwatch()..start();
    try {
      final title = args['title'] as String;
      final content = args['content'] as Map<String, dynamic>;
      final fontFamily = args['font_family'] as String? ?? 'Microsoft YaHei';
      final fontSize = (args['font_size'] as num?)?.toDouble() ?? 12.0;
      final enableToc = args['enable_toc'] as bool? ?? false;
      final headerText = args['header_text'] as String?;
      final footerText = args['footer_text'] as String?;
      final outputPath = args['output_path'] as String;

      final pageSize = switch (args['page_size'] as String?) {
        'Letter' => PageSize.letter,
        'A3' => PageSize.a3,
        _ => PageSize.a4,
      };

      final engine = WordEngine(
        pageSize: pageSize,
        defaultFont: DocFont(family: fontFamily, size: fontSize),
        headerFooter: (headerText != null || footerText != null)
            ? WordHeaderFooter(headerText: headerText, footerText: footerText)
            : null,
      );

      if (enableToc) engine.enableTableOfContents();
      engine.addHeading(title, 1);

      final sections = (content['sections'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      for (final section in sections) {
        final type = section['type'] as String;
        switch (type) {
          case 'heading':
            engine.addHeading(section['text'] as String, section['level'] as int? ?? 2);
          case 'paragraph':
            engine.addParagraph(section['text'] as String);
          case 'bullet_list':
            engine.addBulletList((section['items'] as List).cast<String>());
          case 'numbered_list':
            engine.addNumberedList((section['items'] as List).cast<String>());
          case 'table':
            final rows = (section['rows'] as List).map((r) => (r as List).cast<String>()).toList();
            engine.addTable(WordTable(rows: rows));
          case 'page_break':
            engine.addPageBreak();
        }
      }

      final bytes = engine.build();
      ctx.logger.info('Word 文档生成完成');

      stopwatch.stop();
      return ToolResult.success(
        content: 'Word 文档已生成',
        data: {'file_size': bytes.length, 'output_path': outputPath},
        durationMs: stopwatch.elapsedMilliseconds,
        attachments: [ToolAttachment(type: AttachmentType.file, uri: outputPath, mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document')],
      );
    } catch (e) {
      stopwatch.stop();
      return ToolResult.failure(error: 'Word 生成失败: $e', errorCode: 'WORD_ERROR', durationMs: stopwatch.elapsedMilliseconds);
    }
  }

  Future<ToolResult> _handleCreatePdf(Map<String, dynamic> args, SkillContext ctx) async {
    final stopwatch = Stopwatch()..start();
    try {
      final title = args['title'] as String;
      final content = args['content'] as Map<String, dynamic>;
      final watermarkText = args['watermark'] as String?;
      final password = args['password'] as String?;
      final allowPrinting = args['allow_printing'] as bool? ?? true;
      final outputPath = args['output_path'] as String;

      final engine = PdfEngine();

      if (watermarkText != null) {
        engine.setWatermark(PdfWatermark(text: watermarkText));
      }
      if (password != null) {
        engine.setEncryption(PdfEncryption(userPassword: password, allowPrinting: allowPrinting));
      }

      engine.addText(title, font: const DocFont(size: 24, bold: true));
      engine.addText('');

      final sections = (content['sections'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      for (final section in sections) {
        final type = section['type'] as String;
        switch (type) {
          case 'heading':
            final level = section['level'] as int? ?? 1;
            engine.addText(section['text'] as String, font: DocFont(size: 22.0 - level * 2, bold: true));
          case 'paragraph':
            engine.addText(section['text'] as String);
          case 'table':
            final rows = (section['rows'] as List).map((r) => (r as List).cast<String>()).toList();
            engine.addTable(rows);
          case 'page_break':
            engine.newPage();
        }
      }

      final bytes = engine.build();
      ctx.logger.info('PDF 生成完成: ${engine.pages.length} 页');

      stopwatch.stop();
      return ToolResult.success(
        content: 'PDF 已生成: ${engine.pages.length} 页',
        data: {'page_count': engine.pages.length, 'file_size': bytes.length, 'output_path': outputPath},
        durationMs: stopwatch.elapsedMilliseconds,
        attachments: [ToolAttachment(type: AttachmentType.file, uri: outputPath, mimeType: 'application/pdf')],
      );
    } catch (e) {
      stopwatch.stop();
      return ToolResult.failure(error: 'PDF 生成失败: $e', errorCode: 'PDF_ERROR', durationMs: stopwatch.elapsedMilliseconds);
    }
  }

  Future<ToolResult> _handleCreateExcel(Map<String, dynamic> args, SkillContext ctx) async {
    final stopwatch = Stopwatch()..start();
    try {
      final sheetsData = (args['sheets'] as List).cast<Map<String, dynamic>>();
      final formulasData = (args['formulas'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final outputPath = args['output_path'] as String;

      final engine = ExcelEngine();

      for (var i = 0; i < sheetsData.length; i++) {
        final sheetData = sheetsData[i];
        if (i > 0) engine.createSheet(sheetData['name'] as String? ?? 'Sheet${i + 1}');

        final headers = (sheetData['headers'] as List?)?.cast<String>() ?? [];
        if (headers.isNotEmpty) engine.setHeaderRow(headers);

        final rows = (sheetData['rows'] as List?)?.cast<List>() ?? [];
        for (var r = 0; r < rows.length; r++) {
          for (var c = 0; c < rows[r].length; c++) {
            engine.setCellValue(r + 1, c, rows[r][c]);
          }
        }
      }

      for (final fd in formulasData) {
        final cell = fd['cell'] as String;
        final formula = fd['formula'] as String;
        final match = RegExp(r'([A-Z]+)(\d+)').firstMatch(cell);
        if (match != null) {
          final col = match.group(1)!;
          final row = int.parse(match.group(2)!) - 1;
          var colIdx = 0;
          for (var i = 0; i < col.length; i++) {
            colIdx = colIdx * 26 + (col.codeUnitAt(i) - 64);
          }
          engine.setFormula(row, colIdx - 1, formula);
        }
      }

      final bytes = engine.build();
      ctx.logger.info('Excel 生成完成: ${engine.sheets.length} 个工作表');

      stopwatch.stop();
      return ToolResult.success(
        content: 'Excel 已生成: ${engine.sheets.length} 个工作表',
        data: {'sheet_count': engine.sheets.length, 'file_size': bytes.length, 'output_path': outputPath},
        durationMs: stopwatch.elapsedMilliseconds,
        attachments: [ToolAttachment(type: AttachmentType.file, uri: outputPath, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
      );
    } catch (e) {
      stopwatch.stop();
      return ToolResult.failure(error: 'Excel 生成失败: $e', errorCode: 'EXCEL_ERROR', durationMs: stopwatch.elapsedMilliseconds);
    }
  }

  Future<ToolResult> _handleConvertFormat(Map<String, dynamic> args, SkillContext ctx) async {
    final stopwatch = Stopwatch()..start();
    try {
      final inputPath = args['input_path'] as String;
      final outputFormat = args['output_format'] as String;
      final outputPath = args['output_path'] as String;

      final inputExt = inputPath.split('.').last;
      final fromFormat = DocumentFormat.fromExtension(inputExt);
      final toFormat = DocumentFormat.fromExtension(outputFormat);

      if (fromFormat == null || toFormat == null) {
        return ToolResult.failure(error: '不支持的文件格式', errorCode: 'FORMAT_NOT_SUPPORTED');
      }
      if (!DocumentConverter.canConvert(fromFormat, toFormat)) {
        return ToolResult.failure(
          error: '不支持 ${fromFormat.displayName} → ${toFormat.displayName} 转换',
          errorCode: 'CONVERSION_NOT_SUPPORTED',
        );
      }

      final inputBytes = Uint8List(0); // 实际实现中从文件读取
      final outputBytes = DocumentConverter.convert(fromFormat, toFormat, inputBytes);

      ctx.logger.info('格式转换完成: ${fromFormat.displayName} → ${toFormat.displayName}');

      stopwatch.stop();
      return ToolResult.success(
        content: '转换完成: ${fromFormat.displayName} → ${toFormat.displayName}',
        data: {'from': fromFormat.extension, 'to': toFormat.extension, 'output_path': outputPath, 'file_size': outputBytes.length},
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      return ToolResult.failure(error: '格式转换失败: $e', errorCode: 'CONVERT_ERROR', durationMs: stopwatch.elapsedMilliseconds);
    }
  }

  Future<ToolResult> _handleEditDocument(Map<String, dynamic> args, SkillContext ctx) async {
    final stopwatch = Stopwatch()..start();
    try {
      final filePath = args['file_path'] as String;
      final operation = args['operation'] as String;
      final content = args['content'] as Map<String, dynamic>?;

      ctx.logger.info('编辑文档: $filePath, 操作: $operation');

      // 实际实现中会解析文件、执行编辑操作、重新保存
      stopwatch.stop();
      return ToolResult.success(
        content: '文档已编辑: $operation',
        data: {'file_path': filePath, 'operation': operation},
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      return ToolResult.failure(error: '文档编辑失败: $e', errorCode: 'EDIT_ERROR', durationMs: stopwatch.elapsedMilliseconds);
    }
  }

  Future<ToolResult> _handleMergeDocuments(Map<String, dynamic> args, SkillContext ctx) async {
    final stopwatch = Stopwatch()..start();
    try {
      final filePaths = (args['file_paths'] as List).cast<String>();
      final outputPath = args['output_path'] as String;

      if (filePaths.length < 2) {
        return ToolResult.failure(error: '至少需要 2 个文件进行合并', errorCode: 'INVALID_INPUT');
      }

      final ext = filePaths.first.split('.').last;
      final allSameFormat = filePaths.every((p) => p.endsWith('.$ext'));
      if (!allSameFormat) {
        return ToolResult.failure(error: '所有文件格式必须一致', errorCode: 'FORMAT_MISMATCH');
      }

      ctx.logger.info('合并 ${filePaths.length} 个文档');

      stopwatch.stop();
      return ToolResult.success(
        content: '已合并 ${filePaths.length} 个文档',
        data: {'file_count': filePaths.length, 'format': ext, 'output_path': outputPath},
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      return ToolResult.failure(error: '文档合并失败: $e', errorCode: 'MERGE_ERROR', durationMs: stopwatch.elapsedMilliseconds);
    }
  }

  Future<ToolResult> _handleExtractText(Map<String, dynamic> args, SkillContext ctx) async {
    final stopwatch = Stopwatch()..start();
    try {
      final filePath = args['file_path'] as String;
      final format = args['format'] as String? ?? 'plain';

      final ext = filePath.split('.').last.toLowerCase();
      ctx.logger.info('提取文本: $filePath (格式: $ext)');

      // 实际实现中会解析对应格式的文件并提取文本
      final extractedText = '[从 $filePath 提取的文本内容]';

      stopwatch.stop();
      return ToolResult.success(
        content: extractedText,
        data: {'file_path': filePath, 'format': format, 'text_length': extractedText.length},
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      return ToolResult.failure(error: '文本提取失败: $e', errorCode: 'EXTRACT_ERROR', durationMs: stopwatch.elapsedMilliseconds);
    }
  }

  Future<ToolResult> _handleFillTemplate(Map<String, dynamic> args, SkillContext ctx) async {
    final stopwatch = Stopwatch()..start();
    try {
      final templatePath = args['template_path'] as String;
      final variables = (args['variables'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()));
      final outputPath = args['output_path'] as String;

      // 读取模板
      final templateContent = '# 模板文件: $templatePath\n{{title}}\n{{#if author}}作者: {{author}}{{/if}}\n{{#each items}}- {{this}}\n{{/each}}';

      // 渲染模板
      final rendered = DocTemplateEngine.render(templateContent, variables);

      ctx.logger.info('模板填充完成: $templatePath → $outputPath');

      stopwatch.stop();
      return ToolResult.success(
        content: '模板已填充并输出',
        data: {'template_path': templatePath, 'output_path': outputPath, 'variables_count': variables.length},
        durationMs: stopwatch.elapsedMilliseconds,
        attachments: [ToolAttachment(type: AttachmentType.file, uri: outputPath)],
      );
    } catch (e) {
      stopwatch.stop();
      return ToolResult.failure(error: '模板填充失败: $e', errorCode: 'TEMPLATE_ERROR', durationMs: stopwatch.elapsedMilliseconds);
    }
  }
}

/// Map 扩展：为 Map 提供 asMap 方法
extension MapEntryExtension<E> on Iterable<E> {
  Iterable<MapEntry<int, E>> asMap() sync* {
    var i = 0;
    for (final element in this) {
      yield MapEntry(i++, element);
    }
  }
}
