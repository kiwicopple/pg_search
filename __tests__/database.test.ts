import { createClient } from '@supabase/supabase-js'
import { Database } from '../supabase/database.types'

const supabase = createClient<Database>(
  process.env.SUPABASE_URL || '',
  process.env.SUPABASE_ANON_KEY || ''
)

const markdown = `
import Layout from '~/layouts/DefaultGuideLayout'

export const meta = {
  id: 'database',
  title: 'Database',
  description: 'Use Supabase to manage your data.',
  sidebar_label: 'Overview',
}

Every Supabase project comes with a full [Postgres](https://www.postgresql.org/) database, a free and open source
database which is considered one of the world's most stable and advanced databases.

## Postgres or PostgreSQL?

PostgreSQL the database was derived from the POSTGRES Project, a package written at the University of California at Berkeley in 1986.
This package included a query language called "PostQUEL".

In 1994, Postgres95 was built on top of POSTGRES code, adding an SQL language interpreter as a replacement for PostQUEL.
Eventually, Postgres95 was renamed to PostgreSQL to reflect the SQL query capability.

After this, many people referred to it as Postgres since it's less prone to confusion. Supabase is all about
simplicity, so we also refer to it as Postgres.

## Features

### Table View

You don't have to be a database expert to start using Supabase. Our table view makes Postgres as easy to use as a spreadsheet.

![Table View.](/docs/img/table-view.png)

### Relationships

Dig into the relationships within your data.

<video width="99%" loop="" muted="" playsInline="" controls="true">
  <source
    src="https://xguihxuzqibwxjnimxev.supabase.co/storage/v1/object/public/videos/docs/relational-drilldown-zoom.mp4"
    type="video/mp4"
  />
</video>

### Clone tables

You can duplicate your tables, just like you would inside a spreadsheet.

<video width="99%" muted playsInline controls={true}>
  <source
    src="https://xguihxuzqibwxjnimxev.supabase.co/storage/v1/object/public/videos/docs/duplicate-tables.mp4"
    type="video/mp4"
    muted
    playsInline
  />
</video>

### The SQL Editor

Supabase comes with a SQL Editor. You can also save your favorite queries to run later!

<video width="99%" muted playsInline controls={true}>
  <source
    src="https://xguihxuzqibwxjnimxev.supabase.co/storage/v1/object/public/videos/docs/favorites.mp4"
    type="video/mp4"
    muted
    playsInline
  />
</video>

### Additional features

- Supabase extends Postgres with realtime functionality using our [Realtime Server](https://github.com/supabase/realtime).
- Every project is a full Postgres database, with \`postgres\` level access.
- Supabase manages your database backups.
- Import data directly from a CSV or excel spreadsheet.

<Admonition type="note">

Database backups **do not** include objects stored via the Storage API, as the database only
includes metadata about these objects. Restoring an old backup does not restore objects that have
been deleted since then.

</Admonition>

### Extensions

To expand the functionality of your Postgres database, you can use extensions.
You can enable Postgres extensions with the click of a button within the Supabase dashboard.

<video width="99%" muted playsInline controls={true}>
  <source
    src="https://xguihxuzqibwxjnimxev.supabase.co/storage/v1/object/public/videos/docs/toggle-extensions.mp4"
    type="video/mp4"
    muted
    playsInline
  />
</video>

[Learn more](/docs/guides/database/extensions) about all the extensions provided on Supabase.

## Tips

Read about resetting your database password [here](/docs/guides/database/managing-passwords) and changing the timezone of your server [here](/docs/guides/database/managing-timezones).

## Next steps

- Read more about [Postgres](https://www.postgresql.org/about/)
- Sign in: [app.supabase.com](https://app.supabase.com)

export const Page = ({ children }) => <Layout meta={meta} children={children} />

export default Page

`.trim()

type Document = Database['public']['Tables']['documents']['Row']
type UpsertableDocument = Pick<Document, 'context_id' | 'content' | 'meta'>
const random = (Math.random() + 1).toString(36)
const id = `rand/${random}`
let sections: UpsertableDocument[] = []

beforeAll(async () => {
  const chunks = await supabase.rpc('chunks', {
    content: markdown,
    delimiter: '###',
  })
  sections =
    chunks.data?.map((chunk: string) => ({
      context_id: id,
      content: chunk,
      meta: { test: 'test' },
    })) || []
})

test('content_checksum()', async () => {
  const { data, error } = await supabase.rpc('content_checksum', {
    content: 'hello world',
  })

  expect(data).toBe('5eb63bbbe01eeed093cb22bb8f5acdc3')
  expect(error).toBeNull()
})

test('chunks()', async () => {
  const { data, error } = await supabase.rpc('chunks', {
    content: markdown,
    delimiter: '###',
  })

  expect(data?.length).toEqual(7)
  expect(error).toBeNull()
  if (!!data) {
    expect(data[1].substring(0, 14)).toEqual('### Table View')
  }
})

test('upsert_context()', async () => {
  // Insert and expect 201
  const insert = await supabase.rpc('upsert_context', {
    id,
    content: random,
    meta: { test: 'test' },
    documents: sections,
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
    documents: sections,
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
    documents: sections,
  })

  if (updated.error) {
    console.log('updated.error', updated.error)
  }

  // expect(nochange.status).toBe(304)
  expect(updated.data?.id).toBe(id)
})

it('should return documents that match the query', async () => {
  const query = 'tables'

  const results = await supabase.rpc('text_search', {
    query,
  })

  console.log('results', results)

  expect(results.data).toHaveLength(2)
  results.data && expect(results.data[0].context_id).toEqual(id)
})
