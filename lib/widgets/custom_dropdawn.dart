import 'package:flutter/material.dart';

class CustomDropdawn<T> extends StatelessWidget {
  const CustomDropdawn({
    super.key,
    required this.label,
    required this.initialValue,
    required this.value,
    required this.itemBuilder,
    required this.onSelected,
  });

  final String label;
  final T initialValue;
  final String value;
  final List<PopupMenuEntry<T>> Function(BuildContext) itemBuilder;
  final Function(T)? onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF555555),
            fontSize: 16,
          ),
        ),
        PopupMenuButton<T>(
          initialValue: initialValue,
          position: PopupMenuPosition.under,
          color: Colors.white,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Color(0xFFE4E4E7),
              width: 1,
            ),
          ),
          offset: Offset(0, 4),
          itemBuilder: itemBuilder,
          onSelected: onSelected,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12),
            height: 45,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: Color(0xFFE4E4E7), // zinc-300
                width: 1,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: Color(0xFF09090B), // zinc-900
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down,
                  color: Color(0xFF71717A), // zinc-500
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
