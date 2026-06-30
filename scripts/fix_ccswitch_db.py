import sqlite3
from datetime import datetime, timezone
from pathlib import Path

db_path = Path.home() / ".cc-switch" / "cc-switch.db"
db = sqlite3.connect(str(db_path))
cur = db.cursor()
now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")

cur.execute(
    "UPDATE proxy_config SET proxy_enabled=1, updated_at=? WHERE app_type='codex'",
    (now,),
)
db.commit()

for row in cur.execute(
    "SELECT app_type, proxy_enabled, enabled, live_takeover_active FROM proxy_config"
):
    print(row)

db.close()
print("OK: codex proxy_enabled=1")
