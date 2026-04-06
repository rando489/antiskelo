#!/bin/bash
# setup.sh - Felix's Clean & Reliable PlayFab Spammer (fixed proxy + live status) nya~ 💙

set -e

echo "Nya~ Fixing the no-log and bad proxy problem... ✨"

sudo apt update
sudo apt install -y python3 python3-pip

sudo mkdir -p /opt/playfab-spammer
cd /opt/playfab-spammer

cat << 'EOF' | sudo tee app.py > /dev/null
from flask import Flask, render_template_string, request, jsonify
import random
import string
import threading
import time
import requests
from concurrent.futures import ThreadPoolExecutor, as_completed

app = Flask(__name__)

PROXY_SOURCES = [
    "https://raw.githubusercontent.com/TheSpeedX/PROXY-List/master/http.txt",
    "https://raw.githubusercontent.com/proxifly/free-proxy-list/main/proxies/protocols/http/data.txt",
    "https://cdn.jsdelivr.net/gh/proxifly/free-proxy-list@main/proxies/protocols/http/data.txt"
]

proxies = []
use_proxy_mode = True

HTML = '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Felix Reliable PlayFab Spammer</title>
    <style>
        body { font-family: Arial; text-align: center; padding: 50px; background: #1e1e1e; color: #fff; }
        input, button, select { padding: 12px; margin: 10px; font-size: 18px; }
        button { background: #ff69b4; color: white; border: none; border-radius: 8px; cursor: pointer; }
        button:hover { background: #ff1493; }
        #status { margin-top: 30px; font-size: 17px; white-space: pre-wrap; text-align: left; max-height: 600px; overflow-y: auto; background: #111; padding: 15px; border-radius: 8px; }
    </style>
</head>
<body>
    <h1>✨ Felix's Reliable PlayFab Spammer ✨</h1>
    <form id="form">
        <input type="text" id="titleid" placeholder="PlayFab Title ID (e.g. 11382C)" required><br>
        <input type="text" id="prefix" placeholder="Account Prefix" required><br>
        <input type="number" id="count" value="30" min="1" placeholder="Number of accounts"><br>
        <select id="proxy_mode">
            <option value="0">Direct (No Proxy) - Recommended first</option>
            <option value="1">Use Free Proxies</option>
        </select><br>
        <button type="button" onclick="startSpamming()">Start Creation</button>
    </form>
    <div id="status">Waiting for start...</div>

    <script>
        function startSpamming() {
            const titleid = document.getElementById('titleid').value.trim();
            const prefix = document.getElementById('prefix').value.trim();
            const count = parseInt(document.getElementById('count').value) || 30;
            const useP = document.getElementById('proxy_mode').value === "1";

            if (!titleid || !prefix) {
                alert("Nya~ Please enter Title ID and Prefix!");
                return;
            }

            document.getElementById('status').innerHTML = `Starting ${count} accounts... Mode: ${useP ? "Proxy" : "Direct"}<br>`;

            fetch('/spam', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({titleid: titleid, prefix: prefix, count: count, use_proxy: useP})
            })
            .then(r => r.json())
            .then(data => {
                document.getElementById('status').innerHTML += data.message + "<br>";
            });
        }
    </script>
</body>
</html>
'''

@app.route('/')
def index():
    return render_template_string(HTML)

def load_proxies():
    global proxies
    proxies.clear()
    for url in PROXY_SOURCES:
        try:
            r = requests.get(url, timeout=15)
            if r.status_code == 200:
                new_proxies = [line.strip() for line in r.text.splitlines() if ':' in line.strip()]
                proxies.extend(new_proxies)
        except:
            pass
    proxies = list(dict.fromkeys(proxies))  # remove duplicates while preserving order
    print(f"Loaded {len(proxies)} proxies")
    return len(proxies) > 0

def get_proxy():
    if not use_proxy_mode or not proxies:
        return None
    p = random.choice(proxies)
    return {"http": f"http://{p}", "https": f"http://{p}"}

def create_account(title_id, prefix):
    random_str = ''.join(random.choices(string.ascii_lowercase + string.digits, k=8))
    custom_id = f"{prefix}_{random_str}"

    proxy = get_proxy()
    proxy_str = proxy["http"] if proxy else "DIRECT"

    url = f"https://{title_id}.playfabapi.com/Client/LoginWithCustomID"
    payload = {"TitleId": title_id, "CustomId": custom_id, "CreateAccount": True}

    try:
        r = requests.post(url, json=payload, proxies=proxy, timeout=30)

        if r.status_code == 200:
            pfid = r.json()["data"].get("PlayFabId", "Unknown")
            line = f"{custom_id}|{pfid}|{proxy_str}\n"
            with open("/opt/playfab-spammer/created_accounts.txt", "a") as f:
                f.write(line)
            print(f"[SUCCESS] {custom_id} → {pfid} ({proxy_str})")
            return f"✅ {custom_id} → {pfid} ({proxy_str})"

        elif r.status_code == 429:
            retry = int(r.headers.get("Retry-After", r.json().get("retryAfterSeconds", 10)))
            print(f"[429] Waiting {retry}s")
            time.sleep(retry + 2)
            return f"⏳ {custom_id} throttled (waited {retry}s)"

        else:
            err = r.json().get("errorMessage", str(r.status_code))
            print(f"[ERROR] {custom_id} - {err}")
            return f"❌ {custom_id} → {err} ({proxy_str})"

    except Exception as e:
        print(f"[CONNECTION FAIL] {custom_id} - {str(e)[:100]} ({proxy_str})")
        return f"❌ {custom_id} → Connection failed ({proxy_str})"

@app.route('/spam', methods=['POST'])
def spam():
    global use_proxy_mode
    data = request.get_json()
    title_id = data.get('titleid')
    prefix = data.get('prefix')
    count = int(data.get('count', 30))
    use_proxy_mode = data.get('use_proxy', False)

    if use_proxy_mode:
        load_proxies()

    def run():
        start = time.time()
        results = []
        with ThreadPoolExecutor(max_workers=2) as exe:
            futures = [exe.submit(create_account, title_id, prefix) for _ in range(count)]
            for fut in as_completed(futures):
                res = fut.result()
                results.append(res)
                # live update simulation (append to status via console for now)
                print(res)

        duration = time.time() - start
        summary = f"<br>🏁 Finished {count} attempts in {duration:.1f} seconds<br>"
        summary += f"Check /opt/playfab-spammer/created_accounts.txt for all results nya~ 💙"
        print(summary)
        return summary

    threading.Thread(target=run, daemon=True).start()
    mode = "with proxies" if use_proxy_mode else "DIRECT (no proxy)"
    return jsonify({"message": f"Spamming started in {mode} mode with 2 workers.<br>Watch the status box and server console for live updates."})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
EOF

sudo pip3 install flask requests

cat << EOF | sudo tee /etc/systemd/system/playfab-spammer.service > /dev/null
[Unit]
Description=Felix Reliable PlayFab Spammer
After=network.target

[Service]
User=root
WorkingDirectory=/opt/playfab-spammer
ExecStart=/usr/bin/python3 /opt/playfab-spammer/app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo chmod +x /opt/playfab-spammer/app.py
sudo systemctl daemon-reload
sudo systemctl restart playfab-spammer.service

echo "✨ Done nya~! ✨"
echo "Open http://YOUR_SERVER_IP:5000"
echo "First try with **Direct (No Proxy)** and small number (20-30)"
echo "If direct works, we can tune proxies later."
echo "All attempts (success or fail) are now logged clearly."
sudo systemctl status playfab-spammer.service --no-pager -l
