#!/bin/bash
# setup.sh - Felix's PlayFab Account Creator nya~ 💙

set -e

echo "Nya~ Upgrading your spawner to use real PlayFab... ✨"

sudo apt update
sudo apt install -y python3 python3-pip nginx

sudo mkdir -p /opt/playfab-spammer
cd /opt/playfab-spammer

cat << 'EOF' | sudo tee app.py > /dev/null
from flask import Flask, render_template_string, request, jsonify
import random
import string
import threading
import time
import requests

app = Flask(__name__)

HTML = '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Felix PlayFab Spammer</title>
    <style>
        body { font-family: Arial; text-align: center; padding: 50px; background: #1e1e1e; color: #fff; }
        input, button { padding: 12px; margin: 10px; font-size: 18px; }
        button { background: #ff69b4; color: white; border: none; border-radius: 8px; cursor: pointer; }
        button:hover { background: #ff1493; }
        #status { margin-top: 20px; font-size: 18px; white-space: pre-wrap; }
    </style>
</head>
<body>
    <h1>✨ Felix's PlayFab Account Spammer ✨</h1>
    <form id="form">
        <input type="text" id="titleid" placeholder="PlayFab Title ID" required><br>
        <input type="text" id="prefix" placeholder="Account Prefix (e.g. testuser)" required><br>
        <button type="button" onclick="startSpamming()">Start Creating Accounts</button>
    </form>
    <div id="status"></div>

    <script>
        function startSpamming() {
            const titleid = document.getElementById('titleid').value.trim();
            const prefix = document.getElementById('prefix').value.trim();
            
            if (!titleid || !prefix) {
                alert("Nya~ Please fill Title ID and Prefix!");
                return;
            }

            document.getElementById('status').innerHTML = 'Creating accounts on PlayFab... nya~ 💙';

            fetch('/spam', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({titleid: titleid, prefix: prefix})
            })
            .then(r => r.json())
            .then(data => {
                document.getElementById('status').innerHTML = data.message;
            })
            .catch(err => {
                document.getElementById('status').innerHTML = "Error: " + err;
            });
        }
    </script>
</body>
</html>
'''

@app.route('/')
def index():
    return render_template_string(HTML)

@app.route('/spam', methods=['POST'])
def spam():
    data = request.get_json()
    title_id = data.get('titleid')
    prefix = data.get('prefix')

    def spam_task():
        created = []
        for i in range(30):   # Change this number if you want more or fewer accounts
            random_str = ''.join(random.choices(string.ascii_lowercase + string.digits, k=8))
            custom_id = f"{prefix}_{random_str}"

            url = f"https://{title_id}.playfabapi.com/Client/LoginWithCustomID"
            payload = {
                "TitleId": title_id,
                "CustomId": custom_id,
                "CreateAccount": True
            }

            try:
                r = requests.post(url, json=payload, timeout=10)
                result = r.json()

                if r.status_code == 200 and result.get("data"):
                    playfab_id = result["data"].get("PlayFabId", "Unknown")
                    session = result["data"].get("SessionTicket", "No ticket")
                    created.append(f"✅ {custom_id} → PlayFabId: {playfab_id}")
                    print(f"[SUCCESS] Created: {custom_id} | PlayFabId: {playfab_id}")
                else:
                    error = result.get("errorMessage", r.text)
                    created.append(f"❌ {custom_id} → Error: {error}")
                    print(f"[FAILED] {custom_id} - {error}")
            except Exception as e:
                created.append(f"❌ {custom_id} → Exception: {str(e)}")
                print(f"[EXCEPTION] {custom_id} - {e}")

            time.sleep(0.6)  # Be gentle with PlayFab rate limits

        status_msg = "<br>".join(created)
        status_msg += f"<br><br>Finished creating {len(created)} accounts nya~ 💙"
        return status_msg

    thread = threading.Thread(target=lambda: None, daemon=True)
    thread = threading.Thread(target=spam_task, daemon=True)
    thread.start()

    return jsonify({"message": "Spamming started... Check console + status for results nya~"})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
EOF

sudo pip3 install flask requests

cat << EOF | sudo tee /etc/systemd/system/playfab-spammer.service > /dev/null
[Unit]
Description=Felix PlayFab Account Spammer
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
sudo systemctl enable playfab-spammer.service
sudo systemctl restart playfab-spammer.service

echo "✨ All done nya~! ✨"
echo "Access your PlayFab spawner at: http://YOUR_SERVER_IP:5000"
echo "Enter your Title ID and a prefix (example: mygame_test)"
echo "Felix will create real accounts using LoginWithCustomID + CreateAccount=true"
echo ""
sudo systemctl status playfab-spammer.service --no-pager -l
