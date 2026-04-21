#!/usr/bin/env python3
"""
pac-question-generator.py — Socratic Challenge Generator

Takes signals from pac-analyzer.py and generates high-quality Socratic
challenges following 5 quality rules:
    1. Based on observation, not generic wisdom
    2. Points to structure, not instance
    3. Challenges premise, not options
    4. Time dimension
    5. No answer given

LLM backend: delegates to enso_adapter_distill (adapter.sh) — same fallback
chain as distill-lessons (claude → llm → openai). Falls back to templates
if LLM unavailable.

Usage:
    cat signals.json | python3 pac-question-generator.py > challenge.xml

Stdlib only.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any


# Short timeout: hook must return fast. Templates already handle no-LLM case.
DISTILL_TIMEOUT = int(os.environ.get("PAC_GEN_TIMEOUT", "5"))
PERSONALITY = os.environ.get("PAC_PERSONALITY", "daoist")
LANGUAGE = os.environ.get("PAC_LANGUAGE", "zh-CN")

ENSO_CORE = Path(os.environ.get("ENSO_CORE", str(Path.home() / ".enso/core")))
ADAPTER_SH = ENSO_CORE / "adapter.sh"
# Dev fallback: repo-local adapter when not yet installed
if not ADAPTER_SH.exists():
    here = Path(__file__).resolve()
    ADAPTER_SH = here.parent / "adapter.sh"

PERSONALITY_DESC = {
    "daoist": "以道家式的点而不破、留白大于填满的语气",
    "straight": "以直接、不拐弯的语气",
    "gentle": "以温和但不退让的语气",
    "analytical": "以冷静分析的语气",
}


# ============================================================================
# LLM via adapter.sh (reuses distill fallback chain)
# ============================================================================

def generate_via_llm(signals: list[dict[str, Any]]) -> str | None:
    """Delegate to enso_adapter_distill — same LLM fallback chain as distill-lessons."""
    if not ADAPTER_SH.exists():
        return None

    top = signals[0]
    pattern = top["pattern"]
    confidence = top.get("confidence", 0.70)
    persona = PERSONALITY_DESC.get(PERSONALITY, "以平和的语气")

    prompt = f"""你是用户的 AI 外脑。不是应声虫,是镜子。根据观察到的行为模式,生成 1-3 个高质量 Socratic 式反问。

绝对规则 (违反任何一条立即重写):
1. 基于证据,不基于训练常识 — 必须引用具体的时间/频次/金额/案例
2. 指向结构,不指向现象 — 不问"为什么做X",问"为什么总是做X类事"
3. 挑战前提,不讨论选项 — 不问"选A还是B",问"为什么要做这件事"
4. 有时间维度 — 对比过去/当前/未来
5. 不提供答案 — 问完即停

语气: {persona}。语言: {LANGUAGE}。

输出严格 XML (不要加任何解释或前缀):
<enso-pac-challenge confidence="{confidence:.2f}" pattern="{pattern}">
  <observation>具体的数据观察,含数字和时间</observation>
  <human-reading>一句话人类可读总结</human-reading>
  <challenges>
    <q id="1">第一个反问</q>
    <q id="2">第二个反问(可选)</q>
    <q id="3">第三个反问(可选)</q>
  </challenges>
  <no-answer>这些问题留给你自己。不回答,下次 PAC 会包含"上次回避了什么"。</no-answer>
  <follow-up-in-days>7</follow-up-in-days>
</enso-pac-challenge>

