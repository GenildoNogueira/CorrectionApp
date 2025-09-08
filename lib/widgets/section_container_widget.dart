import 'package:flutter/material.dart';

class SectionContainerWidget extends StatelessWidget {
  final String title;
  final Widget icon;
  final Widget child;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;

  const SectionContainerWidget({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.backgroundColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: backgroundColor ?? Colors.white.withValues(alpha: 0.95),
      margin: EdgeInsets.zero,
      shape: RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.all(25),
        child: Column(
          spacing: 20,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      spacing: 15,
      children: [
        icon,
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
        ),
      ],
    );
  }
}
