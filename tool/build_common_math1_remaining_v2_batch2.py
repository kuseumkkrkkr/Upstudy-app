"""Build the 16 still-untagged 2022 Common Math 1 standards as original V2 modules."""
from __future__ import annotations

import json
import math
from pathlib import Path

from textbook_digest import canonical_file_sha256

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
STANDARDS = ROOT / "work/official-curriculum/2022_math_standards.json"
OUT = MANUSCRIPTS / "공통수학1_2022개정_미연결기준16모듈_Batch2_BookData_V2_시범.json"
PACKAGE = MANUSCRIPTS / "공통수학1_2022개정_미연결기준16모듈_Batch2_원고패키지"

SPECS = [
    {"code":"10공수1-01-01","title":"다항식의 사칙연산","lead":"두 다항식을 더하고 곱할 때 동류항과 분배법칙을 어떻게 적용할까?","concept":"다항식의 덧셈·뺄셈은 동류항끼리 계수를 계산한다. 곱셈은 분배법칙을 적용하고, 나눗셈은 나누는 다항식이 0이 아닌 범위에서 몫과 나머지를 확인한다.","example":"(2x²−x+3)+(x²+4x−1)=3x²+3x+2이다. (x²+3x+2)÷(x+1)=x+2는 (x+1)(x+2)=x²+3x+2로 검산한다.","practice":"(x²−2x+1)(x+2)를 전개하고, x²−1을 x−1로 나누세요.","answer":"곱은 x³−3x+2이고, 나눗셈의 몫은 x+1입니다.","prompt":"(x²+3x+2)÷(x+1)의 몫은?","options":["x+2","x−2","x²+2"],"correct":0,"feedback":"(x+1)(x+2)=x²+3x+2입니다.","wrong":"몫에 x+1을 곱해 원래 다항식이 되는지 확인하세요.","hints":["다항식을 곱으로 인수분해해 보세요.","x²+3x+2=(x+1)(x+2)입니다."],"check":"나눗셈 결과를 나누는 식과 곱해 피제수와 같은지 검산한다."},
    {"code":"10공수1-01-02","title":"항등식과 나머지정리","lead":"다항식을 x−a로 나눈 나머지를 긴 나눗셈 없이 어떻게 찾을까?","concept":"모든 x에서 성립하는 식을 항등식이라 한다. 다항식 f(x)를 x−a로 나눈 나머지는 f(a)이다. 항등식의 계수를 비교하거나 적절한 x값을 대입해 미지수를 구할 수 있다.","example":"f(x)=x³−2x+1을 x−1로 나눈 나머지는 f(1)=1−2+1=0이다. 따라서 x−1은 f(x)의 인수다.","practice":"f(x)=2x²−3x+4를 x+2로 나눌 때 나머지를 구하세요.","answer":"x+2=x−(−2)이므로 나머지는 f(−2)=2·4+6+4=18입니다.","prompt":"f(x)=x³−2x+1을 x−1로 나눈 나머지는?","options":["0","1","−1"],"correct":0,"feedback":"나머지정리에 따라 f(1)=0입니다.","wrong":"x−a에서 a=1을 찾아 f(1)을 계산하세요.","hints":["나누는 식을 x−a 꼴로 읽습니다.","x−1의 a는 1입니다."],"check":"인수정리에서 f(a)=0이면 x−a가 인수임을 확인한다."},
    {"code":"10공수1-01-03","title":"다항식의 인수분해","lead":"다항식의 공통 구조를 찾아 곱으로 나타내면 어떤 문제를 쉽게 풀 수 있을까?","concept":"인수분해는 다항식을 인수들의 곱으로 나타내는 것이다. 공통인수, 곱셈공식, 묶어내기 등을 사용하고, 전개해 원래 식으로 돌아오는지 확인한다.","example":"x²−5x+6은 곱이 6, 합이 −5인 두 수 −2, −3을 찾아 (x−2)(x−3)으로 인수분해한다.","practice":"x³−4x를 인수분해하세요.","answer":"공통인수 x를 먼저 묶으면 x(x²−4)=x(x−2)(x+2)입니다.","prompt":"x²−5x+6의 인수분해는?","options":["(x−2)(x−3)","(x+2)(x+3)","(x−1)(x−6)"],"correct":0,"feedback":"두 상수의 곱은 6, 합은 −5입니다.","wrong":"곱이 6이고 합이 −5인 두 수를 찾으세요.","hints":["6의 인수쌍을 적습니다.","−2와 −3의 곱은 6, 합은 −5입니다."],"check":"인수들의 곱을 전개해 처음 다항식과 일치하는지 확인한다."},
    {"code":"10공수1-02-01","title":"복소수의 뜻과 사칙연산","lead":"제곱해서 −1이 되는 수를 도입하면 어떤 이차방정식을 풀 수 있을까?","concept":"허수단위 i는 i²=−1을 만족한다. 복소수 a+bi에서 실수부와 허수부를 구분하고, 덧셈·뺄셈은 대응 성분끼리 계산한다. 곱셈은 분배법칙 뒤 i²=−1을 적용한다.","example":"(1+2i)(3−i)=3−i+6i−2i²=5+5i이다. (1+i)/(1−i)에 분모의 켤레복소수를 곱하면 i가 된다.","practice":"(2−i)+(−3+4i)와 (2+i)(1−i)를 계산하세요.","answer":"합은 −1+3i이고 곱은 3−i입니다.","prompt":"(1+2i)(3−i)는?","options":["5+5i","3+5i","5−5i"],"correct":0,"feedback":"전개한 뒤 −2i²=2로 바꿉니다.","wrong":"분배법칙을 적용하고 i²을 −1로 바꾸세요.","hints":["실수부와 허수부를 따로 모읍니다.","−2i²은 +2입니다."],"check":"각 계산에서 i²=−1을 사용하고 실수부·허수부를 정리한다."},
    {"code":"10공수1-02-02","title":"판별식으로 이차방정식의 근 판별","lead":"이차방정식이 서로 다른 두 실근, 중근, 서로 켤레인 두 허근을 갖는 조건은 무엇일까?","concept":"ax²+bx+c=0 (a≠0)의 판별식 D=b²−4ac를 사용한다. D>0이면 서로 다른 두 실근, D=0이면 중근, D<0이면 실근이 없고 서로 켤레인 두 허근을 갖는다.","example":"x²−2x+5=0에서 D=(−2)²−4·1·5=−16<0이므로 실근이 없다. 근은 1±2i이다.","practice":"2x²+4x+2=0의 판별식과 근의 종류를 구하세요.","answer":"D=4²−4·2·2=0이므로 중근을 갖고, 방정식은 2(x+1)²=0이어서 x=−1입니다.","prompt":"x²−2x+5=0의 실근은 몇 개인가요?","options":["없다","하나","서로 다른 두 개"],"correct":0,"feedback":"판별식 −16은 0보다 작습니다.","wrong":"D=b²−4ac의 부호와 근의 종류를 연결하세요.","hints":["a=1, b=−2, c=5입니다.","D=4−20입니다."],"check":"판별식 부호로 근의 종류를 판정하고 인수 또는 근의 공식을 검산한다."},
    {"code":"10공수1-02-03","title":"이차방정식의 근과 계수","lead":"두 근의 합과 곱만 알면 원래 이차방정식을 만들 수 있을까?","concept":"ax²+bx+c=0 (a≠0)의 두 근을 α, β라 하면 α+β=−b/a, αβ=c/a이다. 근을 알 때에는 x²−(근의 합)x+(근의 곱)=0을 이용해 방정식을 구성할 수 있다.","example":"x²−5x+6=0의 두 근은 2,3이며 합은 5=−(−5)/1, 곱은 6=6/1이다.","practice":"두 근이 −1과 4인 이차방정식을 최고차항 계수가 1이 되도록 쓰세요.","answer":"근의 합은 3, 곱은 −4이므로 x²−3x−4=0입니다.","prompt":"x²−5x+6=0의 두 근의 곱은?","options":["6","5","−5"],"correct":0,"feedback":"근의 곱은 c/a=6입니다.","wrong":"상수항을 최고차항 계수로 나누세요.","hints":["a=1, c=6입니다.","αβ=c/a를 사용합니다."],"check":"근의 합·곱 공식과 인수분해 결과를 서로 대조한다."},
    {"code":"10공수1-02-04","title":"이차방정식과 이차함수","lead":"f(x)=0의 해는 그래프 y=f(x)에서 어떤 점을 뜻할까?","concept":"이차방정식 ax²+bx+c=0의 실근은 이차함수 y=ax²+bx+c 그래프의 x절편의 x좌표다. 판별식의 부호는 그래프가 x축과 만나는 점의 개수와 연결된다.","example":"f(x)=x²−4x+3=(x−1)(x−3)이므로 방정식 f(x)=0의 해는 1,3이다. 그래프는 x축과 (1,0),(3,0)에서 만난다.","practice":"y=x²+2x+1 그래프와 x축의 교점의 x좌표를 구하고, 근의 종류를 말하세요.","answer":"x²+2x+1=(x+1)²이므로 x=−1에서 한 점 (−1,0)으로 접합니다. 방정식은 중근을 갖습니다.","prompt":"y=x²−4x+3의 x절편은?","options":["1과 3","−1과 −3","2 하나"],"correct":0,"feedback":"x²−4x+3=(x−1)(x−3)입니다.","wrong":"x절편에서는 y=0으로 놓고 인수분해합니다.","hints":["y=0으로 둡니다.","두 인수 중 하나가 0이 되게 합니다."],"check":"방정식의 해와 그래프의 x절편을 같은 x좌표로 연결한다."},
    {"code":"10공수1-02-05","title":"이차함수 그래프와 직선의 위치 관계","lead":"직선과 포물선은 만나지 않거나, 한 점에서 접하거나, 두 점에서 만날 수 있다. 어떻게 구분할까?","concept":"이차함수와 직선의 교점은 두 식을 연립해 얻는 이차방정식의 실근이다. 판별식이 양수·0·음수인지에 따라 교점이 두 개·한 개·없음으로 판정된다.","example":"y=x²와 y=2x−1을 같게 놓으면 (x−1)²=0이므로 두 그래프는 (1,1)에서 접한다.","practice":"y=x²와 y=−1의 교점 개수를 판별식 또는 그래프 성질로 구하세요.","answer":"x²=−1은 실근이 없으므로 교점이 없습니다. 포물선 y=x²는 항상 0 이상입니다.","prompt":"y=x²와 y=2x−1의 교점 개수는?","options":["한 개","두 개","없다"],"correct":0,"feedback":"두 식을 같게 놓으면 (x−1)²=0입니다.","wrong":"연립한 이차방정식의 판별식을 확인하세요.","hints":["x²=2x−1로 놓습니다.","x²−2x+1=0을 정리합니다."],"check":"교점 방정식의 판별식과 접점 좌표를 대조한다."},
    {"code":"10공수1-02-06","title":"이차함수의 최대·최소","lead":"둘레가 20인 직사각형 중 넓이가 가장 큰 모양은 무엇일까?","concept":"a>0인 이차함수는 꼭짓점에서 최솟값을, a<0인 이차함수는 꼭짓점에서 최댓값을 갖는다. 실생활 문제에서는 변수의 범위를 먼저 정하고 꼭짓점이 그 범위 안에 있는지 확인한다.","example":"가로 x, 세로 10−x인 직사각형의 넓이는 A(x)=x(10−x)=−(x−5)²+25이다. 0<x<10에서 x=5일 때 최대 넓이는 25이다.","practice":"가로 x, 세로 8−x인 직사각형에서 0<x<8일 때 넓이의 최댓값을 구하세요.","answer":"A=x(8−x)=−(x−4)²+16이므로 x=4에서 최댓값 16입니다.","prompt":"A=x(10−x), 0<x<10의 최댓값은?","options":["25","20","10"],"correct":0,"feedback":"A=−(x−5)²+25이고 x=5가 범위 안에 있습니다.","wrong":"완전제곱식으로 바꾸고 꼭짓점이 허용 범위에 있는지 확인하세요.","hints":["A=−x²+10x입니다.","A=−(x−5)²+25로 정리됩니다."],"check":"변수 범위, 꼭짓점 위치, 최대 넓이 값을 함께 확인한다."},
    {"code":"10공수1-02-09","title":"연립일차부등식","lead":"두 조건을 동시에 만족하는 x의 범위를 수직선에서 어떻게 찾을까?","concept":"연립일차부등식의 해는 각 부등식의 해집합의 교집합이다. 각각 풀고, 공통으로 포함되는 구간을 부등호의 등호 포함 여부와 함께 표시한다.","example":"x+1>3은 x>2이고 2x−4≤6은 x≤5이다. 두 조건을 모두 만족하는 범위는 2<x≤5이다.","practice":"3x−3≥0, x+2<6을 동시에 만족하는 x의 범위를 구하세요.","answer":"첫째는 x≥1, 둘째는 x<4이므로 1≤x<4입니다.","prompt":"x>2와 x≤5의 공통 해는?","options":["2<x≤5","x<2 또는 x>5","2≤x<5"],"correct":0,"feedback":"두 해집합의 교집합은 2보다 크고 5 이하입니다.","wrong":"두 부등식을 동시에 만족하는 구간만 남깁니다.","hints":["각 부등식을 먼저 풉니다.","수직선에서 겹치는 부분의 끝점 포함을 확인하세요."],"check":"공통 구간의 양 끝점에서 원래 두 부등식을 각각 확인한다."},
    {"code":"10공수1-02-10","title":"절댓값을 포함한 일차부등식","lead":"|2x−3|≤5는 수직선에서 어떤 거리 조건을 뜻할까?","concept":"|A|≤k (k≥0)은 −k≤A≤k와 같다. |A|>k는 A<−k 또는 A>k로 나뉜다. 절댓값 안의 일차식을 각 구간 조건으로 바꾸어 푼다.","example":"|2x−3|≤5이면 −5≤2x−3≤5, 따라서 −1≤x≤4이다.","practice":"|3x+1|>4의 해를 구하세요.","answer":"3x+1<−4 또는 3x+1>4이므로 x<−5/3 또는 x>1입니다.","prompt":"|2x−3|≤5의 해는?","options":["−1≤x≤4","x≤−1 또는 x≥4","−4≤x≤1"],"correct":0,"feedback":"절댓값이 5 이하이므로 안쪽 식은 −5부터 5 사이입니다.","wrong":"−5≤2x−3≤5로 바꾸고 양변을 풀어 보세요.","hints":["절댓값이 k 이하이면 안쪽은 −k 이상 k 이하입니다.","각 변에 3을 더한 뒤 2로 나눕니다."],"check":"부등호의 방향과 절댓값 조건의 연립·합집합 구분을 확인한다."},
    {"code":"10공수1-02-11","title":"이차부등식과 이차함수","lead":"포물선이 x축 위에 있는 구간을 알면 이차부등식을 어떻게 풀 수 있을까?","concept":"f(x)>0 또는 f(x)<0의 해는 그래프 y=f(x)가 x축 위·아래에 놓이는 x의 범위다. 인수분해나 근을 구하고, 구간별 부호를 확인한다. 연립이차부등식은 각 해집합의 교집합을 찾는다.","example":"x²−5x+6≤0은 (x−2)(x−3)≤0이다. 위로 열린 포물선은 두 근 사이에서 0 이하이므로 2≤x≤3이다.","practice":"x²−1>0과 x<3을 동시에 만족하는 범위를 구하세요.","answer":"첫 부등식은 x<−1 또는 x>1입니다. x<3과 교집합을 취하면 x<−1 또는 1<x<3입니다.","prompt":"x²−5x+6≤0의 해는?","options":["2≤x≤3","x≤2 또는 x≥3","2<x<3"],"correct":0,"feedback":"두 근 사이에서 위로 열린 포물선은 x축 아래 또는 위가 아니라 0 이하입니다.","wrong":"근 2와 3을 수직선에 놓고 구간별 부호를 확인하세요.","hints":["식을 (x−2)(x−3)으로 인수분해합니다.","근 사이에서 x=2.5를 대입해 부호를 확인합니다."],"check":"근 포함 여부와 연립 부등식 해집합의 교집합을 검산한다."},
    {"code":"10공수1-03-01","title":"합의 법칙과 곱의 법칙","lead":"서로 겹치지 않는 선택지 중 하나를 고르거나, 두 단계를 차례로 선택할 때 경우의 수는 어떻게 셀까?","concept":"서로 겹치지 않는 선택 방법 중 하나를 고르면 합의 법칙으로 경우의 수를 더한다. 첫 단계와 다음 단계를 차례로 모두 선택하면 곱의 법칙으로 곱한다. 선택지가 겹치는지 먼저 확인한다.","example":"셔츠 3벌과 바지 2벌 중 하나씩 고르는 옷차림은 3×2=6가지다. 셔츠만 고르거나 바지만 고르는 선택은 서로 겹치지 않아 3+2=5가지다.","practice":"음료 4종 중 하나와 빵 3종 중 하나를 고르는 방법 수, 또는 음료나 빵 중 하나만 고르는 방법 수를 각각 구하세요.","answer":"함께 하나씩 고르면 4×3=12가지, 둘 중 하나만 고르면 4+3=7가지입니다.","prompt":"셔츠 3벌과 바지 2벌을 하나씩 고르는 경우의 수는?","options":["6","5","9"],"correct":0,"feedback":"서로 다른 두 단계를 모두 거치므로 곱의 법칙을 씁니다.","wrong":"셔츠 선택마다 바지 선택이 몇 가지씩 가능한지 세세요.","hints":["셔츠를 하나 고른 뒤 바지를 하나 고릅니다.","각 셔츠에 바지 두 선택지가 있으므로 3×2입니다."],"check":"더하기와 곱하기 중 선택 구조에 맞는 법칙을 골랐는지 설명한다."},
    {"code":"10공수1-03-02","title":"순열의 수","lead":"5명 중 회장과 부회장을 한 명씩 뽑으면 왜 순서를 고려해야 할까?","concept":"서로 다른 n개에서 r개를 순서를 고려해 뽑는 순열의 수는 nPr=n!/(n−r)!이다. 각 자리에 가능한 선택 수를 차례대로 곱해도 같은 결과를 얻는다.","example":"5명 중 회장·부회장을 정하는 순서는 5×4=20가지다. 같은 두 사람이라도 맡은 직책이 바뀌면 다른 경우다.","practice":"서로 다른 6권 중 3권을 골라 책장에 한 줄로 놓는 방법 수를 구하세요.","answer":"순서가 중요하므로 6P3=6×5×4=120가지입니다.","prompt":"5명 중 회장과 부회장을 정하는 순열 수는?","options":["20","10","25"],"correct":0,"feedback":"회장을 정한 뒤 남은 4명 중 부회장을 정해 5×4입니다.","wrong":"첫 자리와 둘째 자리의 선택 수가 각각 몇 개인지 세세요.","hints":["회장은 5명 중 한 명입니다.","부회장은 회장을 제외한 4명 중 한 명입니다."],"check":"순서가 바뀌면 다른 경우인지 확인하고 nPr 공식과 곱셈 결과를 비교한다."},
    {"code":"10공수1-03-03","title":"조합의 수","lead":"5명 중 발표 대표 2명을 뽑을 때 순서가 달라도 같은 팀일까?","concept":"서로 다른 n개에서 r개를 순서를 고려하지 않고 뽑는 조합의 수는 nCr=n!/(r!(n−r)!)이다. 순열처럼 뽑은 뒤 r!번 중복 센 것을 나눈다.","example":"5명 중 2명을 고르는 조합 수는 5C2=5·4/(2·1)=10이다. A와 B를 뽑는 것은 B와 A를 뽑는 것과 같은 팀이다.","practice":"8명 중 3명을 순서 없이 뽑는 방법 수를 구하세요.","answer":"8C3=8·7·6/(3·2·1)=56가지입니다.","prompt":"5명 중 발표 대표 2명을 순서 없이 뽑는 방법 수는?","options":["10","20","25"],"correct":0,"feedback":"5P2를 두 사람의 순서 2!로 나누면 20/2=10입니다.","wrong":"두 사람의 순서가 바뀐 경우를 같은 팀으로 묶어 나눕니다.","hints":["5P2=5·4를 먼저 셉니다.","두 사람의 배열 2!번을 한 조합으로 나눕니다."],"check":"조합에서 순서를 구별하지 않는 이유와 중복 제거 r!을 확인한다."},
    {"code":"10공수1-04-01","title":"행렬로 실생활 자료 표현","lead":"두 매장의 상품별 판매량을 행렬에 담으면 특정 행·열의 값은 무엇을 뜻할까?","concept":"행렬은 수나 기호를 행과 열로 배열한 것이다. 행·열의 순서와 각 위치의 의미를 먼저 정하면 표 형태의 실생활 자료를 행렬로 나타낼 수 있다. 같은 크기의 행렬이라도 행·열의 의미가 다르면 자료 해석이 달라진다.","example":"행은 매장 A,B, 열은 연필, 공책이라고 정한다. 판매량 행렬 [[12,8],[9,10]]에서 둘째 행 첫째 열의 9는 매장 B의 연필 판매량이다.","practice":"행은 월(1월,2월), 열은 상품(X,Y)인 행렬 [[4,7],[6,5]]에서 2월 상품 Y의 값을 해석하세요.","answer":"2월 Y 상품 판매량은 5입니다.","prompt":"행이 매장 A,B, 열이 연필·공책일 때 [[12,8],[9,10]]의 둘째 행 첫째 열은?","options":["매장 B의 연필 9개","매장 A의 공책 8개","매장 B의 공책 10개"],"correct":0,"feedback":"둘째 행은 매장 B, 첫째 열은 연필입니다.","wrong":"먼저 행과 열의 약속을 확인한 뒤 위치를 읽으세요.","hints":["행 번호 2는 매장 B입니다.","열 번호 1은 연필입니다."],"check":"행·열 순서를 기록하고 행렬의 각 값을 상황에 맞게 해석한다."},
]


