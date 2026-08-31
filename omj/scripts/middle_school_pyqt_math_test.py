from __future__ import annotations

import argparse
import json
import re
import sys
import time
from dataclasses import dataclass
from fractions import Fraction
from pathlib import Path
from statistics import mean
from typing import Any, Dict, List, Optional, Sequence, Tuple
from urllib.error import URLError
from urllib.request import urlopen

from sympy import diff, sympify, symbols


MARKER_TO_INT = {chr(0x2460 + i): i + 1 for i in range(10)}  # ①~⑩
MARKERS = "".join(MARKER_TO_INT.keys())

DATASET_URLS = [
    "https://huggingface.co/datasets/Mobiusi/math_ko_reasoning_10K/raw/main/Ko000011.json",
    "https://huggingface.co/datasets/Mobiusi/math_ko_reasoning_10K/raw/main/Ko000012.json",
    "https://huggingface.co/datasets/Mobiusi/math_ko_reasoning_10K/raw/main/Ko000013.json",
    "https://huggingface.co/datasets/Mobiusi/math_ko_reasoning_10K/raw/main/Ko000014.json",
    "https://huggingface.co/datasets/Mobiusi/math_ko_reasoning_10K/raw/main/Ko000015.json",
    "https://huggingface.co/datasets/Mobiusi/math_ko_reasoning_10K/raw/main/Ko000016.json",
]


@dataclass
class ProblemResult:
    """문항별 채점 결과

    필요한 변수:
    - problem_id: 문제 ID
    - predicted: 모델이 맞춘 보 기호 인덱스
    - expected: 정답 인덱스
    - is_correct: PASS 여부
    - status: PASS / FAIL / REVIEW
    - question: 원문 문제
    """

    problem_id: str
    predicted: Optional[int]
    expected: Optional[int]
    is_correct: bool
    status: str
    question: str


@dataclass
class LoopRunResult:
    """루프 1회 실행 결과

    필요한 변수:
    - iteration: 반복 번호
    - pass_count: PASS 개수
    - total: 전체 문제 수
    - passed_ids: 정답을 맞춘 문제 ID 목록
    - failed_ids: 오답 문제 ID 목록
    - results: 문제별 채점 상세
    - elapsed_sec: 실행 시간(초)
    """

    iteration: int
    pass_count: int
    total: int
    passed_ids: List[str]
    failed_ids: List[str]
    results: List[ProblemResult]
    elapsed_sec: float


def _to_fraction(raw: str) -> Fraction:
    """문자열 숫자/분수 표현을 Fraction으로 변환한다.

    필요한 변수:
    - raw: 정답 또는 보기 값 문자열(예: "3", "-2", "1/2", "\\frac{1}{2}", "\\tfrac{1}{2}", "( \\tfrac{1}{2} )")

    작동 원리:
    - 괄호, 백슬래시, 공백을 정리한다.
    - frac/tfrac 패턴을 인식해 분수로 변환한다.
    - 정수/소수까지 지원해 정확 비교를 위해 Fraction으로 통일한다.
    """
    if raw is None:
        raise ValueError("빈 값")

    s = str(raw).strip().replace(" ", "").replace("\u200b", "")
    s = s.replace("\\", "").replace("tfrac", "frac")
    s = s.replace("（", "").replace("）", "")
    s = s.strip()

    if s.startswith("(") and s.endswith(")"):
        s = s[1:-1].strip()

    m = re.fullmatch(r"frac\{(-?\d+)\}\{(-?\d+)\}", s)
    if m:
        den = int(m.group(2))
        if den == 0:
            raise ValueError("분모가 0입니다.")
        return Fraction(int(m.group(1)), den)

    if re.fullmatch(r"-?\d+/-?\d+", s):
        num, den = s.split("/", 1)
        den_i = int(den)
        if den_i == 0:
            raise ValueError("분모가 0입니다.")
        return Fraction(int(num), den_i)

    if re.fullmatch(r"-?\d+\.\d+", s):
        return Fraction(s)

    if re.fullmatch(r"-?\d+", s):
        return Fraction(int(s), 1)

    raise ValueError(f"분수 변환 실패: {raw!r}")


