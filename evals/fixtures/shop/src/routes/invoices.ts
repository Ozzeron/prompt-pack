import { Router } from 'express'
import { findInvoice } from '../db/queries'
import { pool } from '../db/pool'

export const invoices = Router()

invoices.get('/invoices/:id', async (req, res) => {
  const invoice = await findInvoice(req.params.id)
  if (!invoice) return res.status(404).json({ error: 'not found' })
  if (invoice.user_id !== req.user!.id) return res.status(403).json({ error: 'forbidden' })
  res.json(invoice)
})

// Planted: D3 (no ownership check - any authenticated user can delete any invoice;
// the sibling GET handler above does check, which is what makes it a review finding)
invoices.delete('/invoices/:id', async (req, res) => {
  await pool.query('DELETE FROM invoices WHERE id = $1', [req.params.id])
  res.status(204).end()
})
