#!/usr/bin/env python3
"""
ai_match_stdin.py — 从 stdin 读取 JSON，输出 pipe 分隔评分
用法: echo '{"resume":{...},"jd_text":"..."}' | python3 ai_match_stdin.py
"""
import sys, json, re, math
from collections import Counter

data = json.loads(sys.stdin.read())
resume = data.get('resume', {})
jd_text = data.get('jd_text', '')

skills = resume.get('skills', [])
exp_years = resume.get('experience_years', 10)
education = resume.get('education', '本科')

def tokenize(text):
    words = re.findall(r'[a-zA-Z]+', text.lower())
    for c in re.findall(r'[\u4e00-\u9fff]+', text):
        words.extend([c[i:i+2] for i in range(len(c)-1)])
        words.extend(list(c))
    return words

def tfidf_sim(t1, t2):
    w1, w2 = tokenize(t1), tokenize(t2)
    if not w1 or not w2: return 0.0
    tf1, tf2 = Counter(w1), Counter(w2)
    all_w = set(tf1.keys()) | set(tf2.keys())
    idf = {w: math.log(3/(1+((1 if w in tf1 else 0)+(1 if w in tf2 else 0))))+1 for w in all_w}
    v1 = {w: tf1.get(w,0)*idf[w] for w in all_w}
    v2 = {w: tf2.get(w,0)*idf[w] for w in all_w}
    dot = sum(v1[w]*v2[w] for w in all_w)
    n1 = math.sqrt(sum(v*v for v in v1.values()))
    n2 = math.sqrt(sum(v*v for v in v2.values()))
    return dot/(n1*n2) if n1>0 and n2>0 else 0.0

skills_text = ' '.join(skills) if skills else ''
sim = tfidf_sim(skills_text, jd_text) if len(jd_text.strip()) > 10 else 0
ss = min(50, round(sim * 100))

em = re.search(r'(\d+)\s*年', jd_text)
re_exp = int(em.group(1)) if em else 0
es = 30 if abs(exp_years-re_exp)<=1 else (
     20 if abs(exp_years-re_exp)<=3 else (
     10 if abs(exp_years-re_exp)<=5 else 5)) if re_exp>0 else 20

edu_order = {'博士':4, '硕士':3, '本科':2, '大专':1}
req_edu = ''
for e in ['博士','硕士','本科','大专']:
    if e in jd_text: req_edu = e; break
eus = 20 if (not req_edu) or (edu_order.get(education,0) >= edu_order.get(req_edu,0)) else (
      10 if edu_order.get(education,0) >= edu_order.get(req_edu,0)-1 else 5)

total = min(100, ss + es + eus)
reason = '语义匹配'
if len(jd_text.strip()) < 10: reason = 'JD过短'
print(f'{total}|{ss}|{es}|{eus}|{re_exp}|{req_edu or "不限"}|{reason}')
