# 自定义字体说明

## 支持格式

本目录用于存放自定义字体文件，支持以下格式：
- `.ttf` — TrueType Font
- `.otf` — OpenType Font

## 使用方法

1. 将字体文件放入此目录
2. 在 `pubspec.yaml` 的 `flutter/fonts` 中注册字体：

```yaml
flutter:
  fonts:
    - family: CustomFont
      fonts:
        - asset: assets/fonts/YourFontFile.ttf
        - asset: assets/fonts/YourFontFile-Bold.ttf
          weight: 700
```

3. 在代码中使用：

```dart
Text(
  '自定义字体',
  style: TextStyle(fontFamily: 'CustomFont'),
)
```

## 推荐字体

| 字体 | 用途 | 来源 |
|------|------|------|
| Noto Sans SC | 中文正文 | [Google Fonts](https://fonts.google.com/noto) |
| HarmonyOS Sans | 中文 UI | [华为字体](https://developer.huawei.com/consumer/cn/design/resource/) |
| Inter | 英文正文 | [rsms.me/inter](https://rsms.me/inter/) |
| JetBrains Mono | 代码展示 | [JetBrains](https://www.jetbrains.com/lp/mono/) |

## 注意事项

- 字体文件会增加应用包体积，请按需添加
- 中文字体通常较大（5~15MB），建议使用子集化（subset）压缩体积
- 确保字体许可证允许商业使用
