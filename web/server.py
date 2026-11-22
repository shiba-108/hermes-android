#!/usr/bin/env python3
"""
Minimal self-hosted web chat for Hermes (Tailscale, port 3000).

No tmux. Started with nohup, kept alive by the watchdog.

It is a thin bridge: it exposes a small HTTP UI + a WebSocket-free JSON poll
API that forwards messages to the local Hermes gateway via its Unix socket
(`$HERMES_HOME/gateway.sock`) using the Hermes CLI. No external deps beyond the
Python stdlib, so it runs inside the same venv as the gateway.

Usage:
    HERMES_HOME=/data/local/hermes-home python3 web/server.py [--port 3000]

Security: this UI has no authentication. Non-root defaults to loopback; root
keeps the existing 0.0.0.0 default for compatibility. Prefer loopback plus
Tailscale Serve for private remote access; do not expose it directly to the Internet.
"""
import argparse
import json
import os
import subprocess
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HERMES_HOME = os.environ.get("HERMES_HOME", "/data/local/hermes-home")
HERMES_VENV = os.environ.get("HERMES_VENV") or os.path.join(HERMES_HOME, "..", "hermes-venv")
BIN = os.path.abspath(os.path.join(HERMES_VENV, "bin", "hermes"))
LOG_PATH = os.path.join(HERMES_HOME, "logs", "webui.log")

INDEX_HTML = """<!doctype html>
<html lang="vi">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>Hermes · Web Chat</title>
<style>
  :root { color-scheme: dark; }
  * { box-sizing: border-box; }
  body { margin:0; font-family: system-ui,-apple-system,sans-serif;
         background:#0e1116; color:#e6edf3; height:100vh; display:flex;
         flex-direction:column; }
  header { padding:14px 18px; border-bottom:1px solid #21262d;
           font-weight:600; display:flex; align-items:center; gap:10px; }
  header .dot { width:10px;height:10px;border-radius:50%;background:#3fb950; }
  #chat { flex:1; overflow-y:auto; padding:18px; display:flex;
          flex-direction:column; gap:12px; }
  .msg { max-width:78%; padding:10px 14px; border-radius:14px; white-space:
         pre-wrap; word-wrap:break-word; line-height:1.45; }
  .msg.user { align-self:flex-end; background:#2f81f7; color:#fff;
              border-bottom-right-radius:4px; }
  .msg.bot  { align-self:flex-start; background:#1c2128; border:1px solid #30363d;
              border-bottom-left-radius:4px; }
  form { display:flex; gap:10px; padding:14px 18px; border-top:1px solid #21262d; }
  input { flex:1; padding:12px 14px; border-radius:12px; border:1px solid #30363d;
          background:#0d1117; color:#e6edf3; font-size:15px; }
  button { padding:12px 20px; border-radius:12px; border:0; background:#2f81f7;
           color:#fff; font-weight:600; cursor:pointer; }
  button:disabled { opacity:.5; cursor:default; }
</style>
</head>
<body>
<header><span class="dot" id="dot"></span> Hermes <span id="status"
       style="font-weight:400;color:#8b949e">· connecting…</span></header>
<div id="chat"></div>
<form id="f"><input id="i" placeholder="Nhắn cho Hermes…" autocomplete="off"/>
     <button id="b" type="submit">Gửi</button></form>
<script>
const chat=document.getElementById('chat'),f=document.getElementById('f'),
      i=document.getElementById('i'),b=document.getElementById('b'),
      statusEl=document.getElementById('status'),dot=document.getElementById('dot');
let busy=false;
function add(who,text){
  const d=document.createElement('div');
  d.className='msg '+(who==='user'?'user':'bot');
  d.textContent=text; chat.appendChild(d); chat.scrollTop=chat.scrollHeight;
}
async function ping(){
  try{const r=await fetch('/api/ping');const j=await r.json();
    if(j.ok){dot.style.background='#3fb950';
      statusEl.textContent='· online · '+j.model;}
    else{dot.style.background='#f85149';statusEl.textContent='· gateway down';}
  }catch(e){dot.style.background='#f85149';statusEl.textContent='· offline';}
}
f.addEventListener('submit',async e=>{
  e.preventDefault(); const text=i.value.trim(); if(!text||busy)return;
  busy=true;b.disabled=true;i.value='';add('user',text);
  add('bot','…');
  try{
    const r=await fetch('/api/send',{method:'POST',
      headers:{'Content-Type':'application/json'},
      body:JSON.stringify({message:text})});
    const j=await r.json();
    chat.lastChild.textContent=j.reply||('Lỗi: '+(j.error||'không rõ'));
  }catch(err){chat.lastChild.textContent='Lỗi kết nối: '+err;}
  busy=false;b.disabled=false;i.focus();ping();
});
ping(); setInterval(ping,15000);
</script>
</body></html>"""


