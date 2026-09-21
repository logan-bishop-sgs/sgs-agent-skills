#!/usr/bin/env python3

"""Azure OpenAI vision hint when AniTa classifier/heuristics are stuck.



Tier-2 only: set ANITA_LLM_ESCALATE=1 (runner does this after second failure).
ANITA_LLM_ASSIST=0 disables all calls. Returns JSON on stdout:

{"action":"...","reason":"..."}



Does not send secrets; image is canvas PNG only.

"""

from __future__ import annotations



import argparse

import base64

import json

import os

import re

import sys

from pathlib import Path



LOGIN_ACTIONS = frozenset({"y_enter", "wait_10s", "abort_relogin", "none"})

EXPORT_ACTIONS = frozenset(

    {

        "see_sales_s",

        "group_g",

        "key_f7",

        "key_esc",

        "page_up",

        "y_enter",

        "wait_10s",

        "none",

        "escalate_human",

    }

)





def llm_enabled() -> bool:
    if os.environ.get("ANITA_LLM_ASSIST", "").strip().lower() in ("0", "false", "no", "off"):
        return False
    return os.environ.get("ANITA_LLM_ESCALATE", "").strip().lower() in ("1", "true", "yes")





def load_dotenv(path: Path) -> None:

    if not path.is_file():

        return

    for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():

        line = raw.strip()

        if not line or line.startswith("#") or "=" not in line:

            continue

        k, v = line.split("=", 1)

        k, v = k.strip(), v.strip().strip('"').strip("'")

        if k and k not in os.environ:

            os.environ[k] = v





def normalize_endpoint(url: str) -> str:

    url = url.rstrip("/")

    if "/openai/deployments/" in url:

        url = url.split("/openai/deployments/")[0]

    return url





def parse_json_object(text: str) -> dict:

    text = text.strip()

    if text.startswith("```"):

        text = re.sub(r"^```(?:json)?\s*", "", text)

        text = re.sub(r"\s*```$", "", text)

    return json.loads(text)





def system_prompt(mode: str) -> str:

    if mode == "export":

        allow = ", ".join(sorted(EXPORT_ACTIONS))

        return (

            "You advise a fixed AniTa SEE SALES group-export automaton. Reply JSON only: "

            '{"action":"<allowed>","reason":"short"}'

            f" Allowed actions: {allow}. "

            "Goal: reach service Group list or product-for-service-group grid for the current month. "

            "If on account view or wrong drill-down, use see_sales_s or key_esc. "

            "If on month list (See sales), use group_g or key_f7 to open service Group. "

            "If stale DONE banner or export complete overlay, see_sales_s then group_g. "

            "If loading/unreadable, wait_10s. "

            "If truly stuck after obvious recovery, escalate_human (Logan only after this). "

            "Never suggest F11, passwords, or typing usernames."

        )

    allow = ", ".join(sorted(LOGIN_ACTIONS))

    return (

        "You advise a fixed AniTa LIMS login automaton. Reply with JSON only: "

        '{"action":"<allowed>","reason":"short"}'

        f" Allowed actions: {allow}. "

        "If the screen shows Linux REMOVE? or SESSIONS CURRENTLY EXIST, use y_enter. "

        "If Oracle IFORMS logon denied / invalid user with no recovery path, use abort_relogin. "

        "If the screen is still loading or unreadable, use wait_10s. "

        "Never suggest typing passwords, usernames, F11, or Backspace."

    )





def main() -> int:

    ap = argparse.ArgumentParser()

    ap.add_argument("--phase", required=True)

    ap.add_argument("--host", required=True)

    ap.add_argument("--classifier", default="")

    ap.add_argument("--image", required=True, help="Path to canvas or snap png")

    ap.add_argument("--repo-root", default="")

    ap.add_argument("--mode", choices=("login", "export"), default="login")

    args = ap.parse_args()



    if not llm_enabled():

        print(json.dumps({"action": "none", "reason": "ANITA_LLM_ASSIST disabled"}))

        return 0



    repo = Path(args.repo_root) if args.repo_root else Path(__file__).resolve().parents[4]

    load_dotenv(repo / ".env")



    api_key = os.environ.get("AZURE_OPENAI_API_KEY", "").strip()

    endpoint = normalize_endpoint(os.environ.get("AZURE_OPENAI_ENDPOINT", "").strip())

    deployment = os.environ.get("AZURE_OPENAI_DEPLOYMENT", "gpt-4.1").strip()

    api_version = os.environ.get("AZURE_OPENAI_API_VERSION", "2024-12-01-preview").strip()



    img_path = Path(args.image)

    if not img_path.is_file():

        print(json.dumps({"action": "none", "reason": f"image missing: {img_path}"}))

        return 2



    if not api_key or not endpoint:

        print(json.dumps({"action": "none", "reason": "Azure OpenAI env not set"}))

        return 2



    try:

        from openai import AzureOpenAI

    except ImportError:

        print(json.dumps({"action": "none", "reason": "pip install openai"}))

        return 2



    allowed = EXPORT_ACTIONS if args.mode == "export" else LOGIN_ACTIONS



    b64 = base64.standard_b64encode(img_path.read_bytes()).decode("ascii")

    user_text = (

        f"Phase: {args.phase}\nHost: {args.host}\nClassifier line: {args.classifier}\n"

        "What single allowed action should run next?"

    )



    client = AzureOpenAI(

        azure_endpoint=endpoint,

        api_key=api_key,

        api_version=api_version,

    )

    resp = client.chat.completions.create(

        model=deployment,

        messages=[

            {"role": "system", "content": system_prompt(args.mode)},

            {

                "role": "user",

                "content": [

                    {"type": "text", "text": user_text},

                    {

                        "type": "image_url",

                        "image_url": {"url": f"data:image/png;base64,{b64}"},

                    },

                ],

            },

        ],

        max_tokens=200,

        temperature=0,

    )

    raw = (resp.choices[0].message.content or "").strip()

    try:

        obj = parse_json_object(raw)

    except json.JSONDecodeError:

        print(json.dumps({"action": "none", "reason": f"non-json model output: {raw[:200]}"}))

        return 1



    action = str(obj.get("action", "none")).strip().lower()

    if action not in allowed:

        action = "none"

    out = {"action": action, "reason": str(obj.get("reason", ""))[:500]}

    print(json.dumps(out))

    return 0





if __name__ == "__main__":

    raise SystemExit(main())

