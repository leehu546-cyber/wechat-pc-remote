import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path

home = Path.home()
settings_path = home / ".cc-switch" / "settings.json"
db_path = home / ".cc-switch" / "cc-switch.db"
deepseek_id = "7c934a7d-e3ba-4bdb-a423-7e05e4d5bfa7"
backup_settings = home / ".cc-switch" / "backups" / "fix-routing-20260630_141209" / "settings.json"

# Restore settings from backup, keep routing enabled
settings = json.loads(backup_settings.read_text(encoding="utf-8"))
settings["enableLocalProxy"] = True
settings["proxyConfirmed"] = True
settings["currentProviderCodex"] = deepseek_id
settings_path.write_text(json.dumps(settings, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("settings.json restored; currentProviderCodex=", settings["currentProviderCodex"])

db = sqlite3.connect(str(db_path))
cur = db.cursor()
now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")

cur.execute("UPDATE providers SET is_current=0 WHERE app_type='codex'")
cur.execute("UPDATE providers SET is_current=1 WHERE id=?", (deepseek_id,))
cur.execute("UPDATE providers SET in_failover_queue=0 WHERE app_type='codex'")
cur.execute(
    "UPDATE proxy_config SET proxy_enabled=1, enabled=1, updated_at=? WHERE app_type='codex'",
    (now,),
)
db.commit()

print("providers:")
for row in cur.execute(
    "SELECT id, name, is_current, in_failover_queue FROM providers WHERE app_type='codex'"
):
    print(" ", row)

db.close()
print("OK")
