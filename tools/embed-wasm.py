#!/usr/bin/env python3
from pathlib import Path
import base64
root = Path(__file__).resolve().parent.parent
wasm = (root / "obj/wasm/cfa.wasm").read_bytes()
b64 = base64.b64encode(wasm).decode("ascii")
tmpl = (root / "web/template.html").read_text()
if "__WASM_BASE64__" not in tmpl:
    raise SystemExit("web/template.html missing __WASM_BASE64__ placeholder")
(root / "dist").mkdir(exist_ok=True)
(root / "dist/index.html").write_text(tmpl.replace("__WASM_BASE64__", b64))
(root / "dist/VERSION").write_text("0.7.0\n")
print("wrote dist/index.html", (root / "dist/index.html").stat().st_size, "wasm", len(wasm))
