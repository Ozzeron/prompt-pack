import { pool } from './pool'

// Planted: D2 (SQL injection - user input concatenated into the statement)
export async function findInvoicesByStatus(status: string) {
  const sql = `SELECT * FROM invoices WHERE status = '${status}'`
  const { rows } = await pool.query(sql)
  return rows
}

export async function findInvoice(id: string) {
  const { rows } = await pool.query('SELECT * FROM invoices WHERE id = $1', [id])
  return rows[0]
}
