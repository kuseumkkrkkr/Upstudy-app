# -*- coding: utf-8 -*-
"""
Book Generator (concept textbook auto-generation)
Reuses the shared SAM OpenAI-compatible calling pattern.
Each leaf concept produces a detailed JSON textbook under gen_textbook/output/*.json.
Usage:
    python omj/generater/book_gen.py --leaves all_leaves.txt --output gen_textbook/output --max-workers 3
"""

import argparse
import asyncio
import base64
import json
import os
import sys

# Insert project root (s11) to path so env_loader and generater can be imported
_PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
if _PROJECT_ROOT not in sys.path:
    sys.path.insert(0, _PROJECT_ROOT)

import env_loader
env_loader.load_env()

from services.ai.sam_client import DEFAULT_PROBLEM_MODEL, generate_json

DEFAULT_MODEL = DEFAULT_PROBLEM_MODEL

# ---- Korean prompt template loaded from base64 to avoid shell escaping ----
_BOOK_PROMPT_TEMPLATE = base64.b64decode(
    "7IiY7ZWZIOqwnOuFkCAne2NvbmNlcHRfbmFtZX0n7JeQIOuMgO2VnCDtlZnsirUg6rWQ7J6s66W8IOyekeyEse2VtCDso7zshLjsmpQuCu2VmeyDnSDsiJjspIA6IO2VnOq1rSDqs6Drk7HtlZnqtZAg7IiY7ZWZICjqs7XthrXsiJjtlZkxLCDqs7XthrXsoJXsiJgsIOuMgOyImCwg6riw7ZWYLCDrr7jsoIHrtoQpLgoK64uk7J2MIOyEuCDqsIDsp4Ag6rCA7J2065Oc65287J247J2EIOuwmOuTnOyLnCDstqnsobHtlbQg7KO87IS47JqUOgoKWzFdIOqwnOuFkCDsg4HshLgg7ISk66qFCi0g7J20IOqwnOuFkOydtCDrrLTsl4fsnbjsp4Ag66qF7ZmV7ZWY6rKMIOygleydmO2VtCDso7zshLjsmpQuCi0g7ZWE7JqU7ZWcIOyghOygnCDsobDqsbTsnbTrgpgg6rSA66CoIOqwnOuFkOydtCDsnojri6TrqbQg6rCE64uo7Z6IIOyWuOq4ie2VtCDso7zshLjsmpQuCi0g7J6s7ZWZ7IOd7J20IOydtO2VtO2VmOq4sCDsib3qsowsIOuFvOumrOyggeycvOuhnCDshKTrqoXtlbQg7KO87IS47JqULgoKWzJdIOqzteyLnSDrsI8gTGFUZVgg66CM642U66eBCi0g7ZW064u5IOqwnOuFkOyXkCDtlYTsmpTtlZwg66qo65OgIO2VteyLrCDqs7Xsi53snYQgJCQuLi4kJCDtmJXtg5zsnZggTGFUZVgg7IiY7Iud7Jy866GcIOyekeyEse2VtCDso7zshLjsmpQuCi0g7JiIOiAkJGFeMiArIGJeMiA9IGNeMiQkCi0g6rO17Iud7J2YIOydmOuvuOyZgCDqsIEg6riw7Zi46rCAIOustOyXh+ydhCDrnLvtlZjripTsp4Ag7ZWcIOusuOyepeyUqSDqsITri6jtnogg7ISk66qF7ZW0IOyjvOyEuOyalC4KClszXSDsmIjsoJwg67CPIO2SgOydtAotIOq1rOyytOyggeyduCDsiJjtlZkg7JiI7KCc66W8IDF+MuqwnCDsoJzsi5ztlZjqs6AsIOuLqOqzhOuzhCDtkoDsnbTrpbwg7Y+s7ZWo7ZW0IOyjvOyEuOyalC4KLSDtkoDsnbQg7KSRIO2VhOyalO2VnCDqs4TsgrAg6rO87KCV64+EIExhVGVYIOyImOyLneycvOuhnCDtkZztmITtlbQg7KO87IS47JqULgoK7Lac66ClIO2YleyLnToK7JWE656YIEpTT04g7ZiV7YOc7J2YIOqwneyytOulvCDrsJjtmZjtlZjshLjsmpQgKOuniO2BrOuLpOyatCDsvZTrk5wg67iU66GdIOq4iOyngCwg7Iic7IiYIEpTT07rp4wpLgoKewogICJuYW1lIjogIntjb25jZXB0X25hbWV9IiwKICAicGF0aCI6ICJ7Y29uY2VwdF9wYXRofSIsCiAgImRlc2NyaXB0aW9uIjogIuqwnOuFkCDsg4HshLgg7ISk66qFIO2FjeyKpO2KuCAoNn4xMCDrrLjsnqUpLi4uIiwKICAiZm9ybXVsYXMiOiBbCiAgICB7CiAgICAgICJsYXRleCI6ICIkJC4uLiQkIiwKICAgICAgImV4cGxhbmF0aW9uIjogIuydtCDqs7Xsi53snYAgLi4uIgogICAgfQogIF0sCiAgImV4YW1wbGVzIjogWwogICAgewogICAgICAicHJvYmxlbSI6ICLrrLjsoJwg7YWN7Iqk7Yq4Li4uIiwKICAgICAgInNvbHV0aW9uIjogIu2SgOydtCDthY3siqTtirguLi4iCiAgICB9CiAgXQp9Cg=="
).decode('utf-8')


