# -*- coding: utf-8 -*-
out = 'import \"textbook.dart\";\n\n'
out += 'const Map<String, BookData> _kPart5 = {\n'

entries = []

# 에스케이프 헬퍼

def e(s):
    return s.replace('\\', '\\\\\\\\')

# 인수분해를이용한극한
c = '인수분해를이용한극한'
entries.append(f'''  \"{e(c)}\": BookData(
    id: \"concept_{e(c)}\",
    title: \"{e(c)}\",
    subtitle: \"미적분I > 극한과연속 > 극한 > {e(c)}\",
    category: \"common\",
    tags: [\"미적분I\", \"극한과연속\", \"극한\", \"{e(c)}\"],
    chapters: [
      BookChapter(
        title: \"{e(c)}\",
        intro: [\"미적분I > 극한과연속 > 극한 > {e(c)} 개념 학습\"],
        sections: [
          BookSection(
            title: \"{e(c)}\",
            paragraphs: [
              \"분수함수의 극한을 계산할 때 분모와 분자가 동시에 0이 되면 분자를 인수분해하여 공통인수를 약분한 뒤 극한값을 구합니다.\",
              \"예를 들어 \\\\lim_{{x \\\\to 2}} \\\\frac{{x^2-4}}{{x-2}} 에서 x=2 를 대입하면 \\\\frac{{0}}{{0}} 의 부정형이 됩니다. 이때 분자를 인수분해하면 x^2-4=(x-2)(x+2) 입니다.\",
              \"공통인수 (x-2) 를 약분한 뒤 극한을 구하면 \\\\lim_{{x \\\\to 2}}(x+2)=4 이 됩니다. 따라서 이 극한의 값은 4입니다.\",
            ],
          ),
        ],
      ),
    ],
  ),''')

# 유리화를이용한극한
c = '유리화를이용한극한'
entries.append(f'''  \"{e(c)}\": BookData(
    id: \"concept_{e(c)}\",
    title: \"{e(c)}\",
    subtitle: \"미적분I > 극한과연속 > 극한 > {e(c)}\",
    category: \"common\",
    tags: [\"미적분I\", \"극한과연속\", \"극한\", \"{e(c)}\"],
    chapters: [
      BookChapter(
        title: \"{e(c)}\",
        intro: [\"미적분I > 극한과연속 > 극한 > {e(c)} 개념 학습\"],
        sections: [
          BookSection(
            title: \"{e(c)}\",
            paragraphs: [
              \"분자나 분모에 루트가 포함된 극한에서는 직접 대입하면 부정형이 될 수 있습니다. 이때 공액무리수를 이용하여 유리화하면 간단한 다항식으로 정리할 수 있습니다.\",
              \"예를 들어 \\\\lim_{{x \\\\to 3}} \\\\frac{{x-3}}{{\\\\sqrt{{x+1}}-2}} 에서 x=3 대입 시 \\\\frac{{0}}{{0}} 형이 됩니다. 분모의 공액무리수 \\\\sqrt{{x+1}}+2 를 분자와 분모에 곱합니다.\",
              \"유리화 후 분모는 (\\\\sqrt{{x+1}}-2)(\\\\sqrt{{x+1}}+2)=(x+1)-4=x-3 이 됩니다. 따라서 식은 \\\\sqrt{{x+1}}+2 로 간단해집니다.\",
              \"따라서 극한값은 \\\\lim_{{x \\\\to 3}}(\\\\sqrt{{x+1}}+2)=4 입니다.\",
            ],
          ),
        ],
      ),
    ],
  ),''')

# 무한대의극한
c = '무한대의극한'
entries.append(f'''  \"{e(c)}\": BookData(
    id: \"concept_{e(c)}\",
    title: \"{e(c)}\",
    subtitle: \"미적분I > 극한과연속 > 극한 > {e(c)}\",
    category: \"common\",
    tags: [\"미적분I\", \"극한과연속\", \"극한\", \"{e(c)}\"],
    chapters: [
      BookChapter(
        title: \"{e(c)}\",
        intro: [\"미적분I > 극한과연속 > 극한 > {e(c)} 개념 학습\"],
        sections: [
          BookSection(
            title: \"{e(c)}\",
            paragraphs: [
              \"x 이 무한대로 발산할 때 분수함수의 극한은 분자와 분모의 최고차항을 비교하여 구합니다. 최고차항의 차수와 계수에 따라 극한값이 달라집니다.\",
              \"분자와 분모의 차수가 같으면 최고차항 계수의 비가 극한값이 되고, 분자의 차수가 분모보다 낮으면 0, 높으면 +\\\\infty 또는 -\\\\infty 로 발산합니다.\",
              \"예를 들어 \\\\lim_{{x \\\\to \\\\infty}} \\\\frac{{2x^2+3x-1}}{{3x^2-5}} 의 경우, 분자와 분모의 최고차항은 각각 2x^2 과 3x^2 입니다.\",
              \"최고차항만 남기면 \\\\lim_{{x \\\\to \\\\infty}} \\\\frac{{2x^2}}{{3x^2}}=\\\\frac{{2}}{{3}} 입니다. 계산 결과 이 극한의 값은 \\\\frac{{2}}{{3}} 이 됩니다.\",
            ],
          ),
        ],
      ),
    ],
  ),''')

out += '\n'.join(entries)
out += '\n};\n'

with open('lib/models/concept_textbooks_part5.dart', 'w', encoding='utf-8') as f:
    f.write(out)
print('Written', len(entries), 'entries')
