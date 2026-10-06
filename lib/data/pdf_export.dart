import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/models.dart';
import '../engine/interpret.dart';
import '../engine/tables.dart';

Future<Uint8List> buildReportPdf({
  required NatalChart chart,
  MatchResult? match,
  NatalChart? partner,
  List<({String q, String a})> qa = const [],
}) async {
  final areas = interpretChart(chart);
  final doc = pw.Document();
  final ink = PdfColor.fromHex('#1c1917');
  final muted = PdfColor.fromHex('#57534e');
  final band = PdfColor.fromHex('#1e3a5f');
  final rust = PdfColor.fromHex('#3f1d0f');

  pw.Widget h(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 12, bottom: 6),
        child: pw.Text(t, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: rust)),
      );
  pw.Widget p(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Text(t, style: pw.TextStyle(fontSize: 10, height: 1.35, color: ink), textAlign: pw.TextAlign.justify),
      );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 40, 36, 40),
      header: (c) => c.pageNumber == 1
          ? pw.SizedBox()
          : pw.Container(
              color: band,
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'PocketAstro  ·  ${chart.input.name}',
                style: pw.TextStyle(color: PdfColors.white, fontSize: 9),
              ),
            ),
      footer: (c) => pw.Text(
        'Interpretive astrology — not medical, legal, or financial advice   ${c.pageNumber}',
        style: pw.TextStyle(fontSize: 8, color: muted),
      ),
      build: (c) => [
        pw.Container(
          color: band,
          padding: const pw.EdgeInsets.all(24),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('POCKETASTRO', style: pw.TextStyle(color: PdfColor.fromHex('#cbd5e1'), fontSize: 10)),
              pw.SizedBox(height: 8),
              pw.Text('Natal analysis', style: pw.TextStyle(color: PdfColors.white, fontSize: 22, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text(
                '${chart.input.name}\n${chart.input.localDateTime}  ·  ${chart.input.place.label}',
                style: pw.TextStyle(color: PdfColor.fromHex('#e2e8f0'), fontSize: 11),
              ),
              pw.SizedBox(height: 8),
              pw.Text(chart.engineStamp, style: pw.TextStyle(color: PdfColor.fromHex('#94a3b8'), fontSize: 8)),
            ],
          ),
        ),
        h('Disclaimer'),
        p('PocketAstro can compute planetary positions offline. It cannot scientifically guarantee future events. Confidence scores cap well below 100. Do not use this report as medical, legal, or financial advice.'),
        h('Vedic placements (Lahiri, whole-sign)'),
        _table(chart, vedic: true),
        h('Western placements (tropical)'),
        _table(chart, vedic: false),
        h('Yogas'),
        p(chart.yogas.isEmpty
            ? 'No catalogued yoga fired on this chart.'
            : chart.yogas.join('\n\n')),
        h('Vimshottari dasha'),
        ...chart.dasha.take(9).map(
              (d) => p('${d.lord}: ${d.start.toIso8601String().substring(0, 10)} – ${d.end.toIso8601String().substring(0, 10)}'),
            ),
        h('Life areas'),
        ...areas.where((a) => a.title != 'Engine').map((a) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('${a.title}  (${a.confidence}/100)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: ink)),
                p(a.body),
              ],
            )),
        if (match != null) ...[
          h('Kundli matching'),
          p('Ashtakoota ${match.total.toStringAsFixed(1)} / ${match.max.toStringAsFixed(0)} — ${match.band}. Confidence ${match.confidence}/100.'),
          ...match.kootas.map((k) => p('${k.name}: ${k.obtained}/${k.max} — ${k.note}')),
          ...match.overlay.map(p),
          if (partner != null) p('Partner: ${partner.input.name}, ${partner.input.place.label}.'),
        ],
        if (qa.isNotEmpty) ...[
          h('Questions asked'),
          ...qa.map((e) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Q. ${e.q}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  p(e.a),
                ],
              )),
        ],
      ],
    ),
  );
  return doc.save();
}

pw.Widget _table(NatalChart chart, {required bool vedic}) {
  final headers = vedic
      ? ['Graha', 'Rashi', 'House', 'Nakshatra', 'Pada', 'Dignity']
      : ['Planet', 'Tropical', 'Sign', 'House', 'Aspects*'];
  final rows = <List<String>>[
    headers,
    ...chart.grahas.map((g) {
      if (vedic) {
        return [g.name, '${g.sign} ${formatDms(g.siderealLon)}', '${g.house}', g.nakshatra, '${g.pada}', g.dignity];
      }
      return [
        g.name,
        '${signOf(g.tropicalLon).name} ${formatDms(g.tropicalLon)}',
        signOf(g.tropicalLon).name,
        '${g.westernHouse}',
        '',
      ];
    }),
  ];
  return pw.TableHelper.fromTextArray(
    headers: rows.first,
    data: rows.skip(1).toList(),
    headerStyle: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold),
    headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1e3a5f)),
    cellStyle: const pw.TextStyle(fontSize: 8),
    cellAlignment: pw.Alignment.centerLeft,
  );
}
