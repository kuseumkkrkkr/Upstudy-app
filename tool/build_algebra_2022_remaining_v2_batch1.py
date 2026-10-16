"""Build original, resumable drafts for unambiguous missing 2022 Algebra standards."""
from __future__ import annotations

import json
import math
from pathlib import Path

from textbook_digest import canonical_file_sha256

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
STANDARDS = ROOT / "work/official-curriculum/2022_math_standards.json"
OUT = MANUSCRIPTS / "대수_2022개정_미연결기준14모듈_Batch1_BookData_V2_시범.json"
PACKAGE = MANUSCRIPTS / "대수_2022개정_미연결기준14모듈_Batch1_원고패키지"

SPECS = [
    {
        "code":"12대수01-01", "title":"거듭제곱과 거듭제곱근", "lead":"정사각형의 넓이가 49라면 한 변의 길이는 어떻게 찾을까?",
        "concept":"aⁿ은 a를 n번 곱한 거듭제곱이다. n제곱근은 n제곱하여 주어진 수가 되는 수를 뜻한다. 실수 범위에서 짝수 제곱근은 피제곱수가 0 이상일 때 다루며, √49는 주값 7이다. 방정식 x²=49의 해는 ±7이므로 기호 √49와 구별한다.",
        "example":"3⁴=81이므로 81의 네제곱근 중 실수는 ±3이다. √81은 주값 9이며, x²=81의 해는 ±9이다.", "practice":"x²=36의 실수 해와 √36의 값을 각각 구하세요.", "answer":"x²=36의 해는 x=±6이고, √36은 주값 6입니다.",
        "prompt":"x²=25의 실수 해와 √25를 바르게 구분한 것은?", "options":["해는 ±5, √25=5","해는 5, √25=±5","해와 제곱근 표기는 모두 ±5"], "correct":0,
        "feedback":"방정식의 해는 ±5이고, √25는 주값 5입니다.", "wrong":"방정식의 해와 근호 기호의 주값을 구분하세요.", "hints":["어떤 수를 제곱하면 25인지 모두 찾습니다.","√ 기호는 음이 아닌 주값을 나타냅니다."],
    },
    {
        "code":"12대수01-02", "title":"유리수 지수와 실수 지수", "lead":"1/2제곱은 제곱근과 어떤 관계일까? 밑의 부호 조건도 함께 살펴보자.",
        "concept":"양수 a와 정수 m, 양의 정수 n에 대하여 a^(m/n)=ⁿ√(a^m)으로 정의한다. 실수 지수는 양수 밑에서 지수의 유리수 근삿값을 통해 직관적으로 확장한다. 밑이 양수라는 조건을 두면 로그와 지수함수의 정의역이 일관된다.",
        "example":"16^(3/4)=(⁴√16)³=2³=8이다. 9^(-1/2)=1/√9=1/3이다. 음수 밑의 임의 실수 지수는 여기서 정의하지 않는다.", "practice":"27^(2/3)과 25^(-1/2)을 구하세요.", "answer":"27^(2/3)=(³√27)²=9이고, 25^(-1/2)=1/√25=1/5입니다.",
        "prompt":"16^(3/4)의 값은?", "options":["8","12","64"], "correct":0,
        "feedback":"⁴√16=2이므로 2³=8입니다.", "wrong":"분모 4를 근호의 차수로, 분자 3을 거듭제곱으로 해석하세요.", "hints":["16의 네제곱근은 2입니다.","2를 세제곱합니다."],
    },
    {
        "code":"12대수01-03", "title":"지수법칙으로 식 간단히 하기", "lead":"같은 밑의 거듭제곱을 곱하거나 나눌 때 지수는 어떻게 바뀔까?",
        "concept":"a>0일 때 a^m·a^n=a^(m+n), a^m/a^n=a^(m−n)(a≠0), (a^m)^n=a^(mn)이다. 같은 지수의 곱에서는 (ab)^n=a^nb^n이 성립한다. 지수법칙은 밑과 지수의 조건을 확인하며 적용한다.",
        "example":"2³·2⁵/2⁴=2^(3+5−4)=2⁴=16이다. (3²)³=3⁶=729이다.", "practice":"x>0일 때 x⁷·x²/x⁴을 간단히 하고, x=2일 때 값을 구하세요.", "answer":"x⁵이고 x=2이면 32입니다.",
        "prompt":"3⁴·3²/3³은?", "options":["27","9","81"], "correct":0,
        "feedback":"지수는 4+2−3=3이므로 3³=27입니다.", "wrong":"곱에서는 지수를 더하고, 나눗셈에서는 뺍니다.", "hints":["먼저 지수끼리 계산합니다.","3^(4+2−3)=3³입니다."],
    },
    {
        "code":"12대수01-04", "title":"로그의 뜻과 성질", "lead":"2를 몇 제곱해야 32가 될까? 곱셈 관계를 덧셈 관계로 바꿔 보자.",
        "concept":"a>0, a≠1, M>0일 때 log_a M=x는 a^x=M과 같은 뜻이다. 로그의 곱·몫·거듭제곱 성질은 지수법칙에서 나온다: log_a(MN)=log_aM+log_aN, log_a(M/N)=log_aM−log_aN, log_a(M^r)=r log_aM.",
        "example":"log₂32=5이다. log₃(27/9)=log₃3=1이며 log₃27−log₃9=3−2=1로 성질을 확인한다.", "practice":"log₅125와 log₂(8·4)를 구하세요.", "answer":"log₅125=3, log₂(8·4)=log₂8+log₂4=3+2=5입니다.",
        "prompt":"log₃81의 값은?", "options":["4","3","9"], "correct":0,
        "feedback":"3⁴=81이므로 log₃81=4입니다.", "wrong":"로그를 지수 방정식으로 바꾸세요.", "hints":["log₃81=x는 3^x=81이라는 뜻입니다.","3⁴=81입니다."],
    },
    {
        "code":"12대수01-05", "title":"상용로그와 규모 비교", "lead":"값이 10배, 100배 커질 때 상용로그는 어떻게 달라질까?",
        "concept":"상용로그는 밑이 10인 로그 log₁₀N이다(N>0). log₁₀(10N)=1+log₁₀N이므로 양을 10배 하면 상용로그 값은 1 커진다. 실제 자료를 해석할 때는 단위와 측정 기준을 함께 확인한다.",
        "example":"log₁₀(1000)=3이고 log₁₀(100000)=5이다. 두 수의 비는 100이므로 상용로그 값 차이는 2이다.", "practice":"log₁₀(10⁶)−log₁₀(10³)을 구하고 두 수의 크기 비를 말하세요.", "answer":"차는 6−3=3이고, 두 수의 비는 10³=1000입니다.",
        "prompt":"N을 100배 하면 log₁₀N은 얼마나 변하나요?", "options":["2만큼 증가","100만큼 증가","변하지 않음"], "correct":0,
        "feedback":"100=10²이므로 log₁₀(100N)=2+log₁₀N입니다.", "wrong":"100을 10의 거듭제곱으로 나타내세요.", "hints":["100=10²입니다.","곱의 로그 성질을 적용합니다."],
    },
    {
        "code":"12대수01-06", "title":"지수함수와 로그함수의 뜻", "lead":"입력 x가 한 단위 커질 때 2ˣ와 log₂x는 각각 어떻게 변할까?",
        "concept":"a>0, a≠1일 때 지수함수 y=aˣ는 양의 실수 x값마다 양의 함숫값을 갖는다. 로그함수 y=log_a x는 x>0에서 정의되며 지수함수의 역함수다. 두 함수에서 입력과 출력의 역할이 서로 바뀐다.",
        "example":"y=2ˣ에서 x=3이면 y=8이다. 역함수 y=log₂x에서는 x=8일 때 y=3이다. 두 대응은 (3,8)과 (8,3)으로 좌표가 바뀐다.", "practice":"y=3ˣ의 역함수를 쓰고, x=9일 때 역함숫값을 구하세요.", "answer":"역함수는 y=log₃x이고 log₃9=2입니다.",
        "prompt":"y=5ˣ과 역함수의 관계로 맞는 것은?", "options":["y=log₅x","y=5ˣ","y=log_x5"], "correct":0,
        "feedback":"지수함수의 역함수는 로그함수 y=log₅x입니다.", "wrong":"x와 y를 바꾸고 지수식을 로그식으로 읽으세요.", "hints":["y=5ˣ에서 x와 y를 바꿉니다.","x=5ʸ를 y=log₅x로 바꿉니다."],
    },
    {
        "code":"12대수01-07", "title":"지수함수와 로그함수의 그래프", "lead":"밑이 2일 때와 1/2일 때 그래프의 증가·감소는 어떻게 달라질까?",
        "concept":"a>1이면 y=aˣ는 증가하고 x축을 점근선으로 가지며 (0,1)을 지난다. 0<a<1이면 감소한다. y=log_a x는 (1,0)을 지나고 y축을 점근선으로 가진다. 지수함수와 로그함수의 그래프는 y=x에 대하여 대칭이다.",
        "example":"y=2ˣ은 (−1,1/2),(0,1),(1,2)를 지나며 증가한다. y=log₂x는 (1/2,−1),(1,0),(2,1)을 지나고, 앞 그래프와 좌표가 바뀐 점을 지난다.", "practice":"y=(1/3)ˣ의 증가·감소와 수평점근선을 말하세요.", "answer":"밑이 0과 1 사이이므로 감소하고, x축(y=0)이 수평점근선입니다.",
        "prompt":"y=log₂x의 점근선은?", "options":["y축 x=0","x축 y=0","직선 y=x"], "correct":0,
        "feedback":"로그함수의 정의역 경계인 x=0이 수직점근선입니다.", "wrong":"로그함수의 입력은 양수이므로 x=0에 가까워지는 모양을 살펴보세요.", "hints":["로그함수의 정의역은 x>0입니다.","그래프는 y축에 가까워지지만 만나지 않습니다."],
    },
    {
        "code":"12대수01-08", "title":"지수함수·로그함수로 문제 해결", "lead":"매 시간 2배가 되는 양은 몇 시간이 지나면 8배가 될까?",
        "concept":"일정한 시간 간격마다 일정한 비율로 변하는 양은 지수식으로 나타낼 수 있다. 목표값에 도달하는 시간을 구할 때는 로그를 사용한다. 시작량·증가율·시간 단위를 식에 먼저 표시한다.",
        "example":"매 시간 2배가 되는 양이 처음의 8배가 되는 시간 t는 2ᵗ=8에서 t=3이다. 시간마다 10% 증가한다면 n시간 뒤 배율은 1.1ⁿ으로 나타낸다.", "practice":"매 단계마다 3배가 되는 양이 처음의 81배가 되는 데 필요한 단계 수를 구하세요.", "answer":"3ⁿ=81=3⁴이므로 n=4단계입니다.",
        "prompt":"매 단계 2배일 때 16배가 되는 단계 수는?", "options":["4","8","16"], "correct":0,
        "feedback":"2ⁿ=16=2⁴이므로 n=4입니다.", "wrong":"배율을 밑이 2인 거듭제곱으로 나타내세요.", "hints":["2를 몇 번 곱하면 16인지 찾습니다.","2⁴=16입니다."],
    },
    {
        "code":"12대수02-01", "title":"일반각과 호도법", "lead":"반지름과 호의 길이가 같으면 중심각은 몇 라디안일까?",
        "concept":"양의 x축에서 시작해 회전한 각은 방향과 회전량으로 나타내는 일반각으로 확장할 수 있다. 라디안 측정에서 θ=s/r(r은 반지름, s는 호의 길이)이다. 180°=π rad이고, 회전 방향을 부호로 구분한다.",
        "example":"호의 길이가 6, 반지름이 3이면 θ=6/3=2 rad이다. 60°는 60·π/180=π/3 rad이다.", "practice":"반지름 4, 호의 길이 2인 부채꼴의 중심각을 라디안으로 구하세요.", "answer":"θ=s/r=2/4=1/2 rad입니다.",
        "prompt":"90°를 라디안으로 나타내면?", "options":["π/2","π/4","2π"], "correct":0,
        "feedback":"90°는 180°의 절반이므로 π/2 rad입니다.", "wrong":"180°=π를 기준으로 비례식을 세우세요.", "hints":["90°/180°=1/2입니다.","π의 절반은 π/2입니다."],
    },
    {
        "code":"12대수02-02", "title":"삼각함수의 그래프", "lead":"단위원 위 점이 한 바퀴 회전할 때 y좌표와 x좌표는 어떤 그래프를 만들까?",
        "concept":"단위원에서 각 θ에 대응하는 점의 좌표는 (cosθ,sinθ)이다. y=sin x와 y=cos x는 주기 2π, 최댓값 1, 최솟값 −1을 갖는다. y=tan x=sin x/cos x는 cos x=0인 곳에서 정의되지 않고 주기 π이다.",
        "example":"sin 0=0, sin(π/2)=1, sin π=0이다. tan x는 x=π/2에서 정의되지 않으며 각 구간에서 주기가 π로 반복된다.", "practice":"y=cos x의 한 주기 길이와 최댓값을 말하세요.", "answer":"한 주기 길이는 2π이고 최댓값은 1입니다.",
        "prompt":"y=tan x의 주기는?", "options":["π","2π","π/2"], "correct":0,
        "feedback":"tan(x+π)=tan x이므로 주기는 π입니다.", "wrong":"탄젠트의 비 sin x/cos x에 x+π를 대입해 보세요.", "hints":["sin과 cos는 π만큼 이동하면 둘 다 부호가 바뀝니다.","두 부호가 나뉘어 몫은 같아집니다."],
    },
    {
        "code":"12대수02-03", "title":"사인법칙과 코사인법칙", "lead":"삼각형에서 두 변과 끼인각을 알면 나머지 한 변을 어떻게 구할까?",
        "concept":"삼각형 ABC에서 변 a,b,c는 각각 맞은편 각 A,B,C의 크기다. 사인법칙은 a/sinA=b/sinB=c/sinC이고, 코사인법칙은 c²=a²+b²−2ab cosC이다. 어떤 자료가 주어졌는지 보고 적절한 법칙을 선택한다.",
        "example":"a=3,b=4,C=90°이면 c²=3²+4²−2·3·4·cos90°=25이므로 c=5이다. 직각삼각형에서는 피타고라스 정리와 일치한다.", "practice":"a=5,b=7,C=60°일 때 c²을 구하세요.", "answer":"c²=25+49−70·(1/2)=39입니다.",
        "prompt":"a=3,b=4,C=90°일 때 c는?", "options":["5","7","√7"], "correct":0,
        "feedback":"코사인법칙에서 cos90°=0이므로 c²=25, c=5입니다.", "wrong":"끼인각 C가 주어졌으므로 코사인법칙을 적용하세요.", "hints":["c²=a²+b²−2ab cosC입니다.","cos90°=0입니다."],
    },
    {
        "code":"12대수03-01", "title":"수열의 뜻과 일반항", "lead":"날짜별로 쌓인 수를 순서대로 적으면 어떤 규칙을 찾을 수 있을까?",
        "concept":"수열은 정해진 순서에 따라 나열한 수의 목록이며 각 수를 항이라고 한다. n번째 항을 n에 대한 식으로 나타낸 것을 일반항이라 한다. 몇 개의 항만으로 규칙이 하나로 정해지지 않을 수 있으므로 규칙을 명시해야 한다.",
        "example":"2,5,8,11,…에서 이웃한 차가 3이고 첫째항이 2라는 규칙을 더하면 aₙ=2+3(n−1)로 나타낼 수 있다. 1,4,9,…는 aₙ=n²로 나타낼 수 있다.", "practice":"규칙이 aₙ=2n+1인 수열의 첫 네 항을 쓰세요.", "answer":"n=1,2,3,4를 대입하면 3,5,7,9입니다.",
        "prompt":"aₙ=2n+1일 때 a₃은?", "options":["7","6","5"], "correct":0,
        "feedback":"a₃=2·3+1=7입니다.", "wrong":"일반항에 n=3을 대입하세요.", "hints":["세 번째 항은 n=3입니다.","2×3+1을 계산합니다."],
    },
    {
        "code":"12대수03-06", "title":"수열의 귀납적 정의", "lead":"첫 항과 앞 항에 적용할 규칙이 주어지면 뒤의 항을 차례로 구할 수 있을까?",
        "concept":"귀납적 정의는 초기항과 앞 항을 이용해 다음 항을 정하는 관계식으로 수열을 나타낸다. 초기항을 빠뜨리면 같은 점화식에 여러 수열이 대응할 수 있다. 점화식의 인덱스 시작점도 확인한다.",
        "example":"a₁=2, aₙ₊₁=aₙ+3 (n≥1)이면 a₂=5, a₃=8, a₄=11이다. 점화식만 있고 a₁이 없으면 수열은 하나로 정해지지 않는다.", "practice":"a₁=1, aₙ₊₁=2aₙ일 때 a₄를 구하세요.", "answer":"a₂=2, a₃=4, a₄=8입니다.",
        "prompt":"a₁=3, aₙ₊₁=aₙ+2일 때 a₃은?", "options":["7","5","9"], "correct":0,
        "feedback":"a₂=5, a₃=7입니다.", "wrong":"초기항에서 점화식을 두 번 적용하세요.", "hints":["a₂=a₁+2입니다.","a₃=a₂+2입니다."],
    },
    {
        "code":"12대수03-07", "title":"수학적 귀납법으로 명제 증명", "lead":"모든 자연수 n에 대해 1+2+…+n=n(n+1)/2임을 어떻게 증명할까?",
        "concept":"수학적 귀납법은 (1) 가장 작은 자연수에서 명제가 참임을 확인하고, (2) n=k에서 참이라고 가정해 n=k+1에서도 참임을 보이는 방법이다. 두 단계를 모두 보여야 모든 자연수에 대한 증명이 된다.",
        "example":"P(n): 1+…+n=n(n+1)/2. P(1)은 1=1로 참이다. P(k)를 가정하면 1+…+k+(k+1)=k(k+1)/2+(k+1)=(k+1)(k+2)/2이므로 P(k+1)이 성립한다.", "practice":"1+3+…+(2n−1)=n²을 귀납법으로 증명할 때 기초 단계의 양변 값을 확인하세요.", "answer":"n=1일 때 좌변은 1, 우변은 1²=1이므로 기초 단계가 성립합니다.",
        "prompt":"귀납법 증명에서 P(k) 가정 뒤에 보여야 하는 것은?", "options":["P(k+1)","P(1)만 다시 확인","모든 k의 계산 나열"], "correct":0,
        "feedback":"P(k)에서 P(k+1)이 따라옴을 보이는 것이 귀납 단계입니다.", "wrong":"기초 단계와 귀납 단계를 나누어 보세요.", "hints":["명제의 진릿값이 다음 자연수로 이어지는지 확인합니다.","귀납 단계의 목표는 k+1입니다."],
    },
]

