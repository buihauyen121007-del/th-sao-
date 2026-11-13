# TASK 2: GIẢI PHÁP TRIỂN KHAI AI AGENT & KẾT QUẢ TỰ KIỂM THỬ (ĐỀ 05)

## 1. Nền tảng, mô hình AI và công cụ triển khai

- **Nền tảng thực thi:** Hệ thống chạy trực tiếp trên Windows bằng **PowerShell 5.1 + .NET TCP Web Server (`src/WebServer.ps1`)** và **Web App HTML/CSS/JavaScript (`web/`)**, hoàn toàn không phụ thuộc cài đặt bên thứ ba (không cần Python/Node.js), mở thẳng qua `start_app.bat` hoặc chạy dòng lệnh `run_agent.ps1`.
- **Mô hình AI & Cơ chế phối hợp (Dual-Mode):**
  1. **Chế độ LLM Function Calling (Gemini API / OpenAI-Compatible API):** Khi cung cấp API Key, mô hình LLM đóng vai trò tác tử điều phối, nhận khai báo 7 công cụ chuẩn JSON Schema (`Get-AgentToolSchemas`), gọi tuần tự các công cụ đọc hồ sơ – đối chiếu – chấm điểm – soạn thảo, đồng thời tổng hợp lý giải bằng tiếng Việt.
  2. **Chế độ Hybrid Local Agent Orchestrator (Offline Fallback):** Đảm bảo chạy độc lập 100% khi không có mạng hoặc không có API Key trong buổi thi; sử dụng bộ trích xuất văn bản tiếng Việt từ mẫu cấu hình (`config/messages_vi.json`) kết hợp toàn bộ 7 công cụ nghiệp vụ xác định và guardrail hoàn chỉnh chuỗi kỹ năng.
- **Tính thích ứng khi giảng viên công bố cấu trúc dữ liệu & quy tắc mới:**
  - `config/rules_config.json`: Tham số hóa toàn bộ ngưỡng bảo hộ (bán kính km, bảo hộ Quận/Phường), hạn mức công nợ (`30 ngày`, `500 triệu`, `5%`, yêu cầu chứng minh tài chính `> 300 triệu`), điều kiện bắt buộc, trọng số 4 tiêu chí và ngưỡng điểm cắt (`75.0` / `50.0`).
  - `config/schema_mapping.json`: Ánh xạ linh hoạt tên trường (hỗ trợ đa biệt danh tiếng Anh & tiếng Việt cho JSON, CSV và TXT).
  - Giao diện Web có tab **Nạp dữ liệu thi & Quy tắc** cho phép nạp trực tiếp bộ file mới của giảng viên, ghi nhận **mã băm SHA-256** để chứng minh **không sửa dữ liệu test hay nhập tay kết luận**.

---

## 2. Thiết kế 3 kỹ năng nghiệp vụ phối hợp & 7 công cụ thực thi

Hệ thống triển khai **3 kỹ năng nghiệp vụ phối hợp chặt chẽ trong cùng một quy trình** (vượt yêu cầu tối thiểu 2 kỹ năng):

