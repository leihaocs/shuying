import 'dart:convert';
import 'dart:typed_data';

/// 已压缩的 RGB 页面，图像内含系统字体渲染的中文，不额外捆绑字体。
class ReportPdfPage {
  const ReportPdfPage(this.width, this.height, this.compressedRgb);
  final int width, height;
  final Uint8List compressedRgb;
}

/// 用少量标准 PDF 对象封装已分页的报告图片，保留独立的文字复制入口。
Uint8List reportPdf(List<ReportPdfPage> pages) {
  if (pages.isEmpty) throw ArgumentError('报告不能为空');
  final output = BytesBuilder(copy: false);
  final offsets = <int>[0];
  void text(String value) => output.add(latin1.encode(value));
  void object(int id, String value, [List<int>? stream]) {
    offsets.add(output.length);
    text('$id 0 obj\n$value');
    if (stream != null) {
      text('\nstream\n');
      output.add(stream);
      text('\nendstream');
    }
    text('\nendobj\n');
  }

  text('%PDF-1.4\n');
  output.add([37, 226, 227, 207, 211, 10]);
  object(1, '<< /Type /Catalog /Pages 2 0 R >>');
  final kids = [for (var i = 0; i < pages.length; i++) '${3 + i * 3} 0 R'];
  object(
      2, '<< /Type /Pages /Kids [${kids.join(' ')}] /Count ${pages.length} >>');
  for (var i = 0; i < pages.length; i++) {
    final page = pages[i];
    if (page.width <= 0 || page.height <= 0 || page.compressedRgb.isEmpty) {
      throw ArgumentError('报告图片无效');
    }
    final id = 3 + i * 3;
    object(
        id,
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] '
        '/Resources << /XObject << /Im$i ${id + 2} 0 R >> >> '
        '/Contents ${id + 1} 0 R >>');
    final content = latin1.encode('q\n595 0 0 842 0 0 cm\n/Im$i Do\nQ\n');
    object(id + 1, '<< /Length ${content.length} >>', content);
    object(
        id + 2,
        '<< /Type /XObject /Subtype /Image /Width ${page.width} '
        '/Height ${page.height} /ColorSpace /DeviceRGB /BitsPerComponent 8 '
        '/Filter /FlateDecode /Length ${page.compressedRgb.length} >>',
        page.compressedRgb);
  }
  final xref = output.length;
  text('xref\n0 ${offsets.length}\n0000000000 65535 f \n');
  for (final offset in offsets.skip(1)) {
    text('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  text('trailer\n<< /Size ${offsets.length} /Root 1 0 R >>\n'
      'startxref\n$xref\n%%EOF\n');
  return output.takeBytes();
}
