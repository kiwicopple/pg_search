import { createClient } from '@supabase/supabase-js'
import { Database } from '../supabase/database.types'

const supabase = createClient<Database>(
  process.env.SUPABASE_URL || '',
  process.env.SUPABASE_ANON_KEY || ''
)

test('content_checksum()', async () => {
  const { data, error } = await supabase.rpc('content_checksum', {
    content: 'hello world',
  })

  expect(data).toBe('5eb63bbbe01eeed093cb22bb8f5acdc3')
  expect(error).toBeNull()
})

test('upsert_context()', async () => {
  let random = (Math.random() + 1).toString(36)
  let id = `rand/${random}`
  // Insert and expect 201
  const insert = await supabase.rpc('upsert_context', {
    id,
    content: random,
    meta: { test: 'test' },
  })

  if (insert.error) {
    console.log('insert.error', insert.error)
  }

  expect(insert.status).toBe(201)
  expect(insert.data?.id).toBe(id)

  let insertedAt = insert.data?.updated_at

  // Unmodified should return 234
  const nochange = await supabase.rpc('upsert_context', {
    id,
    content: random,
    meta: { test: 'test' },
  })

  if (nochange.error) {
    console.log('nochange.error', nochange.error)
  }

  expect(nochange.status).toBe(234)
  expect(nochange.data?.updated_at).toBe(insertedAt)

  // Update and expect 200
  const updated = await supabase.rpc('upsert_context', {
    id,
    content: random + 'updated',
    meta: { test: 'test' },
  })

  if (updated.error) {
    console.log('updated.error', updated.error)
  }

  // expect(nochange.status).toBe(304)
  expect(updated.data?.id).toBe(id)
})
