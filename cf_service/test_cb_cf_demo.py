"""
test_cb_cf_demo.py
Gọi thẳng cf_service (http://localhost:8000) qua HTTP, KHÔNG qua Flutter/Edge Function,
để so sánh nhanh hiệu quả CB (tag_match) và CF (cf_score) giữa 4 mock user.

Yêu cầu:
  pip install requests
  uvicorn phải đang chạy local: cd cf_service && uvicorn main:app --port 8000

Trước khi chạy:
  1. Đã seed đủ 4 user theo các bước trước (demo.culture, demo.culture.heavy,
     demo.nature, control.blank).
  2. Đã trigger lại /admin/cf/retrain SAU KHI seed xong (cf_score_cache không
     tự cập nhật).
"""

import requests

BASE_URL = "http://localhost:8000"

# id_province = Hồ Chí Minh (xác nhận qua bảng `province`, không phải `city_province`)
ID_PROVINCE_HCM = "230e26ed-0118-4f62-96b5-ac0eb3ca1c1b"

# id_trip_interest_option của 'culture_history' — LƯU Ý: đây phải là UUID
# (id_trip_interest_option), KHÔNG phải option_code string 'culture_history'.
# fetch_trip_interest_options_by_ids() query thẳng theo id_trip_interest_option.
INTEREST_CULTURE_HISTORY = "24e0f953-f3aa-4b69-9e91-2b3724c086d3"

USERS = {
    "control.blank":      "dd16ba71-c26b-44dd-a3f4-61973f268822",
    "demo.culture":       "c76c6210-49e2-4c1a-8509-cd74e8735c9a",
    "demo.culture.heavy": "0a3fce5a-50b2-446d-807e-6e68a9f577a7",
    "demo.nature":        "754216fd-5109-40aa-9339-be9a738d262c",
}

# 3 place mục tiêu để so sánh:
#   - Tượng Chúa Kitô Vua / Di Tích Sở Cò: seed ở CẢ demo.culture (vừa phải)
#     VÀ demo.culture.heavy (mạnh) — dùng để đo độ nhạy CF.
#   - Nhà Tù Côn Đảo: chỉ seed ở demo.culture, KHÔNG seed ở demo.culture.heavy
#     — dùng làm đối chứng nội bộ trong nhóm culture.
TARGET_PLACES = {
    "1fcd3233-4a50-5ed4-9dc4-584250a884fa": "Tượng Chúa Kitô Vua",
    "86db10ef-d268-5e8e-98c1-a1d4f4db81bc": "Di Tích Sở Cò",
    "1fc60e41-c12b-5866-8872-34720db30cff": "Nhà Tù Côn Đảo",
}


def call_plan_trip(id_user: str) -> dict:
    payload = {
        "id_user": id_user,
        "id_province": ID_PROVINCE_HCM,
        "n_days": 2,
        "sa_runs": 5,
        "save_plan": False,
        "interest_option_ids": [INTEREST_CULTURE_HISTORY],
    }
    resp = requests.post(f"{BASE_URL}/api/trips/plan", json=payload, timeout=60)
    resp.raise_for_status()
    return resp.json()


def extract_target_place_results(response: dict) -> dict:
    """Tìm 3 target place trong response['days'][*]['places'].

    LƯU Ý: response chỉ chứa place ĐÃ LỌT vào lịch trình cuối cùng (sau
    diversity selection + Module 2 + Module 3 SA). Nếu 1 place không xuất
    hiện, script KHÔNG thể phân biệt "không phải candidate ngay từ đầu" vs
    "là candidate nhưng bị loại ở bước sau" — endpoint HTTP này không expose
    danh sách candidate đầy đủ kèm score.
    """
    found = {pid: None for pid in TARGET_PLACES}
    for day in response.get("days", []):
        for place in day.get("places", []):
            pid = place.get("id_place")
            if pid in found:
                found[pid] = {
                    "day": day.get("day"),
                    "order": place.get("order"),
                    "tag_match": place.get("tag_match"),
                    "cf_score": place.get("cf_score"),
                    "final_score": place.get("final_score"),
                }
    return found


def fmt(v, width=8, digits=4):
    if v is None:
        return "—".rjust(width)
    return f"{v:.{digits}f}".rjust(width)


