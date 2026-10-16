"""Build the 15 untagged 2015 Probability and Statistics criteria as V2 drafts."""
from __future__ import annotations

import json
import math
import re
from pathlib import Path

from textbook_digest import canonical_file_sha256

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
SOURCE = ROOT / "work/official-curriculum/2015_appendix8_math.txt"
OUT = MANUSCRIPTS / "확률과통계_2015개정_미연결기준15모듈_Batch2_BookData_V2_시범.json"
PACKAGE = MANUSCRIPTS / "확률과통계_2015개정_미연결기준15모듈_Batch2_원고패키지"

SPECS = [
    {
        "code": "12확통01-01", "title": "원순열과 중복되는 대상의 순열",
        "lead": "서로 다른 네 사람이 둥근 탁자에 앉을 때 회전해서 같은 배치는 한 가지로 세려면 어떻게 할까?",
        "concept": "서로 다른 n개를 원형으로 배열하는 원순열은 회전한 배열을 같은 것으로 보아 (n−1)!가지다. 같은 것이 있는 순열은 전체 배열 수를 같은 대상끼리의 순열 수로 나눈다. 중복순열은 각 자리에 같은 대상을 다시 사용할 수 있어 n개 중 r개를 고를 때 n^r가지다.",
        "example": "서로 다른 네 사람의 원탁 배치는 (4−1)!=6가지다. A,A,B 세 글자의 서로 다른 배열은 3!/2!=3가지다.",
        "practice": "서로 다른 네 사람이 원탁에 앉는 방법 수와 A,A,B,C의 서로 다른 배열 수를 각각 구하세요.",
        "answer": "원탁 배치는 3!=6가지, A,A,B,C는 4!/2!=12가지입니다.",
        "prompt": "서로 다른 네 사람이 원탁에 앉는 원순열의 수는?", "options": ["12", "6", "24"], "correct": 1,
        "feedback": "회전한 배치를 같게 보므로 한 사람을 고정해 나머지 세 사람을 배열합니다.",
        "wrong": "원순열은 한 사람을 고정하고 남은 사람만 배열합니다.",
        "hints": ["한 사람의 자리를 고정합니다.", "남은 세 사람의 순열 수를 구합니다."],
    },
    {
        "code": "12확통01-02", "title": "중복조합으로 종류별 선택 세기",
        "lead": "세 종류의 과자에서 모두 네 봉지를 고르되 같은 종류를 여러 번 골라도 된다면 몇 가지일까?",
        "concept": "서로 다른 n종류에서 중복을 허용해 r개를 순서 없이 고르는 중복조합의 수는 nHr = n+r−1Cr이다. 선택 순서는 구별하지 않는다.",
        "example": "세 종류에서 네 개를 고르는 경우는 x₁+x₂+x₃=4의 음이 아닌 정수해 수와 같다. 별 네 개와 구분 막대 두 개를 배열해 6C2=15가지다.",
        "practice": "네 종류의 음료에서 세 병을 순서 없이 고르는 방법 수를 구하세요. 같은 음료를 여러 병 골라도 됩니다.",
        "answer": "4H3=4+3−1C3=6C3=20가지입니다.",
        "prompt": "세 종류 과자에서 네 봉지를 중복을 허용해 고르는 방법 수는?", "options": ["12", "15", "20"], "correct": 1,
        "feedback": "3H4=3+4−1C4=6C4=15입니다.",
        "wrong": "종류별 개수를 합이 4가 되는 음이 아닌 정수로 나타냅니다.",
        "hints": ["x₁+x₂+x₃=4로 둡니다.", "별 네 개와 막대 두 개를 놓을 자리 여섯 개 중 막대 둘을 고릅니다."],
    },
    {
        "code": "12확통01-03", "title": "이항정리로 항의 계수 구하기",
        "lead": "(2+x)^5를 모두 전개하지 않고 x^3의 계수를 찾을 수 있을까?",
        "concept": "이항정리는 (a+b)^n = Σ nCk a^(n−k)b^k를 뜻한다. 각 항은 이항계수와 두 항의 거듭제곱을 곱해 얻으며, 필요한 항만 골라 계산할 수 있다.",
        "example": "(2+x)^5에서 x^3항은 5C3·2^(5−3)·x^3 = 10·4·x^3이므로 계수는 40이다.",
        "practice": "(1+2x)^4에서 x^2의 계수를 구하세요.",
        "answer": "4C2·(2x)^2의 계수이므로 6·4=24입니다.",
        "prompt": "(2+x)^5에서 x^3의 계수는?", "options": ["20", "40", "60"], "correct": 1,
        "feedback": "x^3을 고르는 항은 5C3·2^2·x^3입니다.",
        "wrong": "x의 지수가 3인 항의 이항계수와 남은 2의 거듭제곱을 곱합니다.",
        "hints": ["k=3인 항을 선택합니다.", "5C3·2^(5−3)을 계산합니다."],
    },
    {
        "code": "12확통02-01", "title": "통계적 확률과 수학적 확률",
        "lead": "주사위를 여러 번 던져 짝수가 나온 비율과 눈이 모두 같은 가능성이라고 가정해 계산한 확률은 어떻게 다를까?",
        "concept": "수학적 확률은 근원사건이 같은 가능성이라고 가정할 때 사건에 속한 경우의 수를 전체 경우의 수로 나눈 값이다. 통계적 확률은 시행 횟수가 커질 때 관찰된 상대도수로 확률을 추정한다. 통계적 확률은 실제 자료에 기반하며 유한한 시행에서는 값이 변한다.",
        "example": "공정한 주사위에서 짝수 눈의 수학적 확률은 3/6=1/2다. 100회 시행에서 짝수가 54번이면 통계적 상대도수는 54/100=0.54다.",
        "practice": "공정한 주사위를 200회 던져 6이 28번 나왔습니다. 6이 나올 수학적 확률과 이번 실험의 통계적 상대도수를 각각 쓰세요.",
        "answer": "수학적 확률은 1/6, 실험의 상대도수는 28/200=0.14입니다.",
        "prompt": "공정한 주사위에서 짝수가 나올 수학적 확률은?", "options": ["1/3", "1/2", "2/3"], "correct": 1,
        "feedback": "짝수 눈 2,4,6 세 가지를 전체 여섯 눈으로 나눕니다.",
        "wrong": "같은 가능성인 여섯 눈 중 짝수 눈이 몇 개인지 셉니다.",
        "hints": ["짝수 눈을 나열합니다.", "사건에 속하는 눈 수를 6으로 나눕니다."],
    },
    {
        "code": "12확통02-02", "title": "확률의 기본 성질",
        "lead": "서로 겹치지 않는 결과들의 확률을 더하면 어떤 범위 안의 값을 얻을까?",
        "concept": "확률은 0 이상 1 이하이고, 전체 표본공간의 확률은 1이며, 불가능한 사건의 확률은 0이다. 서로 배반인 사건들의 합집합 확률은 각 확률의 합이다.",
        "example": "표본공간의 세 결과에 각각 0.2, 0.3, 0.5의 확률을 주면 합은 1이다. 첫째 또는 둘째 결과가 나올 확률은 0.2+0.3=0.5다.",
        "practice": "서로 배반인 세 사건의 확률이 각각 0.1, 0.25, 0.4입니다. 세 사건 중 하나가 일어날 확률을 구하세요.",
        "answer": "서로 배반이므로 확률의 합은 0.1+0.25+0.4=0.75입니다.",
        "prompt": "서로 배반인 두 결과의 확률이 0.2와 0.3일 때, 둘 중 하나가 나올 확률은?", "options": ["0.5", "0.3", "0.2"], "correct": 0,
        "feedback": "서로 배반이므로 두 확률을 더합니다.",
        "wrong": "두 사건이 동시에 일어나지 않는다는 조건을 사용합니다.",
        "hints": ["두 사건의 교집합 확률은 0입니다.", "합집합 확률은 0.2+0.3입니다."],
    },
    {
        "code": "12확통02-03", "title": "확률의 덧셈정리",
        "lead": "두 사건에 동시에 속하는 결과를 한 번만 세려면 합집합 확률을 어떻게 계산할까?",
        "concept": "두 사건 A,B에 대해 P(A∪B)=P(A)+P(B)−P(A∩B)이다. 두 사건이 겹치는 결과를 두 번 더했으므로 교집합을 한 번 뺀다. 서로 배반이면 교집합 확률이 0이다.",
        "example": "주사위에서 A=짝수, B=5보다 큰 눈이면 P(A)=3/6, P(B)=2/6, P(A∩B)=1/6이다. 따라서 P(A∪B)=4/6=2/3이다.",
        "practice": "주사위에서 A={1,2,3,4}, B={3,4,5}일 때 P(A∪B)를 구하세요.",
        "answer": "A∪B={1,2,3,4,5}이므로 확률은 5/6입니다.",
        "prompt": "주사위에서 A=짝수, B=4보다 큰 눈일 때 P(A∪B)는?", "options": ["1/2", "2/3", "5/6"], "correct": 1,
        "feedback": "3/6+2/6−1/6=4/6=2/3입니다.",
        "wrong": "두 사건에 모두 속하는 눈 6을 한 번 빼야 합니다.",
        "hints": ["P(A)=3/6, P(B)=2/6입니다.", "교집합은 눈 6 하나이므로 1/6을 뺍니다."],
    },
    {
        "code": "12확통02-04", "title": "여사건으로 반대 경우 계산하기",
        "lead": "두 번 던진 주사위에서 6이 적어도 한 번 나올 확률을 직접 세지 않고 구해 보자.",
        "concept": "사건 A의 여사건 Aᶜ는 A가 일어나지 않는 사건이고 P(Aᶜ)=1−P(A)이다. ‘적어도 하나’처럼 직접 세기 복잡한 사건은 ‘하나도 없음’의 여사건으로 계산할 수 있다.",
        "example": "두 번 모두 6이 아닐 확률은 (5/6)^2=25/36이다. 따라서 6이 적어도 한 번 나올 확률은 1−25/36=11/36이다.",
        "practice": "동전을 세 번 던질 때 앞면이 적어도 한 번 나올 확률을 여사건으로 구하세요.",
        "answer": "앞면이 한 번도 안 나올 확률은 (1/2)^3=1/8이므로 구하는 확률은 7/8입니다.",
        "prompt": "주사위를 두 번 던질 때 6이 적어도 한 번 나올 확률은?", "options": ["25/36", "11/36", "5/6"], "correct": 1,
        "feedback": "여사건은 두 번 모두 6이 아닌 경우로 확률은 25/36입니다.",
        "wrong": "먼저 6이 한 번도 나오지 않는 확률을 구해 1에서 뺍니다.",
        "hints": ["한 번에 6이 안 나올 확률은 5/6입니다.", "두 번 모두 안 나올 확률은 (5/6)^2입니다."],
    },
    {
        "code": "12확통02-06", "title": "독립과 종속을 확률로 판단하기",
        "lead": "동전을 던진 결과가 주사위의 눈에 영향을 주지 않는다는 것을 확률식으로 어떻게 표현할까?",
        "concept": "사건 A,B가 독립이면 P(A∩B)=P(A)P(B)이며, 한 사건의 발생이 다른 사건의 확률을 바꾸지 않는다. 이 등식이 성립하지 않으면 두 사건은 종속이다.",
        "example": "공정한 동전에서 앞면 사건 A와 주사위에서 6이 나오는 사건 B는 독립이다. P(A∩B)=1/12=(1/2)(1/6)이다.",
        "practice": "주사위를 한 번 던져 짝수인 사건 A와 3보다 큰 사건 B를 둡니다. 두 사건이 독립인지 확인하세요.",
        "answer": "P(A∩B)=2/6=1/3이고 P(A)P(B)=(1/2)(1/2)=1/4이므로 서로 종속입니다.",
        "prompt": "공정한 동전의 앞면과 주사위의 6은 독립입니다. 두 사건이 모두 일어날 확률은?", "options": ["1/6", "1/12", "1/3"], "correct": 1,
        "feedback": "독립이므로 (1/2)(1/6)=1/12입니다.",
        "wrong": "각 사건의 확률을 곱합니다.",
        "hints": ["앞면의 확률은 1/2입니다.", "6의 확률은 1/6이며 서로 독립입니다."],
    },
    {
        "code": "12확통02-07", "title": "확률의 곱셈정리",
        "lead": "되돌려 놓지 않고 두 번 뽑을 때 두 결과가 모두 빨간 공일 확률을 어떤 순서로 계산할까?",
        "concept": "P(A∩B)=P(A)P(B|A)이다. 첫 사건 A가 일어난 뒤의 조건부확률 P(B|A)를 곱한다. A와 B가 독립인 경우에는 P(B|A)=P(B)이므로 독립 곱셈법칙이 된다.",
        "example": "빨간 공 3개, 파란 공 2개에서 되돌려 놓지 않고 두 번 뽑아 둘 다 빨간색일 확률은 (3/5)(2/4)=3/10이다.",
        "practice": "빨간 공 4개, 파란 공 3개에서 되돌려 놓지 않고 두 번 뽑아 모두 빨간색일 확률을 구하세요.",
        "answer": "(4/7)(3/6)=12/42=2/7입니다.",
        "prompt": "빨간 공 3개, 파란 공 2개에서 두 번 비복원 추출해 모두 빨간색일 확률은?", "options": ["1/5", "3/10", "2/5"], "correct": 1,
        "feedback": "첫 빨간색 확률 3/5에 이어 남은 빨간 공 비율 2/4를 곱합니다.",
        "wrong": "첫 번째 추출 뒤 전체와 빨간 공의 수가 모두 하나씩 줄어듭니다.",
        "hints": ["첫 번째 빨간색 확률은 3/5입니다.", "첫 번째가 빨간색이면 남은 빨간 공은 2개, 전체는 4개입니다."],
    },
    {
        "code": "12확통03-01", "title": "확률변수와 확률분포",
        "lead": "주사위를 던져 짝수면 1, 홀수면 0을 주는 값을 확률변수로 나타내 보자.",
        "concept": "확률변수는 시행 결과를 실수 값에 대응시키는 변수다. 확률분포는 확률변수가 가질 값과 각 값을 가질 확률을 함께 나타낸다. 가능한 확률은 0 이상이고 전체 합은 1이다.",
        "example": "짝수면 X=1, 홀수면 X=0으로 두면 P(X=0)=3/6=1/2, P(X=1)=3/6=1/2이다. 두 확률의 합은 1이다.",
        "practice": "공정한 주사위에서 1 또는 2가 나오면 X=1, 그 밖에는 X=0으로 정의합니다. X의 확률분포를 쓰세요.",
        "answer": "P(X=1)=2/6=1/3, P(X=0)=4/6=2/3입니다.",
        "prompt": "공정한 주사위에서 짝수면 X=1, 홀수면 X=0일 때 P(X=1)은?", "options": ["1/3", "1/2", "2/3"], "correct": 1,
        "feedback": "짝수인 눈은 2,4,6 세 가지입니다.",
        "wrong": "X=1이 되는 주사위 눈을 모두 세어 전체 6으로 나눕니다.",
        "hints": ["X=1은 짝수 눈입니다.", "짝수 눈 세 개를 여섯 눈으로 나눕니다."],
    },
    {
        "code": "12확통03-02", "title": "이산확률변수의 평균과 표준편차",
        "lead": "공정한 동전을 앞면이면 2점, 뒷면이면 0점으로 기록할 때 점수의 평균과 표준편차는 얼마일까?",
        "concept": "이산확률변수 X의 기댓값은 E(X)=ΣxP(X=x)이고 분산은 V(X)=Σ(x−E(X))²P(X=x)이다. 표준편차는 분산의 양의 제곱근이다.",
        "example": "0점과 2점이 각각 1/2 확률이면 E(X)=1이다. 분산은 (0−1)²/2+(2−1)²/2=1이므로 표준편차도 1이다.",
        "practice": "확률변수 X가 1, 3을 각각 1/2 확률로 가질 때 평균과 표준편차를 구하세요.",
        "answer": "평균은 2, 분산은 1이므로 표준편차는 1입니다.",
        "prompt": "동전 앞면에 2점, 뒷면에 0점을 주고 각 확률이 1/2일 때 평균과 표준편차는?", "options": ["평균 0.5, 표준편차 0.5", "평균 1, 표준편차 1", "평균 2, 표준편차 1"], "correct": 1,
        "feedback": "평균은 (0+2)/2=1이고 두 값은 평균에서 각각 1만큼 떨어져 있습니다.",
        "wrong": "먼저 기댓값을 구한 뒤 각 값과 평균의 편차 제곱을 평균합니다.",
        "hints": ["E(X)=0·1/2+2·1/2입니다.", "두 결과의 평균으로부터 거리의 제곱은 모두 1입니다."],
    },
    {
        "code": "12확통03-04", "title": "정규분포의 대칭성과 표준화",
        "lead": "종 모양으로 대칭인 정규분포에서 평균을 기준으로 왼쪽과 오른쪽의 넓이는 어떻게 나뉠까?",
        "concept": "정규분포 N(m,σ²)는 평균 m을 중심으로 대칭인 연속확률분포이며 σ>0은 표준편차다. 평균보다 작은 값과 큰 값의 확률은 각각 1/2이다. 표준화하면 Z=(X−m)/σ가 표준정규분포 N(0,1)을 따른다.",
        "example": "X~N(100,15²)이면 평균 100을 중심으로 대칭이므로 P(X≤100)=P(X≥100)=1/2이다. 연속분포이므로 P(X=100)=0이다.",
        "practice": "X~N(20,4²)일 때 P(X>20)을 구하고, 표준화한 경계값을 쓰세요.",
        "answer": "평균보다 큰 쪽의 넓이는 1/2이고 표준화 경계는 (20−20)/4=0입니다.",
        "prompt": "평균이 100인 정규분포에서 P(X>100)은?", "options": ["0.25", "0.5", "0.95"], "correct": 1,
        "feedback": "정규분포는 평균을 기준으로 대칭이므로 오른쪽 넓이는 절반입니다.",
        "wrong": "평균을 중심으로 곡선의 양쪽 넓이가 같은 성질을 사용합니다.",
        "hints": ["평균은 대칭축입니다.", "전체 넓이 1을 양쪽으로 똑같이 나눕니다."],
    },
    {
        "code": "12확통03-05", "title": "모집단과 표본, 임의추출",
        "lead": "학교 전체 학생의 통학 시간을 조사할 때 일부 학생만 조사해 전체를 추론하려면 누구를 뽑아야 할까?",
        "concept": "모집단은 조사하려는 대상 전체이고 표본은 모집단에서 조사 대상으로 뽑은 일부다. 임의추출은 특정 대상이 체계적으로 유리하거나 불리해지지 않도록 표본을 뽑는 방법이다. 편향을 줄이려면 모집단을 대표할 수 있게 추출해야 한다.",
        "example": "학생 500명의 통학 시간을 알고 싶다면 500명을 모집단으로 보고, 학생 명단에서 무작위로 뽑은 40명을 표본으로 조사할 수 있다. 먼저 등교한 40명만 조사하면 통학 방식이 치우칠 수 있다.",
        "practice": "한 지역 800가구의 전기 사용량을 추정하려 합니다. 모집단과 표본을 구별하고 편향을 줄일 추출 방법을 제안하세요.",
        "answer": "모집단은 800가구 전체이고, 명단에서 무작위로 선정한 일부 가구가 표본입니다.",
        "prompt": "학교 전체 학생의 의견을 조사할 때 편향을 줄이는 표본은?", "options": ["먼저 도착한 20명", "학생 명단에서 무작위로 뽑은 20명", "희망자 20명"], "correct": 1,
        "feedback": "명단에서 무작위 추출하면 특정 시간대나 자원자에 치우치는 것을 줄입니다.",
        "wrong": "표본이 모집단의 일부를 공정하게 대표하도록 뽑아야 합니다.",
        "hints": ["먼저 온 사람이나 자원자만 고르면 특정 집단이 몰릴 수 있습니다.", "전체 명단을 바탕으로 무작위로 뽑습니다."],
    },
    {
        "code": "12확통03-06", "title": "표본평균과 모평균의 관계",
        "lead": "모집단에서 표본을 여러 번 뽑으면 표본평균도 달라진다. 표본평균들의 평균은 무엇과 연결될까?",
        "concept": "표본평균은 표본에 따라 달라지는 확률변수다. 같은 크기의 임의표본을 반복 추출하면 표본평균의 기댓값은 모평균과 같으며, 표본평균의 분포는 모평균 주변에 놓인다.",
        "example": "모집단 {1,3}에서 크기 2의 표본을 복원추출하면 표본평균은 1,2,3이고 확률은 각각 1/4,1/2,1/4이다. 표본평균의 기댓값은 1·1/4+2·1/2+3·1/4=2로 모평균 2와 같다.",
        "practice": "모집단 {0,4}에서 크기 2로 복원추출할 때 가능한 표본평균과 그 확률을 구하고 평균이 모평균과 같은지 확인하세요.",
        "answer": "표본평균은 0,2,4이고 확률은 1/4,1/2,1/4입니다. 그 기댓값은 2로 모평균 2와 같습니다.",
        "prompt": "모집단 {1,3}에서 크기 2를 복원추출할 때 표본평균의 기댓값은?", "options": ["1", "2", "3"], "correct": 1,
        "feedback": "표본평균 분포로 계산하면 1·1/4+2·1/2+3·1/4=2입니다.",
        "wrong": "가능한 표본평균 1,2,3의 확률을 각각 1/4,1/2,1/4로 가중합합니다.",
        "hints": ["두 추출값이 모두 1, 서로 다름, 모두 3인 경우를 셉니다.", "표본평균 확률은 1/4, 1/2, 1/4입니다."],
    },
    {
        "code": "12확통03-07", "title": "정규모집단의 모평균 신뢰구간",
        "lead": "정규분포를 따르는 모집단에서 표본을 뽑아 모평균을 추정할 때 표본평균 주변의 구간을 어떻게 해석할까?",
        "concept": "정규모집단의 표준편차 σ를 알고 크기 n인 임의표본의 평균이 x̄이면 모평균의 95% 신뢰구간은 x̄±1.96σ/√n이다. 같은 방법으로 표본을 반복해 구간을 만들면 그 구간들의 약 95%가 참 모평균을 포함한다. 한 번 얻은 구간 안에 모평균이 있을 확률이 95%라는 뜻은 아니다.",
        "example": "정규모집단에서 σ=6, n=36, 표본평균 x̄=50이면 표준오차는 6/√36=1이다. 95% 신뢰구간은 50±1.96, 즉 [48.04,51.96]이다.",
        "practice": "정규모집단의 σ=10, 표본크기 100, 표본평균 72일 때 95% 신뢰구간을 구하고 반복표집 관점에서 해석하세요.",
        "answer": "표준오차는 10/√100=1이므로 구간은 72±1.96, 즉 [70.04,73.96]입니다. 같은 절차를 반복하면 구간의 약 95%가 모평균을 포함합니다.",
        "prompt": "정규모집단에서 σ=6, n=36, 표본평균 50일 때 95% 신뢰구간은?", "options": ["[48.04,51.96]", "[44,56]", "[49.8,50.2]"], "correct": 0,
        "feedback": "표준오차는 6/6=1이므로 50±1.96입니다.",
        "wrong": "표본평균에 1.96·σ/√n을 더하고 뺍니다.",
        "hints": ["표준오차 σ/√n을 먼저 구합니다.", "6/√36=1이므로 50±1.96을 계산합니다."],
    },
]