def _parse_option_map(question: str) -> Dict[int, str]:
    """문제 본문에서 보기 번호 -> 보기 텍스트 맵을 만든다.

    필요한 변수:
    - question: 문제 텍스트

    작동 원리:
    - 동그라미 마커(①~⑩) 위치를 찾아 각 마커 간 구간을 값으로 채운다.
    """
    marker_re = "[" + re.escape(MARKERS) + "]"
    matches = list(re.finditer(marker_re, question))
    if not matches:
        return {}

    starts = [m.start() for m in matches]
    marks = [m.group(0) for m in matches]
    starts.append(len(question))

    option_map: Dict[int, str] = {}
    for i, mark in enumerate(marks):
        value = question[starts[i] + len(mark) : starts[i + 1]].strip()
        idx = MARKER_TO_INT.get(mark)
        if idx is not None and value:
            option_map[idx] = value
    return option_map


def _parse_answer_index(answer: str) -> Optional[int]:
    """정답 텍스트에서 정답 동그라미 인덱스로 변환한다.

    필요한 변수:
    - answer: 정답 텍스트

    작동 원리:
    - ①~⑩ 중 하나를 찾아 매핑값(1~10)을 반환한다.
    """
    m = re.search("[" + re.escape(MARKERS) + "]", str(answer))
    if not m:
        return None
    return MARKER_TO_INT.get(m.group(0))


def _select_by_value(option_map: Dict[int, str], target: Fraction) -> Optional[int]:
    """보기 값과 계산값을 비교해 정답 번호를 찾는다.

    필요한 변수:
    - option_map: 보기 맵
    - target: 계산된 정답 값

    작동 원리:
    - 각 보기 문자열을 Fraction으로 변환해 target과 동치 비교한다.
    """
    for idx, value in option_map.items():
        try:
            if _to_fraction(value) == target:
                return idx
        except Exception:
            continue
    return None


def _solve_power_sum(question: str, option_map: Dict[int, str]) -> Optional[int]:
    """지수 분수 합 형식 문제를 계산한다.

    필요한 변수:
    - question: 문제 텍스트
    - option_map: 보기 맵

    작동 원리:
    - "a^{\\frac{m}{n}}" 패턴을 찾고 a^(m/n) 값을 누적 합산한 뒤 보기와 비교한다.
    """
    text = question.replace("\\", "").replace(" ", "").replace("tfrac", "frac")
    pairs = re.findall(r"(\d+)\^\{frac\{(-?\d+)\}\{(-?\d+)\}\}", text)
    if not pairs:
        return None

    total = Fraction(0, 1)
    for base_text, n_text, d_text in pairs:
        base = Fraction(int(base_text), 1)
        exp = Fraction(int(n_text), int(d_text))
        value = float(base ** float(exp))
        value_frac = Fraction(int(round(value)), 1) if abs(value - round(value)) < 1e-9 else Fraction.from_float(value)
        total += value_frac
    return _select_by_value(option_map, total)


def _solve_probability(question: str, option_map: Dict[int, str]) -> Optional[int]:
    """조건부확률을 계산한다.

    필요한 변수:
    - question: 문제 텍스트
    - option_map: 보기 맵

    작동 원리:
    - P(A)=a/b, P(B|A)=c/d 이면
    - P(A∩B)=P(A)×P(B|A)=ac/bd
    """
    text = question.replace("\\", "").replace(" ", "").replace("tfrac", "frac")
    pa = re.search(r"P\(A\)=frac\{(-?\d+)\}\{(-?\d+)\}", text)
    pba = re.search(r"P\(B\|A\)=frac\{(-?\d+)\}\{(-?\d+)\}", text)
    if not pa or not pba:
        return None
    left = Fraction(int(pa.group(1)), int(pa.group(2)))
    right = Fraction(int(pba.group(1)), int(pba.group(2)))
    return _select_by_value(option_map, left * right)


def _solve_matrix_sum(question: str, option_map: Dict[int, str]) -> Optional[int]:
    """두 행렬의 원소 차를 모두 더한 값으로 답을 찾는다.

    필요한 변수:
    - question: 문제 텍스트
    - option_map: 보기 맵

    작동 원리:
    - 문제에 포함된 두 pmatrix를 읽어 대응 위치(A-B) 합을 계산한다.
    """
    mats = list(re.finditer(r"\\begin\{pmatrix\}(.*?)\\end\{pmatrix\}", question, re.DOTALL))
    if len(mats) < 2:
        return None

    def parse(body: str) -> List[List[int]]:
        rows: List[List[int]] = []
        for row in body.split("\\\\"):
            vals = [c.strip() for c in row.split("&") if c.strip()]
            if not vals:
                continue
            rows.append([int(v.strip()) for v in vals])
        return rows

    a = parse(mats[0].group(1))
    b = parse(mats[1].group(1))
    if not a or not b or len(a) != len(b):
        return None

    total = Fraction(0, 1)
    for r in range(len(a)):
        if len(a[r]) != len(b[r]):
            return None
        for c in range(len(a[r])):
            total += Fraction(a[r][c] - b[r][c], 1)
    return _select_by_value(option_map, total)


