/// Helpers the core tests share.
library;

/// `한글` written as the jamo a macOS file name carries, which is what the
/// JavaScript tests get from `'한글'.normalize('NFD')`.
final String decomposedHangul = String.fromCharCodes(<int>[
  0x1112,
  0x1161,
  0x11ab,
  0x1100,
  0x1173,
  0x11af,
]);

/// `é` written as `e` and a combining acute accent.
final String decomposedAcute = 'e${String.fromCharCode(0x0301)}';