EXPECTED_CRITERIA = {
    "12확통01-01": "원순열, 중복순열, 같은 것이 있는 순열을 이해하고, 그 순열의 수를 구할 수 있다.",
    "12확통01-02": "중복조합을 이해하고, 중복조합의 수를 구할 수 있다.",
    "12확통01-03": "이항정리를 이해하고 이를 이용하여 문제를 해결할 수 있다.",
    "12확통02-01": "통계적 확률과 수학적 확률의 의미를 이해한다.",
    "12확통02-02": "확률의 기본 성질을 이해한다.",
    "12확통02-03": "확률의 덧셈정리를 이해하고, 이를 활용할 수 있다.",
    "12확통02-04": "여사건의 확률의 뜻을 알고, 이를 활용할 수 있다.",
    "12확통02-06": "사건의 독립과 종속의 의미를 이해하고, 이를 설명할 수 있다.",
    "12확통02-07": "확률의 곱셈정리를 이해하고, 이를 활용할 수 있다.",
    "12확통03-01": "확률변수와 확률분포의 뜻을 안다.",
    "12확통03-02": "이산확률변수의 기댓값(평균)과 표준편차를 구할 수 있다.",
    "12확통03-04": "정규분포의 뜻을 알고, 그 성질을 이해한다.",
    "12확통03-05": "모집단과 표본의 뜻을 알고 표본추출의 원리를 이해한다.",
    "12확통03-06": "표본평균과 모평균의 관계를 이해하고 설명할 수 있다.",
    "12확통03-07": "모평균을 추정하고, 그 결과를 해석할 수 있다.",
}


