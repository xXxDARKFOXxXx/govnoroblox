import { spawn } from 'node:child_process';
import fs from 'node:fs';
const exe = 'C:/Users/frumpers/AppData/Local/Roblox/Versions/version-67c8b1dedbb74fed/StudioMCP.exe';
const proc = spawn(exe, ['--stdio'], { windowsHide: true, stdio: ['pipe', 'pipe', 'pipe'] });
let nextId = 0, buffer = '';
const pending = new Map();
const timer = setTimeout(() => { console.error('Studio MCP request timed out'); proc.kill(); process.exitCode = 2; }, 45000);
proc.stdout.on('data', data => {
  buffer += data;
  let end;
  while ((end = buffer.indexOf('\n')) >= 0) {
    const line = buffer.slice(0, end); buffer = buffer.slice(end + 1);
    if (!line.trim()) continue;
    try { const msg = JSON.parse(line); if (pending.has(msg.id)) { pending.get(msg.id)(msg); pending.delete(msg.id); } } catch {}
  }
});
const request = (method, params) => new Promise(resolve => {
  const id = ++nextId; pending.set(id, resolve);
  proc.stdin.write(JSON.stringify({jsonrpc:'2.0', id, method, params}) + '\n');
});
try {
  const init = await request('initialize', {protocolVersion:'2024-11-05', capabilities:{}, clientInfo:{name:'OceanHUDLocalCheck',version:'1.0.0'}});
  if (init.error) throw new Error(JSON.stringify(init.error));
  proc.stdin.write(JSON.stringify({jsonrpc:'2.0',method:'notifications/initialized'}) + '\n');
  const arg = process.argv[2];
  const result = arg ? await request('tools/call', JSON.parse(fs.readFileSync(arg, 'utf8'))) : await request('tools/list', {});
  console.log(JSON.stringify(result, null, 2));
} finally { clearTimeout(timer); proc.kill(); }
