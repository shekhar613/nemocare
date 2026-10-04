/**
 * Evidence fingerprint: finding keys + rounded value + date per supporting lab row.
 * Must stay compatible with Flutter InsightsService.computeFingerprint.
 *
 * Example:
 * low_hemoglobin[hemoglobin:10.50:2026-09-28]|microcytic_pattern[mcv:81.00:2026-09-14,mch:26.40:2026-09-14]
 */

function fingerprintValue(raw) {
  if (raw == null) return '';
  if (typeof raw === 'number' && Number.isFinite(raw)) {
    return raw.toFixed(2);
  }
  const parsed = Number(String(raw).trim());
  if (Number.isFinite(parsed) && String(raw).trim() !== '') {
    return parsed.toFixed(2);
  }
  return String(raw).trim();
}

/**
 * @param {{ activeFindings: Array<{ key: string }>, supportingValues: Record<string, Array<Record<string, unknown>>> }} ctx
 */
export function computeFingerprint(ctx) {
  const findings = [...(ctx.activeFindings || [])].sort((a, b) =>
    String(a.key).localeCompare(String(b.key)),
  );
  if (findings.length === 0) return '';

  const parts = [];
  for (const finding of findings) {
    const values = [...(ctx.supportingValues?.[finding.key] || [])].sort(
      (a, b) => {
        const byKey = String(a.parameterKey || '').localeCompare(
          String(b.parameterKey || ''),
        );
        if (byKey !== 0) return byKey;
        return String(a.date || '').localeCompare(String(b.date || ''));
      },
    );

    const valuePart = values
      .map((v) => {
        const key = String(v.parameterKey || '').trim();
        const date = String(v.date || '').trim();
        const value = fingerprintValue(v.value);
        return `${key}:${value}:${date}`;
      })
      .join(',');

    parts.push(`${finding.key}[${valuePart}]`);
  }
  return parts.join('|');
}
