#!/usr/bin/env python3
"""
Extract prompts from firefly_prompts.txt and output them ready to paste into Firefly.

Usage:
    python3 tools/prompt_helper.py                  # Print all prompts
    python3 tools/prompt_helper.py --start 50       # Print from prompt #50 onward
    python3 tools/prompt_helper.py --range 10 20    # Print prompts #10-#20
    python3 tools/prompt_helper.py --id kingfisher   # Print prompts matching an ID
    python3 tools/prompt_helper.py --count           # Just count total prompts
"""

import argparse
import os
import re

SUFFIX = (
    ", flat digital illustration, large smooth color blocks, limited color palette, "
    "10 distinct colors, no gradients, no textures, clean shapes, minimal detail, "
    "vector art style, peaceful and serene"
)

def load_prompts(filepath):
    prompts = []
    with open(filepath) as f:
        for line in f:
            line = line.strip()
            match = re.match(r'^(\d{3})\s*\|\s*(\S+)\s*\|\s*(.+)$', line)
            if match:
                num = int(match.group(1))
                art_id = match.group(2)
                description = match.group(3).strip()
                prompts.append((num, art_id, description))
    return prompts


def main():
    parser = argparse.ArgumentParser(description="Extract Firefly prompts")
    parser.add_argument("--start", type=int, default=1, help="Start from prompt number")
    parser.add_argument("--range", type=int, nargs=2, metavar=("START", "END"),
                        help="Print prompts in range [START, END]")
    parser.add_argument("--id", type=str, help="Filter by artwork ID substring")
    parser.add_argument("--count", action="store_true", help="Just count prompts")
    parser.add_argument("--no-suffix", action="store_true", help="Omit the template suffix")
    args = parser.parse_args()

    script_dir = os.path.dirname(os.path.abspath(__file__))
    filepath = os.path.join(script_dir, "firefly_prompts.txt")
    prompts = load_prompts(filepath)

    if args.count:
        print(f"{len(prompts)} prompts loaded")
        return

    if args.range:
        start, end = args.range
        prompts = [p for p in prompts if start <= p[0] <= end]
    elif args.start > 1:
        prompts = [p for p in prompts if p[0] >= args.start]

    if args.id:
        prompts = [p for p in prompts if args.id.lower() in p[1].lower()]

    suffix = "" if args.no_suffix else SUFFIX

    for num, art_id, desc in prompts:
        full_prompt = desc + suffix
        print(f"\n{'='*70}")
        print(f"#{num:03d}  {art_id}")
        print(f"{'='*70}")
        print(full_prompt)

    print(f"\n--- {len(prompts)} prompts shown ---")


if __name__ == "__main__":
    main()
