# Hệ thống AI Agent Đánh giá & Mở rộng Mạng lưới Đối tác — Công ty Đại Thành (AI301 - Đề 05)

Giải pháp xây dựng AI Agent đa kỹ năng phục vụ Phòng Phát triển Kinh doanh (Công ty Thiết bị Gia dụng Đại Thành) sàng lọc, đối chiếu danh tính/địa bàn, kiểm tra điều kiện & chính sách, chấm điểm theo bằng chứng thực chứng, lập kế hoạch phối hợp xác minh với **Kinh doanh – Vận hành – Tài chính** và soạn bản nháp trao đổi đối tác.

## Kiến trúc & Điểm nổi bật
- **Chạy ngay trên Windows không cần cài đặt Python/Node.js:** Backend PowerShell (`src/`) + Local HTTP Server (`TcpListener`) + Giao diện Web (`web/`) + CLI (`run_agent.ps1`).
- **Hỗ trợ song song 2 chế độ mô hình AI:**
  1. **LLM Function Calling (Gemini / OpenAI-Compatible API):** Khi cung cấp API Key (hoặc biến môi trường `GEMINI_API_KEY` / `OPENAI_API_KEY`), mô hình LLM trực tiếp gọi các công cụ qua Tool Calling, kèm guardrail đảm bảo không bỏ sót bất kỳ bước kiểm tra nào.
  2. **Hybrid Local Agent Orchestrator (Offline):** Khi không có API Key hoặc mất mạng trong phòng thi, hệ thống vẫn điều phối tuần tự toàn bộ **3 Kỹ năng nghiệp vụ** và **7 Công cụ thực thi** với bộ trích xuất văn bản tiếng Việt + tính toán xác định, đảm bảo kết quả nhất quán 100%.
- **3 Kỹ năng nghiệp vụ phối hợp (`src/AgentTools.ps1`):**
  1. `partner_identity_territory_screening`: Trích xuất hồ sơ văn bản & ánh xạ schema (`tool_load_and_extract_dossier`), đối chiếu trùng đối tác & xung đột vùng bảo hộ bằng Haversine/hành chính (`tool_check_identity_and_territory`), kiểm tra cổng bắt buộc, chính sách công nợ & bằng chứng độc lập (`tool_check_mandatory_and_policy_gates`).
  2. `partner_scoring_priority_and_escalation`: Chấm điểm 4 tiêu chí tách biệt *điểm tự khai* và *điểm thực chứng* (`tool_evaluate_criteria_and_priority`), phân loại đề xuất & định tuyến chuyển thẩm quyền (`tool_determine_escalation_and_recommendation`).
  3. `partner_reporting_coordination_and_drafting`: Soạn bản nháp trao đổi đối tác (`tool_draft_partner_communication`), tổng hợp bảng 3 khu vực, danh sách ngoại lệ & kế hoạch phối hợp xác minh Kinh doanh – Vận hành – Tài chính (`tool_generate_regional_summary_and_plan`).
- **Truy vết & Chống gian lận cam kết suông:**
  - Tuyệt đối **không tự coi cam kết của ứng viên là kết quả đã xác minh**.
  - Lưu nhật ký đầy đủ mọi bước đọc file, gọi công cụ, mã quy tắc và mã băm SHA-256 dữ liệu đầu vào tại `logs/<run_id>.jsonl`.

## Cấu trúc thư mục
- `config/rules_config.json`: Cấu hình toàn bộ quy tắc (bán kính bảo hộ, hạn mức công nợ, điều kiện bắt buộc, trọng số tiêu chí, ngưỡng cắt).
- `config/schema_mapping.json`: Ánh xạ linh hoạt tên cột/trường JSON/CSV để khớp nhanh cấu trúc giảng viên công bố.
- `config/messages_vi.json`: Mẫu văn bản, mẫu câu trích xuất tiếng Việt và mẫu thư trao đổi.
- `data/sample_exam_pack/`: Bộ 10 hồ sơ mẫu tại 3 khu vực (`applicants.json` + `dossiers/*.txt`, `existing_partners.csv`, `existing_pos.csv`, `verification_results.csv`).
- `src/`: Mã nguồn Agent Engine (`AgentCommon.ps1`, `AgentTools.ps1`, `AgentLLM.ps1`, `AgentOrchestrator.ps1`, `WebServer.ps1`).
- `web/`: Giao diện Web App (`index.html`, `styles.css`, `app.js`).
- `tests/`: Bộ dữ liệu kiểm thử & script tự kiểm thử (`tests/run_tests.ps1`, `tests/test_server.ps1`).
- `docs/`: Tài liệu phân tích & thiết kế (`Task1_PhanTich_Va_ThietKe_HeThong.md`, `Task2_GiaiPhap_Va_KiemThu.md`).
- `outputs/` và `logs/`: Kết quả xuất (`.json`, `.md`, `.csv` UTF-8 BOM) và nhật ký `.jsonl`.

## Hướng dẫn chạy nhanh
### Cách 1: Chạy Web App (Khuyến nghị lúc bảo vệ & thi)
1. Nhấn đúp file `start_app.bat` (hoặc chạy: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\src\WebServer.ps1 -Port 8055 -OpenBrowser`).
2. Trình duyệt mở địa chỉ `http://localhost:8055/` (hỗ trợ cả IPv4 `127.0.0.1` và IPv6 `::1`).
3. Nhấn **Chạy AI Agent** để chạy trên bộ dữ liệu mẫu, hoặc vào tab **6. Nạp dữ liệu thi & Quy tắc** để chọn thư mục/các file dữ liệu mới từ giảng viên và chạy trực tiếp mà không chỉnh sửa dữ liệu test.

### Cách 2: Chạy qua dòng lệnh (CLI)
```powershell
# Chạy trên bộ dữ liệu mẫu
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\run_agent.ps1 -Mode local

# Chạy trên thư mục bộ dữ liệu thi mới của giảng viên
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\run_agent.ps1 -DataDir "C:\duong\dan\bo_du_lieu_thi"

# Chạy kết hợp Gemini Function Calling thật
$env:GEMINI_API_KEY="YOUR_KEY"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\run_agent.ps1 -Mode llm -LlmProvider gemini
```

### Cách 3: Chạy bộ tự kiểm thử (Normal / Missing Data / Rule Boundaries)
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\run_tests.ps1
```

