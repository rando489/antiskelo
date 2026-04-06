#!/bin/bash
# setup.sh - Felix's FIXED PlayFab Spammer with Better Proxy Rotation nya~ 💙

set -e

echo "Nya~ Fixing the proxy issues so we stop getting connection BOOM... ✨"

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

# Better proxy sources (fresher lists)
PROXY_SOURCES = [
    "https://raw.githubusercontent.com/TheSpeedX/PROXY-List/master/http.txt",
    "https://cdn.jsdelivr.net/gh/proxifly/free-proxy-list@main/proxies/protocols/http/data.txt",
    "https://raw.githubusercontent.com/proxifly/free-proxy-list/main/proxies/protocols/http/data.txt"
]

proxies = []
use_proxy = True  # Set to False if you want to test without proxies

HTML = '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Felix Fixed Proxy Spammer</title>
    <style>
        body { font-family: Arial; text-align: center; padding: 50px; background: #1e1e1e; color: #fff; }
        input, button, select { padding: 12px; margin: 10px; font-size: 18px; }
        button { background: #ff69b4; color: white; border: none; border-radius: 8px; cursor: pointer; }
        button:hover { background: #ff1493; }
        #status { margin-top: 20px; font-size: 18px; white-space: pre-wrap; max-height: 700px; overflow-y: auto; }
    </style>
</head>
<body>
    <h1>✨ Felix's Fixed Proxy PlayFab Spammer ✨</h1>
    <form id="form">
        <input type="text" id="titleid" placeholder="PlayFab Title ID" required><br>
        <input type="text" id="prefix" placeholder="Account Prefix" required><br>
        <input type="number" id="count" value="50" placeholder="How many?" min="1"><br>
        <select id="proxy_mode">
            <option value="1">Use Proxies (Recommended)</option>
            <option value="0">No Proxies (Direct)</option>
        </select><br>
        <button type="button" onclick="startSpamming()">🚀 Start Spamming</button>
    </form>
    <div id="status"></div>

    <script>
        function startSpamming() {
            const titleid = document.getElementById('titleid').value.trim();
            const prefix = document.getElementById('prefix').value.trim();
            const count = parseInt(document.getElementById('count').value) || 50;
            const useP = document.getElementById('proxy_mode').value;
            
            if (!titleid || !prefix) {
                alert("Nya~ Fill Title ID and Prefix!");
                return;
            }

            document.getElementById('status').innerHTML = `Starting ${count} accounts... (proxy mode: ${useP == "1" ? "ON" : "OFF"}) nya~ 💙`;

            fetch('/spam', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({titleid: titleid, prefix: prefix, count: count, use_proxy: useP == "1"})
            })
            .then(r => r.json())
            .then(data => document.getElementById('status').innerHTML = data.message);
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
    proxies = []
    for url in PROXY_SOURCES:
        try:
            r = requests.get(url, timeout=20)
            if r.status_code == 200:
                new_list = [line.strip() for line in r.text.splitlines() if line.strip() and ':' in line]
                proxies.extend(new_list)
                print(f"Loaded {len(new_list)} proxies from {url}")
        except:
            pass
    proxies = list(set(proxies))  # remove duplicates
    print(f"Total unique proxies loaded: {len(proxies)}")
    return len(proxies) > 0

def get_random_proxy():
    if not use_proxy or not proxies:
        return None
    proxy_str = random.choice(proxies)
    return {"http": f"http://{proxy_str}", "https": f"http://{proxy_str}"}

def test_proxy(proxy_dict):
    try:
        r = requests.get("https://httpbin.org/ip", proxies=proxy_dict, timeout=8)
        return r.status_code == 200
    except:
        return False

def create_account(title_id, prefix):
    random_str = ''.join(random.choices(string.ascii_lowercase + string.digits, k=8))
    custom_id = f"{prefix}_{random_str}"

    proxy = get_random_proxy()

    url = f"https://{title_id}.playfabapi.com/Client/LoginWithCustomID"
    payload = {"TitleId": title_id, "CustomId": custom_id, "CreateAccount": True}

    for attempt in range(5):
        try:
            r = requests.post(url, json=payload, proxies=proxy, timeout=25)
            
            if r.status_code == 200:
                data = r.json().get("data", {})
                playfab_id = data.get("PlayFabId", "Unknown")
                with open("/opt/playfab-spammer/created_accounts.txt", "a") as f:
                    f.write(f"{custom_id}|{playfab_id}|{proxy['http'] if proxy else 'DIRECT'}\n")
                print(f"[SUCCESS] {custom_id} → {playfab_id}")
                return f"✅ {custom_id} → {playfab_id}"
            
            elif r.status_code == 429:
                retry = int(r.headers.get("Retry-After", 10))
                time.sleep(retry + 2)
                continue
            else:
                error = r.json().get("errorMessage", str(r.status_code))
                return f"❌ {custom_id} → {error}"
                
        except Exception as e:
            if "Max retries exceeded" in str(e) or "Connection" in str(e):
                time.sleep(1.5)
                continue
            return f"❌ {custom_id} → Connection error"

    return f"❌ {custom_id} → Failed"

@app.route('/spam', methods=['POST'])
def spam():
    global use_proxy
    data = request.get_json()
    title_id = data.get('titleid')
    prefix = data.get('prefix')
    count = int(data.get('count', 50))
    use_proxy = data.get('use_proxy', True)

    if use_proxy:
        load_proxies()

    def run_spam():
        start_time = time.time()
        results = []
        with ThreadPoolExecutor(max_workers=2) as executor:   # Only 2 workers for stability
            futures = [executor.submit(create_account, title_id, prefix) for _ in range(count)]
            for future in as_completed(futures):
                results.append(future.result())
        
        duration = time.time() - start_time
        status_msg = "<br>".join(results[:50])  # Show first 50 to avoid huge page
        if len(results) > 50:
            status_msg += f"<br>... and {len(results)-50} more"
        status_msg += f"<br><br>🏁 Done in {duration:.1f}s | Check created_accounts.txt nya~ 💙"
        print(status_msg.replace("<br>", "\n"))
        return status_msg

    threading.Thread(target=run_spam, daemon=True).start()
    mode = "with proxy rotation" if use_proxy else "DIRECT (no proxy)"
    return jsonify({"message": f"Started {count} accounts {mode} (2 workers)<br>Watch console and status nya~"})

if __name__ == '__main__':
    load_proxies()
    app.run(host='0.0.0.0', port=5000, debug=False)
EOF

sudo pip3 install flask requests --break-system-packages

cat << EOF | sudo tee /etc/systemd/system/playfab-spammer.service > /dev/null
[Unit]
Description=Felix Fixed PlayFab Spammer with Better Proxies
After=network.target

[Service]
User=root
WorkingDirectory=/opt/playfab-spammer
ExecStart=/usr/bin/python3 /opt/playfab-spammer/app.py
Restart=always
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

sudo chmod +x /opt/playfab-spammer/app.py
sudo systemctl daemon-reload
sudo systemctl restart playfab-spammer.service

echo "✨ Fixed nya~! ✨"
echo "Access: http://YOUR_SERVER_IP:5000"
echo "Try first with 'No Proxies (Direct)' to see if your server IP works at all."
echo "If direct works but slow → then try proxies."
echo "Successful accounts saved to created_accounts.txt"
sudo systemctl status playfab-spammer.service --no-pager -l
