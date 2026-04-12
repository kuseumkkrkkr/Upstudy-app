# s11

Flutter í´ë¼ì´ì–¸íŠ¸ì™€ ë¡œì»¬ Python(FastAPI) ë°±ì—”ë“œê°€ ì—°ë™ë˜ëŠ” í”„ë¡œì íŠ¸ì…ë‹ˆë‹¤.

## ì‹¤í–‰/í™˜ê²½ ë³€ìˆ˜
- API ì„œë²„ ì£¼ì†Œ: `API_BASE_URL` (ê¸°ë³¸ê°’ `http://localhost:8000`)
  ```bash
  flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
  ```
- ë¡œê·¸ì¸/íšŒì›ê°€ì… ê²½ë¡œ(í•„ìš” ì‹œ ì„œë²„ ìŠ¤í™ì— ë§ê²Œ ì¬ì •ì˜):
  - `API_LOGIN_PATH` (ê¸°ë³¸ `/auth/login`)
  - `API_REGISTER_PATH` (ê¸°ë³¸ `/auth/register`)
  ```bash
  flutter run -d chrome \
    --dart-define=API_BASE_URL=http://localhost:8000 \
    --dart-define=API_LOGIN_PATH=/login \
    --dart-define=API_REGISTER_PATH=/signup
  ```

## ì¸ì¦ íë¦„ ìš”ì•½
1) `LandingPage` â†’ ë¡œê·¸ì¸ ë²„íŠ¼ â†’ `LoginPage`.
2) ë¡œê·¸ì¸ ì„±ê³µ ì‹œ í† í°ì„ `ApiClient`ì— ì €ì¥í•˜ê³  `BuildboxCopyWidget`(í•™ìƒ ëŒ€ì‹œë³´ë“œ)ë¡œ ì´ë™.
3) ë¡œê·¸ì¸ í™”ë©´ì—ì„œ â€œíšŒì›ê°€ì…â€ì„ ì„ íƒí•˜ë©´ `SignupPage`ë¡œ ì´ë™, ê°€ì… í›„ ë™ì¼í•˜ê²Œ ëŒ€ì‹œë³´ë“œë¡œ ì§„ì….

## ê°œë°œ ë…¸íŠ¸
- `lib/services/auth_service.dart`ì—ì„œ ë¡œê·¸ì¸/íšŒì›ê°€ì… ìš”ì²­ì„ ë‹´ë‹¹í•˜ë©°, ìœ„ì˜ dart-define ê°’ìœ¼ë¡œ ê²½ë¡œë¥¼ ì£¼ì…í•  ìˆ˜ ìˆìŠµë‹ˆë‹¤.
- ê¸°ë³¸ ê²½ë¡œë¡œ 404ê°€ ë‚œë‹¤ë©´ ì„œë²„ ìŠ¤í™ì— ë§ì¶° `API_LOGIN_PATH`, `API_REGISTER_PATH`ë¥¼ ì§€ì •í•´ ì£¼ì„¸ìš”.
## µ¥ÀÌÅÍ ÀúÀå À§Ä¡
- ¼­¹ö(FastAPI, omj): `omj/quests.db` (SQLite). Äù½ºÆ® º»¹®/ÇØ¼³ `quest_header/info/data/solve_step`, ¸ğÀÇ°í»ç `exam/exam_item`, »ç¿ëÀÚ/·Î±×ÀÎ `users`, ³­ÀÌµµ/Á¤´ä·ü `rating_*`, Ä£±¸/DM `friend_requests`, `friends`, `messages`, »ç¿ëÀÚº° Å°°ª `user_kv`, Ãë¾à ÅÂ±× `weakness_tags` µîÀ» º¸°ü.
- ±³Àç Àü¿ë DB: `omj/textbook.db` (SQLite). »ç¿ëÀÚ Ä¿½ºÅÒ/°ø¿ë ±³ÀçÀÇ ¸ŞÅ¸, Ã©ÅÍ, ¼½¼Ç, ÀÌ¹ÌÁö °æ·Î¸¦ JSONÀ¸·Î ÀúÀå.
- ÄÚµåº£ÀÌ½º/½Ãµå Ä³½Ã: `omj/codebases.db` (`generater/codebase_store.py`), È¯°æ º¯¼ö `CODEBASE_DB_PATH`·Î °æ·Î ÀçÁöÁ¤ °¡´É.
- ¾÷·Îµå ÀÌ¹ÌÁö: `/analysis/ocr`¡¤`/analysis/solve` ¿äÃ»¿¡ Æ÷ÇÔµÈ ÇĞ»ı Ç®ÀÌ/È÷Æ®¸Ê ÀÌ¹ÌÁö´Â `omj/assets/solve_images/*.png`¿¡ ÆÄÀÏ·Î ³²À½.
- ·ÎÄÃ ¾Û(¸ğ¹ÙÀÏ/µ¥½ºÅ©Åé): `s11_local.db`(sqflite, Å×ÀÌºí `kv_store`)¿¡ JSON ¹®ÀÚ¿­À» key-value·Î ÀúÀå. `activity_store`, `attendance_store`, `bookmark_store`, `exam_paper_store`, `book_page`, `notepad_page` µîÀÌ »ç¿ëÀÚº° ½ºÄÚÇÁ Å°(`*_v1` È¤Àº `*_v1::<username>`)·Î ÀĞ°í ¾¸.
- À¥ ºôµå: `local_db_web.dart`°¡ API `/user/storage`¸¦ ÅëÇØ ¼­¹öÀÇ `user_kv` Å×ÀÌºíÀ» ¿ø°İ key-value ÀúÀå¼Ò·Î »ç¿ë.
Release build: run flutter build <target> --dart-define=API_BASE_URL=https://<prod-host> (required to avoid localhost).
