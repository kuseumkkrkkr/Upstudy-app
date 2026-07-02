import codecs

paragraphs = {
    '이차부등식의풀이': [
        '이차부등식은 $ax^2+bx+c>0$ 또는 $ax^2+bx+c<0$ 의 형태로 주어지며, 여기서 $a,b,c$ 는 실수이고 $a\\neq 0$ 이다.',
        '예제: $x=\\frac{1}{2}$ 입니다.',
    ],
}

out = r'C:\\Users\\82102\\Desktop\\s11\\lib\\models\\test_ps_py.dart'
with codecs.open(out, 'w', 'utf-8') as f:
    f.write("import 'textbook.dart';\n")
    f.write('final Map<String, BookData> x = {\n')
    for k, ps in paragraphs.items():
        f.write(f'  \"{k}\": BookData(\n')
        for p in ps:
            f.write(f'    \"{p}\",\n')
        f.write('  ),\n')
    f.write('};\n')
print('Done')
