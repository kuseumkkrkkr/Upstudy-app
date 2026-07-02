from paddleocr import PaddleOCR, draw_ocr

# OCR 모델 초기화 (한글 지원 설정)
# 처음 실행 시 모델 파일(약 수십MB)을 자동으로 다운로드합니다.
ocr = PaddleOCR(use_angle_cls=True, lang='korean') 

img_path = 'your_image.jpg' # 인식할 이미지 경로

# OCR 실행
result = ocr.ocr(img_path, cls=True)

# 결과 출력
for idx in range(len(result)):
    res = result[idx]
    for line in res:
        print(line)