"""배포 이미지 생성 단계에서 고정 TexTeller 파일만 Hugging Face 캐시에 준비한다."""

import sys
from pathlib import Path

from huggingface_hub import hf_hub_download

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from services.ocr.texteller_grid import _TexTellerRuntime


MODEL_FILES = (
    "config.json",
    "generation_config.json",
    "model.safetensors",
    "tokenizer.json",
    "tokenizer_config.json",
    "special_tokens_map.json",
    "added_tokens.json",
    "vocab.json",
    "merges.txt",
)


def main() -> None:
    """필요 변수: 배포 단계의 네트워크·HF_HOME. 작동 원리: 검증 revision의 추론 필수 파일만 받아 런타임 외부 의존을 없앤다."""
    for filename in MODEL_FILES:
        hf_hub_download(
            repo_id=_TexTellerRuntime.MODEL_ID,
            filename=filename,
            revision=_TexTellerRuntime.MODEL_REVISION,
        )
        print(f"prepared {filename}")


if __name__ == "__main__":
    main()
