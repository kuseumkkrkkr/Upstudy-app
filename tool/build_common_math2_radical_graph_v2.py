"""Create a graph-exploration supplement for the 2022 radical-function criterion."""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
MANUSCRIPTS=ROOT/"docs/advanced-generation-vault/07 Data/교재 원고"
STANDARDS=ROOT/"work/official-curriculum/2022_math_standards.json"
OUT=MANUSCRIPTS/"공통수학2_2022개정_무리함수그래프탐구_Batch1_BookData_V2_시범.json"
PACKAGE=MANUSCRIPTS/"공통수학2_2022개정_무리함수그래프탐구_Batch1_원고패키지"
CODE="10공수2-03-05"

def block(kind,title,text,**extra): return {"type":kind,"title":title,"text":text,**extra}
def page(pid,template,title,*blocks): return {"id":pid,"template":template,"title":title,"blocks":list(blocks)}

def make_book():
    pages=[
      page("radical-open","opening","정의역과 그래프의 시작점을 함께 보기",
        block("lead","기준 연결",f"2022 개정 기준 {CODE}: 무리함수의 그래프를 그리고 성질을 탐구합니다."),
        block("thinking","오늘의 질문","y=√(2x+2)+1의 그래프는 어디서 시작하고, 어느 방향으로 이어질까요?")),
      page("radical-concept","concept","제곱근 안의 조건과 그래프 시작점",
        block("definition","기본형","y=√(ax+b)+c (a≠0)에서 ax+b≥0이어야 하므로 정의역의 경계는 x=−b/a입니다."),
        block("formula","시작점과 치역","경계에서 제곱근 값은 0이므로 그래프는 (−b/a,c)에서 시작합니다. √값은 0 이상이므로 치역은 y≥c입니다."),
        block("misconception","계수 부호","a>0이면 경계부터 오른쪽으로, a<0이면 경계부터 왼쪽으로 그래프가 이어집니다.")),
      page("radical-example","example","함숫값을 계산해 그래프를 그리기",
        block("question","예제","g(x)=√(2x+2)+1의 정의역, 시작점, g(0)을 구하세요."),
        block("solutionStep","정의역","2x+2≥0이므로 x≥−1입니다."),
        block("solutionStep","시작점과 함숫값","x=−1에서 g(−1)=1이므로 시작점은 (−1,1)입니다. g(0)=√2+1≈2.414입니다."),
        block("answer","그래프 정보","x=−1부터 오른쪽으로 이어지며 y값은 1 이상입니다.")),
      page("radical-practice","practice","계수 부호에 따른 정의역 비교",
        block("question","연습","h(x)=√(−x+3)−2의 정의역, 시작점, 치역을 구하세요."),
        block("solutionStep","풀이","−x+3≥0이므로 x≤3입니다. 경계 x=3에서 함수값은 −2입니다."),
        block("answer","정답","정의역은 x≤3, 시작점은 (3,−2), 치역은 y≥−2입니다.")),
      page("radical-explore","experiment","매개변수로 그래프 탐구하기",
        block("lead","조작 순서","a를 바꾸어 그래프가 시작하는 방향을 비교하고 b로 시작 x좌표, c로 시작 y좌표가 어떻게 달라지는지 확인하세요."),
        {"type":"activity","activity":{"id":"radical-function-explorer-2022","kind":"radicalFunctionExplorer",
          "prompt":"y=√(ax+b)+c의 정의역과 그래프 시작점·치역을 탐구합니다.",
          "hints":["ax+b=0을 풀어 경계 x를 찾습니다.","경계에서 y=c이며 제곱근은 음수가 될 수 없습니다."],
          "explorer":{"a_values":[-2,-1,1,2],"initial_a":2,"min_b":-2,"max_b":2,"b_step":0.5,"initial_b":2,"min_c":-3,"max_c":3,"c_step":0.5,"initial_c":1}}}),
      page("radical-quiz","practice","그래프 시작점 확인",
        block("question","퀴즈","y=√(2x+2)+1의 그래프 시작점은?"),
        {"type":"activity","activity":{"id":"radical-startpoint-quiz-2022","kind":"quiz",
          "prompt":"y=√(2x+2)+1의 그래프 시작점은?","options":["(−1,1)","(1,−1)","(−2,1)"],"correct_index":0,
          "correct_feedback":"2x+2=0에서 x=−1이고 함수값은 1입니다.",
          "incorrect_feedback":"먼저 제곱근 안이 0이 되는 x를 찾고 바깥의 +1을 반영하세요.",
          "hints":["2x+2=0을 풉니다.","경계에서 √0+1을 계산합니다."]}}),
      page("radical-summary","summary","정의역·시작점·치역으로 검산하기",
        block("summary","핵심 정리","y=√(ax+b)+c는 ax+b≥0인 x에서 정의됩니다. 경계 x=−b/a에서 (−b/a,c)로 시작하며 치역은 y≥c입니다."),
        block("checklist","스스로 점검","a의 부호로 그래프가 이어지는 방향을 정하고, 시작점과 치역을 그래프와 연결했나요?")),
    ]
    return {"schema_version":2,"title":"공통수학2 · 무리함수 그래프 탐구 보충 후보",
      "subtitle":"정의역과 시작점 설명을 그래프 작도·성질 탐구로 확장",
      "category":"concept_textbook_prototype","curriculum_version":"2022",
      "tags":["공통수학2","2022 개정","무리함수","그래프 탐구",CODE],"standard_codes":[CODE],
      "metadata":{"publication_eligibility":"not_eligible","rights_status":"pending","teacher_review_status":"pending","math_review_status":"author_checks_recorded_independent_review_pending"},
      "chapters":[{"title":"무리함수 그래프와 성질 탐구","standard_codes":[CODE],"pages":pages}]}

