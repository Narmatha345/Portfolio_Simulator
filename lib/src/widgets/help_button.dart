import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../help/help_provider.dart';

class HelpButton extends StatelessWidget {
  final String topic;
  final bool isMini;

  const HelpButton({super.key, required this.topic, this.isMini = true});

  @override
  Widget build(BuildContext context) {
    double size = isMini ? 32 : 40;
    double fontSize = isMini ? 14 : 16;

    return InkWell(
      onTap: () {
        Provider.of<HelpProvider>(context, listen: false).openHelp(topic);
        Scaffold.of(context).openEndDrawer(); // React context click
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text("?", style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold)),
      ),
    );
  }
}