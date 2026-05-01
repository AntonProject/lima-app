import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lima/core/services/app_actions.dart';
import 'package:lima/core/theme/app_theme.dart';

class LpuPresentationsScreen extends StatelessWidget {
  final String drugName;

  const LpuPresentationsScreen({super.key, required this.drugName});

  @override
  Widget build(BuildContext context) {
    final presentations = <Map<String, String>>[
      {
        'title': 'Презентация препарата',
        'description': 'Краткая презентация для визита',
        'asset': 'assets/docs/presentation_1.pdf',
      },
      {
        'title': 'Инструкция по применению',
        'description': 'Информационный материал',
        'asset': 'assets/docs/presentation_2.pdf',
      },
      {
        'title': 'Клинический материал',
        'description': 'Тестовый PDF для открытия',
        'asset': 'assets/docs/presentation_3.pdf',
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Материалы',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              drugName,
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: AppColors.secondaryText,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: presentations.length,
        itemBuilder: (_, i) {
          final p = presentations[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () => openAssetFile(context, p['asset']!),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.secondaryBg,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: shadowSm,
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.iconBgOrange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.picture_as_pdf_rounded,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p['title']!,
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            p['description']!,
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.open_in_new_rounded,
                      color: AppColors.hintText,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

