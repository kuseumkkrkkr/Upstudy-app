import tkinter as tk
import torch
import torch.nn as nn
import os
import time

# ---------------------------
# 1. LSTM 글자 인식 모델 정의
# ---------------------------
class LetterRNN(nn.Module):
    def __init__(self, input_size=4, hidden_size=128, output_size=26):
        super().__init__()
        self.lstm = nn.LSTM(input_size, hidden_size, batch_first=True)
        self.fc = nn.Linear(hidden_size, output_size)

    def forward(self, x):
        _, (h_n, _) = self.lstm(x)
        out = self.fc(h_n[-1])
        return out

# 레이블 매핑
labels_map = {chr(i+65): i for i in range(26)}
labels_map_rev = {v: k for k, v in labels_map.items()}

# ---------------------------
# 2. 철자 모드 앱
# ---------------------------
class SpellingApp:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("철자 인식 모드")

        # 캔버스
        self.canvas = tk.Canvas(self.root, width=400, height=400, bg="white")
        self.canvas.grid(row=0, column=0, columnspan=3)

        # 텍스트 출력
        self.text_output = tk.Text(self.root, height=10, width=50)
        self.text_output.grid(row=1, column=0, columnspan=3)

        # 버튼
        self.clear_btn = tk.Button(self.root, text="삭제", command=self.clear_canvas)
        self.clear_btn.grid(row=2, column=0, sticky="we")
        self.recognize_btn = tk.Button(self.root, text="인식", command=self.recognize_current)
        self.recognize_btn.grid(row=2, column=1, sticky="we")
        self.quit_btn = tk.Button(self.root, text="종료", command=self.root.quit)
        self.quit_btn.grid(row=2, column=2, sticky="we")

        # 그리기 상태
        self.drawing = False
        self.current_stroke = []
        self.start_time = None

        # 모델 불러오기
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        self.model = LetterRNN().to(self.device)
        script_dir = os.path.dirname(os.path.abspath(__file__))
        model_path = os.path.join(script_dir, "letter_rnn_model_v5.pth")
        state = torch.load(model_path, map_location=self.device)
        self.model.load_state_dict(state)
        self.model.eval()

        # 이벤트 바인딩
        self.canvas.bind("<ButtonPress-1>", self.pen_down)
        self.canvas.bind("<B1-Motion>", self.pen_move)
        self.canvas.bind("<ButtonRelease-1>", self.pen_up)

    # ---------------------------
    # 펜 이벤트
    def pen_down(self, event):
        self.drawing = True
        self.current_stroke = []
        self.start_time = time.time()
        self.current_stroke.append({"x": event.x, "y": event.y, "t": 0, "p": 1})

    def pen_move(self, event):
        if self.drawing:
            t = time.time() - self.start_time
            self.current_stroke.append({"x": event.x, "y": event.y, "t": t, "p": 1})
            self.canvas.create_line(
                self.current_stroke[-2]["x"], self.current_stroke[-2]["y"],
                event.x, event.y, fill="black", width=3
            )

    def pen_up(self, event):
        if self.drawing:
            t = time.time() - self.start_time
            self.current_stroke.append({"x": event.x, "y": event.y, "t": t, "p": 0})
            self.drawing = False

    # ---------------------------
    # 인식 버튼 클릭
    def recognize_current(self):
        if not self.current_stroke:
            return
        probs, pred_char = self.recognize_letter(self.current_stroke)
        self.show_probs(probs, pred_char)

    # ---------------------------
    # 글자 인식
    def recognize_letter(self, stroke):
        seq = []
        for point in stroke:
            x = point["x"] / 400
            y = point["y"] / 400
            t = point["t"]
            p = point["p"]
            seq.append([x, y, t, p])
        seq_tensor = torch.tensor([seq], dtype=torch.float32).to(self.device)
        with torch.no_grad():
            logits = self.model(seq_tensor)
            probs = torch.softmax(logits, dim=1).squeeze().cpu().numpy()
            pred_idx = probs.argmax()
        pred_char = labels_map_rev[pred_idx]
        return probs, pred_char

    # ---------------------------
    # 확률 출력
    def show_probs(self, probs, pred_char):
        self.text_output.delete(1.0, tk.END)
        self.text_output.insert(tk.END, f"인식 글자: {pred_char}\n\n")
        for i, p in enumerate(probs):
            self.text_output.insert(tk.END, f"{labels_map_rev[i]}: {p:.2f}\n")

    # ---------------------------
    # 삭제 버튼
    def clear_canvas(self):
        self.canvas.delete("all")
        self.current_stroke = []
        self.text_output.delete(1.0, tk.END)

    # ---------------------------
    def run(self):
        self.root.mainloop()


# ---------------------------
# 3. 실행
if __name__ == "__main__":
    app = SpellingApp()
    app.run()
