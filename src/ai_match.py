#!/usr/bin/env python3
"""
AI简历匹配 - 使用本地 TF-IDF 语义相似度评估匹配度
无需API key，纯本地计算

用法:
  echo '{"resume":{"skills":["产品设计","AI"],"experience_years":10,"education":"本科"},"jd_text":"..."}' \
    | python3 src/ai_match.py

返回JSON:
  {"total":75, "skill_score":40, "exp_score":30, "edu_score":20,
   "required_exp":5, "required_edu":"本科", "reason":"语义匹配"}
"""

import json, re, sys, math
from collections import Counter


def tokenize(text):
    """中文+英文分词"""
    text = text.lower()
    # 提取英文单词
    words = re.findall(r'[a-zA-Z]+', text)
    # 提取中文（按字符二元组）
    chinese_chars = re.findall(r'[\u4e00-\u9fff]+', text)
    for c in chinese_chars:
        # 二元组
        words.extend([c[i:i+2] for i in range(len(c)-1)])
        # 单个字也加入
        words.extend(list(c))
    return words


def tfidf_similarity(text1, text2):
    """计算两段文本的 TF-IDF 余弦相似度"""
    words1 = tokenize(text1)
    words2 = tokenize(text2)
    
    if not words1 or not words2:
        return 0.0
    
    # 词频
    tf1 = Counter(words1)
    tf2 = Counter(words2)
    
    # 并集词汇
    all_words = set(tf1.keys()) | set(tf2.keys())
    
    # IDF（用总词数模拟）
    total_docs = 2
    idf = {}
    for w in all_words:
        df = (1 if w in tf1 else 0) + (1 if w in tf2 else 0)
        idf[w] = math.log((total_docs + 1) / (df + 1)) + 1
    
    # TF-IDF 向量
    vec1 = {w: tf1.get(w, 0) * idf.get(w, 0) for w in all_words}
    vec2 = {w: tf2.get(w, 0) * idf.get(w, 0) for w in all_words}
    
    # 余弦相似度
    dot = sum(vec1[w] * vec2[w] for w in all_words)
    norm1 = math.sqrt(sum(v*v for v in vec1.values()))
    norm2 = math.sqrt(sum(v*v for v in vec2.values()))
    
    if norm1 == 0 or norm2 == 0:
        return 0.0
    
    return dot / (norm1 * norm2)


def extract_exp(jd_text):
    """从JD提取经验要求"""
    em = re.search(r'(\d+)\s*年', jd_text)
    return int(em.group(1)) if em else 0


def extract_edu(jd_text):
    """从JD提取学历要求"""
    for e in ['博士', '硕士', '本科', '大专']:
        if e in jd_text:
            return e
    return ''


def main():
    try:
        input_data = json.loads(sys.stdin.read())
    except json.JSONDecodeError as e:
        print(json.dumps({"error": f"JSON解析失败: {e}"}))
        sys.exit(1)

    resume = input_data.get('resume', {})
    jd_text = input_data.get('jd_text', '')
    
    skills = resume.get('skills', [])
    exp_years = resume.get('experience_years', 10)
    education = resume.get('education', '本科')
    
    # 技能匹配（TF-IDF语义相似度转50分制）
    if jd_text and len(jd_text.strip()) > 10:
        # 计算技能文本与JD的相似度
        skills_text = ' '.join(skills) if skills else ''
        sim = tfidf_similarity(skills_text, jd_text)
        ss = min(50, round(sim * 50 * 2))  # 放大系数2
    else:
        ss = 0

    # 经验匹配
    re_exp = extract_exp(jd_text)
    es = 30 if abs(exp_years - re_exp) <= 1 else (
        20 if abs(exp_years - re_exp) <= 3 else (
        10 if abs(exp_years - re_exp) <= 5 else 5)
    ) if re_exp > 0 else 20

    # 学历匹配
    edu_order = {'博士': 4, '硕士': 3, '本科': 2, '大专': 1}
    req_edu = extract_edu(jd_text)
    if req_edu:
        eus = 20 if edu_order.get(education, 0) >= edu_order.get(req_edu, 0) else (
              10 if edu_order.get(education, 0) >= edu_order.get(req_edu, 0) - 1 else 5)
    else:
        eus = 15

    total = min(100, ss + es + eus)
    
    reason = "语义匹配"
    if not jd_text or len(jd_text.strip()) < 10:
        reason = "关键词匹配(fallback)"

    # pipe分隔，兼容AppleScript解析
    print(f"{total}|{ss}|{es}|{eus}|{re_exp}|{req_edu or '不限'}|{reason}")


if __name__ == '__main__':
    main()
