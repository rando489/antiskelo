#!/bin/bash
# setup.sh - Felix's SUPER FAST PlayFab Account Creator nya~ 💙

set -e

echo "Nya~ Making your spawner blazing fast... ✨"

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

HTML = '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Felix Fast PlayFab Spammer</title>
    <style>
        body { font-family: Arial; text-align: center; padding: 50px; background: #1e1e1e; color: #fff; }
        input, button { padding: 12px; margin: 10px; font-size: 18px; }
        button { background: #ff69b4; color: white; border: none; border-radius: 8px; cursor: pointer; }
        button:hover { background: #ff1493; }
        #status { margin-top: 20px; font-size: 18px; white-space: pre-wrap; max-height: 600px; overflow-y: auto; }
    </style>
</head>
<body>
    <h1>✨ Felix's SUPER FAST PlayFab Spammer ✨</h1>
    <form id="form">
        <input type="text" id="titleid" placeholder="PlayFab Title ID" required><br>
        <input type="text" id="prefix" placeholder="Account Prefix" required><br>
        <input type="number" id="count" value="100" placeholder="How many accounts?" min="1"><br>
        <button type="button" onclick="startSpamming()">🚀 Start Fast Spamming</button>
    </form>
    <div id="status"></div>

    <script>
        function startSpamming() {
            const titleid = document.getElementById('titleid').value.trim();
            const prefix = document.getElementById('prefix').value.trim();
            const count = parseInt(document.getElementById('count').value) || 50;
            
            if (!titleid || !prefix) {
                alert("Nya~ Title ID and Prefix are required!");
                return;
            }

            document.getElementById('status').innerHTML = `Creating ${count} accounts as fast as possible... nya~ 💙`;

            fetch('/spam', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({titleid: titleid, prefix: prefix, count: count})
            })
            .then(r => r.json())
            .then(data => {
                document.getElementById('status').innerHTML = data.message;
            });
        }
    </script>
</body>
</html>
'''

@app.route('/')
def index():
    return render_template_string(HTML)

def create_account(title_id, prefix):
    random_str = ''.join(random.choices(string.ascii_lowercase + string.digits, k=8))
    custom_id = f"{prefix}_{random_str}"

    url = f"https://{title_id}.playfabapi.com/Client/LoginWithCustomID"
    payload = {
        "TitleId": title_id,
        "CustomId": custom_id,
        "CreateAccount": True
    }

    try:
        r = requests.post(url, json=payload, timeout=15)
        result = r.json()

        if r.status_code == 200 and result.get("data"):
            playfab_id = result["data"].get("PlayFabId", "Unknown")
            print(f"[SUCCESS] {custom_id} → {playfab_id}")
            return f"✅ {custom_id} → PlayFabId: {playfab_id}"
        else:
            error = result.get("errorMessage", r.text[:200])
            print(f"[FAILED] {custom_id} - {error}")
            return f"❌ {custom_id} → Error: {error}"
    except Exception as e:
        print(f"[EXCEPTION] {custom_id} - {e}")
        return f"❌ {custom_id} → Exception: {str(e)}"

@app.route('/spam', methods=['POST'])
def spam():
    data = request.get_json()
    title_id = data.get('titleid')
    prefix = data.get('prefix')
    count = int(data.get('count', 50))

    def worker():
        results = []
        with ThreadPoolExecutor(max_workers=6) as executor:   # 6 concurrent workers = much faster
            futures = [executor.submit(create_account, title_id, prefix) for _ in range(count)]
            for future in as_completed(futures):
                results.append(future.result())
        return results

    def run_spam():
        start_time = time.time()
        results = worker()
        duration = time.time() - start_time

        status_msg = "<br>".join(results)
        status_msg += f"<br><br>✅ Finished {len(results)} accounts in {duration:.1f} seconds (~{len(results)/duration:.1f} acc/sec) nya~ 💙"
        print(status_msg.replace("<br>", "\n"))

        # You could also save results to a file here if you want

    threading.Thread(target=run_spam, daemon=True).start()

    return jsonify({"message": f"🚀 Fast spamming of {count} accounts started with 6 workers!<br>Check status and console for live results nya~"})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
EOF

sudo pip3 install flask requests --break-system-packages

cat << EOF | sudo tee /etc/systemd/system/playfab-spammer.service > /dev/null
[Unit]
Description=Felix Fast PlayFab Account Spammer
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

echo "✨ Done nya~! Now it's WAY FASTER ✨"
echo "Access it at: http://YOUR_SERVER_IP:5000"
echo "You can now set how many accounts you want (default 100)"
echo "Felix is using 6 concurrent workers + very low delay"
echo ""
echo "If you get lots of 429 errors, tell me and I'll slow it down a bit~"
sudo systemctl status playfab-spammer.service --no-pager -l
