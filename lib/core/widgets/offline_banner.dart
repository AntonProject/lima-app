import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OfflineBanner extends StatelessWidget {
  final bool visible;
  final bool compact;

  const OfflineBanner({
    super.key,
    required this.visible,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return IgnorePointer(
      ignoring: true,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        offset: visible ? Offset.zero : const Offset(0, -1.2),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: visible ? 1 : 0,
          child: compact
              ? Padding(
                  padding: EdgeInsets.fromLTRB(16, topInset + 8, 16, 0),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 360),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD32F2F),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 16,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.wifi_off, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Работаете в оффлайне',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : Container(
                  height: topInset + 44,
                  color: const Color(0xFFD32F2F),
                  padding: EdgeInsets.fromLTRB(16, topInset, 16, 0),
                  child: SizedBox(
                    height: 44,
                    child: Row(
                      children: [
                        const Icon(Icons.wifi_off, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Нет подключения к интернету',
                          style: GoogleFonts.manrope(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'ОФЛАЙН',
                            style: GoogleFonts.manrope(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
