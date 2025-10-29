# train_letter_model_v3.py
import os
import json
import torch
import torch.nn as nn
from torch.utils.data import Dataset, DataLoader
import random
import math

# ---------------------------
# 1. 데이터 증강 함수
# ---------------------------
def augment_sequence(seq, max_offset=0.01, scale=0.05, rotate=5, t_jitter=0.1):
    """좌표, 스케일, 회전, 시간 변형 적용"""
    angle = random.uniform(-rotate, rotate) * math.pi / 180
    cos_a, sin_a = math.cos(angle), math.sin(angle)
    scale_x, scale_y = 1 + random.uniform(-scale, scale), 1 + random.uniform(-scale, scale)
    seq_aug = []
    for x, y, t, p in seq:
        # 회전
        x_rot = x * cos_a - y * sin_a
        y_rot = x * sin_a + y * cos_a
        # 스케일 + 노이즈
        x_aug = x_rot * scale_x + random.uniform(-max_offset, max_offset)
        y_aug = y_rot * scale_y + random.uniform(-max_offset, max_offset)
        t_aug = t * (1 + random.uniform(-t_jitter, t_jitter))
        seq_aug.append([x_aug, y_aug, t_aug, p])
    return seq_aug

# ---------------------------
# 2. 데이터셋 정의
# ---------------------------
class HandwritingDataset(Dataset):
    def __init__(self, path, target_count=500):
        self.samples = []
        self.labels_map = {chr(i+65): i for i in range(26)}
        self.target_count = target_count

        # 1) 기존 데이터 읽기
        raw_samples = []
        if os.path.isfile(path):
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
            if isinstance(data, list):
                raw_samples.extend(data)
            elif isinstance(data, dict):
                raw_samples.append(data)
        else:
            for filename in os.listdir(path):
                if filename.endswith(".json"):
                    with open(os.path.join(path, filename), "r", encoding="utf-8") as f:
                        try:
                            data = json.load(f)
                        except Exception:
                            continue
                        if isinstance(data, list):
                            raw_samples.extend(data)
                        elif isinstance(data, dict):
                            raw_samples.append(data)

        # 2) 글자별 증강 & 균형
        letters_by_char = {chr(i+65): [] for i in range(26)}
        for sample in raw_samples:
            label = sample.get("label", "").upper()
            if label not in letters_by_char:
                continue
            strokes = sample.get("strokes", [])
            sequence = []
            for stroke in strokes:
                for p in stroke:
                    x = float(p.get("x", 0.0))/400.0
                    y = float(p.get("y", 0.0))/400.0
                    t = float(p.get("t",0.0))/1000.0
                    p_val = float(p.get("p",1.0))
                    sequence.append([x,y,t,p_val])
            if sequence:
                letters_by_char[label].append(sequence)

        # 3) 목표 개수까지 증강
        for char, seq_list in letters_by_char.items():
            current_count = len(seq_list)
            if current_count == 0:
                continue
            multiplier = math.ceil(target_count / current_count)
            for _ in range(multiplier):
                for seq in seq_list:
                    seq_aug = augment_sequence(seq)
                    self.samples.append((seq_aug, self.labels_map[char]))
                    if len([s for s in self.samples if s[1]==self.labels_map[char]]) >= target_count:
                        break
                if len([s for s in self.samples if s[1]==self.labels_map[char]]) >= target_count:
                    break

    def __len__(self):
        return len(self.samples)

    def __getitem__(self, idx):
        seq, label = self.samples[idx]
        seq_tensor = torch.tensor(seq, dtype=torch.float32)
        return seq_tensor, label

# ---------------------------
# 3. 모델 정의
# ---------------------------
class LetterRNN(nn.Module):
    def __init__(self, input_size=4, hidden_size=128, output_size=26):
        super().__init__()
        self.lstm = nn.LSTM(input_size, hidden_size, batch_first=True)
        self.fc = nn.Linear(hidden_size, output_size)
    def forward(self, x, lengths):
        packed = nn.utils.rnn.pack_padded_sequence(x, lengths.cpu(), batch_first=True, enforce_sorted=False)
        _, (h_n, _) = self.lstm(packed)  # h_n: [num_layers=1, batch, hidden]
        out = self.fc(h_n[-1])
        return out

# ---------------------------
# 4. DataLoader
# ---------------------------
dataset_path = "handwriting_data.json"
dataset = HandwritingDataset(dataset_path, target_count=500)

def collate_fn(batch):
    sequences = [item[0] for item in batch]
    lengths = torch.tensor([s.size(0) for s in sequences], dtype=torch.long)
    padded = nn.utils.rnn.pad_sequence(sequences, batch_first=True)
    labels = torch.tensor([item[1] for item in batch], dtype=torch.long)
    return padded, labels, lengths

dataloader = DataLoader(dataset, batch_size=16, shuffle=True, collate_fn=collate_fn)

# ---------------------------
# 5. 훈련 설정
# ---------------------------
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
model = LetterRNN().to(device)
criterion = nn.CrossEntropyLoss()
optimizer = torch.optim.Adam(model.parameters(), lr=0.001)
scheduler = torch.optim.lr_scheduler.StepLR(optimizer, step_size=10, gamma=0.7)
epochs = 50

# ---------------------------
# 6. 훈련 루프
# ---------------------------
for epoch in range(epochs):
    model.train()
    total_loss = 0.0
    for seq_batch, label_batch, lengths in dataloader:
        seq_batch, label_batch = seq_batch.to(device), label_batch.to(device)
        optimizer.zero_grad()
        outputs = model(seq_batch, lengths)
        loss = criterion(outputs, label_batch)
        loss.backward()
        optimizer.step()
        total_loss += loss.item()
    scheduler.step()
    avg_loss = total_loss / (len(dataloader) if len(dataloader) > 0 else 1)
    print(f"Epoch {epoch+1}/{epochs}, Loss: {avg_loss:.4f}")

# ---------------------------
# 7. 모델 저장
# ---------------------------
torch.save(model.state_dict(), "letter_rnn_model_v3.pth")
print("모델 저장 완료: letter_rnn_model_v3.pth")
