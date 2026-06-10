from google import genai
from google.genai import types
import pandas as pd
import json
import time

# 1. Cấu hình Client với thư viện MỚI (google-genai)
API_KEY = "AIzaSyAdhr8fDic1HyvTKlroWSJsWebONFCG_0g"
client = genai.Client(api_key=API_KEY)

# 2. Định nghĩa Prompt
def create_prompt(name, description):
    return f"""
    You are an expert travel and local data classifier for a Vietnamese tourism application. 
    Analyze the place's name and description, then categorize it into EXACTLY ONE of the predefined subcategories.

    Categories to choose from:
    - Sightseeing/Nature: "Biển & Đảo", "Núi rừng & Trekking", "Hồ & Sông", "Công viên & Vườn", "Thiên nhiên & Cảnh quan", "Bảo tàng & Nghệ thuật", "Di tích & Lịch sử", "Tâm linh & Tôn giáo", "Vui chơi giải trí", "Làng nghề & Trải nghiệm địa phương", "Phố đi bộ & Khu dạo chơi".
    - Food & Dining: "Nhà hàng / Fine Dining", "Quán ăn địa phương", "Ẩm thực đường phố", "Cà phê & Trà".

    Rules:
    - If it's a casual, budget-friendly local food spot, choose "Quán ăn địa phương".
    - If it's a formal dining establishment, choose "Nhà hàng / Fine Dining".
    - If it's a waterfall, mountain, or forest without explicit keywords, deduce context and choose "Núi rừng & Trekking" or "Thiên nhiên & Cảnh quan".
    - You must output ONLY a valid JSON object.

    Place Name: {name}
    Description: {description}

    JSON Output format:
    {{"subcategory": "exact_subcategory_name_from_list"}}
    """

# 3. Hàm gọi API
def classify_place(name, description):
    desc = description if pd.notna(description) else "Không có mô tả"
    prompt = create_prompt(name, desc)
    
    try:
        response = client.models.generate_content(
            model='gemini-2.5-flash', # Đã sửa thành bản mới nhất
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
            ),
        )
        result = json.loads(response.text)
        return result.get("subcategory", "Tham quan tổng hợp")
    except Exception as e:
        print(f"Lỗi khi xử lý {name}: {e}")
        return "Tham quan tổng hợp"

# 4. Quá trình xử lý file dữ liệu
print("Đang đọc dữ liệu...")
df = pd.read_csv("place_rows.csv")

# ĐÃ FIX: Sử dụng đúng UUID thật từ file CSV của anh/chị
# 87f29324... là ID cũ của "Tham quan"
# e142d2a4... là ID cũ của "Nhà hàng"
target_ids = [
    '87f29324-298f-4c18-a03c-6784c4ebc9a2', 
    'e142d2a4-43a9-4c94-99fd-094c193be2e3'
] 

df_to_process = df[df['id_place_subcategory'].isin(target_ids)].copy()

print(f"Bắt đầu phân loại {len(df_to_process)} địa điểm bằng Gemini...")

new_subcategories = []
for index, row in df_to_process.iterrows():
    print(f"Đang phân loại [{len(new_subcategories) + 1}/{len(df_to_process)}]: {row['name']}...")
    
    new_sub = classify_place(row['name'], row['description'])
    new_subcategories.append(new_sub)
    
    # Dừng 4 giây để không bị API chặn do vượt quá 15 request/phút (Free tier)
    time.sleep(4) 

df_to_process['new_subcategory_name'] = new_subcategories

# Lưu kết quả
df_to_process.to_csv("places_classified_by_gemini.csv", index=False, encoding='utf-8')
print("Hoàn tất! Đã lưu kết quả vào file places_classified_by_gemini.csv")