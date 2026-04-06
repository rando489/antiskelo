#!/bin/bash
# setup.sh - Felix's Proxy Spammer for Crusch nya~ 💙 (with --break-system-packages)

set -e

echo "Nya~ Installing with --break-system-packages for Miss Crusch... ✨"

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
    "https://cdn.jsdelivr.net/gh/proxifly/free-proxy-list@main/proxies/protocols/http/data.txt",
    "https://raw.githubusercontent.com/TheSpeedX/PROXY-List/master/http.txt",
    "https://raw.githubusercontent.com/proxifly/free-proxy-list/main/proxies/protocols/http/data.txt"
]

working_proxies = []
use_proxy_mode = True

HTML = '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Felix Proxy Spammer - For Crusch</title>
    <style>
        body { font-family: Arial; text-align: center; padding: 50px; background: #1e1e1e; color: #fff; }
        input, button, select { padding: 12px; margin: 10px; font-size: 18px; }
        button { background: #ff69b4; color: white; border: none; border-radius: 8px; cursor: pointer; }
        button:hover { background: #ff1493; }
        #status { margin-top: 30px; text-align: left; background: #111; padding: 20px; border-radius: 8px; max-height: 650px; overflow-y: auto; font-size: 16px; white-space: pre-wrap; }
    </style>
</head>
<body>
    <h1>✨ Felix Proxy Spammer for Crusch ✨</h1>
    <form id="form">
        <input type="text" id="titleid" placeholder="PlayFab Title ID" required><br>
        <input type="text" id="prefix" placeholder="Account Prefix" required><br>
        <input type="number" id="count" value="30" min="1"><br>
        <select id="mode">
            <option value="1">Use Free Proxies (Crusch mode)</option>
            <option value="0">Direct (No Proxy)</option>
        </select><br>
        <button type="button" onclick="startSpamming()">🚀 Start Spamming</button>
    </form>
    <div id="status">Waiting for Crusch's command nya~</div>

    <script>
        function startSpamming() {
            const titleid = document.getElementById('titleid').value.trim();
            const prefix = document.getElementById('prefix').value.trim();
            const count = parseInt(document.getElementById('count').value) || 30;
            const useProxy = document.getElementById('mode').value === "1";

            if (!titleid || !prefix) {
                alert("Nya~ Please fill Title ID and Prefix!");
                return;
            }

            document.getElementById('status').innerHTML = `Crusch mode activated. Starting ${count} accounts...<br>Mode: ${useProxy ? "Proxy" : "Direct"}<br>`;

            fetch('/spam', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({titleid: titleid, prefix: prefix, count: count, use_proxy: useProxy})
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

def load_and_validate_proxies():
    global working_proxies
    working_proxies = []
    print("Loading fresh proxy lists for Crusch...")

    for url in PROXY_SOURCES:
        try:
            r = requests.get(url, timeout=15)
            if r.status_code == 200:
                candidates = [line.strip() for line in r.text.splitlines() if line.strip() and ':' in line]
                for p in candidates[:150]:   # limit to avoid too long validation
                    proxy_dict = {"http": f"http://{p}", "https": f"http://{p}"}
                    try:
                        test = requests.get("https://httpbin.org/ip", proxies=proxy_dict, timeout=8)
                        if test.status_code == 200:
                            working_proxies.append(p)
                            print(f"✅ Valid proxy: {p}")
                            if len(working_proxies) >= 80:  # cap at 80 good ones
                                break
                    except:
                        continue
                if len(working_proxies) >= 80:
                    break
        except:
            continue

    print(f"Crusch has {len(working_proxies)} working proxies ready nya~")
    return len(working_proxies) > 0

def get_proxy():
    if not use_proxy_mode or not working_proxies:
        return None
    p = random.choice(working_proxies)
    return {"http": f"http://{p}", "https": f"http://{p}"}

def create_account(title_id, prefix):
    random_str = ''.join(random.choices(string.ascii_lowercase + string.digits, k=8))
    custom_id = f"{prefix}_{random_str}"

    proxy = get_proxy()
    proxy_str = proxy["http"] if proxy else "DIRECT"

    url = f"https://{title_id}.playfabapi.com/Client/LoginWithCustomID"
    payload = {"TitleId": title_id, "CustomId": custom_id, "CreateAccount": True}

    try:
        r = requests.post(url, json=payload, proxies=proxy, timeout=25)

        if r.status_code == 200:
            pfid = r.json().get("data", {}).get("PlayFabId", "Unknown")
            with open("/opt/playfab-spammer/created_accounts.txt", "a") as f:
                f.write(f"{custom_id}|{pfid}|{proxy_str}\n")
            print(f"[SUCCESS] {custom_id} → {pfid} ({proxy_str})")
            return f"✅ {custom_id} → {pfid}<br>"
        elif r.status_code == 429:
            retry = int(r.headers.get("Retry-After", 12))
            time.sleep(retry + 3)
            return f"⏳ {custom_id} throttled<br>"
        else:
            err = r.json().get("errorMessage", str(r.status_code))
            return f"❌ {custom_id} → {err}<br>"
    except Exception as e:
        print(f"[FAIL] {custom_id} - {str(e)[:80]} ({proxy_str})")
        return f"❌ {custom_id} → Connection failed ({proxy_str})<br>"

@app.route('/spam', methods=['POST'])
def spam():
    global use_proxy_mode
    data = request.get_json()
    title_id = data.get('titleid')
    prefix = data.get('prefix')
    count = int(data.get('count', 30))
    use_proxy_mode = data.get('use_proxy', True)

    if use_proxy_mode:
        load_and_validate_proxies()

    def run_spam():
        start_time = time.time()
        results = []
        with ThreadPoolExecutor(max_workers=2) as executor:
            futures = [executor.submit(create_account, title_id, prefix) for _ in range(count)]
            for future in as_completed(futures):
                results.append(future.result())

        duration = time.time() - start_time
        summary = "".join(results)
        summary += f"<br><br>🏁 Finished {count} attempts in {duration:.1f} seconds nya~ 💙<br>"
        summary += "Check created_accounts.txt for saved accounts"
        print(summary.replace("<br>", "\n"))
        return summary

    threading.Thread(target=run_spam, daemon=True).start()
    mode = "Proxy mode (Crusch special)" if use_proxy_mode else "Direct mode"
    return jsonify({"message": f"Started in {mode} with 2 workers.<br>Live results below."})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
EOF

# Install with the flag Crusch requested
sudo pip3 install flask requests --break-system-packages

cat << EOF | sudo tee /etc/systemd/system/playfab-spammer.service > /dev/null
[Unit]
Description=Felix Proxy Spammer for Crusch
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

echo "✨ Done nya~! Installed with --break-system-packages as Crusch asked ✨"
echo "Open: http://YOUR_SERVER_IP:5000"
echo "Choose 'Use Free Proxies (Crusch mode)'"
echo "Start with small count (20-30) first"
echo "Felix will validate proxies before using them"
sudo systemctl status playfab-spammer.service --no-pager -l
