# -*- coding: utf-8 -*-
import json, os

# Load hand-crafted detailed content overrides
crafts = {}
with open('create_content.py','r',encoding='utf-8') as f:
    # We'll parse the file and extract add_content / add calls.
    # Actually create_content.py uses add() not add_content; let's handle the pattern from earlier script
    pass

# === read leaves ===
leaves = []
with open('data/leaves.txt','r',encoding='utf-8') as f:
    for line in f:
        line=line.strip()
        if not line: continue
        name, path = line.split('\t')
        leaves.append((name, path.split('|')))

# === hard-coded rich map (subset) ===
rich = {
    '?ㅽ빆?앹쓽?㏃뀍': [
        "?ㅽ빆?앹쓽 ?㏃뀍? ?숈감??李⑥닔媛 媛숈? ???쇰━ 怨꾩닔瑜??뷀븯???곗궛?대떎. ???ㅽ빆??A(x)=a_n x^n+...+a_0? B(x)=b_n x^n+...+b_0???⑹? (a_n+b_n)x^n+...+(a_0+b_0)?대떎.",
        "怨꾩궛 ??媛숈? 李⑥닔????겮由щ쭔 ?뷀븯硫??섎ŉ, 臾몄옄? 李⑥닔??洹몃?濡??좎??쒕떎.",
        "?덉젣: (3x^2+2x+1)+(x^2-5x+4)瑜?怨꾩궛?섎㈃ 4x^2-3x+5?대떎."
    ],
    # ... many more would be here
}
print('Total leaves:', len(leaves))
