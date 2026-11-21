from pathlib import Path

log_path = Path(r"C:\Users\bdewe\AppData\Local\Google\DriveFS\Logs\structured_log_118213793054156610633")
with open(log_path, "r", encoding="utf-8", errors="ignore") as f:
    text = f.read()

for kw in ["quota", "storage", "disk space", "full", "pause", "rate limit"]:
    matches = [line.strip() for line in text.split("\n") if kw in line.lower()]
    print(f"Keyword '{kw}': {len(matches)} occurrences")
    for m in matches[-3:]:
        print(f"  -> {m[:140]}")
