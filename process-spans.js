const fs = require('fs')
const path = require('path')
const crypto = require('crypto')

const sitePrefix = 'docs.example.com'
const outputFilePath = `documents.json`
const FOLDER_PATH = path.resolve(__dirname, './example/docs')
var documents = []

function createMD5Checksum(data) {
  const hash = crypto.createHash('md5')
  hash.update(data)
  return hash.digest('hex')
}

function processFile(filePath) {
  const content = fs.readFileSync(filePath, 'utf8')
  const spans = content
    .match(/^.*(?:\r?\n(?!\s*(#{1,3})\s).*)*/gm) // Splits on Markdown headings (lines beginning with '# ', '## ', etc.)
    .filter((span) => span.length > 0) // Removes empty spans
    .map((span) => ({ content: span }))

  documents.push({
    id: `${sitePrefix}${filePath.replace(FOLDER_PATH, '')}`,
    checksum: createMD5Checksum(content),
    spans,
  })
}

function processFolder(folderPath) {
  const items = fs.readdirSync(folderPath)

  items.forEach((item) => {
    const itemPath = path.join(folderPath, item)
    const stat = fs.statSync(itemPath)

    if (stat.isDirectory()) {
      processFolder(itemPath) // Recurse into subdirectories
    } else if (stat.isFile() && /\.mdx?$/.test(itemPath)) {
      processFile(itemPath) // Process .md/.mdx files
    }
  })

  fs.writeFileSync(outputFilePath, JSON.stringify(documents, null, 2), 'utf8')
}

processFolder(FOLDER_PATH)
