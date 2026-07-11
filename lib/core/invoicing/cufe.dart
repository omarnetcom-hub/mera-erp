import 'dart:convert';

/// Computes the canonical CUFE used by MerkaERP for DIAN-related operations.
///
/// The function mirrors the algorithm that was canonicalized from
/// `lib/facturacion_electronica_page.dart`:
///   1. Build a raw string with the fields in the exact order:
///      'Venta:{ventaId}|Total:{total}|Fecha:{fechaIso}|PIN:{pin}'
///   2. UTF-8 encode the raw string and base64-encode the bytes.
///   3. Remove any '=' padding characters from the base64 string and
///      convert to lowercase.
///   4. Append the suffix 'fe2026dian'.
///
/// Inputs:
/// - ventaId: numeric id of the sale
/// - total: numeric total amount (use same numeric formatting as the callers)
/// - fechaIso: ISO-8601 datetime string (full, e.g. DateTime.toIso8601String())
/// - pin: the technical PIN (must be the persisted value from app_config)
///
/// Returns: the canonical CUFE string.
String computeCufe({
  required int ventaId,
  required double total,
  required String fechaIso,
  required String pin,
}) {
  // Normalize the fechaIso to seconds precision (truncate milliseconds) so all call sites
  // produce the same canonical CUFE regardless of how they serialized the DateTime.
  String fechaCanonical;
  try {
    final dt = DateTime.parse(fechaIso);
    final dtSec = DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second);
    fechaCanonical = dtSec.toIso8601String();
  } catch (e) {
    // If parsing fails, fall back to the input string (best-effort). This keeps behavior
    // predictable rather than throwing during CUFE computation for malformed inputs.
    fechaCanonical = fechaIso;
  }

  final totalCanonical = total.toStringAsFixed(2);
  final raw = 'Venta:$ventaId|Total:$totalCanonical|Fecha:$fechaCanonical|PIN:$pin';
  final encoded = base64Encode(utf8.encode(raw)).replaceAll('=', '').toLowerCase();
  return '${encoded}fe2026dian';
}