DEFERRED_EQEDIT_CODES = {"12대수03-03", "12대수03-04", "12대수03-05"}
EXISTING_CODE = "12대수03-02"


def quiz(spec: dict, slug: str) -> dict:
    return {"type":"activity", "activity":{"id":slug+"-quiz", "kind":"quiz", "prompt":spec["prompt"], "options":spec["options"], "correct_index":spec["correct"], "correct_feedback":spec["feedback"], "incorrect_feedback":spec["wrong"], "hints":spec["hints"]}}


def main() -> None:
    official = {row["code"]: row["criterion"] for row in json.loads(STANDARDS.read_text(encoding="utf-8"))["standards"]}
    algebra = {code: text for code, text in official.items() if code.startswith("12대수")}
    expected = set(algebra) - {EXISTING_CODE} - DEFERRED_EQEDIT_CODES
    codes = [spec["code"] for spec in SPECS]
    if len(algebra) != 18 or set(codes) != expected or len(codes) != len(set(codes)):
        raise RuntimeError(f"Official Algebra scope mismatch: official={len(algebra)}, draft={len(codes)}, expected={sorted(expected)}")
    chapters = []
    page_ids = set()
    for spec in SPECS:
        code = spec["code"]
        if code not in official or not official[code]:
            raise RuntimeError(f"Missing official criterion: {code}")
        slug = code.replace("12대수", "algebra-").replace("-", "")
        criterion = official[code]
        pages = [
            {"id":slug+"-open", "template":"opening", "title":"질문으로 시작하기", "blocks":[{"type":"lead","title":"탐구 상황","text":spec["lead"]},{"type":"thinking","title":"먼저 생각하기","text":"조건과 정의역을 표시하고, 어떤 표현이나 관계를 찾아야 하는지 한 문장으로 적어 보세요."}]},
            {"id":slug+"-concept", "template":"concept", "title":"개념과 조건", "blocks":[{"type":"definition","title":"핵심 개념","text":spec["concept"]},{"type":"standard","title":"공식 기준 문구","text":f"{code}: {criterion}"},{"type":"misconception","title":"확인할 조건","text":"정의역, 부호, 인덱스 조건을 먼저 확인하고 성질을 적용합니다."}]},
            {"id":slug+"-example", "template":"example", "title":"예제와 풀이", "blocks":[{"type":"question","title":"예제","text":spec["lead"]},{"type":"solutionStep","title":"풀이","text":spec["example"]},{"type":"verification","title":"확인","text":"조건을 만족하는지 대입하거나 그래프·관계식으로 검산합니다."}]},
            {"id":slug+"-practice", "template":"practice", "title":"연습과 설명", "blocks":[{"type":"question","title":"연습","text":spec["practice"]},{"type":"hint","title":"힌트","text":spec["hints"][0]},{"type":"solutionStep","title":"풀이","text":spec["answer"]},{"type":"answer","title":"정답","text":spec["answer"]},quiz(spec,slug)]},
            {"id":slug+"-summary", "template":"summary", "title":"핵심 정리", "blocks":[{"type":"summary","title":"기준 연결","text":f"{code} · {spec['title']}"},{"type":"checklist","title":"스스로 확인","text":"핵심 개념을 설명하고, 예제의 조건과 계산을 검산할 수 있나요?"}]},
        ]
        for page in pages:
            if page["id"] in page_ids: raise RuntimeError(f"Duplicate page ID: {page['id']}")
            page_ids.add(page["id"])
        chapters.append({"title":spec["title"], "intro":[f"2022 개정 대수 공식 기준 {code}와 연결한 신규 원고 후보입니다.","예시와 수치는 개념 학습용으로 새로 작성했으며 독립 검토 전입니다."], "pages":pages, "candidate_standard_codes":[code]})

    assert math.isclose(16**(3/4), 8)
    assert math.isclose(27**(2/3), 9)
    assert math.isclose(3**4 / 3**2, 9)
    assert math.isclose(math.log(32,2), 5)
    assert math.isclose(math.log10(10**6)-math.log10(10**3), 3)
    assert math.isclose(math.log(9,3), 2)
    assert math.isclose(math.cos(math.pi/2), 0, abs_tol=1e-12)
    assert math.isclose(math.sin(math.pi/2), 1, abs_tol=1e-12)
    assert 1+2+3+4+5 == 5*6/2
    book = {"schema_version":2,"title":"대수 2022 개정 · 공식 기준 추가 14모듈 후보","subtitle":"지수·로그, 삼각함수, 수열의 뜻·귀납적 정의와 증명","category":"concept_textbook_prototype","curriculum_version":"2022","tags":["대수","2022 개정","V2 추가 원고 후보","가상 예시","학기 배정 미확정",*codes],"standard_codes":codes,"chapters":chapters,"metadata":{"status":"review_pending","deferred_eqedit_codes":sorted(DEFERRED_EQEDIT_CODES),"deferred_reason":"Raw EqEdit scripts were recovered and are authored in a separate resumable Batch2."}}
    OUT.write_text(json.dumps(book,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    PACKAGE.mkdir(parents=True,exist_ok=True)
    digest=canonical_file_sha256(OUT)
    try: old=json.loads((PACKAGE/"REVIEW_MANIFEST.json").read_text(encoding="utf-8"))
    except (OSError,json.JSONDecodeError): old={}
    same=old.get("bookdata_sha256")==digest
    manifest={"bookdata_file":OUT.name,"bookdata_sha256":digest,"candidate_code_references":codes,"candidate_code_reference_type":"exact_official_2022_hwp_table_and_extracted_standards","module_count":len(chapters),"page_count":len(page_ids),"native_quiz_count":len(chapters),"official_scope_count":18,"existing_candidate_code":[EXISTING_CODE],"deferred_eqedit_batch2_codes":sorted(DEFERRED_EQEDIT_CODES),"related_html_sources":[{"file":"대수_등차수열_체험형_시범.html","sha256":"7BACEB36A0745E8CD1246EE2D44C8EDB9E88524E814E6D85C2B2E2412050B0D4","linked_standard":"12대수03-02","status":"standalone_asset; not embedded; rights review required"},{"file":"대수_등비수열_체험형_시범.html","sha256":"1737AF2B6A281C0233BD0597C501A8DA6BC3DFE123B9FB2035A5F2CCCF2E86FE","linked_standard":None,"status":"standalone_asset; edition not established; not counted as 2022 coverage"},{"file":"대수_지수와로그_체험형_시범.html","sha256":"55B5B2CBB2067E7B5E2CCE014B6B3A7841EEC69B3D50E551704FB511222EF235","linked_standard":None,"status":"standalone_asset; existing BookData is explicitly 2015; not counted as 2022 coverage"}],"example_content_status":"newly_authored synthetic examples","curriculum_review_status":"15 of 18 codes in this batch set have candidate tags; EqEdit Batch2 supplies the remaining three candidate modules, while content and product scope review remain pending","math_review_status":"arithmetic assertions passed for listed checks only; independent review pending","teacher_review_status":"pending","rights_status":"newly authored text pending rights decision; referenced HTML assets pending source review","interactive_status":"HTML files remain separate; app execution and screen parity unverified","app_model_roundtrip_status":"parser accepts chapters and pages, but BookContentBlock drops activity payloads on serialization; native quiz compatibility failed","integration_status":"tag-driven unit integration output; source BookData page payloads preserved","app_model_roundtrip_status":old.get("app_model_roundtrip_status","pending_current_hash_validation") if same else "pending_current_hash_validation","publication_eligibility":"not_eligible","runtime_import_status":old.get("runtime_import_status","pending_current_hash_validation") if same else "pending_current_hash_validation","runtime_validator_head":old.get("runtime_validator_head") if same else None}
    manifest["app_model_roundtrip_status"] = old.get("app_model_roundtrip_status", "pending_current_hash_validation") if same else "pending_current_hash_validation"
    (PACKAGE/"REVIEW_MANIFEST.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    (PACKAGE/"README.md").write_text(f"# {book['title']}\n\n신규 기준 후보 {len(chapters)}모듈·{len(page_ids)}쪽·퀴즈 {len(chapters)}개입니다. 이 배치는 공식 기준 15/18개를 연결합니다. `{', '.join(sorted(DEFERRED_EQEDIT_CODES))}`는 원본 HWP EqEdit 스크립트를 확인해 별도 Batch2에서 작성합니다. 독립 HTML은 별도 자산이며 화면 동등성·교사 검토·권리 결정이 남아 있습니다.\n\n출판 검토 전 후보입니다.\n",encoding="utf-8")
    if manifest["app_model_roundtrip_status"].startswith("passed:"):
        readme_path=PACKAGE/"README.md"
        readme=readme_path.read_text(encoding="utf-8")
        readme=readme.replace("`BookData.fromJson`은 14개 신규 모듈과 70페이지를 파싱했지만, `BookContentBlock`은 `activity`를 지원하지 않아 parse→serialize 왕복에서 퀴즈 14개가 모두 사라졌습니다. 따라서 이 BookData의 네이티브 퀴즈는 현재 앱 모델과 호환되지 않습니다.\n\n필요한 앱 계약: `activity` 타입과 불투명 payload를 `BookContentBlock`에서 왕복 보존하고, 지원하는 `quiz`를 학생·교사 읽기 화면에서 선택·피드백까지 렌더링합니다. 미지원 activity는 조용히 버리지 말고 보존 가능한 fallback으로 처리합니다. 왕복 단위 테스트와 두 읽기 화면 상호작용 테스트가 필요합니다.", "`BookData.fromJson`→`toJson` 왕복에서 activity payload 전체가 보존되고, 학생 `BookWidget`과 교사 코스 읽기 화면의 quiz 선택·피드백이 호환성 테스트를 통과했습니다. 관련 HTML은 계속 별도 자산이며 앱 HTML 실행·화면 동등성은 미검증입니다.")
        readme_path.write_text(readme,encoding="utf-8")
    print(f"Built {len(chapters)} Algebra modules, {len(page_ids)} pages, {len(chapters)} quizzes; 15/18 candidate standards.")


if __name__ == "__main__":
    main()
