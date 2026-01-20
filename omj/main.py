import json

from generater import make
from generater.fix_gen import get_main_grade
from storage.storage import store_data


def _prompt_int(message: str, *, min_value: int | None = None, allowed: set[int] | None = None) -> int:
    while True:
        raw = input(message).strip()
        try:
            value = int(raw)
        except ValueError:
            print("정수를 입력하세요.")
            continue

        if allowed is not None and value not in allowed:
            allowed_values = ", ".join(str(v) for v in sorted(allowed))
            print(f"{allowed_values} 중 하나를 입력하세요.")
            continue

        if min_value is not None and value < min_value:
            print(f"{min_value} 이상의 값을 입력하세요.")
            continue

        return value


if __name__ == "__main__":
    try:
        while True:
            raw_tags = input("해시태그 입력 (쉼표 구분): ").strip()
            hash_tags = [tag.strip() for tag in raw_tags.split(",") if tag.strip()]
            try:
                get_main_grade(hash_tags)
            except ValueError:
                print("허용되지 않는 태그가 포함되었습니다. 다시 입력하세요.")
                continue
            break

        solves_count = _prompt_int("루트 flow 개수(solves_count): ", min_value=1)

        strategy_level = _prompt_int(
            "전략 수립 난이도 (1=쉬움, 2=중간, 3=어려움): ",
            allowed={1, 2, 3},
        )

        branch_conditions = _prompt_int("분기할 조건/레인 수 (없으면 0): ", min_value=0)

        reference_quest_id = input("참고할 기존 문제 ID (없으면 엔터): ").strip() or None

        # 1. Generate problem and assemble storage data
        final_data = make(
            hash_tags,
            solves_count,
            strategy_level,
            branch_conditions,
            reference_quest_id,
        )
        print("Generated data:")
        print(json.dumps(final_data, indent=2, ensure_ascii=False))

        # 2. Store data in database
        print("\nSaving to database...")
        success = store_data(final_data)

        if success:
            print(f"\nDone! Quest ID: {final_data['header']['quest_id']}")
        else:
            print("\nSave failed")

    except Exception as e:
        print(f"Error: {e}")
        import traceback

        traceback.print_exc()
