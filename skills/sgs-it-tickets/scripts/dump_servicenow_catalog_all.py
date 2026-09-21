"""Collect ServiceNow catalog item links from the logged-in Edge session (CDP 9223).

Uses portal browse URLs, category pages, and single-letter search sweeps.
Writes JSON + a DNS/domain-filtered markdown summary. Does not Submit anything.
"""

from __future__ import annotations

import json
import re
import sys
import urllib.parse
from datetime import datetime, timezone
from pathlib import Path

from playwright.sync_api import sync_playwright

CDP = "http://127.0.0.1:9223"
BASE = "https://sgs.service-now.com"

BROWSE_URLS = [
    f"{BASE}/sp",
    f"{BASE}/sp?id=esc_catalog_tree",
    f"{BASE}/sp?id=services",
    f"{BASE}/sp?id=index",
    f"{BASE}/sp?catalog=true",
    f"{BASE}/sp?id=sc_category&sys_id=7c2e77891b33f01040b0eb186e4bcb72",
]

DNS_KEYWORDS = re.compile(
    r"dns|domain|subdomain|fqdn|cname|hostname|ssl|certificate|tls|"
    r"azure web|app service|internet resource|sgs\.com|website|url|waf",
    re.I,
)


def _collect_links(page) -> list[dict]:
    return page.evaluate(
        """() => {
      const out = [];
      const seen = new Set();
      for (const a of document.querySelectorAll('a[href]')) {
        const href = a.getAttribute('href') || '';
        if (!href.includes('sc_cat_item')) continue;
        const m = href.match(/sys_id=([a-f0-9]{32})/i);
        if (!m) continue;
        const sys_id = m[1];
        const title = (a.innerText || a.getAttribute('title') || '').trim().replace(/\\s+/g, ' ');
        if (!title || title === 'Profile') continue;
        const key = sys_id;
        if (seen.has(key)) continue;
        seen.add(key);
        let url = href;
        if (url.startsWith('?')) url = 'https://sgs.service-now.com/sp' + url;
        else if (url.startsWith('/')) url = 'https://sgs.service-now.com' + url;
        out.push({ sys_id, title, href: href.slice(0, 200), url });
      }
      return out;
    }"""
    )


def _goto(page, url: str, *, scroll: bool = False) -> None:
    try:
        page.goto(url, wait_until="load", timeout=120_000)
    except Exception:
        page.goto(url, wait_until="domcontentloaded", timeout=120_000)
    page.wait_for_timeout(5000)
    if scroll:
        for _ in range(10):
            page.mouse.wheel(0, 2500)
            page.wait_for_timeout(600)


def _collect_from_html(page) -> list[dict]:
    """Also match sys_id= in raw HTML (SPA templates)."""
    html = page.content()
    sids: set[str] = set()
    for m in re.finditer(r"sys_id=([a-f0-9]{32})", html, re.I):
        sids.add(m.group(1))
    return [
        {
            "sys_id": sid,
            "title": f"(html-only {sid[:8]}…)",
            "url": f"{BASE}/sp?id=sc_cat_item&sys_id={sid}",
            "sources": ["html"],
        }
        for sid in sorted(sids)
    ]


DNS_CATEGORY = f"{BASE}/sp?id=sc_category&sys_id=7c2e77891b33f01040b0eb186e4bcb72"

SEARCH_QUERIES = [
    "dns",
    "domain",
    "subdomain",
    "cname",
    "fqdn",
    "ssl",
    "certificate",
    "azure web",
    "web app",
    "app service",
    "hostname",
    "internet",
    "waf",
    "cloud",
    "azure",
    "network",
    "iam",
    "entra",
    "access request",
]


def _try_api(page) -> tuple[list[dict], list[dict]]:
    return page.evaluate(
        """async () => {
      const endpoints = [
        '/api/sn_sc/servicecatalog/items?sysparm_limit=100&sysparm_offset=0',
        '/api/now/table/sc_cat_item?sysparm_limit=100&sysparm_fields=sys_id,name,short_description,active&sysparm_query=active=true^ORDERBYname',
      ];
      const items = [];
      const log = [];
      for (const path of endpoints) {
        let offset = 0;
        for (let pageNum = 0; pageNum < 30; pageNum++) {
          const paged = path.includes('offset=')
            ? path.replace(/offset=\\d+/, 'offset=' + offset)
            : path + (path.includes('?') ? '&' : '?') + 'sysparm_offset=' + offset;
          if (!paged.includes('offset') && offset > 0) {
            const sep = path.includes('?') ? '&' : '?';
            paged = path + sep + 'sysparm_offset=' + offset;
          }
          try {
            const r = await fetch(paged, { credentials: 'include' });
            const text = await r.text();
            if (!r.ok) {
              log.push({ path: paged, status: r.status, error: text.slice(0, 300) });
              break;
            }
            const data = JSON.parse(text);
            const rows = data.result || data;
            if (!Array.isArray(rows) || rows.length === 0) break;
            for (const row of rows) {
              const sys_id = row.sys_id || row.id;
              const title = row.name || row.title || row.short_description || '';
              if (sys_id && title) {
                items.push({
                  sys_id,
                  title: String(title).trim(),
                  url: `https://sgs.service-now.com/sp?id=sc_cat_item&sys_id=${sys_id}`,
                  source: paged,
                });
              }
            }
            if (rows.length < 100) break;
            offset += 100;
          } catch (e) {
            log.push({ path: paged, error: String(e) });
            break;
          }
        }
      }
      return [items, log];
    }"""
    )


