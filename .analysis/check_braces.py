path = r"c:\Users\WALTON\Documents\hishab_pro_new\lib\main.dart"
with open(path, 'r', encoding='utf-8') as f:
    text = f.read()
for ch in ['{','}','(',')','[',']']:
    print(ch, text.count(ch))
# print last 50 lines for quick context
lines = text.splitlines()
print('\n---TAIL 60 LINES---')
for l in lines[-60:]:
    print(l)