只输出 XML,无其他内容。"""

    context = (
        f"检测到的模式: {pattern}\n"
        f"一句话总结: {top.get('summary', '')}\n"
        f"证据数据:\n{json.dumps(top['evidence'], ensure_ascii=False, indent=2)}"
    )

    try:
        result = subprocess.run(
            ["bash", "-c",
             f'source "{ADAPTER_SH}" && enso_adapter_distill "$1" "$2" "$3"',
             "_", context, str(DISTILL_TIMEOUT), prompt],
            capture_output=True,
            text=True,
            timeout=DISTILL_TIMEOUT + 5,  # small buffer for subprocess overhead
        )
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        pass
    return None


# ============================================================================
# Template Fallback
# ============================================================================

TEMPLATES: dict[str, dict[str, Any]] = {
    "repetition": {
        "observation_fmt": "过去{lookback_days}天你启动了{new_events_count}个新事项。样本: {sample_summary}",
        "human_fmt": "你在重复启动新事项,但每个都没跑完。",
        "questions": [
            "这{new_events_count}件事里,哪件是'不做就完蛋',哪件是'可以做也可以不做'?",
            "如果强制只能做3件,你会留下哪3件?为什么不是这9条?",
            "你启动新事项的真正动机,是机会好,还是用新鲜感逃避现有问题?",
        ],
    },
    "claim_action_conflict": {
        "observation_fmt": "你声明聚焦 {declared_focus},但实际行动中 {conflicting_lines_str} 占了主要精力。",
        "human_fmt": "声明的优先级和实际行动不匹配。",
        "questions": [
            "你真正优先的事是声明的那一层,还是精力实际流向的那一层?",
            "如果这次强制你'说的和做的必须一致',你愿意改哪一边?",
            "导致声明和行动分裂的根本原因,是你不相信声明,还是你逃避优先级的代价?",
        ],
    },
    "capability_mismatch": {
        "observation_fmt": "你将战略性任务委托给{person}。基于历史画像,{person}擅长执行而非战略判断。",
        "human_fmt": "战略任务交给了执行层的人。",
        "questions": [
            "这件事本该由你扛的,你为什么要委托出去?是时间不够,还是不想面对?",
            "如果{person}在这件事上再次出问题,代价会不会是整条业务线?",
            "你是在培养他,还是在转移责任?",
        ],
    },
    "sunk_cost": {
        "observation_fmt": "{business}已连续{zero_growth_days}天零增长,但你仍在投入 ({recent_action_count} 次近期动作)。",
        "human_fmt": "这条业务长期无产出,但仍在加码。",
        "questions": [
            "{business}的核心假设(目标用户/渠道/定价)有没有被真正验证过?还是你只在改战术?",
            "如果再给它6个月仍无起色,你会在什么数据/信号出现时下决心关闭?",
            "你不关它,是因为相信它能起来,还是因为关了就等于承认当初的判断错了?",
        ],
    },
    "decision_node": {
        "observation_fmt": "你正在面临重大决策: {matched_text}",
        "human_fmt": "重大决策前需要停下来问自己。",
        "questions": [
            "这个决策如果失败,最坏的后果是什么?你能承受吗?",
            "在决定前,你问过自己'为什么要做',而不只是'怎么做'吗?",
            "如果这件事3年后回看,你会感激今天做了这个决定,还是后悔?",
        ],
    },
}


def _prepare_template_kwargs(evidence: dict[str, Any]) -> dict[str, Any]:
    """Flatten evidence into flat kwargs for template.format()."""
    kwargs = dict(evidence)
    if "sample_events" in kwargs:
        kwargs["sample_summary"] = "; ".join(
            e.get("task", "")[:60] for e in kwargs["sample_events"][:3]
        )
    if "conflicting_lines" in kwargs:
        kwargs["conflicting_lines_str"] = ", ".join(
            f"{line}({pct:.0%})" for line, pct in kwargs["conflicting_lines"]
        )
    if "quotes" in kwargs and kwargs["quotes"]:
        kwargs["person"] = kwargs["quotes"][0].get("person", "执行层")
    kwargs.setdefault("person", "执行层")
    return kwargs


def generate_via_template(signals: list[dict[str, Any]]) -> str:
    """Template-based generation when no LLM available."""
    top = signals[0]
    pattern = top["pattern"]
    confidence = top.get("confidence", 0.70)
    template = TEMPLATES.get(pattern)

    if not template:
        return (
            f'<enso-pac-challenge confidence="{confidence:.2f}" pattern="{pattern}">\n'
            f'  <observation>{top.get("summary", "未知模式")}</observation>\n'
            f'  <human-reading>观察到一个值得思考的模式。</human-reading>\n'
            f'  <challenges>\n'
            f'    <q id="1">这个模式在过去是否已经出现过?</q>\n'
            f'    <q id="2">如果继续下去,最可能的结果是什么?</q>\n'
            f'  </challenges>\n'
            f'  <no-answer>这些问题留给你自己。</no-answer>\n'
            f'  <follow-up-in-days>7</follow-up-in-days>\n'
            f'</enso-pac-challenge>'
        )

    try:
        kwargs = _prepare_template_kwargs(top["evidence"])
        observation = template["observation_fmt"].format(**kwargs)
        human = template["human_fmt"].format(**kwargs)
        questions = [q.format(**kwargs) for q in template["questions"]]
    except (KeyError, IndexError):
        observation = top.get("summary", "检测到模式")
        human = "需要反思的模式已被识别。"
        questions = ["这个模式你自己有没有意识到?", "如果有,为什么还在继续?"]

    q_xml = "\n    ".join(
        f'<q id="{i+1}">{q}</q>' for i, q in enumerate(questions)
    )

    return (
        f'<enso-pac-challenge confidence="{confidence:.2f}" pattern="{pattern}">\n'
        f'  <observation>{observation}</observation>\n'
        f'  <human-reading>{human}</human-reading>\n'
        f'  <challenges>\n    {q_xml}\n  </challenges>\n'
        f'  <no-answer>这些问题留给你自己。不回答,下次 PAC 会包含"上次回避了什么"。</no-answer>\n'
        f'  <follow-up-in-days>7</follow-up-in-days>\n'
        f'</enso-pac-challenge>'
    )


# ============================================================================
# Validation
# ============================================================================

REQUIRED_TAGS = (
    "<enso-pac-challenge",
    "<observation>",
    "<challenges>",
    "<q id=",
    "</enso-pac-challenge>",
)


def validate_output(xml: str) -> bool:
    return all(tag in xml for tag in REQUIRED_TAGS)


# ============================================================================
# Main
# ============================================================================

def main() -> None:
    try:
        raw = sys.stdin.read().strip()
        signals = json.loads(raw) if raw else []
    except (json.JSONDecodeError, OSError):
        signals = []

    if not signals:
        sys.exit(0)

    output = generate_via_llm(signals)
    if not output or not validate_output(output):
        output = generate_via_template(signals)

    if not validate_output(output):
        sys.exit(1)

    print(output)


if __name__ == "__main__":
    main()
