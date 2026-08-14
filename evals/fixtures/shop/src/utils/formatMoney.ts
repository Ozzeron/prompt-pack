// Planted: D1 (duplicate implementation, see src/lib/money.ts)
export function formatMoney(cents: number, currency = 'USD'): string {
  const amount = (cents / 100).toFixed(2);
  return currency === 'USD' ? `$${amount}` : `${amount} ${currency}`;
}
