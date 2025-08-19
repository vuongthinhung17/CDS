from flask import Flask, render_template, request, redirect, url_for
import google.generativeai as genai
from dotenv import load_dotenv
import os

app = Flask(__name__)

# Lưu hội thoại
messages = [
    {"sender": "bot", "text": "Xin chào! Tôi là Travel Chatbot 🌍. Bạn muốn tìm combo du lịch như thế nào?"}
]

# Nạp biến môi trường từ file .env
load_dotenv()
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")

# Cấu hình SDK và khởi tạo model (thay cho Client cũ)
genai.configure(api_key=GEMINI_API_KEY)
model = genai.GenerativeModel(
    model_name="gemini-2.0-flash",
    system_instruction=(
        "Bạn là chatbot du lịch, chuyên gợi ý combo theo ngân sách, sở thích và thời gian.\n"
        "BẮT BUỘC ĐỊNH DẠNG CÂU TRẢ LỜI NHƯ SAU (giữ nguyên tiêu đề và thứ tự):\n"
        "Phần 1: Tóm tắt nhanh (1–2 câu)\n"
        "- Điểm đến, thời lượng, số người, ngân sách.\n\n"
        "Phần 2: Lịch trình chi tiết\n"
        "- Ngày 1:\n"
        "  - Buổi sáng:\n"
        "  - Buổi chiều:\n"
        "  - Buổi tối:\n"
        "- Ngày 2:\n"
        "  - Buổi sáng:\n"
        "  - Buổi chiều:\n\n"
        "Phần 3: Khách sạn/Resort (3 gợi ý)\n"
        "- Tên – mô tả ngắn – khoảng giá/đêm.\n\n"
        "Phần 4: Di chuyển\n"
        "- Máy bay/xe – giá ước tính – mẹo đặt sớm.\n\n"
        "Phần 5: Ăn uống & trải nghiệm nổi bật (3–5 gợi ý)\n"
        "- Tên – mô tả ngắn – chi phí ước tính.\n\n"
        "Phần 6: Ước tính chi phí (gạch đầu dòng)\n"
        "- Vé máy bay (2 người): ...\n"
        "- Khách sạn (1 đêm): ...\n"
        "- Ăn uống: ...\n"
        "- Di chuyển nội thành: ...\n"
        "- Tham quan: ...\n"
        "- Tổng cộng: ...\n\n"
        "Phần 7: Lưu ý & mẹo tiết kiệm\n"
        "- 2–4 dòng ngắn.\n\n"
        "QUY TẮC:\n"
        "- Dùng xuống dòng và gạch đầu dòng như mẫu, không viết dồn 1 đoạn dài.\n"
        "- Không dùng bảng phức tạp; chỉ tiêu đề 'Phần X' + gạch đầu dòng.\n"
        "- Ước tính chi phí theo VND, ghi rõ phạm vi (ví dụ: 1–2 triệu).\n"
    )
)

@app.route("/", methods=["GET", "POST"])
def index():
    global messages
    if request.method == "POST":
        user_input = request.form.get("user_input")
        if user_input:
            messages.append({"sender": "user", "text": user_input})
            bot_reply = call_ai(user_input)
            messages.append({"sender": "bot", "text": bot_reply})
        return redirect(url_for("index"))
    return render_template("index.html", messages=messages)

def call_ai(user_input):
    try:
        response = model.generate_content(user_input)
        text = (getattr(response, "text", "") or "").strip()
        # Nắn nhẹ nếu model quên tiêu đề
        if text and not text.startswith("Phần 1:"):
            text = "Phần 1: Tóm tắt nhanh\n" + text
        return text if text else "Xin lỗi, mình chưa thể trả lời câu này."
    except Exception as e:
        return f"❌ Lỗi khi gọi API: {e}"

if __name__ == "__main__":
    app.run(debug=True)
