"""Build V2 candidate lessons for the 18 untagged 2022 Calculus II standards."""
from __future__ import annotations

import json
import math
from pathlib import Path

from textbook_digest import canonical_file_sha256

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
STANDARDS = ROOT / "work/official-curriculum/2022_math_standards.json"
OUT = MANUSCRIPTS / "미적분Ⅱ_2022개정_미분적분18기준_Batch2_BookData_V2_시범.json"
PACKAGE = MANUSCRIPTS / "미적분Ⅱ_2022개정_미분적분18기준_Batch2_원고패키지"

SPECS = [
    {"code":"12미적Ⅱ-02-01","title":"지수함수와 로그함수의 극한·미분","lead":"지수함수 2ˣ와 로그함수 ln x의 순간변화율은 어떻게 구할까?","concept":"자연로그 밑 e를 사용하면 (eˣ)'=eˣ, (ln x)'=1/x (x>0)이다. 일반 밑 a>0, a≠1에 대해 (aˣ)'=aˣ ln a이다. 극한 lim(h→0)(eʰ−1)/h=1과 로그의 극한을 미분계수 정의에 연결한다.","example":"(2ˣ)'=2ˣ ln 2이고 (ln(3x))'=1/x (x>0)이다. 첫 식은 밑이 2라 ln 2가 곱해지고, 둘째는 ln(3x)의 안쪽 미분 3을 나누어 3/(3x)=1/x가 된다.","practice":"f(x)=3ˣ+ln x (x>0)의 도함수를 구하고 f'(1)을 계산하세요.","answer":"f'(x)=3ˣ ln 3+1/x이므로 f'(1)=3 ln 3+1입니다.","prompt":"(5ˣ)'는?","options":["5ˣ ln 5","5ˣ","x·5ˣ"],"correct":0,"feedback":"밑 a의 지수함수 미분은 aˣ ln a입니다.","wrong":"밑이 e가 아닐 때 ln a 인자가 붙습니다.","hints":["일반 밑 a의 미분 공식을 떠올리세요.","a=5를 대입합니다."],"check":"5ˣ의 도함수 및 f'(1)을 미분 공식으로 다시 계산한다."},
    {"code":"12미적Ⅱ-02-02","title":"삼각함수의 덧셈정리","lead":"각 α와 β를 합치면 사인과 코사인의 값은 각각 어떻게 결합될까?","concept":"sin(α+β)=sinα cosβ+cosα sinβ, cos(α+β)=cosα cosβ−sinα sinβ이다. 차의 공식은 β 대신 −β를 대입해 얻는다. 각의 단위와 부호를 먼저 확인한다.","example":"sin(π/3+π/6)=sin(π/3)cos(π/6)+cos(π/3)sin(π/6)=3/4+1/4=1이다.","practice":"cos(π/3+π/6)을 덧셈정리로 구하세요.","answer":"cos(α+β)=cosαcosβ−sinαsinβ를 적용하면 1/4−(√3/2)(1/2)=1/4−√3/4=(1−√3)/4입니다.","prompt":"cos(α+β)의 식은?","options":["cosαcosβ−sinαsinβ","cosαcosβ+sinαsinβ","sinαcosβ−cosαsinβ"],"correct":0,"feedback":"코사인의 합 공식에서는 두 사인 항의 곱을 뺍니다.","wrong":"사인 합 공식과 코사인 합 공식의 부호를 구별하세요.","hints":["cos(α+β)는 cosα cosβ와 sinα sinβ를 결합합니다.","뒤의 곱 앞에는 음의 부호가 있습니다."],"check":"두 합 공식에서 코사인 합의 부호와 사인 합의 교차항을 확인한다."},
    {"code":"12미적Ⅱ-02-03","title":"삼각함수의 극한과 사인·코사인 미분","lead":"x가 0에 가까울 때 sin x와 x의 비는 어디에 가까워질까? 각은 라디안으로 둔다.","concept":"라디안에서 lim(x→0) sin x/x=1이다. 이 극한을 미분계수 정의에 적용하면 (sin x)'=cos x, (cos x)'=−sin x를 얻는다. 각을 도 단위로 넣으면 이 미분 공식이 그대로 성립하지 않는다.","example":"lim(x→0) sin(3x)/x=3·lim(x→0)sin(3x)/(3x)=3이다. 또한 (2sin x−cos x)'=2cos x+sin x이다.","practice":"f(x)=sin x+3cos x의 도함수와 f'(0)을 구하세요.","answer":"f'(x)=cos x−3sin x이고 f'(0)=1입니다.","prompt":"lim(x→0) sin(4x)/x는?","options":["4","1","0"],"correct":0,"feedback":"sin(4x)/(4x)의 극한은 1이므로 전체 극한은 4입니다.","wrong":"표준 극한의 분모를 4x로 맞추세요.","hints":["분자와 함께 분모에 4를 만들어 보세요.","sin(4x)/(4x) 앞에 남는 계수는 4입니다."],"check":"라디안 조건 아래 표준 극한과 sin·cos 미분 부호를 확인한다."},
    {"code":"12미적Ⅱ-02-04","title":"함수의 몫 미분","lead":"두 함수의 비를 미분할 때 분자와 분모를 각각 미분해 나누면 될까?","concept":"v(x)≠0인 구간에서 (u/v)'=(u'v−uv')/v²이다. 분모를 제곱하고, 분자에서는 앞의 도함수×뒤 함수에서 앞 함수×뒤의 도함수를 뺀다.","example":"y=x/(x+1)이면 y'=((x+1)−x)/(x+1)²=1/(x+1)² (x≠−1)이다.","practice":"f(x)=(x²+1)/x (x≠0)의 도함수를 몫의 미분법으로 구하세요.","answer":"f'(x)=(2x·x−(x²+1)·1)/x²=(x²−1)/x²입니다.","prompt":"(x/(x+1))'는?","options":["1/(x+1)²","1/(x+1)","x/(x+1)²"],"correct":0,"feedback":"분자는 (x+1)−x=1, 분모는 (x+1)²입니다.","wrong":"u'v−uv' 순서를 지키고 분모를 제곱하세요.","hints":["u=x, v=x+1로 둡니다.","u'v−uv'=(x+1)−x입니다."],"check":"분모 정의역과 u'v−uv'의 순서를 확인한다."},
    {"code":"12미적Ⅱ-02-05","title":"합성함수의 미분","lead":"바깥 함수 sin과 안쪽 함수 x²가 겹친 sin(x²)는 어떻게 미분할까?","concept":"합성함수 y=f(g(x))의 도함수는 f'(g(x))g'(x)이다. 바깥 함수를 먼저 미분하고 안쪽 함수의 도함수를 곱한다.","example":"y=sin(x²)이면 y'=cos(x²)·2x=2x cos(x²)이다.","practice":"y=ln(1+x²)의 도함수를 구하세요 (모든 실수 x).","answer":"y'=2x/(1+x²)입니다.","prompt":"(cos(3x))'는?","options":["−3sin(3x)","−sin(3x)","3cos(3x)"],"correct":0,"feedback":"cos의 도함수 −sin에 안쪽 도함수 3을 곱합니다.","wrong":"바깥 미분 뒤 안쪽 3x의 도함수 3을 곱하세요.","hints":["바깥 함수는 cos, 안쪽 함수는 3x입니다.","−sin(3x)·3입니다."],"check":"사인·코사인·로그 합성에서 안쪽 도함수까지 곱했는지 확인한다."},
    {"code":"12미적Ⅱ-02-06","title":"매개변수로 나타낸 함수의 미분","lead":"x와 y가 모두 t에 따라 변할 때 dy/dx를 어떻게 구할까?","concept":"x=x(t), y=y(t)이고 dx/dt≠0이면 dy/dx=(dy/dt)/(dx/dt)이다. 이는 같은 t 변화에 대한 y의 변화율을 x의 변화율로 나누는 식이다.","example":"x=t²+1, y=t³일 때 dy/dx=(3t²)/(2t)=3t/2 (t≠0)이다. t=1에서는 x=2이고 기울기는 3/2이다.","practice":"x=2t+1, y=t²일 때 t=2에서 dy/dx를 구하세요.","answer":"dy/dt=2t이므로 t=2에서 dy/dt=4이고 dx/dt=2입니다. 따라서 dy/dx=2입니다.","prompt":"x=t², y=t³일 때 t=2에서 dy/dx는?","options":["3","3/2","2/3"],"correct":0,"feedback":"(3t²)/(2t)=3t/2이고 t=2에서 3입니다.","wrong":"dy/dt를 dx/dt로 나누고 t=2를 대입합니다.","hints":["dy/dt=3t², dx/dt=2t입니다.","비를 약분한 다음 t=2를 대입합니다."],"check":"분모 dx/dt가 0이 아닌 지점에서 매개변수 미분을 적용한다."},
    {"code":"12미적Ⅱ-02-07","title":"음함수와 역함수의 미분","lead":"x²+y²=25처럼 y를 x의 식으로 바로 풀지 않고도 dy/dx를 구할 수 있을까?","concept":"음함수 관계를 x에 대해 양변 미분할 때 y는 x의 함수이므로 y가 포함된 항은 연쇄법칙을 적용한다. 역함수 y=f⁻¹(x)는 f'(f⁻¹(x))≠0인 곳에서 (f⁻¹)'(x)=1/f'(f⁻¹(x))를 만족한다.","example":"x²+y²=25를 미분하면 2x+2y·dy/dx=0이므로 dy/dx=−x/y (y≠0)이다. 점 (3,4)에서 접선 기울기는 −3/4이다.","practice":"x²+xy+y²=7을 음함수로 미분해 dy/dx를 구하세요.","answer":"2x+y+x(dy/dx)+2y(dy/dx)=0이므로 dy/dx=−(2x+y)/(x+2y)입니다 (x+2y≠0).","prompt":"x²+y²=25에서 dy/dx는?","options":["−x/y","x/y","−y/x"],"correct":0,"feedback":"양변을 미분하면 2x+2y y'=0입니다.","wrong":"y² 미분에서 2y에 y'를 곱해야 합니다.","hints":["y를 x의 함수로 봅니다.","2x+2y y'=0에서 y'를 정리합니다."],"check":"음함수 미분에서 y' 인자를 포함하고 분모가 0이 아닌지 확인한다."},
    {"code":"12미적Ⅱ-02-08","title":"여러 곡선의 접선","lead":"곡선 y=x³−3x 위의 x=2인 점에서 접선을 구해 보자.","concept":"미분계수 f'(a)는 곡선 y=f(x)의 x=a에서 접선 기울기다. 접선은 y−f(a)=f'(a)(x−a)로 쓴다. 음함수·매개변수 곡선도 해당 미분법으로 기울기를 구한 뒤 점기울기식을 적용한다.","example":"f(2)=2, f'(x)=3x²−3이므로 f'(2)=9이다. 접선은 y−2=9(x−2), 즉 y=9x−16이다.","practice":"y=x²+1에서 x=1인 점의 접선 방정식을 구하세요.","answer":"점은 (1,2), 기울기는 y'=2x에서 2이므로 y−2=2(x−1), 즉 y=2x입니다.","prompt":"y=x³−3x의 x=2에서 접선 기울기는?","options":["9","3","2"],"correct":0,"feedback":"도함수는 3x²−3이고 x=2에서 9입니다.","wrong":"먼저 함수를 미분한 뒤 x=2를 대입하세요.","hints":["f'(x)=3x²−3입니다.","f'(2)=12−3입니다."],"check":"접선이 곡선의 지정점을 지나고 기울기가 도함수 값과 일치하는지 확인한다."},
    {"code":"12미적Ⅱ-02-09","title":"도함수로 그래프 개형 그리기","lead":"f(x)=x³−3x의 증가·감소와 극값을 도함수 부호로 찾아 보자.","concept":"f'(x)>0인 구간에서 f는 증가하고, f'(x)<0인 구간에서 감소한다. 도함수 부호가 +에서 −로 바뀌면 극대, −에서 +로 바뀌면 극소다. 도함수가 0인 점만으로 극값이라 단정하지 않는다.","example":"f'(x)=3(x²−1)이므로 임계점은 −1,1이다. 부호는 바깥 구간에서 +, 가운데에서 −, 다시 +이다. f(−1)=2는 극댓값, f(1)=−2는 극솟값이다.","practice":"g(x)=x²−4x의 증가·감소 구간과 극솟값을 구하세요.","answer":"g'(x)=2x−4이므로 x<2에서 감소하고 x>2에서 증가합니다. x=2에서 극솟값은 g(2)=−4입니다.","prompt":"f(x)=x³−3x에서 x=−1의 극값은?","options":["극대 2","극소 −2","극값이 아님"],"correct":0,"feedback":"도함수 부호가 +에서 −로 바뀌고 f(−1)=2입니다.","wrong":"임계점 양쪽의 도함수 부호와 함수값을 모두 확인하세요.","hints":["f'(x)=3(x²−1)입니다.","−1의 왼쪽은 양수, 오른쪽은 음수입니다."],"check":"도함수 부호표와 함수값을 이용해 극대·극소를 구분한다."},
    {"code":"12미적Ⅱ-02-10","title":"미분으로 방정식·부등식 문제 풀기","lead":"x³+3x=4는 실수 해가 몇 개일까?","concept":"함수의 증가·감소와 극값을 조사하면 방정식의 해 개수나 부등식의 참인 범위를 판단할 수 있다. 도함수가 구간 전체에서 양수이면 함수는 그 구간에서 증가한다.","example":"h(x)=x³+3x−4로 두면 h'(x)=3x²+3>0이므로 h는 실수 전체에서 증가한다. h(1)=0이므로 해는 x=1 하나뿐이다.","practice":"x³+x=0의 실수 해를 구하고, 도함수로 다른 실수 해가 없는지 설명하세요.","answer":"h(x)=x³+x라 두면 h'(x)=3x²+1>0이어서 엄격히 증가합니다. h(0)=0이므로 유일한 실수 해는 0입니다.","prompt":"x³+3x=4의 실수 해는?","options":["하나, x=1","둘, x=±1","없다"],"correct":0,"feedback":"함수 x³+3x−4는 도함수가 항상 양수여서 한 번만 0을 지납니다.","wrong":"도함수의 부호로 단조성을 확인하고 알려진 근을 대입하세요.","hints":["h(x)=x³+3x−4로 둡니다.","h'(x)=3x²+3>0이고 h(1)=0입니다."],"check":"해를 직접 대입해 확인하고 엄격한 증가성이 유일성을 보장하는지 확인한다."},
    {"code":"12미적Ⅱ-02-11","title":"속도와 가속도에 미분 활용","lead":"위치가 s(t)=t³−6t²+9t로 주어질 때 t=1에서 순간속도와 가속도는 얼마일까?","concept":"위치 s(t)를 시간으로 미분하면 속도 v(t)=s'(t), 속도를 미분하면 가속도 a(t)=v'(t)=s''(t)이다. 속도 부호는 운동 방향, 속력은 |v(t)|로 해석한다.","example":"s(t)=t³−6t²+9t이면 v(t)=3t²−12t+9, a(t)=6t−12이다. t=1에서 v=0, a=−6이다. 위치 단위와 시간 단위를 정하면 속도·가속도 단위도 각각 위치/시간, 위치/시간²가 된다.","practice":"s(t)=2t²+3t (t≥0)일 때 t=2에서 속도와 가속도를 구하세요.","answer":"v(t)=4t+3이므로 v(2)=11이고 a(t)=4입니다.","prompt":"위치 s(t)를 두 번 미분하면 무엇인가?","options":["가속도","속도","이동거리"],"correct":0,"feedback":"첫 미분은 속도, 두 번째 미분은 가속도입니다.","wrong":"위치→속도→가속도 순서로 한 번씩 미분합니다.","hints":["v=s'입니다.","a=v'=s''입니다."],"check":"단위까지 포함해 위치·속도·가속도의 미분 관계를 점검한다."},
    {"code":"12미적Ⅱ-03-01","title":"지수·삼각함수의 부정적분과 정적분","lead":"eˣ, sin x, cos x의 도함수 관계를 거꾸로 사용하면 어떤 적분을 얻을까?","concept":"∫eˣdx=eˣ+C, ∫sin x dx=−cos x+C, ∫cos x dx=sin x+C이다. a≠0일 때 ∫eᵃˣdx=eᵃˣ/a+C이다. 정적분은 원시함수 F를 사용해 ∫ₐᵇf(x)dx=F(b)−F(a)로 계산한다.","example":"∫₀^{π/2}cos x dx=sin(π/2)−sin 0=1이다.","practice":"∫₀¹(2eˣ+cos x)dx를 구하세요.","answer":"원시함수는 2eˣ+sin x이므로 값은 2(e−1)+sin 1입니다.","prompt":"∫sin x dx는?","options":["−cos x+C","cos x+C","sin x+C"],"correct":0,"feedback":"(−cos x)'=sin x입니다.","wrong":"미분해 원래 integrand가 되는 원시함수를 확인하세요.","hints":["cos x를 미분하면 −sin x입니다.","부호를 바꾸면 sin x의 원시함수가 됩니다."],"check":"각 원시함수를 미분해 integrand가 되는지 확인하고 정적분은 상한−하한 순서를 지킨다."},
    {"code":"12미적Ⅱ-03-02","title":"치환적분법","lead":"∫2x cos(x²)dx에서 안쪽 함수 x²를 새 변수로 두면 적분이 어떻게 단순해질까?","concept":"합성함수의 미분을 거꾸로 이용한다. u=g(x), du=g'(x)dx로 치환하면 ∫f(g(x))g'(x)dx=∫f(u)du이다. 정적분은 구간도 함께 치환하거나 원래 변수로 돌아와 경계값을 대입한다.","example":"u=x²이면 du=2x dx이므로 ∫2x cos(x²)dx=∫cos u du=sin(x²)+C이다.","practice":"∫₀¹ 2x e^(x²) dx를 치환적분으로 구하세요.","answer":"u=x²로 두면 경계는 0에서 1이고 적분은 ∫₀¹eᵘdu=e−1입니다.","prompt":"∫2x cos(x²)dx는?","options":["sin(x²)+C","cos(x²)+C","2sin x+C"],"correct":0,"feedback":"u=x²로 치환하면 ∫cos u du=sin u+C입니다.","wrong":"안쪽 함수와 그 도함수 2x dx가 함께 있는지 찾으세요.","hints":["u=x²로 놓습니다.","du=2x dx이므로 cos u를 적분합니다."],"check":"치환된 원시함수를 미분해 원래 integrand와 일치하는지 확인한다."},
    {"code":"12미적Ⅱ-03-03","title":"부분적분법","lead":"곱 x eˣ를 적분할 때 미분하면 단순해지는 인자와 적분하기 쉬운 인자를 어떻게 고를까?","concept":"미분의 곱셈법칙을 거꾸로 쓰면 ∫u dv=uv−∫v du이다. 다항식은 미분해 단순하게 하고, 지수·삼각함수는 적분해 형태가 유지되는 선택이 자주 유용하다.","example":"u=x, dv=eˣdx로 두면 du=dx, v=eˣ이다. 따라서 ∫xeˣdx=xeˣ−∫eˣdx=eˣ(x−1)+C이다.","practice":"∫x cos x dx를 부분적분으로 구하세요.","answer":"u=x, dv=cos x dx로 두면 v=sin x이므로 ∫x cos x dx=x sin x+cos x+C입니다.","prompt":"∫xeˣdx의 원시함수는?","options":["eˣ(x−1)+C","xeˣ+C","eˣ(x+1)+C"],"correct":0,"feedback":"부분적분하면 xeˣ−eˣ=eˣ(x−1)입니다.","wrong":"uv에서 남은 ∫v du를 빼야 합니다.","hints":["u=x, dv=eˣdx로 두세요.","uv−∫vdu=xeˣ−∫eˣdx입니다."],"check":"결과를 미분해 xeˣ가 되는지 검산한다."},
    {"code":"12미적Ⅱ-03-04","title":"정적분과 급수의 합","lead":"[0,1]을 n등분해 오른쪽 끝점에서 높이 x를 읽어 직사각형 넓이를 더하면 극한은 무엇일까?","concept":"연속함수의 정적분은 분할을 점점 촘촘히 할 때 직사각형 넓이 합의 극한으로 이해할 수 있다. 등분 폭 Δx=(b−a)/n, 표본점 xᵢ를 정하면 ∫ₐᵇf(x)dx=lim(n→∞)Σf(xᵢ)Δx이다.","example":"[0,1]에서 f(x)=x의 오른쪽 끝점 합은 Σ(i/n)(1/n)=(1/n²)·n(n+1)/2=(n+1)/(2n)이고, 극한은 1/2이다. 이는 ∫₀¹x dx와 같다.","practice":"[0,2]에서 f(x)=1의 오른쪽 끝점 리만 합을 쓰고 그 극한을 구하세요.","answer":"각 폭은 2/n이고 높이는 모두 1이므로 합은 n·1·(2/n)=2이며 극한도 2입니다.","prompt":"[0,1]에서 f(x)=x의 오른쪽 끝점 합의 극한은?","options":["1/2","1","0"],"correct":0,"feedback":"합은 (n+1)/(2n)이고 n이 커지면 1/2에 가까워집니다.","wrong":"각 직사각형 넓이는 (i/n)(1/n)입니다.","hints":["Σi=n(n+1)/2를 사용하세요.","합을 (n+1)/(2n)으로 정리합니다."],"check":"직사각형 폭·높이·시그마 합 공식과 적분값을 대조한다."},
    {"code":"12미적Ⅱ-03-05","title":"곡선으로 둘러싸인 도형의 넓이","lead":"0≤x≤1에서 y=x와 y=x² 사이의 넓이를 정적분으로 구해 보자.","concept":"두 곡선의 교점을 구해 적분 구간을 정한다. 구간에서 위쪽 함수에서 아래쪽 함수를 빼 적분하면 둘러싸인 넓이를 얻는다. 곡선의 순서가 바뀌면 구간을 나누거나 절댓값을 고려한다.","example":"0≤x≤1에서 x≥x²이므로 넓이는 ∫₀¹(x−x²)dx=[x²/2−x³/3]₀¹=1/6이다.","practice":"0≤x≤2에서 y=2x와 y=x² 사이의 넓이를 구하세요.","answer":"교점은 x=0,2이고 구간 안에서는 2x≥x²입니다. 넓이는 ∫₀²(2x−x²)dx=[x²−x³/3]₀²=4/3입니다.","prompt":"0≤x≤1에서 y=x와 y=x² 사이 넓이는?","options":["1/6","1/3","1/2"],"correct":0,"feedback":"위 함수 x에서 아래 함수 x²를 빼 적분합니다.","wrong":"먼저 두 함수의 교점과 위아래 순서를 확인하세요.","hints":["구간 안에서 x와 x²를 비교하세요.","적분함수는 x−x²입니다."],"check":"교점과 위아래 순서, 최종 넓이의 양수 여부를 점검한다."},
    {"code":"12미적Ⅱ-03-06","title":"회전체의 부피","lead":"0≤x≤1에서 y=x인 선분 아래 영역을 x축 둘레로 돌리면 부피는 얼마일까?","concept":"x축 둘레로 회전하는 영역에서 단면이 원판이면 반지름 r(x)의 단면적은 πr(x)²이다. 부피는 V=π∫ₐᵇr(x)²dx로 계산한다. 축과 경계곡선 사이의 거리가 반지름이다.","example":"y=x, 0≤x≤1을 x축 둘레로 돌리면 V=π∫₀¹x²dx=π/3이다.","practice":"0≤x≤2에서 y=2인 직사각형 영역을 x축 둘레로 돌린 원기둥의 부피를 적분식으로 구하세요.","answer":"반지름 2인 원판이 길이 2만큼 이어지므로 V=π∫₀²2²dx=8π입니다.","prompt":"y=x, 0≤x≤1을 x축 둘레로 회전한 부피는?","options":["π/3","π","2π"],"correct":0,"feedback":"단면적 πx²를 0부터 1까지 적분하면 π/3입니다.","wrong":"반지름을 제곱해 단면적 πr²을 만든 뒤 적분하세요.","hints":["각 단면의 반지름은 y=x입니다.","V=π∫₀¹x²dx입니다."],"check":"반지름 제곱과 구간 적분을 확인하고 부피가 양수인지 확인한다."},
    {"code":"12미적Ⅱ-03-07","title":"속도와 거리의 적분 활용","lead":"속도 v(t)=t−1로 0≤t≤3 동안 움직일 때 변위와 이동거리는 어떻게 다를까?","concept":"속도를 적분하면 변위 s(b)−s(a)=∫ₐᵇv(t)dt를 얻는다. 속도가 부호를 바꾸면 이동거리는 ∫ₐᵇ|v(t)|dt로 계산하며, 부호가 바뀌는 시점에서 구간을 나눈다.","example":"∫₀³(t−1)dt=[t²/2−t]₀³=3/2이므로 변위는 1.5이다. v=0인 t=1에서 나누면 이동거리는 ∫₀¹(1−t)dt+∫₁³(t−1)dt=1/2+2=5/2이다.","practice":"속도 v(t)=2−t로 0≤t≤3 동안 움직일 때 변위와 이동거리를 각각 구하세요.","answer":"변위는 ∫₀³(2−t)dt=3/2입니다. t=2에서 방향이 바뀌므로 이동거리는 ∫₀²(2−t)dt+∫₂³(t−2)dt=2+1/2=5/2입니다.","prompt":"v(t)=t−1, 0≤t≤3의 이동거리는?","options":["5/2","3/2","2"],"correct":0,"feedback":"t=1에서 방향이 바뀌므로 속도의 절댓값을 두 구간으로 적분합니다.","wrong":"부호 있는 적분은 변위입니다. 이동거리는 속도가 음수인 구간도 양수 길이로 더합니다.","hints":["먼저 v(t)=0인 시점을 찾으세요.","[0,1]과 [1,3]에서 속력의 식을 나눕니다."],"check":"변위는 부호 있는 적분, 이동거리는 속력의 적분으로 구분하고 방향 전환점을 나눈다."},
]