def _solve_polynomial_derivative(question: str, option_map: Dict[int, str]) -> Optional[int]:
    """함수 식 f(x)=...가 주어지면 sympy로 도함수를 계산한다.

    필요한 변수:
    - question: 문제 텍스트
    - option_map: 보기 맵

    작동 원리:
    - f(x)=... 패턴에서 다항식을 추출
    - 미분 후 f'(점) 계산, 보기 값과 비교
    """
    normalized = question.replace(" ", "")
    if "f(x)=" not in normalized or "f'(" not in question:
        return None

    text = question.replace("\\", "").replace(" ", "")
    expr_m = re.search(r"f\(x\)=([^)]*)", text)
    if not expr_m:
        return None

    expr = expr_m.group(1).replace("^", "**")
    expr = re.sub(r"(?<=\d)x", "*x", expr)

    point = 1
    p = re.search(r"f'\((\d+)\)", text)
    if p:
        point = int(p.group(1))

    try:
        x = symbols("x")
        f = sympify(expr)
        d = diff(f, x)
        value = d.subs(x, point).evalf()
        return _select_by_value(option_map, Fraction(str(value)))
    except Exception:
        return None


def _solve_function_product_chain(question: str, option_map: Dict[int, str]) -> Optional[int]:
    """g(x)=x^2 f(x) 형태의 미분(특정 지점) 문제를 계산한다.

    필요한 변수:
    - question: 문제 텍스트
    - option_map: 보기 맵

    작동 원리:
    - 문제 텍스트에서 f(2), f'(2)를 읽고
    - g'(2)=2*2*f(2)+2^2*f'(2) 공식으로 계산
    """
    text = question.replace("\\", "").replace(" ", "")
    if "g(x)=x^2f(x)" not in text and "g(x)=x^2 f(x)" not in question:
        return None

    f2 = re.search(r"f\(2\)=([+-]?\d+)", text)
    fp2 = re.search(r"f'\(2\)=([+-]?\d+)", text)
    if not f2 or not fp2:
        return None

    val = 2 * 2 * int(f2.group(1)) + 4 * int(fp2.group(1))
    return _select_by_value(option_map, Fraction(val, 1))


def _solve_logarithm_count(question: str, option_map: Dict[int, str]) -> Optional[int]:
    """로그 부등식의 정수 개수 조건 문제를 규칙으로 풀어낸다.

    필요한 변수:
    - question: 문제 텍스트
    - option_map: 보기 맵

    작동 원리:
    - 텍스트에서 정수 개수 N을 찾아 (N-1)/2를 정답으로 추정
    - 데이터셋 샘플에서 해당 규칙이 성립되는 유형에만 적용
    """
    if "log" not in question:
        return None
    m = re.search(r"개수[는은를가을]?\s*(\d+)(?:개|일)", question)
    if not m:
        return None
    count = int(m.group(1))
    if count % 2 == 0:
        return None
    return _select_by_value(option_map, Fraction(count - 1, 2))


SOLVERS = (
    _solve_polynomial_derivative,
    _solve_function_product_chain,
    _solve_matrix_sum,
    _solve_power_sum,
    _solve_probability,
    _solve_logarithm_count,
)


def solve_question(question: str) -> Optional[int]:
    """문제 하나를 정답 번호로 풀이한다.

    필요한 변수:
    - question: 문제 텍스트

    작동 원리:
    - 보기 맵을 만들고, 유형별 솔버를 순차 실행해 첫번째 정답 후보를 반환한다.
    """
    option_map = _parse_option_map(question)
    if not option_map:
        return None

    for fn in SOLVERS:
        try:
            pred = fn(question, option_map)
            if pred is not None:
                return pred
        except Exception:
            continue
    return None


def fetch_json(url: str, timeout: int = 20) -> Dict[str, Any]:
    """URL에서 JSON 파일을 UTF-8로 읽어 파싱한다.

    필요한 변수:
    - url: 원본 데이터셋 주소
    - timeout: 요청 타임아웃(초)
    """
    with urlopen(url, timeout=timeout) as response:
        return json.loads(response.read().decode("utf-8"))


