import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'home_card.dart';

class AISuggestion {
  const AISuggestion({required this.text, required this.confidence});

  final String text;
  final int confidence;
}

class AISuggestionCard extends StatelessWidget {
  const AISuggestionCard({
    super.key,
    required this.suggestion,
    this.onViewMatch,
  });

  final AISuggestion suggestion;
  final VoidCallback? onViewMatch;

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      onTap: onViewMatch,
      padding: const EdgeInsets.all(14),
      radius: 16,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  suggestion.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.trending_up_rounded,
                        size: 14,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${suggestion.confidence}% match',
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onViewMatch,
            child: const Text('View'),
          ),
        ],
      ),
    );
  }
}
