#!/bin/bash
# setup.sh - Felix's PlayFab Spammer with Free Proxy Rotation nya~ 💙

set -e

echo "Nya~ Adding free proxy rotation to dodge throttling... ✨"

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

PROXY_LIST_URL = "https://raw.githubusercontent.com/proxifly/free-proxy-list/main/proxies/protocols/http/data.txt"  # Fresh HTTP proxies, updated ~every 5 min
proxies = []  # Global list of working proxies

HTML = '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Felix Proxy PlayFab Spammer</title>
    <style>
        body { font-family: Arial; text-align: center; padding: 50px; background: #1e1e1e; color: #fff; }
        input, button { padding: 12px; margin: 10px; font-size: 18px; }
        button { background: #ff69b4; color: white; border: none; border-radius: 8px; cursor: pointer; }
        button:hover { background: #ff1493; }
        #status { margin-top: 20px; font-size: 18px; white-space: pre-wrap; max-height: 700px; overflow-y: auto; }
    </style>
</head>
<body>
    <h1>✨ Felix's Proxy PlayFab Spammer ✨</h1>
    <form id="form">
        <input type="text" id="titleid" placeholder="PlayFab Title ID" required><br>
        <input type="text" id="prefix" placeholder="Account Prefix" required><br>
        <input type="number" id="count" value="100" placeholder="How many?" min="1"><br>
        <button type="button" onclick="startSpamming()">🌐 Start with Proxy Rotation</button>
    </form>
    <div id="status"></div>

    <script>
        function startSpamming() {
            const titleid = document.getElementById('titleid').value.trim();
            const prefix = document.getElementById('prefix').value.trim();
            const count = parseInt(document.getElementById('count').value) || 50;
            
            if (!titleid || !prefix) {
                alert("Nya~ Title ID and Prefix required!");
                return;
            }

            document.getElementById('status').innerHTML = `Starting creation of ${count} accounts with proxy rotation... nya~ 💙`;

            fetch('/spam', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({titleid: titleid, prefix: prefix, count: count})
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
    try:
        r = requests.get(PROXY_LIST_URL, timeout=15)
        if r.status_code == 200:
            new_proxies = [line.strip() for line in r.text.splitlines() if line.strip() and ':' in line]
            if new_proxies:
                proxies = new_proxies
                print(f"Loaded {len(proxies)} fresh proxies nya~")
                return True
    except Exception as e:
        print(f"Failed to load proxies: {e}")
    return False

def get_random_proxy():
    if not proxies:
        load_proxies()
    if proxies:
        return {"http": f"http://{random.choice(proxies)}", "https": f"http://{random.choice(proxies)}"}
    return None

def create_account(title_id, prefix):
    random_str = ''.join(random.choices(string.ascii_lowercase + string.digits, k=8))
    custom_id = f"{prefix}_{random_str}"

    proxy = get_random_proxy()

    url = f"https://{title_id}.playfabapi.com/Client/LoginWithCustomID"
    payload = {"TitleId": title_id, "CustomId": custom_id, "CreateAccount": True}

    for attempt in range(4):
        try:
            r = requests.post(url, json=payload, proxies=proxy, timeout=20)
            
            if r.status_code == 200:
                data = r.json().get("data", {})
                playfab_id = data.get("PlayFabId", "Unknown")
                with open("/opt/playfab-spammer/created_accounts.txt", "a") as f:
                    f.write(f"{custom_id} | {playfab_id} | {proxy['http'] if proxy else 'no-proxy'}\n")
                print(f"[SUCCESS] {custom_id} → {playfab_id} (via proxy)")
                return f"✅ {custom_id} → PlayFabId: {playfab_id}"
            
            elif r.status_code == 429:
                retry_after = int(r.headers.get("Retry-After", 8))
                print(f"[429] Throttled — waiting {retry_after}s (proxy: {proxy})")
                time.sleep(retry_after + 2)
                continue
            
            else:
                error = r.json().get("errorMessage", r.text[:100])
                return f"❌ {custom_id} → {error}"
                
        except Exception as e:
            print(f"[Proxy/Error] {custom_id} - {e}")
            time.sleep(1.5)
            continue

    return f"❌ {custom_id} → Failed after retries"

@app.route('/spam', methods=['POST'])
def spam():
    data = request.get_json()
    title_id = data.get('titleid')
    prefix = data.get('prefix')
    count = int(data.get('count', 50))

    # Refresh proxy list before starting
    load_proxies()

    def run_spam():
        start_time = time.time()
        results = []
        with ThreadPoolExecutor(max_workers=3) as executor:   # 3 workers + proxy rotation
            futures = [executor.submit(create_account, title_id, prefix) for _ in range(count)]
            for future in as_completed(futures):
                results.append(future.result())
        
        duration = time.time() - start_time
        status_msg = "<br>".join(results)
        status_msg += f"<br><br>🏁 Finished {len(results)} attempts in {duration:.1f} seconds with proxy rotation nya~ 💙"
        status_msg += f"<br>✅ Check created_accounts.txt for successes"
        print(status_msg.replace("<br>", "\n"))
        return status_msg

    threading.Thread(target=run_spam, daemon=True).start()
    return jsonify({"message": f"🌐 Proxy rotation enabled! Creating {count} accounts with fresh proxies.<br>Proxies refreshed automatically nya~"})

if __name__ == '__main__':
    load_proxies()  # Load on startup
    app.run(host='0.0.0.0', port=5000, debug=False)
EOF

sudo pip3 install flask requests

# systemd service
cat << EOF | sudo tee /etc/systemd/system/playfab-spammer.service > /dev/null
[Unit]
Description=Felix PlayFab Spammer with Proxy Rotation
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
sudo systemctl enable playfab-spammer.service
sudo systemctl restart playfab-spammer.service

echo "✨ Done nya~! Proxy rotation is now active ✨"
echo "Access: http://YOUR_SERVER_IP:5000"
echo "It will automatically download fresh HTTP proxies every time you start spamming"
echo "Successful accounts + used proxy saved in created_accounts.txt"
sudo systemctl status playfab-spammer.service --no-pager -l
