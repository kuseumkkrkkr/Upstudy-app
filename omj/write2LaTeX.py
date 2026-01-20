from pix2text import Pix2Text

p2t = Pix2Text()
mfr = Pix2Text(analyzer_config={"model_name": "mfr"})

page = p2t("test.jpg")

final = []

def extract_blocks(page_obj):
    if isinstance(page_obj, (list, tuple)):
        return page_obj
    for name in ("blocks", "data", "elements", "lines"):
        if hasattr(page_obj, name):
            attr = getattr(page_obj, name)
            return attr() if callable(attr) else attr
    if hasattr(page_obj, "to_list"):
        return page_obj.to_list()
    if hasattr(page_obj, "to_dict"):
        d = page_obj.to_dict()
        if isinstance(d, dict) and "blocks" in d:
            return d["blocks"]
        if isinstance(d, list):
            return d
    return [page_obj]

for block in extract_blocks(page):
    if isinstance(block, dict) and block.get("type") == "formula":
        mfr_page = mfr(block.get("box"))
        latex = mfr_page[0]["text"] if (isinstance(mfr_page, (list, tuple)) and len(mfr_page) > 0) else ""
        final.append({"type": "formula", "text": latex})
    else:
        final.append(block)

print("\n=== FINAL RESULT ===")
for r in final:
    print(r)
