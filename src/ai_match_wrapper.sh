#!/usr/bin/env python3
"""
ai_match_wrapper.py — AppleScript调用入口

接收两个参数：resume_json_file 和 jd_text_file
输出 pipe 分隔的评分结果
"""
import sys, json

resume_file = sys.argv[1]
jd_file = sys.argv[2]

with open(resume_file) as f:
    resume = json.loads(f.read())

with open(jd_file) as f:
    jd_text = f.read()

# 构建输入
input_data = json.dumps({"resume": resume, "jd_text": jd_text})

# 调用 ai_match.py
import subprocess
result = subprocess.run(
    [sys.executable, "-c", """
import json, re, sys, math
from collections import Counter

def tokenize(text):
    words = re.findall(r'[a-zA-Z]+', text.lower())
    chinese_chars = re.findall(r'[\\u4e00-\\u9fff]+', text)
    for c in chinese_chars:
        words.extend([c[i:i+2] for i in range(len(c)-1)])
        words.extend(list(c))
    return words

def tfidf_similarity(t1, t2):
    w1, w2 = tokenize(t1), tokenize(t2)
    if not w1 or not w2: return 0.0
    tf1, tf2 = Counter(w1), Counter(w2)
    all_w = set(tf1.keys()) | set(tf2.keys())
    idf = {w: math.log(3/(1+((1 if w in tf1 else 0)+(1 if w in tf2 else 0)))+1)+1 for w in all_w}
    v1 = {w: tf1.get(w,0)*idf[w] for w in all_w}
    v2 = {w: tf2.get(w,0)*idf[w] for w in all_w}
    dot = sum(v1[w]*v2[w] for w in all_w)
    n1 = math.sqrt(sum(v*v for v in v1.values()))
    n2 = math.sqrt(sum(v*v for v in v2.values()))
    return dot/(n1*n2) if n1>0 and n2>0 else 0.0

data = json.loads('''" + input_data.replace("'", "\\'") + """')
r = data.get('resume',{})
j = data.get('jd_text','')
skills = r.get('skills',[])
exp = r.get('experience_years',10)
edu = r.get('education','本科')

skills_text = ' '.join(skills)
sim = tfidf_similarity(skills_text, j) if j and len(j.strip())>10 else 0
ss = min(50, round(sim*100))

em = re.search(r'(\\\\d+)\\\\s*\\\\u5e74', j)
re_exp = int(em.group(1)) if em else 0
es = 30 if abs(exp-re_exp)<=1 else (20 if abs(exp-re_exp)<=3 else (10 if abs(exp-re_exp)<=5 else 5)) if re_exp>0 else 20

edu_o = {'\\\\u535a\\\\u58eb':4,'\\\\u7855\\\\u58eb':3,'\\\\u672c\\\\u79d1':2,'\\\\u5927\\\\u4e13':1}
req_edu = ''
for e in ['\\\\u535a\\\\u58eb','\\\\u7855\\\\u58eb','\\\\u672c\\\\u79d1','\\\\u5927\\\\u4e13']:
    if e in j: req_edu = e; break
eus = 20 if edu_o.get(edu,0)>=edu_o.get(req_edu,0) else (10 if edu_o.get(edu,0)>=edu_o.get(req_edu,0)-1 else 5) if req_edu else 15

total = min(100, ss+es+eus)
print(f'{total}|{ss}|{es}|{eus}|{re_exp}|{req_edu or \"\\\\u4e0d\\\\u9650\"}|\"\u8bed\u4e49\u5339\u914d\"')
"""],
    input=input_data,
    capture_output=True,
    text=True,
    timeout=30
)

print(result.stdout.strip() or f"0|0|0|0|0|不限|AI失败")
