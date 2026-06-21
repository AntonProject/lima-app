import 'dart:io';
import 'dart:ui' as ui;

import 'package:excel/excel.dart' as ex;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:lima/core/i18n/app_i18n.dart';

enum SpecificationFormat { xlsx, png }

class SpecificationItem {
  final String name;
  final String manufacturer;
  final int quantity;
  final String serialNumber;
  final String expiryDate;
  final double basePrice;
  final double markupPercent;
  final String unit;

  const SpecificationItem({
    required this.name,
    this.manufacturer = '',
    required this.quantity,
    required this.serialNumber,
    required this.expiryDate,
    required this.basePrice,
    this.markupPercent = 20,
    this.unit = '',
  });
}

class SpecificationData {
  final int orderId;
  final DateTime date;
  final String seller;
  final String buyer;
  final List<SpecificationItem> items;
  final double vatRatePercent;

  const SpecificationData({
    required this.orderId,
    required this.date,
    required this.seller,
    required this.buyer,
    required this.items,
    this.vatRatePercent = 12,
  });
}

class SpecificationExportService {
  Future<void> export(
    BuildContext context, {
    required SpecificationData data,
    required SpecificationFormat format,
  }) async {
    late final File saved;
    try {
      final bytes = switch (format) {
        SpecificationFormat.xlsx => await _buildXlsx(data),
        SpecificationFormat.png => await _buildPng(data),
      };
      saved = await _saveFile(
        bytes,
        '${_sanitize(data.buyer)}.${format == SpecificationFormat.xlsx ? 'xlsx' : 'png'}',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppI18n.tr('exportGenError', args: {'e': '$e'})),
        ),
      );
      return;
    }

    if (!context.mounted) return;

    try {
      final result = await OpenFilex.open(saved.path);
      if (result.type != ResultType.done) {
        await Share.shareXFiles(
          [XFile(saved.path)],
          text: AppI18n.tr('specification'),
          subject: AppI18n.tr('specification'),
        );
      }
    } on MissingPluginException {
      await Share.shareXFiles(
        [XFile(saved.path)],
        text: 'Спецификация',
        subject: 'Спецификация',
      );
    } catch (_) {
      await Share.shareXFiles(
        [XFile(saved.path)],
        text: 'Спецификация',
        subject: 'Спецификация',
      );
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(AppI18n.tr('exportFileSaved', args: {'path': saved.path})),
      ),
    );
  }

  Future<File> _saveFile(Uint8List bytes, String name) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final specsDir = Directory(p.join(docsDir.path, 'specifications'));
    if (!await specsDir.exists()) {
      await specsDir.create(recursive: true);
    }
    final file = File(p.join(specsDir.path, name));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<Uint8List> _buildXlsx(SpecificationData data) async {
    final templateBytes = await rootBundle.load(
      'assets/docs/specification_template.xlsx',
    );
    final excel = ex.Excel.decodeBytes(templateBytes.buffer.asUint8List());
    final sheet = excel['Спецификация'];
    ex.Data cell(String addr) => sheet.cell(ex.CellIndex.indexByString(addr));
    final items = data.items.isEmpty
        ? const [
            SpecificationItem(
              name: '—',
              manufacturer: '—',
              quantity: 1,
              serialNumber: '—',
              expiryDate: '—',
              basePrice: 0,
            ),
          ]
        : data.items;

    final headerStyleA2 = cell('A2').cellStyle;
    final headerStyleA3 = cell('A3').cellStyle;
    final sellerTopStyle = cell('C6').cellStyle;
    final buyerTopStyle = cell('C8').cellStyle;
    final sellerBottomStyle = cell('A22').cellStyle;
    final buyerBottomStyle = cell('L22').cellStyle;

    cell('A2').value = ex.TextCellValue('СПЕЦИФИКАЦИЯ №${data.orderId}');
    cell('A3').value = ex.TextCellValue('от ${_russianDate(data.date)}');
    cell('C6').value = ex.TextCellValue(data.seller);
    cell('C8').value = ex.TextCellValue(data.buyer);
    if (headerStyleA2 != null) cell('A2').cellStyle = headerStyleA2;
    if (headerStyleA3 != null) cell('A3').cellStyle = headerStyleA3;
    if (sellerTopStyle != null) cell('C6').cellStyle = sellerTopStyle;
    if (buyerTopStyle != null) cell('C8').cellStyle = buyerTopStyle;

    final templateStyles = <String, ex.CellStyle?>{};
    final totalTemplateStyles = <String, ex.CellStyle?>{};
    for (final col in [
      'A',
      'B',
      'C',
      'D',
      'E',
      'F',
      'G',
      'H',
      'I',
      'J',
      'K',
      'L',
      'M',
      'N',
      'O',
      'P',
    ]) {
      templateStyles[col] = cell('${col}13').cellStyle;
      totalTemplateStyles[col] = cell('${col}14').cellStyle;
    }

    for (var i = 1; i < items.length; i++) {
      sheet.insertRow(13 + i);
      _mergeRowForItem(sheet, 13 + i);
      for (final col in templateStyles.keys) {
        final s = templateStyles[col];
        if (s != null) {
          cell('$col${13 + i}').cellStyle = s;
        }
      }
    }

    double totalSupply = 0;
    double totalVat = 0;
    double totalWithVat = 0;

    for (var i = 0; i < items.length; i++) {
      final row = 13 + i;
      final item = items[i];
      final supplyPrice = item.basePrice * (1 + item.markupPercent / 100);
      final supplySum = supplyPrice * item.quantity;
      final vatSum = supplySum * (data.vatRatePercent / 100);
      final withVat = supplySum + vatSum;

      totalSupply += supplySum;
      totalVat += vatSum;
      totalWithVat += withVat;

      // Apply styles and borders FIRST so subsequent value writes are not
      // accidentally overwritten by the excel library's style setter.
      for (final col in templateStyles.keys) {
        final s = templateStyles[col];
        if (s != null) {
          cell('$col$row').cellStyle = s;
        }
      }
      _reinforceMergedBorders(cell, row);

      // Write values AFTER styles.
      cell('A$row').value = ex.IntCellValue(i + 1);
      cell('B$row').value = ex.TextCellValue(
        '${item.name}\n'
        'Производитель: ${item.manufacturer.isEmpty ? '—' : item.manufacturer}\n'
        'Серия:${item.serialNumber}\n'
        'Срок годности: ${item.expiryDate}',
      );
      sheet.setRowHeight(row, _rowHeightForItem(item));
      cell('E$row').value = ex.TextCellValue(item.unit);
      cell('F$row').value = ex.IntCellValue(item.quantity);
      cell('G$row').value = ex.DoubleCellValue(item.basePrice);
      cell('H$row').value = ex.TextCellValue(
        '${item.markupPercent.toStringAsFixed(2)}%',
      );
      cell('I$row').value = ex.DoubleCellValue(supplyPrice);
      cell('K$row').value = ex.DoubleCellValue(supplySum);
      cell('M$row').value = ex.TextCellValue(
        '${data.vatRatePercent.toStringAsFixed(0)}%',
      );
      cell('N$row').value = ex.DoubleCellValue(vatSum);
      cell('O$row').value = ex.DoubleCellValue(withVat);
    }

    final totalRow = 13 + items.length;
    // Same pattern for the total row: styles first, values after.
    for (final col in totalTemplateStyles.keys) {
      final s = totalTemplateStyles[col];
      if (s != null) {
        cell('$col$totalRow').cellStyle = s;
      }
    }
    _reinforceMergedBorders(cell, totalRow);
    cell('K$totalRow').value = ex.DoubleCellValue(totalSupply);
    cell('M$totalRow').value = ex.DoubleCellValue(totalVat);
    cell('O$totalRow').value = ex.DoubleCellValue(totalWithVat);
    sheet.setRowHeight(totalRow, 15);

    final footerValueRow = 22 + (items.length - 1);
    cell('A$footerValueRow').value = ex.TextCellValue(data.seller);
    cell('L$footerValueRow').value = ex.TextCellValue(data.buyer);
    if (sellerBottomStyle != null) {
      cell('A$footerValueRow').cellStyle = sellerBottomStyle;
    }
    if (buyerBottomStyle != null) {
      cell('L$footerValueRow').cellStyle = buyerBottomStyle;
    }

    final encoded = excel.encode();
    return Uint8List.fromList(encoded ?? <int>[]);
  }

  double _rowHeightForItem(SpecificationItem item) {
    // Approximate wrapped-line count in the merged B:D area and add vertical padding.
    const charsPerLine = 34;
    final lines = <String>[
      item.name,
      'Производитель: ${item.manufacturer.isEmpty ? '—' : item.manufacturer}',
      'Серия:${item.serialNumber}',
      'Срок годности: ${item.expiryDate}',
    ];
    var visualLines = 0;
    for (final line in lines) {
      final len = line.trim().isEmpty ? 1 : line.trim().length;
      visualLines += (len / charsPerLine).ceil().clamp(1, 6);
    }
    const lineHeight = 14.0;
    const verticalPadding = 12.0;
    final height = (visualLines * lineHeight) + verticalPadding;
    return height.clamp(50.0, 160.0);
  }

  void _mergeRowForItem(ex.Sheet sheet, int row) {
    void merge(String fromCol, String toCol) {
      sheet.merge(
        ex.CellIndex.indexByString('$fromCol$row'),
        ex.CellIndex.indexByString('$toCol$row'),
      );
    }

    merge('B', 'D');
    merge('I', 'J');
    merge('K', 'L');
    merge('M', 'N');
    merge('O', 'P');
  }

  void _reinforceMergedBorders(ex.Data Function(String) cell, int row) {
    final thin = ex.Border(
      borderStyle: ex.BorderStyle.Thin,
      borderColorHex: ex.ExcelColor.black,
    );

    void patchRight(String col) {
      final current = cell('$col$row').cellStyle;
      if (current != null) {
        cell('$col$row').cellStyle = current.copyWith(rightBorderVal: thin);
      }
    }

    void patchLeft(String col) {
      final current = cell('$col$row').cellStyle;
      if (current != null) {
        cell('$col$row').cellStyle = current.copyWith(leftBorderVal: thin);
      }
    }

    patchLeft('B');
    patchRight('D');
    patchLeft('I');
    patchRight('J');
    patchLeft('K');
    patchRight('L');
    patchLeft('M');
    patchRight('N');
    patchLeft('O');
    patchRight('P');
  }

  Future<Uint8List> _buildPng(SpecificationData data) async {
    final items = data.items.isEmpty
        ? const [
            SpecificationItem(
              name: '—',
              manufacturer: '—',
              quantity: 1,
              serialNumber: '—',
              expiryDate: '—',
              basePrice: 0,
            ),
          ]
        : data.items;
    final extraRows = (items.length - 1).clamp(0, 999);
    const rowHeight = 79;
    final canvasHeight = 565 + (extraRows * rowHeight);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const pageWidth = 1600.0;
    final whitePaint = Paint()..color = Colors.white;
    final linePaint = Paint()
      ..color = const Color(0xFF282828)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, pageWidth, canvasHeight.toDouble()),
      whitePaint,
    );
    final tableTop = 205;
    final headerBottom = 274;
    final itemTop = headerBottom;
    final totalTop = itemTop + (items.length * rowHeight);
    final tableBottom = totalTop + 30;
    final signY = 500 + (extraRows * rowHeight);
    final signNameY = 546 + (extraRows * rowHeight);

    _drawText(
      canvas,
      text: 'СПЕЦИФИКАЦИЯ №${data.orderId}',
      x: 0,
      y: 22,
      width: pageWidth,
      align: TextAlign.center,
      fontSize: 24,
      bold: true,
    );
    _drawText(
      canvas,
      text: 'от ${_russianDate(data.date)}',
      x: 0,
      y: 52,
      width: pageWidth,
      align: TextAlign.center,
      fontSize: 24,
      bold: true,
    );
    _drawText(canvas, text: 'Продавец ', x: 130, y: 126, fontSize: 24);
    _drawText(
      canvas,
      text: data.seller,
      x: 310,
      y: 126,
      fontSize: 24,
      bold: true,
    );
    _drawText(canvas, text: 'Покупатель ', x: 130, y: 170, fontSize: 24);
    _drawText(
      canvas,
      text: data.buyer,
      x: 310,
      y: 170,
      fontSize: 24,
      bold: true,
    );

    canvas.drawRect(
      Rect.fromLTRB(5, tableTop.toDouble(), 1590, tableBottom.toDouble()),
      linePaint,
    );
    canvas.drawLine(
      Offset(5, headerBottom.toDouble()),
      Offset(1590, headerBottom.toDouble()),
      linePaint,
    );
    for (var i = 1; i < items.length; i++) {
      final y = itemTop + (i * rowHeight);
      canvas.drawLine(
        Offset(5, y.toDouble()),
        Offset(1590, y.toDouble()),
        linePaint,
      );
    }
    canvas.drawLine(
      Offset(5, totalTop.toDouble()),
      Offset(1590, totalTop.toDouble()),
      linePaint,
    );
    for (final x in [100, 390, 487, 583, 710, 806, 999, 1192, 1401]) {
      canvas.drawLine(
        Offset(x.toDouble(), tableTop.toDouble()),
        Offset(x.toDouble(), tableBottom.toDouble()),
        linePaint,
      );
    }
    canvas.drawLine(Offset(1192, 251), Offset(1401, 251), linePaint);
    canvas.drawLine(
      Offset(1290, 251),
      Offset(1290, tableBottom.toDouble()),
      linePaint,
    );

    // Column boundaries: 5|100|390|487|583|710|806|999|1192|1290|1401|1590
    _drawText(
      canvas,
      text: '№',
      x: 5,
      y: 230,
      width: 95,
      align: TextAlign.center,
      bold: true,
      fontSize: 20,
    );
    _drawText(
      canvas,
      text: 'Наименование товара',
      x: 100,
      y: 230,
      width: 290,
      align: TextAlign.center,
      bold: true,
      fontSize: 17,
    );
    _drawText(
      canvas,
      text: 'Ед.',
      x: 390,
      y: 230,
      width: 97,
      align: TextAlign.center,
      bold: true,
      fontSize: 17,
      maxLines: 1,
    );
    _drawText(
      canvas,
      text: 'Кол-во',
      x: 487,
      y: 230,
      width: 96,
      align: TextAlign.center,
      bold: true,
      fontSize: 17,
      maxLines: 1,
    );
    _drawText(
      canvas,
      text: 'Базовая\nцена',
      x: 583,
      y: 222,
      width: 127,
      align: TextAlign.center,
      bold: true,
      fontSize: 17,
      maxLines: 2,
    );
    _drawText(
      canvas,
      text: 'Торговая\nнаценка',
      x: 710,
      y: 222,
      width: 96,
      align: TextAlign.center,
      bold: true,
      fontSize: 16,
      maxLines: 2,
    );
    _drawText(
      canvas,
      text: 'Цена поставки',
      x: 806,
      y: 230,
      width: 193,
      align: TextAlign.center,
      bold: true,
      fontSize: 17,
      maxLines: 1,
    );
    _drawText(
      canvas,
      text: 'Сумма поставки',
      x: 999,
      y: 230,
      width: 193,
      align: TextAlign.center,
      bold: true,
      fontSize: 17,
      maxLines: 1,
    );
    _drawText(
      canvas,
      text: 'НДС',
      x: 1192,
      y: 222,
      width: 209,
      align: TextAlign.center,
      bold: true,
      fontSize: 17,
      maxLines: 1,
    );
    _drawText(
      canvas,
      text: 'Ставка',
      x: 1192,
      y: 256,
      width: 98,
      align: TextAlign.center,
      bold: true,
      fontSize: 16,
      maxLines: 1,
    );
    _drawText(
      canvas,
      text: 'Сумма',
      x: 1290,
      y: 256,
      width: 111,
      align: TextAlign.center,
      bold: true,
      fontSize: 16,
      maxLines: 1,
    );
    _drawText(
      canvas,
      text: 'Стоимость поставки\nс учётом НДС',
      x: 1401,
      y: 220,
      width: 189,
      align: TextAlign.center,
      bold: true,
      fontSize: 17,
      maxLines: 2,
    );

    double totalSupply = 0;
    double totalVat = 0;
    double totalWithVat = 0;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final supplyPrice = item.basePrice * (1 + item.markupPercent / 100);
      final supplySum = supplyPrice * item.quantity;
      final vat = supplySum * (data.vatRatePercent / 100);
      final total = supplySum + vat;

      totalSupply += supplySum;
      totalVat += vat;
      totalWithVat += total;

      final rowY = itemTop + (i * rowHeight);
      _drawText(
        canvas,
        text: '${i + 1}',
        x: 8,
        y: rowY + 28,
        width: 84,
        align: TextAlign.center,
        fontSize: 18,
      );
      _drawText(
        canvas,
        text:
            '${item.name}\nПроизводитель: ${item.manufacturer.isEmpty ? '—' : item.manufacturer}\nСерия:${item.serialNumber}\nСрок годности: ${item.expiryDate}',
        x: 108,
        y: rowY + 4,
        width: 274,
        align: TextAlign.left,
        fontSize: 16,
        maxLines: 4,
      );
      _drawText(
        canvas,
        text: '${item.quantity}',
        x: 495,
        y: rowY + 28,
        width: 80,
        align: TextAlign.center,
        fontSize: 18,
      );
      _drawText(
        canvas,
        text: _money(item.basePrice),
        x: 591,
        y: rowY + 28,
        width: 111,
        align: TextAlign.center,
        fontSize: 18,
      );
      _drawText(
        canvas,
        text: '${item.markupPercent.toStringAsFixed(2)}%',
        x: 718,
        y: rowY + 28,
        width: 80,
        align: TextAlign.center,
        fontSize: 18,
      );
      _drawText(
        canvas,
        text: _money(supplyPrice),
        x: 814,
        y: rowY + 28,
        width: 177,
        align: TextAlign.center,
        fontSize: 18,
      );
      _drawText(
        canvas,
        text: _money(supplySum),
        x: 1007,
        y: rowY + 28,
        width: 177,
        align: TextAlign.center,
        fontSize: 18,
      );
      _drawText(
        canvas,
        text: '${data.vatRatePercent.toStringAsFixed(0)}%',
        x: 1200,
        y: rowY + 28,
        width: 82,
        align: TextAlign.center,
        fontSize: 18,
      );
      _drawText(
        canvas,
        text: _money(vat),
        x: 1298,
        y: rowY + 28,
        width: 95,
        align: TextAlign.center,
        fontSize: 18,
      );
      _drawText(
        canvas,
        text: _money(total),
        x: 1409,
        y: rowY + 28,
        width: 173,
        align: TextAlign.center,
        fontSize: 18,
      );
    }

    _drawText(
      canvas,
      text: 'Всего к оплате:',
      x: 108,
      y: totalTop + 6,
      width: 274,
      align: TextAlign.left,
      bold: true,
      fontSize: 16,
    );
    _drawText(
      canvas,
      text: _money(totalSupply),
      x: 1007,
      y: totalTop + 6,
      width: 177,
      align: TextAlign.center,
      bold: true,
      fontSize: 16,
    );
    _drawText(
      canvas,
      text: _money(totalVat),
      x: 1298,
      y: totalTop + 6,
      width: 95,
      align: TextAlign.center,
      bold: true,
      fontSize: 16,
    );
    _drawText(
      canvas,
      text: _money(totalWithVat),
      x: 1409,
      y: totalTop + 6,
      width: 173,
      align: TextAlign.center,
      bold: true,
      fontSize: 16,
    );

    _drawText(
      canvas,
      text: 'Продавец',
      x: 0,
      y: signY.toDouble(),
      width: 800,
      align: TextAlign.center,
      fontSize: 24,
    );
    _drawText(
      canvas,
      text: 'Покупатель',
      x: 800,
      y: signY.toDouble(),
      width: 800,
      align: TextAlign.center,
      fontSize: 24,
    );
    _drawText(
      canvas,
      text: data.seller,
      x: 0,
      y: signNameY.toDouble(),
      width: 800,
      align: TextAlign.center,
      bold: true,
      fontSize: 24,
    );
    _drawText(
      canvas,
      text: data.buyer,
      x: 800,
      y: signNameY.toDouble(),
      width: 800,
      align: TextAlign.center,
      bold: true,
      fontSize: 24,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(pageWidth.toInt(), canvasHeight);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  void _drawText(
    Canvas canvas, {
    required String text,
    required double x,
    required double y,
    double? width,
    double fontSize = 24,
    bool bold = false,
    TextAlign align = TextAlign.left,
    int? maxLines,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: const Color(0xFF191919),
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          height: 1.1,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: maxLines,
    );
    painter.layout(maxWidth: width ?? double.infinity);
    // TextPainter.width reflects the text's natural width, not maxWidth.
    // For center/right alignment we must manually offset within the given width.
    double dx = x;
    if (width != null) {
      if (align == TextAlign.center) {
        dx = x + (width - painter.width) / 2;
      } else if (align == TextAlign.right) {
        dx = x + width - painter.width;
      }
    }
    painter.paint(canvas, Offset(dx, y));
  }

  static String _russianDate(DateTime date) {
    const months = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];
    final month = months[date.month - 1];
    return '${date.day} $month ${date.year} г.';
  }

  static String _money(double value) {
    final n = value.toStringAsFixed(2);
    final parts = n.split('.');
    final intPart = parts[0];
    final dec = parts[1];
    final buff = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      final idxFromEnd = intPart.length - i;
      buff.write(intPart[i]);
      if (idxFromEnd > 1 && idxFromEnd % 3 == 1) buff.write(' ');
    }
    return '${buff.toString()}.$dec';
  }

  static String _sanitize(String input) {
    final out = input.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return out.isEmpty ? 'specification' : out;
  }
}