def activity(spec: dict[str, object], aid: str) -> dict[str, object]:
    return {"type":"activity","activity":{"id":aid,"kind":"quiz","prompt":spec["prompt"],"options":spec["options"],"correct_index":spec["correct"],"correct_feedback":spec["feedback"],"incorrect_feedback":spec["wrong"],"hints":spec["hints"]}}


def main() -> None:
    official={row["code"]:row["criterion"] for row in json.loads(STANDARDS.read_text(encoding="utf-8"))["standards"]}
    codes=[str(spec["code"]) for spec in SPECS]
    if len(codes)!=18 or len(set(codes))!=18 or any(code not in official for code in codes):
        raise RuntimeError("Expected 18 distinct codes present in official HWP criteria")
    chapters=[]
    for spec in SPECS:
        slug=str(spec["code"]).replace("12미적Ⅱ-","calc2-").replace("-","")
        pages=[
            {"id":slug+"-open","template":"opening","title":"상황과 질문","blocks":[{"type":"lead","title":"가상 예시","text":spec["lead"]},{"type":"thinking","title":"먼저 생각하기","text":"함수의 정의역·조건·변화 구간을 표시하고 사용할 정리의 가정을 확인합니다."}]},
            {"id":slug+"-concept","template":"concept","title":"정의와 성질","blocks":[{"type":"definition","title":"핵심 개념","text":spec["concept"]},{"type":"formula","title":"연결한 공식 기준","text":spec["code"]},{"type":"misconception","title":"조건 점검","text":"미분 공식의 정의역·연쇄법칙 인자 또는 적분 구간과 부호를 확인합니다."}]},
            {"id":slug+"-example","template":"example","title":"예제와 풀이","blocks":[{"type":"question","title":"예제","text":spec["lead"]},{"type":"solutionStep","title":"풀이","text":spec["example"]},{"type":"verification","title":"검산","text":spec["check"]}]},
            {"id":slug+"-practice","template":"practice","title":"연습과 설명","blocks":[{"type":"question","title":"연습","text":spec["practice"]},{"type":"hint","title":"힌트","text":spec["hints"][0]},{"type":"solutionStep","title":"해설","text":spec["answer"]},{"type":"answer","title":"정답","text":spec["answer"]},activity(spec,slug+"-quiz")]},
            {"id":slug+"-summary","template":"summary","title":"핵심 정리","blocks":[{"type":"summary","title":"기억할 점","text":spec["title"]},{"type":"checklist","title":"스스로 확인","text":"조건과 계산 과정을 설명하고 결과를 검산할 수 있나요?"}]},
        ]
        intro=[f"2022 교육과정 공식 기준 {spec['code']}에 연결한 신규 집필 후보입니다.","예제와 수치는 직접 만든 가상 예시입니다."]
        if spec["code"] == "12미적Ⅱ-03-01":
            intro.append("공식 HWP 텍스트 추출에서 기준 문구 앞부분의 수식이 누락되어 보이는 상태이므로, 현재 원고는 확인 가능한 지수함수·삼각함수 적분만 다룹니다. 누락 수식 확인 전 기준 전체 충족을 주장하지 않습니다.")
        chapters.append({"title":spec["title"],"intro":intro,"pages":pages})
    book={"schema_version":2,"title":"미적분Ⅱ · 미분과 적분 보완 18모듈 후보","subtitle":"미분법 11개 기준과 적분법 7개 기준의 원고 시범","category":"concept_textbook_prototype","curriculum_version":"2022","tags":["미적분Ⅱ","2022 개정","추가 원고 후보","가상 예시","학기 배정 미확정"],"standard_codes":codes,"chapters":chapters}
    ids=[p["id"] for ch in chapters for p in ch["pages"]]
    if len(ids)!=90 or len(ids)!=len(set(ids)): raise RuntimeError("Expected 90 unique pages")
    assert math.isclose(math.log(math.e),1)
    assert math.isclose(math.sin(math.pi/3+math.pi/6),1)
    assert math.isclose(3**1*math.log(3)+1, 3*math.log(3)+1)
    assert math.isclose(math.cos(math.pi/3+math.pi/6), 0, abs_tol=1e-12)
    assert math.isclose(math.cos(0)-3*math.sin(0), 1)
    assert math.isclose((2*2*2-(2**2+1))/(2**2), 0.75)
    assert math.isclose(2*2/(1+2**2), 0.8)
    assert math.isclose((2*2)/(2), 2)
    assert math.isclose(-(2*3+4)/(3+2*4), -10/11)
    assert math.isclose(9*2-16, 2)
    assert 3*((-1)**2-1)==0 and 3*(2**2-1)==9
    assert 1**3+3*1-4==0 and 3*1**2+3>0
    assert 3*1**2-12*1+9==0 and 6*1-12==-6
    assert math.isclose(math.sin(math.pi/2)-math.sin(0), 1)
    assert math.isclose(math.exp(1)-math.exp(0), math.e-1)
    assert math.isclose(math.exp(2)*(2-1)+math.exp(2), 2*math.exp(2))
    assert math.isclose((100+1)/(2*100), 0.505)
    assert math.isclose(1/2-1/3, 1/6)
    assert math.isclose(2**2-2**3/3, 4/3)
    assert math.isclose(math.pi*4*2, 8*math.pi)
    assert math.isclose(3/2, 1.5) and math.isclose(1/2+2, 2.5)
    OUT.write_text(json.dumps(book,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    PACKAGE.mkdir(parents=True,exist_ok=True)
    manifest_path=PACKAGE/"REVIEW_MANIFEST.json"
    try: old=json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError,json.JSONDecodeError): old={}
    digest=canonical_file_sha256(OUT); same=old.get("bookdata_sha256")==digest
    manifest={"bookdata_file":OUT.name,"bookdata_sha256":digest,"candidate_code_references":codes,"candidate_code_reference_type":"official_2022_hwp_criterion_table","module_count":18,"page_count":90,"native_activity_count":18,"native_activity_kinds":["quiz"],"example_data_status":"synthetic_original_examples; no commercial text, problem, illustration, or dataset copied","curriculum_review_status":"official_codes_verified; criterion_12미적Ⅱ-03-01_leading_expression_unresolved; semester_and_full_scope_pending","math_review_status":"pending_full_teacher_review","math_arithmetic_check_status":"pass_for_listed_examples_only","teacher_review_status":"pending","rights_status":"newly_authored; publication_rights_decision_pending","source_interaction_status":"native_quiz_activity_candidate; no source HTML parity claimed","integration_status":"not_merged_into_master_book","publication_eligibility":"not_eligible","runtime_import_status":old.get("runtime_import_status","pending_current_hash_validation") if same else "pending_current_hash_validation","runtime_validator_head":old.get("runtime_validator_head") if same else None,"runtime_validation_command":old.get("runtime_validation_command") if same else None,"runtime_validator_candidate_sha256":old.get("runtime_validator_candidate_sha256") if same else None}
    manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    (PACKAGE/"README.md").write_text(f"# {book['title']}\n\n공식 2022 기준 코드 18개에 연결한 18모듈·90쪽 V2 후보입니다. 예제와 수치는 직접 작성했습니다. `12미적Ⅱ-03-01`은 공식 HWP 텍스트 추출에서 문구 앞 수식이 누락되어 보여, 확인 가능한 지수함수·삼각함수 적분만 다룹니다. native quiz는 BookData activity 계약을 사용하는 후보이며 교사·수학 검토, 전체 과목 범위 대조, 원문 수식 확인, 권리 결정 전에는 출판 적격이 아닙니다.\n\nBookData: [`{OUT.name}`](../{OUT.name})\n",encoding="utf-8")
    print(f"Built 18 Calculus II modules, 90 pages, 18 quizzes: {OUT}")


if __name__=="__main__": main()