| Kỹ năng nghiệp vụ | Công cụ thực thi | Nhiệm vụ cụ thể & Bằng chứng truy vết |
|---|---|---|
| **Skill 1: `partner_identity_territory_screening`** *(Sàng lọc Danh tính, Địa bàn & Chính sách)* | 1. `tool_load_and_extract_dossier`<br>2. `tool_check_identity_and_territory`<br>3. `tool_check_mandatory_and_policy_gates` | - Đọc file văn bản hồ sơ (`dossiers/*.txt`) & JSON/CSV, giữ nguyên trích dẫn gốc (`evidence_quotes`), gắn kết quả xác minh từ `verification_results` và tách riêng trường bị thiếu (`missing_fields`).<br>- Đối chiếu MST, SĐT, Email, tên tương đồng (Levenshtein không dấu) với `existing_partners`; tính khoảng cách GPS Haversine (km) và đối chiếu Quận/Huyện/Phường với `existing_pos`.<br>- Kiểm tra điều kiện bắt buộc, chính sách công nợ/hỗ trợ và tách bạch **cam kết tự khai** vs **bằng chứng đã xác minh**. |
| **Skill 2: `partner_scoring_priority_and_escalation`** *(Đánh giá Tiêu chí, Xếp ưu tiên & Định tuyến Thẩm quyền)* | 4. `tool_evaluate_criteria_and_priority`<br>5. `tool_determine_escalation_and_recommendation` | - Chấm điểm 4 tiêu chí (100 điểm): Điểm bán (25), Bảo hành (30), Kế hoạch nhập hàng (20), Tài chính & Công nợ (25). Tính đồng thời **Điểm tự khai** và **Điểm thực chứng** (áp dụng `unverified_cap_ratio` khi chưa xác minh độc lập).<br>- Xếp mức ưu tiên (`P1`, `P2`, `P3`, `HOLD`, `REJECT`), phân loại đề xuất (`Tiếp tục`, `Bổ sung`, `Chưa tiếp tục làm việc`), sinh danh sách việc cần xác minh theo từng bộ phận và kích hoạt cờ chuyển thẩm quyền (`IDENTITY_DUPLICATE`, `TERRITORY_CONFLICT`, `POLICY_EXCEEDED`, `MISSING_EVIDENCE`). |
| **Skill 3: `partner_reporting_coordination_and_drafting`** *(Tổng hợp Khu vực, Kế hoạch Xác minh & Soạn thảo)* | 6. `tool_draft_partner_communication`<br>7. `tool_generate_regional_summary_and_plan` | - Tạo **bản nháp trao đổi** riêng cho từng đối tác bám sát căn cứ, điều kiện chưa đạt và hạng mục cần xác minh.<br>- Tổng hợp **Bảng đề xuất đối tác theo 3 khu vực** (Miền Bắc, Miền Trung, Miền Nam), **Danh sách ngoại lệ chuyển cấp thẩm quyền**, và **Kế hoạch phối hợp xác minh** gửi Kinh doanh – Vận hành – Tài chính. |

---

## 3. Cơ chế lưu nhật ký truy vết (Audit Trail)

Mỗi lần chạy đều tự động lưu file `logs/<run_id>.jsonl` (JSON Lines), ghi nhận đầy đủ:
- `DATA_LOADED`: Đường dẫn bộ dữ liệu, chế độ chạy, số bản ghi và **mã băm SHA-256** của từng file dữ liệu đầu vào (`applicants`, `existing_partners`, `existing_pos`, `verification_results`, `rules_config`).
- `LLM_REQUEST` / `SKILL_STEP` / `TOOL_RESULT`: Thứ tự từng bước gọi kỹ năng (`skill_name`), tên công cụ (`tool_name`), mã hồ sơ (`applicant_id`), tham số gọi (`tool_args`), các quy tắc nghiệp vụ đã áp dụng (`rule_ids_applied`), nguồn tham chiếu (`evidence_refs`), kết quả tóm tắt (`result_summary`) và thời gian thực thi (`duration_ms`).

---

## 4. Kết quả chạy trên bộ dữ liệu mẫu 10 hồ sơ (`data/sample_exam_pack`)

Trên bộ dữ liệu mẫu 10 hồ sơ (phân bố tại 3 khu vực: 3 Miền Bắc, 3 Miền Trung, 4 Miền Nam), chạy bằng `.\run_agent.ps1 -Mode local` (`run_20261111_100807`) ghi nhận **123 sự kiện nhật ký**, xuất trọn bộ báo cáo (`ket_qua_danh_gia.json`, `bao_cao_tong_hop.md`, `bang_de_xuat_khu_vuc.csv`, `ke_hoach_xac_minh.csv`):

