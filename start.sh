#!/usr/bin/env bash
set -e
export PATH="/tools/node/bin:/usr/local/bin:$PATH"
cd /content/1MiroFish

# Kill existing tmux session or any stray processes
tmux kill-session -t mirofish 2>/dev/null || true
pkill -f "run.py" || true
pkill -f "vite" || true
pkill -f "cloudflared" || true
sleep 1

# Start tmux session for backend
tmux new-session -d -s mirofish -n backend "bash -c 'export PATH=/tools/node/bin:/usr/local/bin:\$PATH; cd /content/1MiroFish/backend && uv run python run.py > /content/1MiroFish/backend.log 2>&1'"

echo "Waiting for backend on port 5001..."
for i in {1..30}; do
    if curl -s http://localhost:5001/api/simulation/env-status >/dev/null 2>&1; then
        echo "Backend is up!"
        break
    fi
    sleep 1
done

# Start frontend in tmux
tmux new-window -t mirofish -n frontend "bash -c 'export PATH=/tools/node/bin:/usr/local/bin:\$PATH; cd /content/1MiroFish/frontend && npm run dev > /content/1MiroFish/frontend.log 2>&1'"

echo "Waiting for frontend on port 3000..."
for i in {1..30}; do
    if curl -s http://localhost:3000 >/dev/null 2>&1; then
        echo "Frontend is up!"
        break
    fi
    sleep 1
done

# Start cloudflared tunnel
rm -f /content/1MiroFish/tunnel.log
tmux new-window -t mirofish -n tunnel "bash -c 'cloudflared tunnel --url http://localhost:3000 > /content/1MiroFish/tunnel.log 2>&1'"

echo "Waiting for Cloudflare tunnel URL..."
for i in {1..30}; do
    URL=$(grep -o "https://[a-zA-Z0-9-]*\.trycloudflare\.com" /content/1MiroFish/tunnel.log 2>/dev/null | tail -n 1 || true)
    if [ -n "$URL" ]; then
        echo "TUNNEL_URL=$URL"
        break
    fi
    sleep 1
done
