#!/usr/bin/env python3
"""Generate tools/curate.html — an interactive curation tool for the 366-piece
catalog. The output HTML embeds artwork metadata + paths to the SVG files, and
ships a self-contained browser UI for triaging into Hero / Solid / Cut.

Decisions persist to localStorage (resume across sessions) and can be exported
as JSON or Markdown for use in a curated catalog rewrite.

Usage:
    python3 tools/gen_curate.py
    open tools/curate.html       # macOS
"""
import re, os, glob, json
from collections import OrderedDict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARTWORKS_DIR = os.path.join(ROOT, "One Hue", "Artworks")
CATALOG_FILE = os.path.join(ROOT, "One Hue", "Daily Artwork", "DailyArtwork.swift")
OUT_FILE = os.path.join(ROOT, "tools", "curate.html")

# ---- Parse catalog ----------------------------------------------------------

def parse_catalog():
    """Extract [(id, displayName, fileName, month, day)] from DailyArtwork.swift."""
    with open(CATALOG_FILE, encoding="utf-8") as f:
        content = f.read()
    # Multi-line tolerant regex
    pat = re.compile(
        r'Artwork\(\s*id:\s*"([^"]+)"\s*,'
        r'\s*fileName:\s*"([^"]+)"\s*,'
        r'\s*displayName:\s*"([^"]+)"\s*,'
        r'.*?'
        r'month:\s*(\d+)\s*,\s*day:\s*(\d+)',
        re.DOTALL,
    )
    out = OrderedDict()
    for m in pat.finditer(content):
        aid, fname, dname, mo, da = m.group(1), m.group(2), m.group(3), int(m.group(4)), int(m.group(5))
        out[aid] = {
            "id": aid, "fileName": fname, "displayName": dname,
            "month": mo, "day": da, "inCatalog": True,
        }
    return out

# ---- Inspect SVG ------------------------------------------------------------

def inspect_svg(path):
    """Return {paths, colors, sizeKB, format, gaps, viewBox} for a single SVG."""
    size = os.path.getsize(path)
    with open(path, encoding="utf-8", errors="replace") as f:
        content = f.read()

    paths = len(re.findall(r"<path\b", content))
    polygons = len(re.findall(r"<polygon\b", content))
    rects = len(re.findall(r"<rect\b", content))
    elements = paths + polygons + rects

    style_match = re.search(r"<style[^>]*>(.*?)</style>", content, re.DOTALL)
    style_text = style_match.group(1) if style_match else ""

    colors_hex = re.findall(r"fill:\s*#([0-9a-fA-F]{3,6})", style_text)
    num_colors = len(set(c.lower() for c in colors_hex))

    has_cls = bool(re.search(r"\.cls-\d+", style_text))
    has_st = bool(re.search(r"\.st\d+", style_text))
    fmt = "cls" if has_cls else ("st" if has_st else "unknown")

    if has_cls:
        nums = sorted(set(int(m) for m in re.findall(r"\.cls-(\d+)", style_text)))
        gaps = len([i for i in range(1, max(nums) + 1) if i not in nums]) if nums else 0
    elif has_st:
        nums = sorted(set(int(m) for m in re.findall(r"\.st(\d+)", style_text)))
        gaps = len([i for i in range(0, max(nums) + 1) if i not in nums]) if nums else 0
    else:
        gaps = 0

    vb_match = re.search(r'viewBox="([^"]+)"', content)
    viewBox = vb_match.group(1) if vb_match else None
    is_square = False
    if viewBox:
        parts = viewBox.split()
        if len(parts) == 4:
            try:
                _, _, w, h = (float(p) for p in parts)
                is_square = abs(w - h) / max(w, h) < 0.02
            except ValueError:
                pass

    return {
        "elements": elements,
        "paths": paths,
        "colors": num_colors,
        "sizeKB": round(size / 1024),
        "format": fmt,
        "gaps": gaps,
        "viewBox": viewBox,
        "isSquare": is_square,
    }

# ---- Anomaly scoring --------------------------------------------------------

def anomaly_score(meta):
    """Higher score = more suspect (likely cut). Used as default sort.
    The pipeline doc says 60–350 elements is the sweet spot."""
    s = 0
    e = meta["elements"]
    if e < 50: s += 30
    elif e < 80: s += 10
    elif e > 800: s += 40
    elif e > 400: s += 15

    if meta["sizeKB"] > 500: s += 15
    if meta["sizeKB"] < 30: s += 15
    if meta["colors"] < 4: s += 20
    if meta["colors"] > 22: s += 10
    if meta["gaps"] > 3: s += 10
    if not meta["isSquare"]: s += 25  # non-square = legacy / not regenerated
    return s