def main():
    results = {}  # label -> {place_id: {...} or None}

    for label, uid in USERS.items():
        if uid == "PASTE-UUID-HERE":
            print(f"[SKIP] {label}: chưa điền UUID thật, sửa USERS ở đầu file.")
            continue
        print(f"\n>>> Calling planTrip for {label} ({uid}) ...")
        try:
            resp = call_plan_trip(uid)
        except Exception as e:
            print(f"    ERROR: {e}")
            continue
        results[label] = extract_target_place_results(resp)

    if not results:
        print("\nKhông có user nào gọi thành công — kiểm tra lại UUID / uvicorn có đang chạy không.")
        return

    # ── Bảng so sánh ──────────────────────────────────────────────────────────
    print("\n" + "=" * 100)
    print("BẢNG SO SÁNH — tag_match / cf_score / final_score theo place, theo user")
    print("=" * 100)

    for pid, pname in TARGET_PLACES.items():
        print(f"\nPlace: {pname}  ({pid})")
        print(f"  {'user':<22s} {'in_trip':<8s} {'tag_match':>10s} {'cf_score':>10s} {'final_score':>12s}")
        for label in USERS:
            if label not in results:
                continue
            r = results[label].get(pid)
            if r is None:
                print(f"  {label:<22s} {'NO':<8s} {'—':>10s} {'—':>10s} {'—':>12s}")
            else:
                print(
                    f"  {label:<22s} {'YES':<8s} "
                    f"{fmt(r['tag_match'], 10)} {fmt(r['cf_score'], 10)} {fmt(r['final_score'], 12)}"
                )

    # ── Bước 3: tự đánh giá + cảnh báo ─────────────────────────────────────────
    print("\n" + "=" * 100)
    print("ĐÁNH GIÁ TỰ ĐỘNG")
    print("=" * 100)

    warnings = []

    def cf_score_for(label, pid):
        r = results.get(label, {}).get(pid)
        return r["cf_score"] if r else None

    def tag_match_for(label, pid):
        r = results.get(label, {}).get(pid)
        return r["tag_match"] if r else None

    # 3a. control.blank phải ~0
    if "control.blank" in results:
        blank_scores = [
            cf_score_for("control.blank", pid)
            for pid in TARGET_PLACES
            if cf_score_for("control.blank", pid) is not None
        ]
        if blank_scores:
            max_blank = max(blank_scores)
            if max_blank > 0.05:
                warnings.append(
                    f"[CẢNH BÁO] control.blank có cf_score = {max_blank:.4f} (> 0.05, "
                    "không xấp xỉ 0) — nghi ngờ baseline sai. Kiểm tra lại: user này có "
                    "vô tình bị seed dữ liệu gì không, hoặc cf_score_cache đang trả giá trị "
                    "mặc định/nhiễu thay vì 0."
                )
        else:
            warnings.append(
                "[LƯU Ý] control.blank không xuất hiện ở place nào trong trip cuối "
                "— không đủ dữ liệu để đánh giá baseline cf_score."
            )

    # 3b. demo.culture.heavy phải cao hơn rõ rệt demo.culture (>= 1.5-2x) trên 2 place đã seed
    heavy_places = ["1fcd3233-4a50-5ed4-9dc4-584250a884fa", "86db10ef-d268-5e8e-98c1-a1d4f4db81bc"]
    for pid in heavy_places:
        pname = TARGET_PLACES[pid]
        cf_normal = cf_score_for("demo.culture", pid)
        cf_heavy = cf_score_for("demo.culture.heavy", pid)
        if cf_normal is None or cf_heavy is None:
            warnings.append(
                f"[LƯU Ý] Không đủ dữ liệu so sánh cf_score cho '{pname}' "
                f"(demo.culture={cf_normal}, demo.culture.heavy={cf_heavy})."
            )
            continue
        if cf_normal <= 0:
            warnings.append(
                f"[LƯU Ý] '{pname}': cf_score demo.culture = 0, không tính được tỉ lệ. "
                "Có thể do chưa trigger /admin/cf/retrain sau seed."
            )
            continue
        ratio = cf_heavy / cf_normal
        if ratio < 1.5:
            warnings.append(
                f"[CẢNH BÁO] '{pname}': cf_score demo.culture.heavy ({cf_heavy:.4f}) chỉ gấp "
                f"{ratio:.2f}x demo.culture ({cf_normal:.4f}) — CHƯA đủ rõ rệt (kỳ vọng >=1.5-2x). "
                "Đề xuất: (1) trigger lại POST /admin/cf/retrain nếu chưa làm sau seed, hoặc "
                "(2) nếu đã retrain rồi mà vẫn thấp, cần seed thêm — thử tăng số plan lặp từ 5 "
                "lên 8-10, hoặc thêm view_detail/view_thumbnail event trực tiếp vào user_event_log "
                "cho 2 place này để tăng trọng số trong ma trận CF."
            )
        else:
            print(f"[OK] '{pname}': cf_score heavy gấp {ratio:.2f}x demo.culture — đạt kỳ vọng.")

    # 3c. tag_match demo.culture vs demo.nature (cùng chọn culture_history) phải TƯƠNG ĐƯƠNG
    for pid, pname in TARGET_PLACES.items():
        tm_culture = tag_match_for("demo.culture", pid)
        tm_nature = tag_match_for("demo.nature", pid)
        if tm_culture is None or tm_nature is None:
            continue  # 1 trong 2 user không có place này trong trip, bỏ qua so sánh
        diff = abs(tm_culture - tm_nature)
        if diff > 0.02:  # dung sai nhỏ cho làm tròn/nhiễu tính toán
            warnings.append(
                f"[CẢNH BÁO] '{pname}': tag_match demo.culture ({tm_culture:.4f}) khác "
                f"demo.nature ({tm_nature:.4f}) dù CẢ HAI đều chọn interest_option_ids="
                f"culture_history (chênh {diff:.4f}). tag_match không nên phụ thuộc lịch sử "
                "user (favorite/review/plan) — chỉ nên phụ thuộc interest đã chọn cho trip này "
                "+ tag của place. Nghi ngờ CB đang lẫn tín hiệu hành vi (behavior_weight/"
                "final_weight từ user_interest_tag) vào tag_match theo cách không mong muốn — "
                "cần audit lại rank_places_by_tag_match()/build_effective_interest_state()."
            )
        else:
            print(f"[OK] '{pname}': tag_match demo.culture ≈ demo.nature ({diff:.4f} chênh lệch) — CB nhất quán.")

    print()
    if warnings:
        print(f"── {len(warnings)} CẢNH BÁO ──")
        for w in warnings:
            print(w)
            print()
    else:
        print("Không có cảnh báo — CB/CF hoạt động đúng kỳ vọng trên 4 user demo.")


if __name__ == "__main__":
    main()