def parse_leaves(path: str) -> list:
    """Parse all_leaves.txt into list[{'name':..., 'path':[...]}]."""
    leaves = []
    if not os.path.exists(path):
        raise FileNotFoundError(f"{path} not found")
    with open(path, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            if '\t' in line:
                name, raw_path = line.split('\t', 1)
                leaves.append({"name": name, "path": raw_path.split('|')})
            else:
                leaves.append({"name": line, "path": [line]})
    return leaves


def _extract_json_text(raw: str) -> str:
    text = raw or ""
    if text.startswith("```"):
        text = text.lstrip("`").split("\n", 1)[-1]
    if text.endswith("```"):
        text = text.rsplit("\n", 1)[0]
    return text.strip()


def call_api_sync(prompt: str, model: str = DEFAULT_MODEL) -> str:
    """Synchronous SAM call."""
    data = generate_json(
        model=model,
        prompt=prompt,
        temperature=0.3,
        max_tokens=4096,
    )
    return json.dumps(data, ensure_ascii=False)


async def generate_concept(concept: dict, model: str, output_dir: str) -> str:
    """Generate and save textbook for a single concept."""
    prompt = _BOOK_PROMPT_TEMPLATE.format(
        concept_name=concept["name"],
        concept_path=" > ".join(concept["path"]),
    )
    try:
        loop = asyncio.get_running_loop()
        raw_json = await loop.run_in_executor(None, call_api_sync, prompt, model)
        data = json.loads(raw_json)
    except Exception as e:
        data = {
            "name": concept["name"],
            "path": " > ".join(concept["path"]),
            "description": f"[ERROR {type(e).__name__}: {e}]",
            "formulas": [],
            "examples": [],
            "_error": str(e),
        }

    safe_name = concept["name"].replace("/", "_").replace("\\", "_")
    out_path = os.path.join(output_dir, f"{safe_name}.json")
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    status = "OK" if "_error" not in data else "ERROR"
    print(f"[{status}] {concept['name']} -> {out_path}")
    return out_path


async def main():
    parser = argparse.ArgumentParser(description="Concept Textbook Generator")
    parser.add_argument("--leaves", default="all_leaves.txt", help="Leaf concepts file")
    parser.add_argument("--output", default="gen_textbook/output", help="Output directory")
    parser.add_argument("--model", default=DEFAULT_MODEL, help="Model name")
    parser.add_argument("--max-workers", type=int, default=3, help="Concurrent API calls")
    args = parser.parse_args()

    os.makedirs(args.output, exist_ok=True)
    leaves = parse_leaves(args.leaves)
    print(f"Total concepts: {len(leaves)}, max workers: {args.max_workers}")

    semaphore = asyncio.Semaphore(args.max_workers)

    async def fetch(c):
        async with semaphore:
            return await generate_concept(c, args.model, args.output)

    tasks = [asyncio.create_task(fetch(c)) for c in leaves]
    results = await asyncio.gather(*tasks, return_exceptions=True)

    ok = sum(1 for r in results if isinstance(r, str))
    print(f"\nDone: {ok}/{len(leaves)}")


if __name__ == "__main__":
    asyncio.run(main())