def quiz(spec: dict[str, object], activity_id: str) -> dict[str, object]:
    return {"type": "activity", "activity": {
        "id": activity_id, "kind": "quiz", "prompt": spec["prompt"],
        "options": spec["options"], "correct_index": spec["correct"],
        "correct_feedback": spec["feedback"], "incorrect_feedback": spec["wrong"],
        "hints": spec["hints"],
    }}


def main() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    official = {m.group(1): re.sub(r"\s+", " ", m.group(2)).strip()
                for m in re.finditer(r"\[([^\]\s]+-\d{2})\]\s*([^\r\n]*)", source)}
    existing = {"12확통02-05", "12확통03-03"}
    expected = {
        "12확통01-01", "12확통01-02", "12확통01-03", "12확통02-01",
        "12확통02-02", "12확통02-03", "12확통02-04", "12확통02-06",
        "12확통02-07", "12확통03-01", "12확통03-02", "12확통03-04",
        "12확통03-05", "12확통03-06", "12확통03-07",
    }
    codes = [str(item["code"]) for item in SPECS]
    if len(codes) != 15 or len(set(codes)) != 15 or set(codes) != expected:
        raise RuntimeError("Batch2 must contain exactly the 15 currently unmapped 2015 standards")
    if set(codes) & existing or any(code not in official for code in codes):
        raise RuntimeError("Batch2 codes overlap existing candidates or are absent from the official source")
    if any(official.get(code) != criterion for code, criterion in EXPECTED_CRITERIA.items()):
        raise RuntimeError("An official 2015 criterion changed; review the draft-to-standard mapping")
    chapters = []
    for item in SPECS:
        code = str(item["code"])
        slug = code.replace("12확통", "prob15-").replace("-", "")
        pages = [
            {"id": slug+"-open", "template": "opening", "title": "상황과 질문", "blocks": [
                {"type": "lead", "title": "가상 예시", "text": item["lead"]},
                {"type": "thinking", "title": "먼저 생각하기", "text": "주어진 조건과 구하려는 값을 표시하고, 사용할 확률 또는 통계 관계를 예상합니다."},
            ]},
            {"id": slug+"-concept", "template": "concept", "title": "정의와 성질", "blocks": [
                {"type": "definition", "title": "핵심 개념", "text": item["concept"]},
                {"type": "formula", "title": "연결한 공식 기준", "text": code},
                {"type": "misconception", "title": "조건 점검", "text": "표본공간, 독립 여부, 분포의 가정 또는 추정 절차를 확인합니다."},
            ]},
            {"id": slug+"-example", "template": "example", "title": "예제와 풀이", "blocks": [
                {"type": "question", "title": "예제", "text": item["lead"]},
                {"type": "solutionStep", "title": "풀이", "text": item["example"]},
                {"type": "verification", "title": "검산", "text": "계산 결과가 확률의 범위와 문제의 조건을 만족하는지 확인합니다."},
            ]},
            {"id": slug+"-practice", "template": "practice", "title": "연습과 설명", "blocks": [
                {"type": "question", "title": "연습", "text": item["practice"]},
                {"type": "hint", "title": "힌트", "text": item["hints"][0]},
                {"type": "solutionStep", "title": "해설", "text": item["answer"]},
                {"type": "answer", "title": "정답", "text": item["answer"]},
                quiz(item, slug+"-quiz"),
            ]},
            {"id": slug+"-summary", "template": "summary", "title": "핵심 정리", "blocks": [
                {"type": "summary", "title": "기억할 점", "text": item["title"]},
                {"type": "checklist", "title": "스스로 확인", "text": "공식의 조건을 확인하고 계산과 결과의 의미를 설명할 수 있나요?"},
            ]},
        ]
        chapters.append({"title": item["title"], "intro": [
            f"2015 교육과정 공식 기준 {code}에 연결한 신규 후보입니다.",
            "상황과 수치는 직접 만든 가상 예시입니다.",
        ], "pages": pages})
    all_ids = [p["id"] for c in chapters for p in c["pages"]]
    if len(all_ids) != 75 or len(set(all_ids)) != 75:
        raise RuntimeError("Expected 75 unique pages")
    # Independent arithmetic spot checks for examples and answers in this batch.
    checks = [
        math.factorial(3), math.comb(6, 2), math.comb(5, 3)*2**2,
        3/6, 0.2+0.3, 3/6+2/6-1/6, 1-(5/6)**2,
        (1/2)*(1/6), (3/5)*(2/4), 3/6,
        math.sqrt(((0-1)**2+(2-1)**2)/2), 0.5,
        0.5, (1/4)+2*(1/2)+3*(1/4), 50-1.96,
    ]
    expected_values = [6, 15, 40, 0.5, 0.5, 2/3, 11/36, 1/12, 3/10, 0.5, 1, 0.5, 0.5, 2, 48.04]
    if any(not math.isclose(a, b, rel_tol=1e-12, abs_tol=1e-12) for a,b in zip(checks, expected_values)):
        raise RuntimeError("Arithmetic spot check failed")
    for item in SPECS:
        if not (0 <= int(item["correct"]) < len(item["options"])):
            raise RuntimeError(f"Invalid quiz answer key for {item['code']}")
    union_quiz = next(item for item in SPECS if item["code"] == "12확통02-03")
    if "B=4보다 큰" not in str(union_quiz["prompt"]) or union_quiz["options"][union_quiz["correct"]] != "2/3":
        raise RuntimeError("The addition-rule quiz prompt and answer must describe A={even}, B={5,6}")
    book = {
        "schema_version": 2,
        "title": "확률과 통계 · 2015 미연결 기준 보완 15모듈 후보",
        "subtitle": "경우의 수·확률·확률분포·통계적 추정",
        "category": "concept_textbook_prototype", "curriculum_version": "2015",
        "tags": ["확률과 통계", "2015 개정", "추가 원고 후보", "가상 예시", "상품 범위 미완", *codes],
        "standard_codes": codes, "chapters": chapters,
    }
    OUT.write_text(json.dumps(book, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    PACKAGE.mkdir(parents=True, exist_ok=True)
    manifest_path = PACKAGE / "REVIEW_MANIFEST.json"
    try:
        old = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        old = {}
    digest = canonical_file_sha256(OUT)
    same = old.get("bookdata_sha256") == digest
    manifest = {
        "bookdata_file": OUT.name, "bookdata_sha256": digest,
        "candidate_code_references": codes,
        "candidate_code_reference_type": "official_2015_appendix8_text",
        "module_count": 15, "page_count": 75, "native_activity_count": 15,
        "native_activity_kinds": ["quiz"],
        "example_data_status": "synthetic_original_examples; no commercial text, problem, illustration, or dataset copied",
        "curriculum_review_status": "official_codes_verified; product_scope_pending",
        "math_review_status": "pending_full_teacher_review",
        "math_arithmetic_check_status": "pass_for_listed_spot_checks_only",
        "author_math_review_status": "manual_spot_review_with_12확통02-03_prompt_correction; independent_teacher_review_pending",
        "teacher_review_status": "pending",
        "rights_status": "newly_authored; publication_rights_decision_pending",
        "source_interaction_status": "native_quiz_activity_candidate; no source HTML parity claimed",
        "integration_status": "candidate_for_unit_grouping; not_merged_into_master_book",
        "publication_eligibility": "not_eligible",
        "runtime_import_status": old.get("runtime_import_status", "pending_current_hash_validation") if same else "pending_current_hash_validation",
        "runtime_validator_head": old.get("runtime_validator_head") if same else None,
        "runtime_validation_command": old.get("runtime_validation_command") if same else None,
        "runtime_validator_candidate_sha256": old.get("runtime_validator_candidate_sha256") if same else None,
    }
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    (PACKAGE / "README.md").write_text(
        f"# {book['title']}\n\n2015 공식 기준 15개에 연결한 15모듈·75쪽 V2 후보입니다. 내용과 수치는 직접 작성했으며, 학기 배정 및 과목 전체 연결은 별도 대조가 필요합니다. 교사·수학 검토와 권리 결정 전에는 출판 적격이 아닙니다.\n\nBookData: [`{OUT.name}`](../{OUT.name})\n",
        encoding="utf-8",
    )
    print(f"Built 15 2015 Probability and Statistics modules, 75 pages, 15 quizzes: {OUT}")


if __name__ == "__main__":
    main()
