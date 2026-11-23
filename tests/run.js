// Loads the addon in TOC order inside fengari (a Lua VM in JavaScript) with a
// mocked WoW client, then runs a Lua test file.
// Usage: node run.js [addonRoot] [testFile]
const fs = require('fs'), path = require('path');
const { lua, lauxlib, lualib, to_luastring } = require('fengari');

const root = path.resolve(process.argv[2] || path.join(__dirname, '..'));
const testFile = path.resolve(process.argv[3] || path.join(__dirname, 'harness.lua'));
const toPosix = p => p.split('\\').join('/');

const files = [];
function addFile(rel, base) {
  const p = path.join(base, rel.split('\\').join('/'));
  if (p.endsWith('.xml')) {
    const x = fs.readFileSync(p, 'utf8').replace(/<!--[\s\S]*?-->/g, '');
    for (const m of x.matchAll(/(?:Script|Include)\s+file="([^"]+)"/g)) addFile(m[1], path.dirname(p));
  } else files.push(toPosix(p));
}
const toc = fs.readFileSync(path.join(root, 'WorkoutBuddy.toc'), 'utf8')
  .split(/\r?\n/).filter(l => l.trim() && !l.startsWith('#'));
for (const l of toc) addFile(l.trim(), root);

const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
lua.lua_newtable(L);
files.forEach((f, i) => { lua.lua_pushstring(L, to_luastring(f)); lua.lua_rawseti(L, -2, i + 1); });
lua.lua_setglobal(L, to_luastring('ADDON_FILES'));
lua.lua_pushstring(L, to_luastring(toPosix(path.join(__dirname, 'harness.lua'))));
lua.lua_setglobal(L, to_luastring('HARNESS'));

if (lauxlib.luaL_dofile(L, to_luastring(toPosix(testFile))) !== lua.LUA_OK) {
  console.log('LUA ERROR:', lua.lua_tojsstring(L, -1));
  process.exit(1);
}
lua.lua_getglobal(L, to_luastring('TEST_FAILURES'));
const failures = lua.lua_tonumber(L, -1);
process.exit(failures > 0 ? 1 : 0);
