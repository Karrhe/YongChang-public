"""STO-2: turn the script (personal repo story-final/STORY-FINAL-v3.md) into rows of data/text/story.csv.

Usage: python script_to_story_csv.py SCRIPT.md STORY.csv [EXTRA.csv]
- Generates the scenes P1 … G3-5 (story scenes, choice dialogue and option rows, C3_A_result) and
  replaces those scenes in STORY.csv; every other scene already in the table (battle lines, ending)
  is kept as is. EXTRA.csv rows (same columns) are appended / replace their scenes too
  (used for the STO-07 event lines from DRAFT-001).
- Format: personal repo TEAM-001 §4. Conditional lines [一代存活] → GEN1_ALIVE etc.
- Skipped on purpose: the lead's notes in half-width parentheses, "> " mechanics notes, the
  death-stage replacement lines (they live in the ending table), the B8 battle lines (already
  entered as B8_start / B8_end), G3-2 version B (deleted in the script)."""
import csv
import re
import sys

COND = {"[一代存活]": "GEN1_ALIVE", "[一代阵亡]": "GEN1_DEAD", "[二代都不在]": "GEN2_NONE"}
AB_SCENES = {"G1-2", "G1-3", "G1-4", "C1", "G1-5", "G1-6", "T1", "G2-2", "C2", "G2-3", "G2-4", "C3", "G2-5", "G2-6"}
# who says the chosen option: the hero of that generation in version A, the companion in version B
SAY = {("C1", "A"): "王成", ("C1", "B"): "阿棠", ("C2", "A"): "{名2}", ("C2", "B"): "周砚",
       ("C3", "A"): "{名2}", ("C3", "B"): "周砚", ("C4", ""): "{名3}", ("C5", ""): "{名3}"}
NOTE_WORDS = ("界面", "机制", "命名", "删掉", "剧情表", "不设")
SCENE_RE = re.compile(r"^#{2,3} (P1|G\d-\d|T\d|C\d)\b")
LINE_RE = re.compile(r"^\*\*(.+?)：\*\*\s*(.*)$")
OPT_RE = re.compile(r"^- \*\*选项 ([AB])：(.+?)。?\*\*\s*[\"“](.+?)[\"”]\s*$")


def clean(text):
    text = re.sub(r"\([^()]*[一-鿿][^()]*\)", "", text)  # lead's notes in half-width parentheses
    return re.sub(r"\s+$", "", text).strip()


def parse(md):
    rows = []
    scene = version = goal = None
    counters = {}
    skip = False

    def key():
        k = scene
        if scene in AB_SCENES and version:
            k += "_" + version
        if goal:
            k += "_" + goal
        return k

    def add(k, line_id, cond, speaker, text):
        if line_id is None:
            counters[k] = counters.get(k, 0) + 1
            line_id = "%02d" % counters[k]
        rows.append([k, line_id, cond, speaker, "", text])

    for raw in md.splitlines():
        line = raw.rstrip()
        m = SCENE_RE.match(line)
        if line.startswith("# ") or (line.startswith("## ") and not m):
            scene = None if not m else scene
        if m:
            scene, version, goal, skip = m.group(1), None, None, False
            if line.startswith("## "):
                continue
        if scene is None:
            continue
        if line.startswith("## E") or line.startswith("# 结局"):
            scene = None
            continue
        if line.startswith("### "):
            h = line[4:]
            goal = None
            skip = False
            if "版本 A" in h or "第一代主角存活" in h:
                version = "A"
            elif "版本 B" in h or "第一代主角阵亡" in h:
                version = "B"
            elif "C3-A 结果句" in h:
                scene, version = "C3_A_result", None
            elif "命名界面" in h or "B8 战斗内" in h:
                skip = True
            continue
        if skip or not line.strip() or line.startswith(">") or line.startswith("---"):
            continue
        if line.startswith("**城墙目标达成"):
            goal = "met"
            continue
        if line.startswith("**城墙目标未达成"):
            goal = "unmet"
            continue
        if line.startswith("**死亡阶段替换句") or line.startswith("**开场") or line.startswith("**结束"):
            continue
        if scene in ("G3-2",) and version == "B":
            continue
        if scene in ("C4", "C5", "G3-1", "G3-2", "G3-3", "G3-4", "G3-5"):
            version = None
        om = OPT_RE.match(line)
        if om:
            pick, label, say = om.groups()
            base = scene + ("_" + version if scene in AB_SCENES and version else "")
            add(base, "opt" + pick, "", "", clean(label))
            add(base, "opt%s_say" % pick, "", SAY.get((scene, version or ""), "旁白"), clean(say))
            continue
        lm = LINE_RE.match(line)
        if lm:
            who, text = lm.groups()
            cond = ""
            for mark, code in COND.items():
                if who.startswith(mark):
                    cond, who = code, who[len(mark):].strip()
            if who.startswith("[二代长辈]"):
                rest = who[len("[二代长辈]"):].strip()
                cond = "GEN2_ELDER_A" if rest.startswith("甲") else "GEN2_ELDER_B"
                who = rest[1:].strip()
            text = clean(text)
            if text:
                add(key(), None, cond, who, text)
            continue
        if line.startswith("（") and line.endswith("）"):  # stage direction on its own line
            if not any(w in line for w in NOTE_WORDS):  # design notes also use （）
                add(key(), None, "", "旁白", line)
            continue
        if re.fullmatch(r"\([^()]{1,10}\)", line):  # short stage direction written with ( )
            add(key(), None, "", "旁白", "（%s）" % line[1:-1])
            continue
        # anything else is a note to the lead / designer: not entered
    return rows


def main():
    script, table = sys.argv[1], sys.argv[2]
    with open(script, encoding="utf-8") as f:
        new_rows = parse(f.read())
    if len(sys.argv) > 3:
        with open(sys.argv[3], encoding="utf-8", newline="") as f:
            new_rows += [r for r in csv.reader(f) if r and not r[0].startswith("#") and r[0] != "scene_id"]
    replaced = {r[0] for r in new_rows}
    with open(table, encoding="utf-8", newline="") as f:
        old = list(csv.reader(f))
    header, body = old[0], old[1:]
    comments = [r for r in body if r and r[0].startswith("#")]
    kept = [r for r in body if r and not r[0].startswith("#") and r[0] not in replaced]
    comments = [["# 剧情表：一行一句，格式见 personal 仓库 TEAM-001 §4。P1–G3-5 由 tools/story/script_to_story_csv.py 从剧本 STORY-FINAL-v3 生成（STO-2）；战斗台词和结局另录。"]]
    with open(table, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(header)
        w.writerows(comments)
        w.writerows(new_rows)
        w.writerows(kept)
    print("scenes:", len(replaced), "rows:", len(new_rows), "kept rows:", len(kept))


if __name__ == "__main__":
    main()
