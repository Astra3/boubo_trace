import json
from collections import defaultdict
import pandas as pd
from pathlib import Path
import plotly.express as px
import subprocess
import fileinput
from dataclasses import dataclass

@dataclass
class FileProcess:
    coverage: float
    total: int
    unique_coverage: float
    total_unique: int

def process_file(filename: str, not_covered: dict) -> FileProcess:
    with open(filename) as f:
        data: list[dict] = json.load(f)

    filename = Path(filename).stem

    filtered = [i for i in data if "syscall_error" not in i]

    total = len(filtered)
    unknown= [i for i in data if "unknown" in i]
    unknown_count = len(unknown)

    coverage = (total - unknown_count) / total * 100
    unique = {next(iter(i)) if "unknown" not in i else i["unknown"]["id"] for i in filtered}
    total_unique = len(unique)
    unique_coverage = sum(1 for i in unique if isinstance(i, str) and i != "syscall_error") / total_unique * 100

    for call in unknown:
        not_covered[call["unknown"]["id"]][filename] += 1

    return FileProcess(coverage, total, unique_coverage, total_unique)


print("Enter filenames, CTRL+D to continue")
filenames = [line.rstrip() for line in fileinput.input()]

not_covered = defaultdict(lambda: {Path(i).stem: 0 for i in filenames})

print("filename, coverage of all syscalls, total syscalls called, coverage of unique syscalls, total unique syscalls called")
for filename in filenames:
    file_proc = process_file(filename, not_covered)
    print(f"[{filename}], [{file_proc.coverage:.2f}], [{file_proc.total}], [{file_proc.unique_coverage:.2f}], [{file_proc.total_unique}]")

df = pd.DataFrame.from_dict(not_covered, orient="index")
df.loc[:, "total"] = df.sum(axis=1)
df = df.sort_values("total", ascending=False).head(10).drop(columns="total")
df.columns = df.columns.str.capitalize()
df = df.rename(columns={"Vlc": "VLC"})

    
calls = df.index.to_series().astype("str")
for call in df.index:
    process = subprocess.Popen(["/usr/bin/scmp_sys_resolver", str(call)], stdout=subprocess.PIPE)
    process.wait()
    call_name = process.stdout.read().decode("utf-8").strip() # type: ignore
    calls.loc[call] = call_name
df.index = calls.values

# df = df.reindex(columns=["Dolphin", "Neovim", "VLC", "Krita", "Chromium"])

df_head = df.head(10)
fig = px.bar(df_head, barmode="group", labels={"value": "Počet zavolání", "index": "Systémové volání", "variable": "Program"}, log_y=True)

fig.show()
fig.write_json("figure.json")
# fig.write_image("out.svg")

print(df)
print("syscall stats saved!")