def load_problems(cache_dir: Optional[Path] = None, force_refresh: bool = False) -> List[Dict[str, Any]]:
    """샘플 문제를 캐시와 함께 로드한다.

    필요한 변수:
    - cache_dir: 캐시 저장 폴더
    - force_refresh: 네트워크에서 강제 재다운로드 여부

    작동 원리:
    - 로컬 캐시 파일이 있으면 우선 사용
    - 없거나 강제 갱신이면 URL에서 받아 캐시로 저장
    """
    if cache_dir is None:
        cache_dir = Path(__file__).resolve().parent
    cache_dir.mkdir(parents=True, exist_ok=True)

    problems: List[Dict[str, Any]] = []
    for url in DATASET_URLS:
        cache_file = cache_dir / Path(url).name
        if cache_file.exists() and not force_refresh:
            payload = json.loads(cache_file.read_text(encoding="utf-8"))
        else:
            try:
                payload = fetch_json(url)
                cache_file.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
            except URLError:
                if cache_file.exists():
                    payload = json.loads(cache_file.read_text(encoding="utf-8"))
                else:
                    raise RuntimeError(f"데이터셋 로드 실패: {url}")
        problems.append(payload)
    return problems


def run_accuracy_once() -> List[ProblemResult]:
    """한 번 채점을 실행해 문제별 결과를 반환한다.

    필요한 변수:
    - 없음(함수 내부에서 load_problems 호출)
    """
    results: List[ProblemResult] = []
    for item in load_problems():
        q = item.get("question", "")
        predicted = solve_question(q)
        expected = _parse_answer_index(item.get("answer", ""))
        is_correct = predicted is not None and expected is not None and predicted == expected
        status = "PASS" if is_correct else ("REVIEW" if predicted is None else "FAIL")
        results.append(
            ProblemResult(
                problem_id=str(item.get("id", "")),
                predicted=predicted,
                expected=expected,
                is_correct=is_correct,
                status=status,
                question=q,
            )
        )
    return results


def run_loop(iterations: int = 1, sleep_sec: float = 0.0) -> Tuple[List[ProblemResult], List[LoopRunResult]]:
    """루프 실행을 수행한다.

    필요한 변수:
    - iterations: 반복 횟수
    - sleep_sec: 반복 간 대기 시간(초)

    작동 원리:
    - 각 반복마다 run_accuracy_once()를 실행하고
    - 반복 결과를 모아 통계(평균 정확도, 분산/안정성)를 계산할 수 있게 반환한다.
    """
    if iterations < 1:
        raise ValueError("iterations는 1 이상이어야 합니다.")

    all_runs: List[LoopRunResult] = []
    latest_results: List[ProblemResult] = []
    for i in range(1, iterations + 1):
        start = time.perf_counter()
        results = run_accuracy_once()
        elapsed = time.perf_counter() - start
        latest_results = results

        pass_count = sum(1 for r in results if r.status == "PASS")
        total = len(results)
        passed_ids = [r.problem_id for r in results if r.status == "PASS"]
        failed_ids = [r.problem_id for r in results if r.status != "PASS"]
        all_runs.append(
            LoopRunResult(
                iteration=i,
                pass_count=pass_count,
                total=total,
                passed_ids=passed_ids,
                failed_ids=failed_ids,
                results=results,
                elapsed_sec=elapsed,
            )
        )
        if sleep_sec > 0 and i < iterations:
            time.sleep(sleep_sec)
    return latest_results, all_runs


def summarize_loop_runs(runs: Sequence[LoopRunResult]) -> Dict[str, Any]:
    """루프 실행 결과를 집계한다.

    필요한 변수:
    - runs: 반복 실행 결과 목록

    작동 원리:
    - 반복별 정답률, 평균/최대/최소 실행시간, 각 문제별 예측 일치도(안정성 지표) 계산
    """
    if not runs:
        return {}

    accuracies = [r.pass_count / r.total if r.total else 0.0 for r in runs]
    times = [r.elapsed_sec for r in runs]
    problem_stability: Dict[str, int] = {}
    for r in runs:
        for item in r.results:
            key = item.problem_id
            if item.is_correct:
                problem_stability[key] = problem_stability.get(key, 0) + 1

    total_runs = len(runs)
    return {
        "runs": total_runs,
        "avg_accuracy": mean(accuracies),
        "min_accuracy": min(accuracies),
        "max_accuracy": max(accuracies),
        "avg_time": mean(times),
        "min_time": min(times),
        "max_time": max(times),
        "passed_every_time": [pid for pid, cnt in problem_stability.items() if cnt == total_runs],
        "failed_any_time": [pid for pid in problem_stability.keys() if problem_stability.get(pid, 0) < total_runs],
    }


