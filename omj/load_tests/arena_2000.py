"""실서비스 Redis/PostgreSQL을 대상으로 아레나 2,000 연결을 검증한다."""

from __future__ import annotations

import argparse
import asyncio
import json
import time
import uuid
from collections import Counter
from pathlib import Path
from typing import Any

import httpx
import websockets

LOAD_HTTP_TIMEOUT_SECONDS = 120
LOAD_WEBSOCKET_TIMEOUT_SECONDS = 60
LOAD_TRANSPORT_RETRIES = 3


def _load_tokens(path: Path, expected: int) -> list[str]:
    """필요 변수: UTF-8 토큰 파일과 목표 인원. 빈 줄을 제외하고 정확한 사용자 토큰 수를 검증한다."""

    tokens = [line.strip() for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
    if len(tokens) < expected:
        raise ValueError(f"토큰이 {expected}개 필요하지만 {len(tokens)}개만 있습니다.")
    return tokens[:expected]


async def _join_queue(client: httpx.AsyncClient, token: str, index: int) -> dict[str, Any]:
    """필요 변수: HTTP 클라이언트·JWT·사용자 순번. 같은 멱등키로 전송 오류만 재시도하며 큐에 참가한다."""

    idempotency_key = f"load-join-{index}-{uuid.uuid4().hex}"
    for attempt in range(LOAD_TRANSPORT_RETRIES):
        try:
            response = await client.post(
                "/arena/queue/join",
                headers={"Authorization": f"Bearer {token}"},
                json={"queue_type": "duel_ox", "idempotency_key": idempotency_key},
            )
            response.raise_for_status()
            return response.json()
        except httpx.TransportError:
            if attempt + 1 >= LOAD_TRANSPORT_RETRIES:
                raise
            await asyncio.sleep(0.25 * (attempt + 1))
    raise RuntimeError("큐 참가 전송 재시도 상태가 올바르지 않습니다.")


async def _active_match(client: httpx.AsyncClient, token: str) -> str:
    """필요 변수: HTTP 클라이언트와 JWT. 일시 전송 오류를 건너뛰며 캐시 없는 요약 API를 조회한다."""

    deadline = time.monotonic() + LOAD_HTTP_TIMEOUT_SECONDS
    while time.monotonic() < deadline:
        try:
            response = await client.get(
                "/arena/summary",
                headers={"Authorization": f"Bearer {token}"},
                params={"load_nonce": uuid.uuid4().hex},
            )
        except httpx.TransportError:
            await asyncio.sleep(0.25)
            continue
        response.raise_for_status()
        match_id = response.json().get("active_match_id")
        if match_id:
            return str(match_id)
        await asyncio.sleep(0.2)
    raise TimeoutError(f"{LOAD_HTTP_TIMEOUT_SECONDS}초 안에 매칭이 성립하지 않았습니다.")


async def _socket_worker(
    ws_base: str,
    token: str,
    match_id: str,
    index: int,
    ready: asyncio.Barrier,
) -> tuple[str, int, int]:
    """필요 변수: WS 주소·JWT·경기·순번·2,000 연결 장벽. 동일 답안을 두 번 보내 멱등 시도 횟수를 비교한다."""

    uri = f"{ws_base}/ws/arena?token={token}&match_id={match_id}"
    async with websockets.connect(
        uri,
        open_timeout=LOAD_WEBSOCKET_TIMEOUT_SECONDS,
        ping_interval=20,
        max_size=2**20,
    ) as socket:
        await ready.wait()
        question_id = ""
        while not question_id:
            event = json.loads(
                await asyncio.wait_for(socket.recv(), timeout=LOAD_WEBSOCKET_TIMEOUT_SECONDS)
            )
            if event.get("type") == "match_state":
                questions = event.get("data", {}).get("questions", [])
                if questions:
                    question_id = str(questions[0]["id"])
        key = f"load-answer-{index}-{uuid.uuid4().hex}"
        payload = {
            "type": "submit_answer",
            "question_id": question_id,
            "answer": "",
            "idempotency_key": key,
        }
        await socket.send(json.dumps(payload, ensure_ascii=False))
        first = await _next_answer_result(socket)
        await socket.send(json.dumps(payload, ensure_ascii=False))
        second = await _next_answer_result(socket)
        return match_id, int(first["attempts_used"]), int(second["attempts_used"])


async def _next_answer_result(socket: Any) -> dict[str, Any]:
    """필요 변수: 열린 WebSocket. 상태 이벤트를 건너뛰고 다음 답안 결과만 반환한다."""

    while True:
        event = json.loads(
            await asyncio.wait_for(socket.recv(), timeout=LOAD_WEBSOCKET_TIMEOUT_SECONDS)
        )
        if event.get("type") == "answer_result":
            return dict(event["data"])
        if event.get("type") == "error":
            raise RuntimeError(str(event.get("message")))


async def run(base_url: str, tokens_path: Path, connections: int) -> None:
    """필요 변수: API 주소·토큰 파일·연결 수. 큐 참가부터 동시 WS·멱등 제출·중복 매치까지 한 번에 검증한다."""

    tokens = _load_tokens(tokens_path, connections)
    limits = httpx.Limits(max_connections=connections + 100, max_keepalive_connections=200)
    timeout = httpx.Timeout(LOAD_HTTP_TIMEOUT_SECONDS)
    async with httpx.AsyncClient(base_url=base_url, limits=limits, timeout=timeout) as client:
        await asyncio.gather(*(_join_queue(client, token, index) for index, token in enumerate(tokens)))
        match_ids = await asyncio.gather(*(_active_match(client, token) for token in tokens))
    counts = Counter(match_ids)
    invalid = {match_id: count for match_id, count in counts.items() if count != 2}
    if invalid or len(counts) != connections // 2:
        raise AssertionError(f"중복 또는 유실 매치: matches={len(counts)}, invalid={invalid}")

    ws_base = base_url.replace("https://", "wss://").replace("http://", "ws://").rstrip("/")
    barrier = asyncio.Barrier(connections)
    results = await asyncio.gather(
        *(
            _socket_worker(ws_base, token, match_id, index, barrier)
            for index, (token, match_id) in enumerate(zip(tokens, match_ids))
        )
    )
    mismatches = [result for result in results if result[1] != result[2]]
    if mismatches:
        raise AssertionError(f"멱등 답안 상태 유실: {mismatches[:10]}")
    print(
        json.dumps(
            {
                "connections": connections,
                "matches": len(counts),
                "duplicate_matches": 0,
                "idempotency_mismatches": 0,
            },
            ensure_ascii=False,
        )
    )


def main() -> None:
    """필요 변수: CLI API 주소·UTF-8 토큰 파일·연결 수. 비동기 부하 검증을 실행한다."""

    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", required=True)
    parser.add_argument("--tokens", type=Path, required=True)
    parser.add_argument("--connections", type=int, default=2000)
    args = parser.parse_args()
    if args.connections < 2 or args.connections % 2:
        raise ValueError("1v1 검증 연결 수는 2 이상의 짝수여야 합니다.")
    asyncio.run(run(args.base_url.rstrip("/"), args.tokens, args.connections))


if __name__ == "__main__":
    main()
