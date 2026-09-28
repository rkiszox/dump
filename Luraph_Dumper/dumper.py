import os
import sys
import shutil
import tempfile
import subprocess
from pathlib import Path

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

SCRIPT_DIR = Path(__file__).resolve().parent
LUNE_BIN = SCRIPT_DIR / "lune.exe"
ENGINE_LUAU = SCRIPT_DIR / "engine" / "luraph_core.luau"
DESKTOP_DIR = Path.home() / "Desktop"

def clean_input_path(raw_path: str) -> Path:
    s = raw_path.strip()
    if s.startswith("&"):
        s = s[1:].strip()
    s = s.strip("'\"`").strip()
    p = Path(s).expanduser()
    if not p.is_absolute():
        if (SCRIPT_DIR / p).exists():
            p = (SCRIPT_DIR / p).resolve()
        elif (DESKTOP_DIR / p).exists():
            p = (DESKTOP_DIR / p).resolve()
        else:
            p = p.resolve()
    return p

def dump_single_file(target_path: Path) -> bool:
    if not target_path.is_file():
        print(f"[!] Error: File not found: {target_path}")
        return False
        
    if not LUNE_BIN.is_file():
        print(f"[!] Error: lune.exe not found at: {LUNE_BIN}")
        return False
        
    if not ENGINE_LUAU.is_file():
        print(f"[!] Error: Engine core not found at: {ENGINE_LUAU}")
        return False

    output_lua = target_path.parent / f"{target_path.stem}-output.lua"
    temp_json = Path(tempfile.gettempdir()) / f"luraph_dump_{target_path.stem}.json"
    
    print(f"\n[+] Processing: {target_path.name}")
    
    cmd = [
        str(LUNE_BIN),
        "run",
        str(ENGINE_LUAU).replace("\\", "/"),
        str(target_path).replace("\\", "/"),
        str(temp_json).replace("\\", "/"),
        str(output_lua).replace("\\", "/")
    ]
    
    if output_lua.is_file():
        try:
            output_lua.unlink()
        except Exception:
            pass
            
    res = subprocess.run(cmd, capture_output=True, text=True, cwd=str(SCRIPT_DIR))
    
    if res.stdout:
        for line in res.stdout.strip().splitlines():
            print(f"    {line}")
            
    if res.returncode == 0 and output_lua.is_file() and output_lua.stat().st_size > 0:
        size_bytes = output_lua.stat().st_size
        print(f"[+] Output: {output_lua} ({size_bytes:,} bytes)")
        try:
            if temp_json.is_file():
                temp_json.unlink()
        except Exception:
            pass
        return True
    else:
        print(f"[!] Failed to deobfuscate {target_path.name}")
        if res.stderr:
            print(f"[!] Engine Error:\n{res.stderr}")
        return False

def dump_path(target_path: Path):
    if target_path.is_dir():
        candidates = []
        for ext in ("*.lua", "*.txt", "*.luau"):
            candidates.extend(target_path.glob(ext))
        candidates = [c for c in candidates if not c.name.endswith("-output.lua")]
        if not candidates:
            print(f"[!] No Lua/txt scripts found in folder: {target_path}")
            return
        print(f"[+] Found {len(candidates)} script(s) in {target_path.name}. Starting batch dump...")
        success_count = 0
        for item in candidates:
            if dump_single_file(item):
                success_count += 1
        print(f"\n[+] Batch complete: {success_count}/{len(candidates)} files successfully dumped.")
    else:
        dump_single_file(target_path)

if __name__ == "__main__":
    if len(sys.argv) > 1:
        target_str = " ".join(sys.argv[1:])
        target_path = clean_input_path(target_str)
        dump_path(target_path)
    else:
        print("[!] Usage: python dumper.py <path_to_file_or_directory>")