def validate(book):
    standards=json.loads(STANDARDS.read_text(encoding="utf-8"))["standards"]
    row=next(r for r in standards if r["code"]==CODE)
    assert "그래프를 그릴" in row["criterion"] and "성질" in row["criterion"]
    assert len(book["chapters"])==1 and len(book["chapters"][0]["pages"])==7
    assert book["chapters"][0]["standard_codes"]==[CODE]
    assert -2/2==-1 and math.sqrt(2*0+2)+1==1+math.sqrt(2)
    second_start=-3/(-1)
    assert second_start==3 and math.sqrt(-second_start+3)-2==-2
    assert math.sqrt(-2+3)-2==-1
    acts=[b["activity"] for p in book["chapters"][0]["pages"] for b in p["blocks"] if b.get("type")=="activity"]
    assert {a["kind"] for a in acts}=={"quiz","radicalFunctionExplorer"}

def main():
    book=make_book(); validate(book)
    OUT.write_text(json.dumps(book,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    PACKAGE.mkdir(parents=True,exist_ok=True)
    (PACKAGE/"README.md").write_text(f"# 공통수학2 무리함수 그래프 탐구 보충 후보\n\n원본: [`{OUT.name}`](../{OUT.name})\n\n기존 {CODE} 후보는 정의역·시작점 설명은 있으나 graph 데이터나 그래프 조작이 없어 그래프 작도와 성질 탐구를 보완한다. 공식 기준, 교사·독립 수학·권리 검토는 대기 중이다.\n",encoding="utf-8")
    manifest={"bookdata_file":OUT.name,"bookdata_sha256":hashlib.sha256(OUT.read_bytes()).hexdigest(),
      "candidate_code_references":[CODE],"candidate_code_reference_type":"official_2022_hwp_standard",
      "module_count":1,"page_count":7,"native_activity_count":2,"native_activity_kinds":["radicalFunctionExplorer","quiz"],
      "curriculum_review_status":"pending","math_review_status":"pending_independent_review","teacher_review_status":"pending",
      "rights_status":"pending","publication_eligibility":"not_eligible","integration_status":"supplement_not_merged"}
    (PACKAGE/"REVIEW_MANIFEST.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print("Generated one 2022 Common Math 2 radical-function graph supplement (7 pages, 2 activities).")

if __name__=="__main__": main()
