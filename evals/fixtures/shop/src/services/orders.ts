import { pool } from '../db/pool'

// Planted: D4 (N+1 - one query per order inside the loop instead of a single join)
export async function ordersWithItems(userId: string) {
  const { rows: orders } = await pool.query('SELECT * FROM orders WHERE user_id = $1', [userId])
  for (const order of orders) {
    const { rows: items } = await pool.query('SELECT * FROM order_items WHERE order_id = $1', [order.id])
    order.items = items
  }
  return orders
}
