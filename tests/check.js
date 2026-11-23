// Lua 5.1 syntax check of every .lua file, and a check that every file the TOC loads exists.
const fs = require('fs'), path = require('path'), lp = require('luaparse');
const root = path.resolve(process.argv[2] || path.join(__dirname, '..'));
let bad = 0, n = 0;
function walk(d) {
  for (const f of fs.readdirSync(d)) {
    const p = path.join(d, f);
    if (fs.statSync(p).isDirectory()) { if (!['.git', 'node_modules', 'tests'].includes(f)) walk(p); }
    else if (f.endsWith('.lua')) {
      n++;
      const src = fs.readFileSync(p, 'utf8');
      try { lp.parse(src, { luaVersion: '5.1' }); }
      catch (e) { bad++; console.log('SYNTAX', path.relative(root, p), e.message); }
      // Lua 5.1 silently drops the backslash of an unknown escape ("Interface\Icons"
      // becomes "InterfaceIcons"), so texture paths break without an error.
      if (!path.relative(root, p).startsWith('Libs')) {
        src.split(/\r?\n/).forEach((line, i) => {
          if (line.trim().startsWith('--')) return;
          for (let j = 0; j < line.length - 1; j++) {
            if (line[j] !== '\\') continue;
            if (!'\\nrtabfv"\'0123456789'.includes(line[j + 1])) {
              bad++; console.log('ESCAPE', `${path.relative(root, p)}:${i + 1}`, line.trim().slice(0, 80));
            }
            j++;
          }
        });
      }
    }
  }
}
walk(root);
const toc = fs.readFileSync(path.join(root, 'WorkoutBuddy.toc'), 'utf8').split(/\r?\n/).filter(l => l.trim() && !l.startsWith('#'));
function checkFile(rel, base) {
  const p = path.join(base, rel.split('\\').join('/'));
  if (!fs.existsSync(p)) { bad++; console.log('MISSING', p); return; }
  if (p.endsWith('.xml')) {
    const x = fs.readFileSync(p, 'utf8').replace(/<!--[\s\S]*?-->/g, '');
    for (const m of x.matchAll(/(?:Script|Include)\s+file="([^"]+)"/g)) checkFile(m[1], path.dirname(p));
  }
}
for (const l of toc) checkFile(l.trim(), root);
console.log(`${n} lua files parsed, ${toc.length} toc entries, problems: ${bad}`);
process.exit(bad ? 1 : 0);