- **Tiếp tục (3 hồ sơ):**
  - `HS001` (Miền Bắc - Long Biên, Hà Nội): `98/100` (`P1 - Ưu tiên cao`), đủ bằng chứng Kinh doanh – Vận hành – Tài chính, cách điểm bán gần nhất `> 5 km`.
  - `HS005` (Miền Bắc - Lê Chân, Hải Phòng): `78/100` (`P2 - Ưu tiên trung bình`), nằm đúng ranh giới chính sách (30 ngày, 500 triệu, 5%, 1 KTV, ngoài bán kính bảo hộ).
  - `HS010` (Miền Nam - Biên Hòa, Đồng Nai): `100/100` (`P1 - Ưu tiên cao`).
- **Bổ sung / Chờ thẩm quyền (5 hồ sơ):**
  - `HS003` (Miền Trung - Hải Châu, Đà Nẵng): Năng lực tốt (`90/100`) nhưng **Xung đột địa bàn bảo hộ** (`1.751 km <= 5 km` và trùng Quận Hải Châu với `POS003`) -> `HOLD`, chuyển Trưởng phòng PTKD & Kinh doanh.
  - `HS004` (Miền Nam - Thủ Dầu Một, Bình Dương): **Bẫy cam kết cao** (`900 triệu/tháng`) nhưng 0 KTV bảo hành hiện hữu, chưa có xác minh thực địa/BCTC và đòi công nợ vượt chuẩn (45 ngày, 800 triệu, hỗ trợ 8%) -> Agent kìm điểm thực chứng xuống `24.9/100`, gắn cảnh báo không coi cam kết là bằng chứng, chuyển Vận hành & Tài chính.
  - `HS006` (Miền Trung - TP Vinh, Nghệ An): Hồ sơ thiếu MST, thiếu diện tích, thiếu KTV và chưa có bản ghi xác minh -> liệt kê rõ toàn bộ mục chưa xác định và chuyển Kinh doanh + Vận hành thu thập bổ sung.
  - `HS008` (Miền Bắc - Từ Sơn, Bắc Ninh): Trùng SĐT (`0987654321`) và tương đồng tên (`85%`) với đối tác hiện tại `DT002` -> chuyển Kinh doanh & Trưởng phòng PTKD xác minh quan hệ sở hữu.
  - `HS009` (Miền Trung - Nha Trang, Khánh Hòa): Đạt thực địa nhưng vượt chính sách công nợ (`35 ngày > 30`, `550 triệu > 500`, `6% > 5%`) -> `HOLD`, chuyển Tài chính & Trưởng phòng PTKD.
- **Chưa tiếp tục làm việc (2 hồ sơ):**
  - `HS002` (Miền Nam - Quận 7, TP.HCM): Tự nhận là đối tác mới nhưng **trùng MST `0312345678`** với `DT004 - Công ty TNHH Tân Phát` và trùng địa bàn Quận 7 (`1.383 km`) -> `REJECT`, chuyển Kinh doanh & Trưởng phòng PTKD ghi nhận.
  - `HS007` (Miền Nam - Ninh Kiều, Cần Thơ): Mặt bằng 25 m2, 0 KTV, xác minh thực địa Vận hành `VERIFIED_FAIL` -> `REJECT`.

---

## 5. Kết quả tự kiểm thử tự động (`tests/run_tests.ps1`)

Chạy trực tiếp `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\run_tests.ps1` đạt **10/10 assertions PASS (0 FAILED)**:

