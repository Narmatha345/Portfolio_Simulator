import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'help_provider.dart';
import 'help_content.dart';

class HelpDrawer extends StatelessWidget {
  const HelpDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final helpProv = Provider.of<HelpProvider>(context);
    final topic = helpProv.currentTopic != null ? helpContent[helpProv.currentTopic] : null;

    // Screen width check for responsiveness
    double screenWidth = MediaQuery.of(context).size.width;
    double drawerWidth = screenWidth > 800 ? 750 : screenWidth * 0.95;

    return Drawer(
      width: drawerWidth,
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Row(
          children: [
            // 1. Left Sidebar (Navigation) - Fixed Width
            Container(
              width: 200, // Reduced width for better balance
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6),
                border: Border(right: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 20),
                children: helpCategories.map((cat) => _buildNavCategory(context, cat, helpProv)).toList(),
              ),
            ),

            // 2. Right Content Area - Dynamic Width
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Close Button Header
                  Padding(
                    padding: const EdgeInsets.only(right: 10, top: 10),
                    child: Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.black54),
                        onPressed: helpProv.closeHelp,
                      ),
                    ),
                  ),

                  // Actual Content with safe Padding
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                      child: topic != null
                          ? SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    topic.title,
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF111827),
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  // Fixed Markdown rendering
                                  Markdown(
                                    data: topic.content,
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    padding: EdgeInsets.zero,
                                  ),
                                  const SizedBox(height: 40),
                                ],
                              ),
                            )
                          : const Center(
                              child: Text(
                                "Select a topic from the left menu",
                                style: TextStyle(color: Colors.grey, fontSize: 16),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavCategory(BuildContext context, HelpCategory cat, HelpProvider prov) {
    bool isCatActive = prov.currentTopic == cat.topicId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: Text(
            cat.title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isCatActive ? const Color(0xFF3B82F6) : const Color(0xFF374151),
            ),
          ),
          onTap: () => prov.openHelp(cat.topicId),
        ),
        ...cat.subTopics.map((subId) {
          bool isSubActive = prov.currentTopic == subId;
          return ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: const EdgeInsets.only(left: 32),
            title: Text(
              helpContent[subId]?.title ?? subId,
              style: TextStyle(
                fontSize: 13,
                color: isSubActive ? const Color(0xFF3B82F6) : const Color(0xFF6B7280),
                fontWeight: isSubActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            onTap: () => prov.openHelp(subId),
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }
}