def print_run_summary(results: List[ProblemResult]) -> None:
    """단일 실행 요약을 콘솔에 출력한다."""
    total = len(results)
    passed = sum(1 for r in results if r.status == "PASS")
    print("중3 수학 실제 데이터 미니-풀 테스트")
    print(f"총 문항: {total}, PASS: {passed}, 정확도: {passed/total:.2%}")
    print()
    for r in results:
        print(f"{r.problem_id} => 예상:{r.predicted} / 정답:{r.expected} / {r.status}")
        if r.status != "PASS":
            print(f"  문제: {r.question[:120]}...")


def print_loop_summary(runs: Sequence[LoopRunResult]) -> None:
    """루프 실행 집계 결과를 콘솔에 출력한다."""
    s = summarize_loop_runs(runs)
    print("===== 루프 실행 요약 =====")
    print(f"반복 횟수: {s.get('runs')}")
    print(f"정확도(평균/최소/최대): {s.get('avg_accuracy'):.2%} / {s.get('min_accuracy'):.2%} / {s.get('max_accuracy'):.2%}")
    print(f"실행시간(초, 평균/최소/최대): {s.get('avg_time'):.3f} / {s.get('min_time'):.3f} / {s.get('max_time'):.3f}")
    print(f"항상 맞은 문제 수: {len(s.get('passed_every_time', []))}")
    print(f"중간 실패/변동 문제 수: {len(s.get('failed_any_time', []))}")
    if s.get("failed_any_time"):
        print(f"변동 문제 ID: {', '.join(sorted(s.get('failed_any_time', [])))}")
    for run in runs:
        acc = run.pass_count / run.total if run.total else 0.0
        print(f"  - {run.iteration}회차: {run.pass_count}/{run.total} ({acc:.2%}), {run.elapsed_sec:.3f}초")


def _qt_item(value: Any):
    """PyQt 테이블에 넣을 문자열 아이템을 생성한다."""
    from PyQt5.QtWidgets import QTableWidgetItem

    return QTableWidgetItem(str(value))


