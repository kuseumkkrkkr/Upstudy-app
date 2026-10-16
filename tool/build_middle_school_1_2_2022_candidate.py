"""Build an original, semester-unassigned 2022 middle-school candidate book."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고/중학수학1-2_2022개정_통합시범"
BOOK_FILE = "중학수학1-2_2022개정_수학의언어와자료_BookData_시범.json"

BASE_TAGS = [
    "중학수학 1-2", "2022 개정", "학기 배정 후보", "공식 학기 배열 아님",
    "교사 검수 대기", "출처: NCIC 국가교육과정정보센터 별책8 수학과 교육과정",
    "저작권: 신규 집필 초안, 상업 교재 문장·문제·그림 미사용",
]

def block(kind: str, title: str, text: str = "", **extra: object) -> dict:
    return {"type": kind, "title": title, "text": text, **extra}

def page(pid: str, template: str, title: str, kicker: str, blocks: list[dict]) -> dict:
    return {"id": pid, "template": template, "title": title, "kicker": kicker, "blocks": blocks}

def make_chapter(code: str, slug: str, title: str, standard: str, html_file: str,
                 opening: str, concept: str, example: str, solution: str,
                 practice: str, answer: str, summary: list[str]) -> dict:
    return {
        "title": title,
        "intro": [f"{title}를 예측·조작·설명으로 익힙니다.",
                  f"교육부 고시 제2022-33호 별책8의 {standard} 관련 후보 시범입니다. 성취기준 코드는 중학교 학년군에 제시되며 학기 귀속은 확인되지 않았습니다."],
        "sections": [{"title": "학습 기준과 자산", "paragraphs": [
            f"기준 후보: {standard}. 이 단원의 조작 자료는 {html_file}에 별도 보존합니다.",
            "이 책은 새로 쓴 검토용 초안입니다. 교육과정 원문 표현이나 상업 교재의 설명·문제·그림을 옮기지 않았습니다.",
        ]}],
        "pages": [
            page(f"{slug}-opening", "opening", opening, "먼저 예측하기", [
                block("lead", "오늘의 질문", opening),
                block("thinking", "생각 열기", "관찰한 사실과 추측을 구분해 말해 보세요."),
                block("hint", "힌트", "대상을 하나씩 표시하고, 무엇이 바뀌지 않는지 찾아보세요."),
                block("answer", "오늘의 목표", f"{title}의 기준을 말과 그림으로 설명합니다."),
            ]),
            page(f"{slug}-experiment", "experiment", "직접 바꾸며 확인하기", "체험 도구", [
                block("lead", "조작", f"독립 체험 파일 {html_file}에서 값을 바꾸고 결과를 관찰하세요."),
                block("thinking", "관찰 질문", "값을 바꾸어도 유지되는 관계는 무엇인가요?"),
                block("hint", "힌트", "한 번에 한 조건만 바꾸고, 바꾸기 전후를 비교하세요."),
                block("answer", "확인", "체험 도구는 원고와 별도 파일로 보존됩니다. 앱에서 자동 실행되는 기능은 아닙니다."),
            ]),
            page(f"{slug}-concept", "concept", "핵심 개념", "정의와 이유", [
                block("definition", "기억할 내용", concept),
                block("formula", "표현", standard),
                block("misconception", "주의", "그림의 겉모양만으로 결론을 내리지 말고 주어진 조건과 정의를 확인하세요."),
                block("checklist", "스스로 말하기", items=["정의나 규칙을 말로 설명한다.", "그림·표·수식이 같은 내용을 나타내는지 확인한다."]),
            ]),
            page(f"{slug}-example", "example", "예제와 풀이", "근거를 적기", [
                block("question", "예제", example),
                block("solutionStep", "풀이 1", solution),
                block("verification", "검산", "조건을 다시 대입하거나 다른 표현으로 바꾸어 답을 확인합니다."),
                block("answer", "결론", "답뿐 아니라 사용한 정의와 이유를 함께 적습니다."),
            ]),
            page(f"{slug}-practice", "practice", "혼자 풀기", "연습과 해설", [
                block("question", "연습", practice),
                block("thinking", "Socratic 질문", "어떤 조건을 먼저 확인했고, 그 조건이 왜 필요한가요?"),
                block("hint", "힌트", "예제에서 쓴 조건을 하나씩 점검하고, 필요한 계산을 분리하세요."),
                block("solutionStep", "해설", answer),
                block("answer", "정답 확인", answer),
            ]),
            page(f"{slug}-summary", "summary", "한 줄로 정리하기", "마무리", [
                block("summary", "핵심", " · ".join(summary)),
                block("checklist", "점검", items=summary),
            ]),
        ],
    }

def chapters() -> list[dict]:
    return [
        make_chapter(
            "geometry-terms", "ms12-22-geometry-terms", "점·선·면과 각의 언어", "9수03-01",
            "중학수학1-2_2022개정_점선면과각_체험형_시범.html",
            "지도 위 두 도로가 만나는 곳을 점 하나로 나타내도 충분할까요? 수학에서 점·선·면은 실제 물체와 어떻게 다를까요?",
            "점은 위치를 나타내며 크기를 갖지 않는 대상으로 다룹니다. 직선은 양쪽으로 끝없이 이어지고, 반직선은 시작점과 한 방향을 정하며, 선분은 양 끝점을 정합니다. 각은 한 점에서 시작하는 두 반직선이 벌어진 정도입니다. 각의 크기는 두 변의 길이가 아니라 벌어진 정도로 정합니다.",
            "한 점 O에서 시작하는 두 반직선 OA, OB가 있을 때 ∠AOB에서 꼭짓점은 어디인가요? OA의 길이만 두 배로 늘리면 각의 크기도 두 배가 될까요?",
            "꼭짓점은 O입니다. 각의 크기는 두 반직선의 벌어진 정도이므로 OA의 길이만 늘려도 각은 변하지 않습니다. 각을 세 글자로 쓸 때 꼭짓점 O를 가운데 씁니다.",
            "그림에서 점 P를 시작점으로 하고 Q 방향으로 끝없이 한쪽만 이어지는 도형의 이름과 기호를 쓰세요. 또한 ∠XYZ의 꼭짓점을 고르세요.",
            "첫 도형은 반직선 PQ입니다. ∠XYZ의 꼭짓점은 가운데 글자인 Y입니다. 도형이 선분인지 반직선인지 직선인지는 끝점의 수와 연장 방향으로 판별합니다.",
            ["점은 위치를 나타낸다.", "직선·반직선·선분은 끝점과 연장 방향으로 구별한다.", "각의 꼭짓점은 세 글자 표기에서 가운데에 온다."],
        ),
        make_chapter(
            "triangle-construction", "ms12-22-triangle-construction", "조건을 이용해 삼각형 작도하기", "9수03-03",
            "중학수학1-2_2022개정_삼각형작도_체험형_시범.html",
            "세 변의 길이가 같은 두 삼각형은 꼭 같은 크기와 모양일까요? 자와 컴퍼스로 확인할 방법을 계획해 보세요.",
            "세 변의 길이를 a, b, c라 할 때 삼각형이 되려면 가장 긴 변의 길이가 나머지 두 변의 합보다 작아야 합니다. 조건을 만족하면 한 변을 먼저 긋고, 양 끝점을 중심으로 나머지 두 길이의 원호를 그어 교점을 찾습니다. 교점을 연결하면 주어진 세 변을 가진 삼각형을 작도할 수 있습니다.",
            "세 변의 길이가 4, 5, 7인 삼각형을 작도할 수 있는지 확인하고, 작도 순서를 설명하세요.",
            "4+5>7, 4+7>5, 5+7>4이므로 삼각형이 가능합니다. 길이 7인 선분을 그리고, 양 끝점을 중심으로 반지름 4와 5인 원호를 그립니다. 교점을 세 번째 꼭짓점으로 정해 양 끝점과 잇습니다.",
            "세 변의 길이가 2, 3, 6인 삼각형은 작도할 수 있나요? 가장 짧은 이유를 쓰세요.",
            "작도할 수 없습니다. 2+3=5가 6보다 작아서 두 짧은 변을 이어도 가장 긴 변까지 닿지 못합니다. 삼각형의 부등식을 만족하지 않습니다.",
            ["삼각형의 세 변은 삼각형 부등식을 만족한다.", "밑변과 두 원호의 교점으로 세 변 길이가 정해진 삼각형을 작도한다.", "작도 방법을 순서와 근거로 설명한다."],
        ),
        make_chapter(
            "polygon-angle-sum", "ms12-22-polygon-angle-sum", "다각형의 각과 대각선 탐구", "9수03-05",
            "중학수학1-2_2022개정_다각형각과대각선_체험형_시범.html",
            "다각형의 꼭짓점 수가 늘면 안쪽 각의 합과 대각선 수는 어떻게 변할까요? 삼각형으로 나누어 예상해 보세요.",
            "볼록 n각형의 한 꼭짓점에서 대각선을 그으면 n-2개의 삼각형으로 나뉩니다. 따라서 내각의 합은 (n-2)×180°입니다. 한 꼭짓점에서 자기 자신과 양옆 꼭짓점에는 대각선을 그을 수 없으므로 대각선 수는 n(n-3)/2입니다. 볼록다각형의 외각을 한 바퀴씩 같은 방향으로 돌면 외각의 합은 360°입니다.",
            "육각형의 내각의 합과 대각선 수를 구하세요.",
            "삼각형 4개로 나뉘므로 내각의 합은 4×180°=720°입니다. 대각선 수는 6×(6-3)/2=9개입니다.",
            "팔각형의 내각의 합과 대각선 수를 각각 구하고, 식에서 8과 8-2가 나타내는 뜻을 설명하세요.",
            "내각의 합은 (8-2)×180°=1080°입니다. 대각선은 8×(8-3)/2=20개입니다. 8-2는 한 꼭짓점에서 만든 삼각형 수, 8-3은 각 꼭짓점에서 그을 수 있는 대각선 수입니다. 각 대각선은 양 끝에서 두 번 세므로 2로 나눕니다.",
            ["볼록 n각형의 내각의 합은 (n-2)×180°이다.", "볼록 n각형의 대각선 수는 n(n-3)/2이다.", "외각의 합은 360°이며 회전 한 바퀴와 연결된다."],
        ),
        make_chapter(
            "representative-values", "ms12-22-representative-values", "자료를 대표하는 값 고르기", "9수04-01",
            "중학수학1-2_2022개정_대푯값_체험형_시범.html",
            "다섯 명의 연습 횟수가 2, 3, 3, 4, 8회라면 보통 수준을 하나의 수로 어떻게 나타내는 것이 알맞을까요?",
            "평균은 자료의 합을 자료 수로 나눈 값, 중앙값은 자료를 크기순으로 놓았을 때 가운데 값, 최빈값은 가장 자주 나타나는 값입니다. 극단적으로 큰 값이 섞이면 평균이 크게 달라질 수 있으므로 자료의 분포와 질문의 목적을 살펴 대표값을 고릅니다.",
            "자료 2, 3, 3, 4, 8의 평균·중앙값·최빈값을 구하고, 연습 횟수의 일반적인 값을 설명하세요.",
            "합은 20이고 자료는 5개이므로 평균은 4입니다. 가운데 값은 3, 가장 자주 나온 값도 3입니다. 8회처럼 큰 값의 영향을 덜 받는 가운데 값을 대표로 쓰는 선택을 설명할 수 있습니다.",
            "자료 2, 3, 3, 4, 8에 20을 더했습니다. 새 평균·중앙값·최빈값을 구하고, 어떤 대표값이 기존 자료의 중심을 더 잘 보여 주는지 근거를 쓰세요.",
            "합은 40, 자료 수는 6이므로 평균은 40/6=20/3회입니다. 중앙값은 (3+4)/2=3.5회, 최빈값은 3회입니다. 20이라는 큰 값 때문에 평균이 크게 바뀌었으므로 자료의 가운데를 설명하려면 중앙값이 더 안정적일 수 있습니다. 목적에 따라 적절한 값을 고릅니다.",
            ["평균·중앙값·최빈값은 서로 다른 기준으로 자료를 대표한다.", "자료의 크기순 배열과 자료 개수를 먼저 확인한다.", "자료의 특성과 질문 목적에 맞는 대표값을 근거와 함께 고른다."],
        ),
    ]

def make_html(slug: str, title: str, kind: str) -> str:
    if kind == "angle":
        controls = '<label for="angle">각의 크기 <output id="angleOut">60°</output></label><input id="angle" type="range" min="0" max="180" value="60" aria-label="각의 크기, 0도에서 180도">'
        script = """const s=document.querySelector('#angle'),o=document.querySelector('#angleOut'),g=document.querySelector('#angleSvg'),k=document.querySelector('#kind');function draw(){const d=+s.value;o.value=d+'°';k.textContent=d<90?'예각':d===90?'직각':d<180?'둔각':'평각';const r=d*Math.PI/180,x=120+75*Math.cos(r),y=120-75*Math.sin(r);g.querySelector('#ray').setAttribute('x2',x);g.querySelector('#ray').setAttribute('y2',y);g.querySelector('#arc').setAttribute('d',`M 175 120 A 55 55 0 0 0 ${120+55*Math.cos(r)} ${120-55*Math.sin(r)}`);}s.addEventListener('input',draw);document.querySelector('#check').addEventListener('click',()=>{const d=+s.value,correct=d<90?'예각':d===90?'직각':d<180?'둔각':'평각';document.querySelector('#feedback').textContent=document.querySelector('#guess').value===correct?'맞았습니다.':'각의 크기와 90도·180도를 비교해 보세요.'});draw();"""
        body = f'<svg id="angleSvg" viewBox="0 0 240 150" role="img" aria-label="두 반직선이 이루는 각"><line x1="120" y1="120" x2="210" y2="120" stroke="currentColor"/><line id="ray" x1="120" y1="120" x2="157" y2="55" stroke="currentColor"/><path id="arc" fill="none" stroke="#b45309" stroke-width="3"/><circle cx="120" cy="120" r="4"/></svg><p>이 각은 <strong id="kind" aria-live="polite"></strong>입니다.</p>{controls}<label for="guess">각의 종류</label><select id="guess"><option>예각</option><option>직각</option><option>둔각</option><option>평각</option></select><button id="check" type="button">답 확인</button><p id="feedback" role="status"></p>'
        quiz = "각의 크기는 변의 길이가 아니라 벌어진 정도로 판단합니다."
    elif kind == "triangle":
        controls = ''.join(f'<label for="{key}">{label} <output id="{key}Out">{value}</output></label><input id="{key}" type="range" min="1" max="10" value="{value}" aria-label="{label} 길이 1에서 10">' for key,label,value in [('a','변 a',4),('b','변 b',5),('c','변 c',7)])
        script = """const ids=['a','b','c'];function possible(){const v=ids.map(id=>+document.getElementById(id).value);return v.every((x,i)=>x<v[(i+1)%3]+v[(i+2)%3]);}function draw(){const v=ids.map(id=>+document.getElementById(id).value);ids.forEach((id,i)=>document.getElementById(id+'Out').value=v[i]);const ok=possible();document.getElementById('triState').textContent=ok?'삼각형을 만들 수 있습니다.':'삼각형을 만들 수 없습니다.';document.getElementById('construct').disabled=!ok;}ids.forEach(id=>document.getElementById(id).addEventListener('input',draw));document.getElementById('construct').addEventListener('click',()=>{document.getElementById('triExplain').textContent='가장 긴 변을 밑변으로 두고, 양 끝점을 중심으로 나머지 두 변 길이의 원호를 그려 교점을 찾습니다.'});document.getElementById('check').addEventListener('click',()=>{document.getElementById('feedback').textContent=document.querySelector('#guess').value===(possible()?'yes':'no')?'맞았습니다.':'세 변의 합을 비교해 보세요.'});draw();"""
        body = f'<p id="triState" role="status"></p><svg viewBox="0 0 220 150" role="img" aria-label="세 변의 길이로 삼각형 작도"><path d="M30 120 L190 120 L105 35 Z" fill="none" stroke="currentColor" stroke-width="3"/></svg>{controls}<button id="construct" type="button">작도 순서 확인</button><p id="triExplain" aria-live="polite"></p><label for="guess">삼각형을 만들 수 있나요?</label><select id="guess"><option value="yes">가능하다</option><option value="no">불가능하다</option></select><button id="check" type="button">답 확인</button><p id="feedback" role="status"></p>'
        quiz = "2, 3, 6은 삼각형 부등식을 만족하지 않아 작도할 수 없습니다."
    elif kind == "polygon":
        controls = '<label for="sides">변의 수 <output id="nOut">6</output></label><input id="sides" type="range" min="3" max="12" value="6" aria-label="다각형의 변의 수 3에서 12">'
        script = """const s=document.querySelector('#sides');function draw(){const n=+s.value;document.querySelector('#nOut').value=n;document.querySelector('#sum').textContent=(n-2)*180+'°';document.querySelector('#diag').textContent=n*(n-3)/2+'개';const pts=Array.from({length:n},(_,i)=>{const a=2*Math.PI*i/n-Math.PI/2;return (100+70*Math.cos(a))+','+(85+70*Math.sin(a))}).join(' ');document.querySelector('#poly').setAttribute('points',pts);}s.addEventListener('input',draw);document.querySelector('#check').addEventListener('click',()=>{document.querySelector('#feedback').textContent=(+document.querySelector('#guess').value===(+s.value-2)*180)?'맞았습니다.':'삼각형으로 나누어 보세요.'});draw();"""
        body = f'<svg viewBox="0 0 200 180" role="img" aria-label="변의 수를 바꾸는 볼록다각형"><polygon id="poly" fill="none" stroke="currentColor" stroke-width="3"/></svg>{controls}<p>내각의 합: <strong id="sum" aria-live="polite"></strong></p><p>대각선 수: <strong id="diag" aria-live="polite"></strong></p><label for="guess">내각의 합을 입력하세요 (도)</label><input id="guess" type="number" min="180" max="1800" step="180"><button id="check" type="button">답 확인</button><p id="feedback" role="status"></p>'
        quiz = "육각형은 내각의 합 720도, 대각선 9개입니다."
    else:
        controls = '<label for="outlier">마지막 자료 <output id="valueOut">8</output></label><input id="outlier" type="range" min="0" max="20" value="8" aria-label="다섯 번째 자료 값 0에서 20">'
        script = """const s=document.querySelector('#outlier');function draw(){const a=[2,3,3,4,+s.value].sort((x,y)=>x-y),mean=a.reduce((x,y)=>x+y,0)/a.length,med=a[2];document.querySelector('#valueOut').value=s.value;document.querySelector('#sampleValue').textContent=s.value;document.querySelector('#mean').textContent=Number.isInteger(mean)?mean:mean.toFixed(2);document.querySelector('#median').textContent=med;document.querySelector('#mode').textContent='3';}s.addEventListener('input',draw);document.querySelector('#check').addEventListener('click',()=>{document.querySelector('#feedback').textContent=(+document.querySelector('#guess').value===+document.querySelector('#median').textContent)?'맞았습니다.':'자료를 크기순으로 놓고 가운데 값을 확인하세요.'});draw();"""
        body = f'<p>자료: 2, 3, 3, 4, <span id="sampleValue">8</span></p>{controls}<p>평균: <strong id="mean" aria-live="polite"></strong></p><p>중앙값: <strong id="median" aria-live="polite"></strong></p><p>최빈값: <strong id="mode" aria-live="polite"></strong></p><label for="guess">중앙값은 얼마인가요?</label><input id="guess" type="number" min="0" max="20" step="0.5"><button id="check" type="button">답 확인</button><p id="feedback" role="status"></p>'
        quiz = "마지막 자료를 20으로 바꾸면 평균은 6.4, 중앙값은 3, 최빈값은 3입니다."
    return f'''<!doctype html>
<html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{title}</title>
<style>body{{font:17px/1.6 system-ui,sans-serif;max-width:46rem;margin:0 auto;padding:1.25rem;color:#172033}}fieldset{{border:1px solid #94a3b8;border-radius:12px;padding:1rem}}label{{display:block;margin-top:1rem}}input{{width:100%;min-height:2.5rem;accent-color:#1d4ed8}}button{{min-height:2.75rem;padding:.6rem 1rem}}svg{{display:block;width:min(100%,24rem);height:auto;margin:1rem auto}}:focus-visible{{outline:3px solid #b45309;outline-offset:3px}}@media(prefers-reduced-motion:reduce){{*{{scroll-behavior:auto!important;transition:none!important}}}}</style></head>
<body data-lesson="{slug}"><main><h1>{title}</h1><p>값을 바꾸고 무엇이 달라지며 무엇이 유지되는지 설명해 보세요.</p><fieldset><legend>직접 조작</legend>{body}</fieldset><section aria-labelledby="quiz"><h2 id="quiz">생각 확인</h2><p>{quiz}</p></section><p>기준: 별책 8 성취기준 후보 · 학기 배정 후보 · 교사 검수 대기</p></main><script>{script}</script></body></html>'''

def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    chapter_list = chapters()
    quiz_activities = [
        {"id": "ms12-geometry-terms-quiz", "kind": "quiz", "prompt": "∠XYZ의 꼭짓점은 어느 점인가요?", "options": ["X", "Y", "Z"], "correct_index": 1, "correct_feedback": "각의 꼭짓점은 가운데 글자인 Y입니다.", "incorrect_feedback": "세 글자 표기에서 꼭짓점은 가운데에 씁니다.", "hints": ["∠XYZ의 가운데 글자를 찾아보세요."]},
        {"id": "ms12-triangle-construction-quiz", "kind": "quiz", "prompt": "세 변의 길이가 2, 3, 6인 삼각형을 작도할 수 있나요?", "options": ["가능하다", "불가능하다"], "correct_index": 1, "correct_feedback": "2+3<6이므로 삼각형 부등식을 만족하지 않습니다.", "incorrect_feedback": "가장 긴 변이 나머지 두 변의 합보다 짧아야 합니다.", "hints": ["가장 긴 변 6과 나머지 두 변의 합을 비교하세요."]},
        {"id": "ms12-polygon-quiz", "kind": "quiz", "prompt": "오각형의 대각선은 모두 몇 개인가요?", "options": ["5개", "7개", "10개"], "correct_index": 0, "correct_feedback": "5×(5−3)/2=5개입니다.", "incorrect_feedback": "각 꼭짓점에서 n−3개를 그을 수 있고, 각 대각선을 두 번 세므로 2로 나눕니다.", "hints": ["n(n−3)/2에 n=5를 넣으세요."]},
        {"id": "ms12-representative-values-quiz", "kind": "quiz", "prompt": "자료 1, 2, 2, 3, 12의 평균·중앙값·최빈값은 각각 무엇인가요?", "options": ["4, 2, 2", "4, 3, 2", "5, 2, 3"], "correct_index": 0, "correct_feedback": "합 20을 5로 나누면 4, 가운데 값과 최빈값은 2입니다.", "incorrect_feedback": "자료를 정렬한 뒤 합, 가운데 위치, 가장 자주 나온 값을 각각 확인하세요.", "hints": ["합은 20이고 자료는 5개입니다.", "가운데 값은 세 번째 자료입니다."]},
    ]
    for chapter, activity in zip(chapter_list, quiz_activities):
        chapter["pages"][-2]["blocks"].append({"type": "activity", "activity": activity})
    book = {
        "schema_version": 2,
        "title": "중학수학 1-2 개념서 · 2022 개정 · 기하와 자료 후보 시범",
        "subtitle": "정의와 조건을 확인하고, 조작한 결과를 말과 식으로 설명합니다",
        "category": "concept_textbook_prototype",
        "tags": BASE_TAGS + ["성취기준 후보: 9수03-01", "성취기준 후보: 9수03-03", "성취기준 후보: 9수03-05", "성취기준 후보: 9수04-01"],
        "curriculum_version": "2022",
        "standard_codes": ["9수03-01", "9수03-03", "9수03-05", "9수04-01"],
        "chapters": chapter_list,
    }
    (OUT / BOOK_FILE).write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    html_names = [
        "중학수학1-2_2022개정_점선면과각_체험형_시범.html",
        "중학수학1-2_2022개정_삼각형작도_체험형_시범.html",
        "중학수학1-2_2022개정_다각형각과대각선_체험형_시범.html",
        "중학수학1-2_2022개정_대푯값_체험형_시범.html",
    ]
    kinds = ["angle", "triangle", "polygon", "stats"]
    for chapter, html_name, kind in zip(chapter_list, html_names, kinds):
        slug = chapter["pages"][0]["id"].removesuffix("-opening")
        (OUT / html_name).write_text(make_html(slug, chapter["title"], kind), encoding="utf-8")

    rows = ["# 중학수학 1-2 개념서 · 2022 개정 후보 원고", "",
            "> 상태: 오리지널 검토용 초안. 성취기준은 중학교 학년군 코드이며 전국 공통 1-2 배정을 뜻하지 않습니다.",
            "> 출처: 교육부 고시 제2022-33호, 별책 8 수학과 교육과정(HWP 원문을 로컬 텍스트 추출로 대조).", "",
            "## 집필·권리 메타데이터", "",
            "- 집필: 이 저장소에서 새로 작성한 개념 설명·예시·연습·해설.",
            "- 외부 교재: 상업 교재 문장·문제·그림을 복사하지 않음.",
            "- 시각 자산: HTML의 SVG와 CSS를 코드로 신규 생성; 외부 이미지·폰트·스크립트 없음.",
            "- 라이선스/배포 권리: 프로젝트 소유권·공개 라이선스 결정 전; 공개 배포 보류.",
            "- 교사 검수: 대기. 성취기준 학기 귀속과 1-2 상품 범위 대조: 대기.", "",
            "## 단원 후보와 원고", ""]
    for ch in chapter_list:
        rows.extend([f"### {ch['title']}", f"기준 후보: {ch['sections'][0]['paragraphs'][0]}", ""])
        for pg in ch["pages"]:
            rows.extend([f"#### {pg['title']}", ""])
            for b in pg["blocks"]:
                text = b.get("text", "")
                items = b.get("items", [])
                if text:
                    rows.extend([f"**{b['title']}** {text}", ""])
                if items:
                    rows.extend([f"- {item}" for item in items] + [""])
        rows.append(f"체험 파일: `{html_names[len([x for x in rows if x.startswith('### ')]) - 1]}`\n")
    (OUT / "중학수학1-2_2022개정_학생용원고_시범.md").write_text("\n".join(rows), encoding="utf-8")
    manifest = {
        "target": "중학수학 1-2 개념서 · 2022 개정",
        "schema_version": 2,
        "status": "candidate_partial_draft",
        "semester_assignment": "editorial_candidate_not_officially_confirmed",
        "standards": ["9수03-01", "9수03-03", "9수03-05", "9수04-01"],
        "standard_source": "교육부 고시 제2022-33호 별책8 수학과 교육과정, NCIC official record",
        "standard_source_url": "https://www.moe.go.kr/boardCnts/viewRenew.do?boardID=141&boardSeq=93458",
        "source_file": "NCIC [별책8] 수학과 교육과정.pdf official record; PDF download failed, so the official HWP bundle entry was extracted locally with hwp5txt",
        "source_archive_sha256": "B37A372A90D6D00BB3985888BBB41CAAE7A35F28877DC243A6F4B28861C53146",
        "source_hwp_sha256": "AAB8EED59ECF244223D04AFAD75F4CF5AC5085FADCFC3CF52C2F6D54DDFC7856",
        "extraction_tool": "hwp5txt from hwp5 0.1b15",
        "content_rights": "newly authored draft; no commercial textbook content or external assets used; publication rights decision pending",
        "math_review": "automated arithmetic checked; teacher review pending",
        "features": [{"standard": code, "html": filename, "type": kind, "runtime": "standalone source asset; not app-integrated"}
                     for code, filename, kind in zip(["9수03-01", "9수03-03", "9수03-05", "9수04-01"], html_names, kinds)],
    }
    (OUT / "중학수학1-2_2022개정_원고매니페스트.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (OUT / "README.md").write_text(
        "# 중학수학 1-2 개념서 · 2022 개정 후보 시범\n\n"
        "4개 모듈과 24개 지면을 신규 작성했습니다. 기준 후보는 `9수03-01`, `9수03-03`, `9수03-05`, `9수04-01`입니다. "
        "교육부 별책 8은 중학교 성취기준을 학년군 코드로 제시하며 이들을 전국 공통 1-2 범위로 배정하지 않습니다. "
        "따라서 학기 배정은 편집 후보이고, 이 자료는 전체 1-2 교과 범위가 아닙니다.\n\n"
        f"- BookData: `{BOOK_FILE}`\n"
        "- 학생용 원고: `중학수학1-2_2022개정_학생용원고_시범.md`\n"
        "- 기능/권리/검수 상태: `중학수학1-2_2022개정_원고매니페스트.json`\n"
        "- 체험 HTML 4개: 점·선·면과 각, 삼각형 작도, 다각형, 대푯값\n"
        "- 교사 수학 검수·학기 범위 확정·프로젝트 권리 결정·앱 통합·학생 파일럿은 미완료\n\n"
        "재생성: `python tool/build_middle_school_1_2_2022_candidate.py`\n", encoding="utf-8")
    print(f"Built candidate book: {len(chapter_list)} modules, {sum(len(ch['pages']) for ch in chapter_list)} pages, {len(html_names)} interactive HTML sources.")

if __name__ == "__main__":
    main()
