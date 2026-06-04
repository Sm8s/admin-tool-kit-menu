const fs = require('fs');
const path = require('path');

const reportsDir = path.join(__dirname, 'reports');
const files = fs.existsSync(reportsDir)
  ? fs.readdirSync(reportsDir).filter(f => f.endsWith('.txt') || f.endsWith('.csv') || f.endsWith('.json'))
  : [];

if (!files.length) {
  console.log('Keine Reports gefunden.');
  process.exit(0);
}

console.log('Gefundene Reports:');
files.sort().forEach((file, i) => console.log(`${i + 1}. ${file}`));