import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dart:io' as io;
import 'package:ChatMcp/llm/model.dart';
import 'chat_message.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ChatMcp/provider/provider_manager.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ChatMcp/utils/platform.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:logging/logging.dart';
import 'package:ChatMcp/utils/color.dart';

class ListViewToImageScreen extends StatefulWidget {
  final List<ChatMessage> messages;
  const ListViewToImageScreen({super.key, required this.messages});

  @override
  _ListViewToImageScreenState createState() => _ListViewToImageScreenState();
}

class _ListViewToImageScreenState extends State<ListViewToImageScreen> {
  final ScrollController _scrollController = ScrollController();
  final screenshotController = ScreenshotController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Share Chat Image'),
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.camera),
            onPressed: _captureListViewAsImage,
          ),
        ],
      ),
      body: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          scrollbars: false, // 完全禁用滚动条
        ),
        child: SingleChildScrollView(
          controller: _scrollController,
          child: _buildMessage(),
        ),
      ),
    );
  }

  Widget _buildMessage() {
    List<List<ChatMessage>> groupedMessages = [];
    List<ChatMessage> currentGroup = [];

    for (var msg in widget.messages) {
      if (msg.role == MessageRole.user) {
        if (currentGroup.isNotEmpty) {
          groupedMessages.add(currentGroup);
          currentGroup = [];
        }
        currentGroup.add(msg);
        groupedMessages.add(currentGroup);
        currentGroup = [];
      } else {
        currentGroup.add(msg);
      }
    }

    if (currentGroup.isNotEmpty) {
      groupedMessages.add(currentGroup);
    }
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ProviderManager.chatProvider.activeChat?.title != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      ProviderManager.chatProvider.activeChat!.title!,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    "by ChatMcp",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 16),
          ],
          ...groupedMessages.map((group) {
            return ChatUIMessage(
              messages: group,
              onRetry: (ChatMessage message) {},
              onSwitch: (String messageId) {},
            );
          }).toList(),
        ],
      ),
    );
  }

  Future<void> _captureListViewAsImage() async {
    try {
      // 创建一个离屏widget来渲染完整内容
      final renderWidget = Screenshot(
        controller: screenshotController,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            devicePixelRatio: 3.0,
          ),
          child: Material(
            child: _buildMessage(),
          ),
        ),
      );

      // 使用Overlay将widget临时添加到屏幕外
      final overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          left: -10000, // 放在屏幕外
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: renderWidget,
          ),
        ),
      );

      Overlay.of(context).insert(overlayEntry);

      // 等待widget完全渲染
      await Future.delayed(const Duration(milliseconds: 500));

      // 捕获图像
      final image = await screenshotController.capture(
        pixelRatio: 3.0,
      );

      // 移除临时widget
      overlayEntry.remove();

      if (image == null) {
        Logger.root.severe('截图失败: 无法获取图片');
        return;
      }

      if (kIsDesktop) {
        final path = await FilePicker.platform.saveFile(
          dialogTitle: ProviderManager.chatProvider.activeChat?.title ??
              'Save chat image',
          fileName:
              'ChatMcp-${ProviderManager.chatProvider.activeChat?.title ?? DateTime.now().millisecondsSinceEpoch}.png',
          type: FileType.custom,
          allowedExtensions: ['png'],
        );
        if (path != null) {
          await io.File(path).writeAsBytes(image);
        }
      }

      if (kIsMobile) {
        final title =
            ProviderManager.chatProvider.activeChat?.title ?? 'Chat Image';
        final safeTitle = title
            .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
            .replaceAll(RegExp(r'\s+'), '_');

        final tempDir = await getTemporaryDirectory();
        final tempFile = io.File(
            '${tempDir.path}/ChatMcp_${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.png');
        await tempFile.writeAsBytes(image);

        await Share.shareXFiles(
          [XFile(tempFile.path)],
          subject: "ChatMcp $title",
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      Logger.root.severe('截图失败: $e');
    }
  }
}