| Nhóm kịch bản | Mã kiểm thử | Tình huống kiểm chứng | Kết quả quan sát |
|---|---|---|---|
| **Thông thường** | `T_NORM_CONTINUE` | Hồ sơ chuẩn, đủ xác minh độc lập, điểm >= 85 | **PASS** (`CONTINUE`, `P1`, `vScore=100`, `esc=False`) |
| **Thông thường** | `T_NORM_REJECT` | Hồ sơ yếu, xác minh POS & bảo hành không đạt | **PASS** (`NOT_CONTINUE`, `REJECT`, `vScore=28.6`) |
| **Thiếu dữ liệu** | `T_MISS_UNVERIFIED_COMMIT` | Cam kết `1.2 tỷ/tháng` nhưng chưa xác minh thực tế | **PASS** (`purchase=1200M`, `warn=True`, `SUPPLEMENT`, `verified=46.5 < claimed=100`) |
| **Thiếu dữ liệu** | `T_MISS_FIELDS` | Thiếu MST, diện tích, KTV, GPS và thiếu bản ghi xác minh | **PASS** (`missing_count=5`, `ver_found=False`, `SUPPLEMENT`) |
| **Ranh giới quy tắc** | `T_BND_CREDIT_EXACT_PASS` | Đúng trần `30 ngày`, `500 triệu`, `5.0%`, `40 m2`, `1 KTV`, `150 triệu` | **PASS** (`policy_ok=True`, `mandatory_ok=True`, `vScore=78`, `CONTINUE`) |
| **Ranh giới quy tắc** | `T_BND_CREDIT_OVER_1` | Vượt đúng 1 đơn vị (`31 ngày`, `501 triệu`, `5.1%`) | **PASS** (`violations=3`, `POLICY_EXCEEDED`, `SUPPLEMENT`) |
| **Ranh giới quy tắc** | `T_BND_RADIUS_EXACT_CONFLICT` | Điểm bán khác quận, cách điểm bảo hộ `4.993 km <= 5.0 km` | **PASS** (`terr_status=CONFLICT`, `TERRITORY_CONFLICT`, `SUPPLEMENT`) |
| **Ranh giới quy tắc** | `T_BND_RADIUS_JUST_OUTSIDE` | Điểm bán khác quận, cách điểm bảo hộ `5.171 km > 5.0 km` | **PASS** (`terr_status=CLEAR`, `CONTINUE`) |
| **Ranh giới quy tắc** | `T_BND_TAX_DUPLICATE` | Đổi tên/địa chỉ/SĐT nhưng trùng MST đối tác hiện tại | **PASS** (`CONFIRMED_DUPLICATE`, `IDENTITY_DUPLICATE`, `NOT_CONTINUE`) |
| **Kiến trúc & Trace** | `T_ARCH_SKILLS_TOOLS` | Phối hợp đủ 3 kỹ năng, 7 công cụ, 3 khu vực trên dữ liệu mẫu | **PASS** (`skills=3`, `tools=7`, `sample_total=10`, `regions=3`) |

---

## 6. Quy trình vận hành tại buổi thi

1. Mở Web App qua `start_app.bat` (hoặc chạy CLI `run_agent.ps1`).
2. Vào tab **6. Nạp dữ liệu thi & Quy tắc**:
   - Nếu cấu trúc tên cột hoặc ngưỡng chính sách mới khác mặc định, cập nhật nhanh `rules_config.json` hoặc `schema_mapping.json`.
   - Chọn thư mục/các file bộ dữ liệu thi do giảng viên cung cấp và nhấn **Nạp & Chạy trực tiếp dữ liệu thi**.
3. Trình bày trực tiếp trên màn hình:
   - Tab **1**: Bảng đề xuất theo 3 khu vực.
   - Tab **2**: Hồ sơ chi tiết, căn cứ, mục thiếu/chưa xác định và bản nháp trao đổi từng ứng viên.
   - Tab **3 & 4**: Các trường hợp xung đột/vượt chính sách cần chuyển thẩm quyền & kế hoạch phối hợp Kinh doanh – Vận hành – Tài chính.
   - Tab **5**: Nhật ký `.jsonl` chứng minh Agent tự đọc dữ liệu, gọi công cụ và áp dụng quy tắc mà không nhập tay kết luận.

