import codecs
f = codecs.open(r'C:\\Users\\82102\\Desktop\\s11\\lib\\models\\concept2_dart_test.dart', 'w', 'utf-8')
f.write("import 'textbook.dart';\n\n")
f.write('final Map<String, BookData> x = {\n')
f.write('  \"이차부등식의풀이\": BookData(\n')
f.write('    id: \"concept_이차부등식의풀이\",\n')
f.write("  ),\n};")
f.close()