# ---- Build dataset ----------------------------------------------------------

def build_dataset():
    catalog = parse_catalog()
    svgs = sorted(glob.glob(os.path.join(ARTWORKS_DIR, "*.svg")))
    items = []
    catalog_seen = set()

    for path in svgs:
        name = os.path.basename(path).replace(".svg", "")
        meta = inspect_svg(path)
        cat = catalog.get(name)
        if cat:
            catalog_seen.add(name)
        item = {
            "id": name,
            "displayName": cat["displayName"] if cat else name,
            "month": cat["month"] if cat else None,
            "day": cat["day"] if cat else None,
            "inCatalog": cat is not None,
            **meta,
        }
        item["score"] = anomaly_score(item)
        items.append(item)

    orphans_in_catalog = set(catalog.keys()) - catalog_seen
    return items, sorted(orphans_in_catalog)

# ---- HTML template ----------------------------------------------------------

HTML = """<!DOCTYPE html>
<html><head><meta charset="utf-8">
<title>One Hue — Curate</title>
<style>
  :root { --bg:#121212; --card:#1d1d1d; --line:rgba(255,255,255,0.08); --txt:rgba(255,255,255,0.9); --mute:rgba(255,255,255,0.5); --hero:#e9b949; --solid:#5db87a; --cut:#c46060; }
  * { box-sizing: border-box; }
  html,body { background:var(--bg); color:var(--txt); margin:0; font:14px -apple-system, system-ui, sans-serif; }
  header { position:sticky; top:0; background:rgba(18,18,18,0.95); backdrop-filter:blur(10px); border-bottom:1px solid var(--line); padding:14px 20px; z-index:10; }
  .row { display:flex; align-items:center; gap:14px; flex-wrap:wrap; }
  h1 { font-size:16px; font-weight:600; margin:0; letter-spacing:0.4px; }
  .stat { font-size:12px; color:var(--mute); padding:4px 10px; background:rgba(255,255,255,0.06); border-radius:14px; }
  .stat b { color:var(--txt); font-weight:600; }
  .stat.hero b { color:var(--hero); }
  .stat.solid b { color:var(--solid); }
  .stat.cut b { color:var(--cut); }
  button { font:inherit; color:var(--txt); background:rgba(255,255,255,0.06); border:1px solid var(--line); padding:6px 12px; border-radius:8px; cursor:pointer; transition:background 0.15s; }
  button:hover { background:rgba(255,255,255,0.12); }
  button.active { background:rgba(255,255,255,0.18); border-color:rgba(255,255,255,0.3); }
  select { font:inherit; color:var(--txt); background:rgba(255,255,255,0.06); border:1px solid var(--line); padding:6px 10px; border-radius:8px; }
  .grid { display:grid; grid-template-columns:repeat(auto-fill, minmax(220px, 1fr)); gap:14px; padding:18px 20px 60px; }
  .card { background:var(--card); border-radius:10px; overflow:hidden; border:1px solid var(--line); display:flex; flex-direction:column; transition:transform 0.15s, border-color 0.15s; }
  .card:hover { transform:translateY(-2px); border-color:rgba(255,255,255,0.18); }
  .card.dec-hero  { border-color:var(--hero); }
  .card.dec-solid { border-color:var(--solid); }
  .card.dec-cut   { border-color:var(--cut); opacity:0.55; }
  .thumb { background:#fff; aspect-ratio:1/1; display:flex; align-items:center; justify-content:center; }
  .thumb img { width:100%; height:100%; object-fit:contain; }
  .meta { padding:8px 10px 4px; font-size:12px; color:var(--mute); display:flex; justify-content:space-between; align-items:center; gap:6px; }
  .name { padding:0 10px 4px; font-size:13px; color:var(--txt); white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
  .display { padding:0 10px 8px; font-size:11px; color:var(--mute); white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
  .badges { display:flex; gap:4px; flex-wrap:wrap; }
  .badge { font-size:10px; padding:1px 6px; border-radius:4px; background:rgba(255,255,255,0.08); color:var(--mute); }
  .badge.warn { background:rgba(196,96,96,0.2); color:#e8a8a8; }
  .badge.orphan { background:rgba(233,185,73,0.18); color:#e9b949; }
  .actions { display:flex; border-top:1px solid var(--line); }
  .actions button { flex:1; border:none; border-radius:0; border-right:1px solid var(--line); background:transparent; padding:10px 0; font-size:12px; }
  .actions button:last-child { border-right:none; }
  .actions button.on.hero  { background:rgba(233,185,73,0.18); color:var(--hero); font-weight:600; }
  .actions button.on.solid { background:rgba(93,184,122,0.18); color:var(--solid); font-weight:600; }
  .actions button.on.cut   { background:rgba(196,96,96,0.18);  color:var(--cut);   font-weight:600; }
  dialog { background:var(--card); color:var(--txt); border:1px solid var(--line); border-radius:14px; padding:18px; max-width:600px; width:90%; }
  dialog::backdrop { background:rgba(0,0,0,0.6); }
  pre { background:#0a0a0a; padding:12px; border-radius:6px; max-height:380px; overflow:auto; font-size:11px; line-height:1.5; }
  .hint { color:var(--mute); font-size:12px; margin-left:auto; }
</style></head>
<body>
<header>
  <div class="row">
    <h1>One Hue · Curate</h1>
    <span class="stat hero"   id="stat-hero">★ <b>0</b></span>
    <span class="stat solid"  id="stat-solid">✓ <b>0</b></span>
    <span class="stat cut"    id="stat-cut">✗ <b>0</b></span>
    <span class="stat"        id="stat-todo">unrated <b>0</b></span>
    <span class="stat"        id="stat-total">/ <b>0</b></span>
  </div>
  <div class="row" style="margin-top:10px;">
    <button data-filter="all"     class="active">All</button>
    <button data-filter="todo">Unrated</button>
    <button data-filter="hero">★ Hero</button>
    <button data-filter="solid">✓ Solid</button>
    <button data-filter="cut">✗ Cut</button>
    <button data-filter="orphan">Orphans only</button>
    <span style="width:14px;"></span>
    <label>Sort
      <select id="sort">
        <option value="score">Suspect first</option>
        <option value="alpha">Alphabetical</option>
        <option value="date">Calendar date</option>
        <option value="elements">Elements (high → low)</option>
        <option value="size">Size (high → low)</option>
      </select>
    </label>
    <span class="hint">Keys: 1 ★ &nbsp; 2 ✓ &nbsp; 3 ✗ &nbsp; click empty area to clear</span>
    <button id="export" style="margin-left:auto;">Export</button>
    <button id="reset">Reset</button>
  </div>
</header>

<div class="grid" id="grid"></div>

<dialog id="export-dialog">
  <h3 style="margin-top:0;">Export decisions</h3>
  <div class="row" style="margin-bottom:10px;">
    <button class="tab active" data-tab="json">JSON</button>
    <button class="tab" data-tab="md">Markdown</button>
    <button class="tab" data-tab="swift">Swift catalog hint</button>
  </div>
  <pre id="export-text"></pre>
  <div class="row" style="margin-top:10px;">
    <button id="copy">Copy to clipboard</button>
    <button id="download">Download</button>
    <button id="close" style="margin-left:auto;">Close</button>
  </div>
</dialog>

<script>
const DATA = __DATA__;
const KEY = "onehue.curate.decisions.v1";
const ARTWORK_PATH = "../One%20Hue/Artworks/";

let decisions = JSON.parse(localStorage.getItem(KEY) || "{}");
let activeFilter = "all";
let activeSort = "score";
let activeCard = null;

function saveDecisions() { localStorage.setItem(KEY, JSON.stringify(decisions)); refreshStats(); }

function refreshStats() {
  let h=0,s=0,c=0;
  for (const k of Object.keys(decisions)) {
    if (decisions[k] === "hero") h++;
    else if (decisions[k] === "solid") s++;
    else if (decisions[k] === "cut") c++;
  }
  const todo = DATA.length - h - s - c;
  document.querySelector("#stat-hero  b").textContent = h;
  document.querySelector("#stat-solid b").textContent = s;
  document.querySelector("#stat-cut   b").textContent = c;
  document.querySelector("#stat-todo  b").textContent = todo;
  document.querySelector("#stat-total b").textContent = DATA.length;
}

function sortItems(items) {
  const cmp = {
    score:    (a,b) => b.score - a.score || a.id.localeCompare(b.id),
    alpha:    (a,b) => a.id.localeCompare(b.id),
    elements: (a,b) => b.elements - a.elements,
    size:     (a,b) => b.sizeKB - a.sizeKB,
    date:     (a,b) => {
      if (a.inCatalog !== b.inCatalog) return a.inCatalog ? -1 : 1;
      return (a.month||13)*100 + (a.day||32) - ((b.month||13)*100 + (b.day||32));
    },
  };
  return [...items].sort(cmp[activeSort]);
}

function filterItems(items) {
  if (activeFilter === "all")    return items;
  if (activeFilter === "todo")   return items.filter(it => !decisions[it.id]);
  if (activeFilter === "orphan") return items.filter(it => !it.inCatalog);
  return items.filter(it => decisions[it.id] === activeFilter);
}

function badgesFor(item) {
  const out = [];
  if (!item.inCatalog) out.push(`<span class="badge orphan">orphan</span>`);
  if (item.elements < 50)  out.push(`<span class="badge warn">tiny ${item.elements}p</span>`);
  if (item.elements > 800) out.push(`<span class="badge warn">huge ${item.elements}p</span>`);
  if (item.sizeKB > 500)   out.push(`<span class="badge warn">${item.sizeKB}KB</span>`);
  if (!item.isSquare)      out.push(`<span class="badge warn">non-square</span>`);
  if (item.colors < 4)     out.push(`<span class="badge warn">${item.colors}c</span>`);
  if (item.gaps > 3)       out.push(`<span class="badge warn">${item.gaps} gaps</span>`);
  return out.join("");
}

function render() {
  const grid = document.getElementById("grid");
  const items = sortItems(filterItems(DATA));
  grid.innerHTML = "";
  for (const it of items) {
    const dec = decisions[it.id] || "";
    const card = document.createElement("div");
    card.className = "card" + (dec ? " dec-" + dec : "");
    card.dataset.id = it.id;
    const dateStr = it.inCatalog ? `${it.month}/${it.day}` : "—";
    card.innerHTML = `
      <div class="thumb"><img loading="lazy" src="${ARTWORK_PATH}${it.id}.svg" alt="${it.id}"></div>
      <div class="meta">
        <span>${it.elements}p · ${it.colors}c · ${it.sizeKB}K</span>
        <span>${dateStr}</span>
      </div>
      <div class="meta"><div class="badges">${badgesFor(it)}</div></div>
      <div class="name">${it.id}</div>
      <div class="display">${it.displayName !== it.id ? it.displayName : ""}</div>
      <div class="actions">
        <button class="hero  ${dec==='hero' ?'on':''}" data-act="hero">★ Hero</button>
        <button class="solid ${dec==='solid'?'on':''}" data-act="solid">✓ Solid</button>
        <button class="cut   ${dec==='cut'  ?'on':''}" data-act="cut">✗ Cut</button>
      </div>
    `;
    card.addEventListener("click", e => {
      const btn = e.target.closest("button[data-act]");
      activeCard = it.id;
      if (btn) setDecision(it.id, btn.dataset.act, card);
    });
    card.addEventListener("mouseenter", () => { activeCard = it.id; });
    grid.appendChild(card);
  }
  refreshStats();
}

function setDecision(id, dec, card) {
  if (decisions[id] === dec) {
    delete decisions[id];
  } else {
    decisions[id] = dec;
  }
  saveDecisions();
  // Update just this card without full re-render
  card.className = "card" + (decisions[id] ? " dec-" + decisions[id] : "");
  card.querySelectorAll(".actions button").forEach(b => {
    b.classList.toggle("on", b.dataset.act === decisions[id]);
  });
}

document.querySelectorAll("[data-filter]").forEach(b => {
  b.addEventListener("click", () => {
    document.querySelectorAll("[data-filter]").forEach(x => x.classList.remove("active"));
    b.classList.add("active");
    activeFilter = b.dataset.filter;
    render();
  });
});
document.getElementById("sort").addEventListener("change", e => { activeSort = e.target.value; render(); });

document.addEventListener("keydown", e => {
  if (e.target.tagName === "INPUT" || e.target.tagName === "SELECT") return;
  if (!activeCard) return;
  if (e.key === "1" || e.key === "2" || e.key === "3") {
    const dec = {"1":"hero","2":"solid","3":"cut"}[e.key];
    const card = document.querySelector(`.card[data-id="${activeCard}"]`);
    if (card) setDecision(activeCard, dec, card);
  } else if (e.key === "0" || e.key === "Backspace") {
    if (decisions[activeCard]) {
      delete decisions[activeCard]; saveDecisions();
      const card = document.querySelector(`.card[data-id="${activeCard}"]`);
      if (card) {
        card.className = "card";
        card.querySelectorAll(".actions button").forEach(b => b.classList.remove("on"));
      }
    }
  }
});

document.getElementById("reset").addEventListener("click", () => {
  if (confirm("Clear ALL decisions? This cannot be undone.")) {
    decisions = {}; saveDecisions(); render();
  }
});

const dialog = document.getElementById("export-dialog");
const exportText = document.getElementById("export-text");
let exportTab = "json";

function buildExport() {
  const buckets = { hero: [], solid: [], cut: [] };
  for (const it of DATA) {
    const d = decisions[it.id];
    if (d) buckets[d].push(it);
  }
  if (exportTab === "json") {
    return JSON.stringify({
      generated: new Date().toISOString(),
      counts: { hero: buckets.hero.length, solid: buckets.solid.length, cut: buckets.cut.length, total: DATA.length },
      hero:  buckets.hero.map(i => i.id),
      solid: buckets.solid.map(i => i.id),
      cut:   buckets.cut.map(i => i.id),
    }, null, 2);
  }
  if (exportTab === "md") {
    const fmt = (arr) => arr.map(i => `- ${i.id}${i.displayName !== i.id ? ` — ${i.displayName}` : ""}${i.inCatalog ? ` (${i.month}/${i.day})` : " (orphan)"}`).join("\n");
    return `# Curation decisions — ${new Date().toISOString().slice(0,10)}\n\n` +
      `**Hero (${buckets.hero.length})** — App-Store-screenshot quality\n${fmt(buckets.hero)}\n\n` +
      `**Solid (${buckets.solid.length})** — ships fine\n${fmt(buckets.solid)}\n\n` +
      `**Cut (${buckets.cut.length})**\n${fmt(buckets.cut)}\n`;
  }
  if (exportTab === "swift") {
    const heroIds = buckets.hero.map(i => `"${i.id}"`).join(", ");
    const solidIds = buckets.solid.map(i => `"${i.id}"`).join(", ");
    const cutIds  = buckets.cut.map(i => `"${i.id}"`).join(", ");
    return `// Generated ${new Date().toISOString()}\n` +
      `// Use these sets to filter Artwork.catalog\n\n` +
      `static let heroIDs:  Set<String> = [${heroIds}]\n\n` +
      `static let solidIDs: Set<String> = [${solidIds}]\n\n` +
      `static let cutIDs:   Set<String> = [${cutIds}]\n`;
  }
}

document.getElementById("export").addEventListener("click", () => {
  exportText.textContent = buildExport();
  dialog.showModal();
});
document.querySelectorAll(".tab").forEach(b => {
  b.addEventListener("click", () => {
    document.querySelectorAll(".tab").forEach(x => x.classList.remove("active"));
    b.classList.add("active");
    exportTab = b.dataset.tab;
    exportText.textContent = buildExport();
  });
});
document.getElementById("close").addEventListener("click", () => dialog.close());
document.getElementById("copy").addEventListener("click", () => {
  navigator.clipboard.writeText(exportText.textContent);
  document.getElementById("copy").textContent = "Copied!";
  setTimeout(() => document.getElementById("copy").textContent = "Copy to clipboard", 1200);
});
document.getElementById("download").addEventListener("click", () => {
  const ext = { json:"json", md:"md", swift:"swift" }[exportTab];
  const blob = new Blob([exportText.textContent], { type:"text/plain" });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = `onehue-curation-${new Date().toISOString().slice(0,10)}.${ext}`;
  a.click();
});

render();
</script>
</body></html>
"""

# ---- Main -------------------------------------------------------------------

def main():
    items, missing_in_catalog = build_dataset()

    in_catalog = sum(1 for it in items if it["inCatalog"])
    orphans = sum(1 for it in items if not it["inCatalog"])
    suspect = sum(1 for it in items if it["score"] >= 30)

    print(f"Scanned {len(items)} SVGs in {ARTWORKS_DIR}")
    print(f"  in catalog: {in_catalog}")
    print(f"  orphans (SVG on disk, not in catalog): {orphans}")
    print(f"  suspect (anomaly score ≥ 30): {suspect}")
    if missing_in_catalog:
        print(f"  catalog entries with no matching SVG: {len(missing_in_catalog)}")
        for mid in missing_in_catalog[:10]:
            print(f"    - {mid}")

    html = HTML.replace("__DATA__", json.dumps(items))
    with open(OUT_FILE, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"\nWrote {OUT_FILE} ({len(html)//1024} KB)")
    print("Open it in a browser. Decisions persist in localStorage; export when done.")

if __name__ == "__main__":
    main()
