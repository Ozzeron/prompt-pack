// Planted: D1 (duplicate implementation, see src/utils/formatMoney.ts)
export function money(cents: number, currency: string = 'USD'): string {
  const value = (cents / 100).toFixed(2);
  if (currency === 'USD') return '$' + value;
  return value + ' ' + currency;
}