def main() -> int:
    repo = Path(__file__).resolve()
    for parent in repo.parents:
        candidate = parent / "ehs_dashboard" / "CONTEXT" / "drafts"
        if (parent / "ehs_dashboard" / "main.py").is_file():
            out_dir = candidate
            break
    else:
        out_dir = Path(__file__).resolve().parents[4] / "ehs_dashboard" / "CONTEXT" / "drafts"
    out_dir.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    json_path = out_dir / f"servicenow-catalog-dump-{stamp}.json"
    md_path = out_dir / f"servicenow-catalog-dns-hits-{stamp}.md"

    pw = sync_playwright().start()
    browser = pw.chromium.connect_over_cdp(CDP)
    ctx = browser.contexts[0]
    page = ctx.pages[0] if ctx.pages else ctx.new_page()

    merged: dict[str, dict] = {}
    meta: dict = {"started_url": page.url, "sources": []}

    if "login.microsoftonline.com" in page.url:
        print("LOGIN_REQUIRED: sign in to ServiceNow in Edge (CDP 9223) first.", file=sys.stderr)
        pw.stop()
        return 20

    api_rows, api_log = _try_api(page)
    meta["api_log"] = api_log
    meta["api_count"] = len(api_rows)
    for row in api_rows:
        if "sys_id" in row and row.get("title"):
            merged[row["sys_id"]] = {
                "sys_id": row["sys_id"],
                "title": row["title"],
                "url": row.get("url") or f"{BASE}/sp?id=sc_cat_item&sys_id={row['sys_id']}",
                "sources": ["api"],
            }

    def _merge(items: list[dict], source: str) -> None:
        for it in items:
            if "sc_cat_item" not in it.get("href", "") and source != "html":
                if not it.get("url", "").startswith(f"{BASE}/sp?id=sc_cat_item"):
                    continue
            sid = it["sys_id"]
            if sid not in merged:
                merged[sid] = {**it, "sources": [source]}
            elif source not in merged[sid]["sources"]:
                merged[sid]["sources"].append(source)

    for url in BROWSE_URLS:
        _goto(page, url)
        if "login.microsoftonline.com" in page.url:
            print("LOGIN_REQUIRED during browse", file=sys.stderr)
            pw.stop()
            return 20
        items = _collect_links(page)
        meta["sources"].append({"url": url, "title": page.title(), "count": len(items)})
        _merge(items, url)

    _goto(page, DNS_CATEGORY)
    html_path = out_dir / f"servicenow-dns-category-html-{stamp}.html"
    html_path.write_text(page.content(), encoding="utf-8")
    meta["dns_category_html"] = str(html_path.name)
    meta["dns_category_title"] = page.title()
    _merge(_collect_links(page) + _collect_from_html(page), DNS_CATEGORY)

    for q in SEARCH_QUERIES:
        enc = urllib.parse.quote(q)
        search_url = f"{BASE}/sp?id=search&spa=1&t=sc&q={enc}"
        _goto(page, search_url, scroll=True)
        if "login.microsoftonline.com" in page.url:
            print("LOGIN_REQUIRED during search", file=sys.stderr)
            pw.stop()
            return 20
        items = _collect_links(page)
        meta["sources"].append({"search": q, "count": len(items)})
        _merge(items, f"search:{q}")

    all_items = sorted(merged.values(), key=lambda x: x["title"].lower())
    dns_hits = [x for x in all_items if DNS_KEYWORDS.search(x["title"])]

    payload = {
        "generated_utc": datetime.now(timezone.utc).isoformat(),
        "total_unique_items": len(all_items),
        "meta": meta,
        "items": all_items,
        "dns_related_titles": dns_hits,
    }
    json_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")

    md_lines = [
        f"# ServiceNow catalog DNS/domain-related items ({stamp} UTC)",
        "",
        f"Full dump: `{json_path.name}` ({len(all_items)} unique `sc_cat_item` links).",
        "",
        "| Title | sys_id | URL |",
        "|---|---|---|",
    ]
    for it in dns_hits:
        md_lines.append(
            f"| {it['title']} | `{it['sys_id']}` | {it['url']} |"
        )
    md_path.write_text("\n".join(md_lines) + "\n", encoding="utf-8")

    print(f"Wrote {json_path}")
    print(f"Wrote {md_path} ({len(dns_hits)} DNS/domain hits / {len(all_items)} total)")
    pw.stop()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