def quiz(spec: dict[str, object], aid: str) -> dict[str, object]:
    return {"type":"activity","activity":{"id":aid,"kind":"quiz","prompt":spec["prompt"],"options":spec["options"],"correct_index":spec["correct"],"correct_feedback":spec["feedback"],"incorrect_feedback":spec["wrong"],"hints":spec["hints"]}}


def main() -> None:
    official={row["code"]:row["criterion"] for row in json.loads(STANDARDS.read_text(encoding="utf-8"))["standards"]}
    codes=[str(spec["code"]) for spec in SPECS]
    expected_codes={"10공수1-01-01","10공수1-01-02","10공수1-01-03","10공수1-02-01","10공수1-02-02","10공수1-02-03","10공수1-02-04","10공수1-02-05","10공수1-02-06","10공수1-02-09","10공수1-02-10","10공수1-02-11","10공수1-03-01","10공수1-03-02","10공수1-03-03","10공수1-04-01"}
    if len(codes)!=16 or len(set(codes))!=16 or any(code not in official for code in codes):
        raise RuntimeError("Expected 16 distinct official 2022 Common Math 1 standards")
    if set(codes)!=expected_codes:
        raise RuntimeError("Batch2 code list no longer matches the 16 missing-code ledger entries")
    if set(codes)&{"10공수1-02-07","10공수1-02-08","10공수1-04-02"}:
        raise RuntimeError("Batch2 overlaps Batch1 standards")
    chapters=[]
    for spec in SPECS:
        code=str(spec["code"]); slug=code.replace("10공수1-","cm1-").replace("-","")
        pages=[
            {"id":slug+"-open","template":"opening","title":"상황과 질문","blocks":[{"type":"lead","title":"가상 예시","text":spec["lead"]},{"type":"thinking","title":"먼저 생각하기","text":"문제의 조건과 필요한 수학적 관계를 표시하고 풀이 방법을 예상합니다."}]},
            {"id":slug+"-concept","template":"concept","title":"정의와 성질","blocks":[{"type":"definition","title":"핵심 개념","text":spec["concept"]},{"type":"formula","title":"연결한 공식 기준","text":code},{"type":"misconception","title":"조건 점검","text":"정리의 가정, 부호, 정의역 또는 순서의 구별을 확인합니다."}]},
            {"id":slug+"-example","template":"example","title":"예제와 풀이","blocks":[{"type":"question","title":"예제","text":spec["lead"]},{"type":"solutionStep","title":"풀이","text":spec["example"]},{"type":"verification","title":"검산","text":spec["check"]}]},
            {"id":slug+"-practice","template":"practice","title":"연습과 설명","blocks":[{"type":"question","title":"연습","text":spec["practice"]},{"type":"hint","title":"힌트","text":spec["hints"][0]},{"type":"solutionStep","title":"해설","text":spec["answer"]},{"type":"answer","title":"정답","text":spec["answer"]},quiz(spec,slug+"-quiz")]},
            {"id":slug+"-summary","template":"summary","title":"핵심 정리","blocks":[{"type":"summary","title":"기억할 점","text":spec["title"]},{"type":"checklist","title":"스스로 확인","text":"공식의 조건과 계산 근거를 설명하고 결과를 검산할 수 있나요?"}]},
        ]
        chapters.append({"title":spec["title"],"intro":[f"2022 교육과정 공식 기준 {code}에 연결한 신규 후보입니다.","수치와 상황은 직접 만든 가상 예시입니다."],"pages":pages})
    book={"schema_version":2,"title":"공통수학1 · 2022 개정 미연결 기준 보완 16모듈 후보","subtitle":"다항식·방정식·부등식·경우의 수·행렬","category":"concept_textbook_prototype","curriculum_version":"2022","tags":["공통수학1","2022 개정","추가 원고 후보","가상 예시","학기 배정 미확정",*codes],"standard_codes":codes,"chapters":chapters}
    ids=[p["id"] for c in chapters for p in c["pages"]]
    if len(ids)!=80 or len(set(ids))!=80: raise RuntimeError("Expected 80 unique pages")
    assert (2+1+3)==6 and (1+2+3)==6
    assert 1**3-2*1-1== -2 and (1**3-2*1+1)==0
    assert (1-2)*(1-3)==2 and (1-2)+(1-3)==-3
    assert (1+2j)*(3-1j)==5+5j and ((1+1j)/(1-1j))==1j
    assert (-2)**2-4*1*5==-16 and 4**2-4*2*2==0
    assert 2+3==5 and 2*3==6
    assert (1-1)*(1-3)==0
    assert 1**2-2*1+1==0
    assert 5*(10-5)==25 and 4*(8-4)==16
    assert 1**2-4*1+3==0 and 3**2-4*3+3==0
    assert (2*2-3)==1 and (-1)<=-1 and 4<=4
    assert (2**2-5*2+6)==0 and (3**2-5*3+6)==0
    assert 3*2==6 and 3+2==5
    assert 5*4==20 and math.factorial(6)//math.factorial(3)==120
    assert math.comb(5,2)==10 and math.comb(8,3)==56
    assert [[12,8],[9,10]][1][0]==9
    OUT.write_text(json.dumps(book,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    PACKAGE.mkdir(parents=True,exist_ok=True)
    manifest_path=PACKAGE/"REVIEW_MANIFEST.json"
    try: old=json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError,json.JSONDecodeError): old={}
    digest=canonical_file_sha256(OUT); same=old.get("bookdata_sha256")==digest
    manifest={"bookdata_file":OUT.name,"bookdata_sha256":digest,"candidate_code_references":codes,"candidate_code_reference_type":"official_2022_hwp_criterion_table","module_count":16,"page_count":80,"native_activity_count":16,"native_activity_kinds":["quiz"],"example_data_status":"synthetic_original_examples; no commercial text, problem, illustration, or dataset copied","curriculum_review_status":"official_codes_verified; semester_and_full_scope_pending","math_review_status":"pending_full_teacher_review","math_arithmetic_check_status":"pass_for_listed_examples_only","teacher_review_status":"pending","rights_status":"newly_authored; publication_rights_decision_pending","source_interaction_status":"native_quiz_activity_candidate; no source HTML parity claimed","integration_status":"candidate_for_unit_grouping; not_merged_into_master_book","publication_eligibility":"not_eligible","runtime_import_status":old.get("runtime_import_status","pending_current_hash_validation") if same else "pending_current_hash_validation","runtime_validator_head":old.get("runtime_validator_head") if same else None}
    manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    (PACKAGE/"README.md").write_text(f"# {book['title']}\n\n공식 기준 코드 16개에 연결한 16모듈·80쪽 V2 후보입니다. 예제와 수치는 직접 작성했습니다. 네 단원 코드를 포함하며 자동 통합 초안에서 단원별로 묶입니다. 교사·수학 검토, 과목 전체 범위 대조, 학기 배정과 권리 결정 전에는 출판 적격이 아닙니다.\n\nBookData: [`{OUT.name}`](../{OUT.name})\n",encoding="utf-8")
    print(f"Built 16 Common Math 1 modules, 80 pages, 16 quizzes: {OUT}")


if __name__=="__main__": main()