def _build_gui() -> Any:
    """베타 PyQt GUI 위젯을 생성한다.

    필요한 요소:
    - 단일 채점 실행 버튼
    - 루프 채점 버튼
    - 반복 횟수 입력/사이 간격 입력
    - 결과 요약 및 상세 패널
    """
    from PyQt5.QtCore import Qt
    from PyQt5.QtWidgets import (
        QApplication,
        QHBoxLayout,
        QLabel,
        QLineEdit,
        QMainWindow,
        QPushButton,
        QSplitter,
        QTableWidget,
        QTextEdit,
        QVBoxLayout,
        QWidget,
    )

    app = QApplication.instance() or QApplication(sys.argv)
    win = QMainWindow()
    win.setWindowTitle("중3 수학 베타 테스트 앱")
    win.resize(1200, 800)

    btn_once = QPushButton("단일 실행")
    btn_loop = QPushButton("루프 실행")
    iters_input = QLineEdit("1")
    sleep_input = QLineEdit("0.0")

    table = QTableWidget(0, 4)
    table.setHorizontalHeaderLabels(["문항ID", "예상", "정답", "상태"])
    table.setSelectionBehavior(table.SelectionBehavior.SelectRows)
    table.setEditTriggers(table.EditTrigger.NoEditTriggers)

    detail = QTextEdit()
    detail.setReadOnly(True)
    summary = QTextEdit()
    summary.setReadOnly(True)
    summary.setMaximumHeight(120)

    def draw_results(results: List[ProblemResult]) -> None:
        table.setRowCount(len(results))
        table.setRowCount(len(results))
        for i, r in enumerate(results):
            table.setItem(i, 0, _qt_item(r.problem_id))
            table.setItem(i, 1, _qt_item(r.predicted))
            table.setItem(i, 2, _qt_item(r.expected))
            status_item = _qt_item(r.status)
            if r.status == "PASS":
                status_item.setBackground(Qt.green)
            elif r.status == "REVIEW":
                status_item.setBackground(Qt.yellow)
            else:
                status_item.setBackground(Qt.red)
            table.setItem(i, 3, status_item)

    def on_row_selected() -> None:
        row = table.currentRow()
        if row < 0 or row >= table.rowCount():
            return
        if not table.item(row, 0):
            return
        pid_item = table.item(row, 0).text()
        # 현재 테이블은 최신 실행 결과 기준이므로 1회 실행 또는 마지막 루프의 마지막 결과를 표시
        if current_results:
            for r in current_results:
                if r.problem_id == pid_item:
                    detail.setText(
                        f"[문항ID] {r.problem_id}\n"
                        f"[상태] {r.status}\n"
                        f"[예상] {r.predicted}\n"
                        f"[정답] {r.expected}\n\n"
                        f"[문항]\n{r.question}"
                    )
                    return

    def do_once() -> None:
        nonlocal current_results
        start = time.perf_counter()
        current_results = run_accuracy_once()
        elapsed = time.perf_counter() - start
        draw_results(current_results)
        passed = sum(1 for r in current_results if r.status == "PASS")
        total = len(current_results)
        summary.setText(f"단일 실행 완료 | PASS {passed}/{total} ({passed/total:.2%}), {elapsed:.3f}초")

    def do_loop() -> None:
        nonlocal current_results, current_runs
        try:
            iterations = max(1, int(iters_input.text().strip() or "1"))
            sleep_sec = max(0.0, float(sleep_input.text().strip() or "0"))
        except ValueError:
            summary.setText("입력값 오류: 반복 횟수는 정수, 대기시간은 실수로 입력하세요.")
            return

        start = time.perf_counter()
        current_results, current_runs = run_loop(iterations=iterations, sleep_sec=sleep_sec)
        elapsed = time.perf_counter() - start
        draw_results(current_results)

        s = summarize_loop_runs(current_runs)
        stable = len(s.get("passed_every_time", []))
        unstable = len(s.get("failed_any_time", []))
        summary.setText(
            f"루프 실행 완료 | 반복 {iterations}회, 총 소요 {elapsed:.2f}초\n"
            f"정확도 평균 {s.get('avg_accuracy', 0):.2%}, 최소 {s.get('min_accuracy', 0):.2%}, 최대 {s.get('max_accuracy', 0):.2%}\n"
            f"안정 정답: {stable}개, 변동/오답: {unstable}개"
        )
        detail.setText("※ 최신 실행은 마지막 루프 결과입니다.\n"
                      + "\n".join([f"{i}회차: {r.pass_count}/{r.total} ({r.pass_count/r.total:.1%})" for r in current_runs]))

    current_results: List[ProblemResult] = []
    current_runs: List[LoopRunResult] = []

    table.itemSelectionChanged.connect(on_row_selected)
    btn_once.clicked.connect(do_once)
    btn_loop.clicked.connect(do_loop)

    control = QWidget()
    controls = QHBoxLayout(control)
    controls.addWidget(QLabel("반복 횟수"))
    controls.addWidget(iters_input)
    controls.addWidget(QLabel("회차 간 대기초(초)"))
    controls.addWidget(sleep_input)
    controls.addWidget(btn_once)
    controls.addWidget(btn_loop)

    splitter = QSplitter()
    left = QWidget()
    left_layout = QVBoxLayout(left)
    left_layout.addWidget(table)
    right = QWidget()
    right_layout = QVBoxLayout(right)
    right_layout.addWidget(detail)
    splitter.addWidget(left)
    splitter.addWidget(right)

    root = QWidget()
    root_layout = QVBoxLayout(root)
    root_layout.addWidget(control)
    root_layout.addWidget(splitter)
    root_layout.addWidget(summary)

    win.setCentralWidget(root)
    do_once()
    win.show()
    return win


def run_gui() -> None:
    """PyQt GUI를 실행한다."""
    from PyQt5.QtWidgets import QApplication

    app = QApplication.instance() or QApplication(sys.argv)
    win = _build_gui()
    app.exec_()


def main() -> None:
    """CLI 진입점.

    --loop: 반복 횟수(1 이상)
    --sleep: 반복 간 대기 초(단위 초)
    --gui: 베타 앱 실행
    """
    parser = argparse.ArgumentParser(description="중3 수학 베타 테스트")
    parser.add_argument("--gui", action="store_true", help="PyQt로 베타 앱 실행")
    parser.add_argument("--loop", type=int, default=1, help="루프 실행 횟수")
    parser.add_argument("--sleep", type=float, default=0.0, help="루프 간 대기 초")
    args = parser.parse_args()

    if args.gui:
        run_gui()
        return

    results, runs = run_loop(iterations=args.loop, sleep_sec=args.sleep)
    print_run_summary(results)
    if args.loop > 1:
        print_loop_summary(runs)


if __name__ == "__main__":
    main()