def gateway_reply(message: str) -> str:
    """Forward a message to the gateway via the hermes CLI (one-shot)."""
    try:
        out = subprocess.run(
            [BIN, "run", "--message", message],
            capture_output=True, text=True, timeout=300,
            env={**os.environ, "HERMES_HOME": HERMES_HOME},
        )
        if out.returncode == 0:
            return out.stdout.strip() or "(no output)"
        return (out.stderr.strip() or out.stdout.strip())[:2000] or "error"
    except subprocess.TimeoutExpired:
        return "Timeout: gateway không trả lời sau 300s."
    except Exception as e:  # noqa: BLE001
        return f"Lỗi gọi gateway: {e}"


def gateway_status() -> dict:
    sock = os.path.join(HERMES_HOME, "gateway.sock")
    ok = os.path.exists(sock)
    model = "?"
    try:
        cfg = open(os.path.join(HERMES_HOME, "config.yaml")).read()
        for line in cfg.splitlines():
            if "default:" in line and "model" in cfg:
                model = line.split("default:")[1].strip()
                break
    except Exception:  # noqa: BLE001
        pass
    return {"ok": ok, "model": model}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):  # route to file, keep stdout clean
        try:
            os.makedirs(os.path.dirname(LOG_PATH), exist_ok=True)
            with open(LOG_PATH, "a") as fh:
                fh.write("%s - %s\n" % (time.strftime("%F %T"), fmt % args))
        except Exception:  # noqa: BLE001
            pass

    def _send(self, code, body, ctype="application/json"):
        if isinstance(body, (dict, list)):
            body = json.dumps(body, ensure_ascii=False)
        data = body.encode("utf-8") if isinstance(body, str) else body
        self.send_response(code)
        self.send_header("Content-Type", ctype + "; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):  # noqa: N802
        if self.path in ("/", "/index.html"):
            self._send(200, INDEX_HTML, "text/html")
        elif self.path == "/api/ping":
            self._send(200, gateway_status())
        else:
            self._send(404, {"error": "not found"})

    def do_POST(self):  # noqa: N802
        if self.path != "/api/send":
            self._send(404, {"error": "not found"})
            return
        n = int(self.headers.get("Content-Length", 0))
        try:
            payload = json.loads(self.rfile.read(n) or b"{}")
        except Exception:  # noqa: BLE001
            payload = {}
        msg = (payload.get("message") or "").strip()
        if not msg:
            self._send(400, {"error": "empty message"})
            return
        self._send(200, {"reply": gateway_reply(msg)})


def default_host():
    """Keep the unauthenticated UI local for non-root; preserve root behavior."""
    return "0.0.0.0" if os.geteuid() == 0 else "127.0.0.1"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=3000)
    ap.add_argument("--host", default=default_host())
    args = ap.parse_args()
    os.makedirs(os.path.dirname(LOG_PATH), exist_ok=True)
    srv = ThreadingHTTPServer((args.host, args.port), Handler)
    print(f"Hermes web UI on http://{args.host}:{args.port} "
          f"(gateway sock: {os.path.join(HERMES_HOME,'gateway.sock')})")
    sys.stdout.flush()
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
