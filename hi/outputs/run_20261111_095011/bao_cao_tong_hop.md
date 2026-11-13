# BÁO CÁO ĐÁNH GIÁ HỒ SƠ ĐỐI TÁC PHÂN PHỐI
- Đơn vị: Công ty Thiết bị Gia dụng Đại Thành
- Run ID: `run_20261111_095011` | Mode: `local_agent_orchestrator` | Time: 2026-11-11T02:50:12.8984485+00:00

## 1. Tổng quan phiên chạy AI Agent
| Chi so | Gia tri |
|---|---|
| Tong so ho so | 10 |
| Tiep tuc | 2 |
| Bo sung | 6 |
| Chua tiep tuc lam viec | 2 |
| Ho so can chuyen tham quyen | 8 |

## 2. Bảng đề xuất đối tác theo 3 khu vực
### Miền Bắc (3 ho so: 1 Tiep tuc / 2 Bo sung / 0 Chua tiep tuc)
| Ma HS | Doi tac | Dia ban | Diem thuc chung | Diem tu khai | Uu tien | De xuat | Chuyen tham quyen |
|---|---|---|---:|---:|---|---|---|
| HS005 | Công ty TNHH Gia dụng Đất Cảng | Lê Chân, Hải Phòng | 78 | 78 | P2 - Ưu tiên trung bình | Tiếp tục | Khong |
| HS001 | Công ty TNHH Điện máy An Phú | Cầu Giấy, Hà Nội | 98 | 98 | HOLD - Chờ thẩm quyền | Bổ sung | TERRITORY_CONFLICT |
| HS008 | Công ty Thiết bị Nhà bếp Kinh Bắc Plus | TP Từ Sơn, Bắc Ninh | 75 | 90 | HOLD - Chờ thẩm quyền | Bổ sung | IDENTITY_DUPLICATE, POLICY_EXCEEDED, MISSING_EVIDENCE |

### Miền Trung (3 ho so: 0 Tiep tuc / 3 Bo sung / 0 Chua tiep tuc)
| Ma HS | Doi tac | Dia ban | Diem thuc chung | Diem tu khai | Uu tien | De xuat | Chuyen tham quyen |
|---|---|---|---:|---:|---|---|---|
| HS003 | Siêu thị Gia dụng Sông Hàn | Hải Châu, Đà Nẵng | 90 | 90 | HOLD - Chờ thẩm quyền | Bổ sung | TERRITORY_CONFLICT |
| HS009 | Công ty TNHH Gia dụng Biển Đông | TP Nha Trang, Khánh Hòa | 73 | 73 | HOLD - Chờ thẩm quyền | Bổ sung | POLICY_EXCEEDED |
| HS006 | Cửa hàng Điện máy Minh Khai | TP Vinh, Nghệ An | 19 | 40 | P3 - Theo dõi / Bổ sung | Bổ sung | MISSING_EVIDENCE |

### Miền Nam (4 ho so: 1 Tiep tuc / 1 Bo sung / 2 Chua tiep tuc)
| Ma HS | Doi tac | Dia ban | Diem thuc chung | Diem tu khai | Uu tien | De xuat | Chuyen tham quyen |
|---|---|---|---:|---:|---|---|---|
| HS010 | Công ty TNHH Phân phối Gia dụng Đồng Nai | TP Biên Hòa, Đồng Nai | 100 | 100 | P1 - Ưu tiên cao | Tiếp tục | Khong |
| HS004 | Trung tâm Điện máy Hoàng Gia | Thủ Dầu Một, Bình Dương | 24.9 | 46 | HOLD - Chờ thẩm quyền | Bổ sung | POLICY_EXCEEDED, MISSING_EVIDENCE |
| HS002 | Công ty Gia dụng Tân Phát Nam Bộ | Quận 7, TP.HCM | 75 | 90 | REJECT - Chưa tiếp tục | Chưa tiếp tục làm việc | IDENTITY_DUPLICATE, TERRITORY_CONFLICT, POLICY_EXCEEDED, MISSING_EVIDENCE |
| HS007 | Hộ kinh doanh Gia dụng Tây Đô | Ninh Kiều, Cần Thơ | 28.6 | 37 | REJECT - Chưa tiếp tục | Chưa tiếp tục làm việc | MISSING_EVIDENCE |

## 3. Danh sách trường hợp chuyển người có thẩm quyền (Xung đột / Thiếu bằng chứng / Vượt chính sách)
### HS001 - Công ty TNHH Điện máy An Phú (Miền Bắc)
- **[TERRITORY_CONFLICT] Xung đột địa bàn bảo hộ với đối tác hiện tại** -> Chuyển cấp có thẩm quyền: **Trưởng phòng PTKD & Bộ phận Kinh doanh**
  - Chi tiet: Điểm bán cách POS001 (Công ty TNHH Điện máy Thủ Đô, Đống Đa) chỉ 2.894 km <= bán kính bảo hộ 5 km

### HS003 - Siêu thị Gia dụng Sông Hàn (Miền Trung)
- **[TERRITORY_CONFLICT] Xung đột địa bàn bảo hộ với đối tác hiện tại** -> Chuyển cấp có thẩm quyền: **Trưởng phòng PTKD & Bộ phận Kinh doanh**
  - Chi tiet: Điểm bán cách POS003 (Công ty CP Gia dụng Miền Trung, Hải Châu) chỉ 1.751 km <= bán kính bảo hộ 5 km; Trùng Quận/Huyện bảo hộ (Hải Châu, Đà Nẵng) với điểm bán POS003 của đối tác Công ty CP Gia dụng Miền Trung

### HS008 - Công ty Thiết bị Nhà bếp Kinh Bắc Plus (Miền Bắc)
- **[IDENTITY_DUPLICATE] Trùng danh tính / Đã thuộc hệ thống hiện tại** -> Chuyển cấp có thẩm quyền: **Trưởng phòng PTKD & Bộ phận Kinh doanh**
  - Chi tiet: Trùng số điện thoại (0987654321) với đối tác hiện tại DT002 (Cửa hàng Bếp Kinh Bắc); Tên đối tác tương đồng (85%) với đối tác hiện tại DT002 (Cửa hàng Bếp Kinh Bắc)
- **[POLICY_EXCEEDED] Yêu cầu công nợ / hỗ trợ thương mại vượt chính sách** -> Chuyển cấp có thẩm quyền: **Bộ phận Tài chính & Trưởng phòng PTKD**
  - Chi tiet: Hạn mức công nợ đề nghị (350 triệu > 300 triệu) nhưng chưa có xác minh tài chính đạt chuẩn
- **[MISSING_EVIDENCE] Thiếu bằng chứng xác minh / Chưa kiểm chứng cam kết** -> Chuyển cấp có thẩm quyền: **Bộ phận Vận hành / Kinh doanh / Tài chính (xác minh thực tế)**
  - Chi tiet: Chua xac minh: identity, financial

### HS009 - Công ty TNHH Gia dụng Biển Đông (Miền Trung)
- **[POLICY_EXCEEDED] Yêu cầu công nợ / hỗ trợ thương mại vượt chính sách** -> Chuyển cấp có thẩm quyền: **Bộ phận Tài chính & Trưởng phòng PTKD**
  - Chi tiet: Vượt chính sách số ngày công nợ (35 ngày > 30 ngày); Vượt chính sách hạn mức công nợ (550 triệu > 500 triệu); Vượt chính sách hỗ trợ thương mại (6% > 5.0%)

### HS004 - Trung tâm Điện máy Hoàng Gia (Miền Nam)
- **[POLICY_EXCEEDED] Yêu cầu công nợ / hỗ trợ thương mại vượt chính sách** -> Chuyển cấp có thẩm quyền: **Bộ phận Tài chính & Trưởng phòng PTKD**
  - Chi tiet: Vượt chính sách số ngày công nợ (45 ngày > 30 ngày); Vượt chính sách hạn mức công nợ (800 triệu > 500 triệu); Vượt chính sách hỗ trợ thương mại (8% > 5.0%); Hạn mức công nợ đề nghị (800 triệu > 300 triệu) nhưng chưa có xác minh tài chính đạt chuẩn
- **[MISSING_EVIDENCE] Thiếu bằng chứng xác minh / Chưa kiểm chứng cam kết** -> Chuyển cấp có thẩm quyền: **Bộ phận Vận hành / Kinh doanh / Tài chính (xác minh thực tế)**
  - Chi tiet: Ứng viên cam kết nhập hàng cao nhưng chưa có bằng chứng xác minh độc lập; không coi cam kết là kết quả đã xác minh. | Chua xac minh: pos, warranty, financial

### HS006 - Cửa hàng Điện máy Minh Khai (Miền Trung)
- **[MISSING_EVIDENCE] Thiếu bằng chứng xác minh / Chưa kiểm chứng cam kết** -> Chuyển cấp có thẩm quyền: **Bộ phận Vận hành / Kinh doanh / Tài chính (xác minh thực tế)**
  - Chi tiet: Chua xac minh: identity, pos, warranty, financial | Thiếu Mã số thuế để đối chiếu danh tính pháp nhân; Thiếu diện tích trưng bày (m2); Thiếu thông tin số lượng kỹ thuật viên bảo hành

### HS002 - Công ty Gia dụng Tân Phát Nam Bộ (Miền Nam)
- **[IDENTITY_DUPLICATE] Trùng danh tính / Đã thuộc hệ thống hiện tại** -> Chuyển cấp có thẩm quyền: **Trưởng phòng PTKD & Bộ phận Kinh doanh**
  - Chi tiet: Trùng Mã số thuế (0312345678) với đối tác hiện tại DT004 (Công ty TNHH Tân Phát)
- **[TERRITORY_CONFLICT] Xung đột địa bàn bảo hộ với đối tác hiện tại** -> Chuyển cấp có thẩm quyền: **Trưởng phòng PTKD & Bộ phận Kinh doanh**
  - Chi tiet: Điểm bán cách POS005 (Công ty TNHH Tân Phát, Quận 7) chỉ 1.383 km <= bán kính bảo hộ 5 km; Trùng Quận/Huyện bảo hộ (Quận 7, TP.HCM) với điểm bán POS005 của đối tác Công ty TNHH Tân Phát
- **[POLICY_EXCEEDED] Yêu cầu công nợ / hỗ trợ thương mại vượt chính sách** -> Chuyển cấp có thẩm quyền: **Bộ phận Tài chính & Trưởng phòng PTKD**
  - Chi tiet: Hạn mức công nợ đề nghị (450 triệu > 300 triệu) nhưng chưa có xác minh tài chính đạt chuẩn
- **[MISSING_EVIDENCE] Thiếu bằng chứng xác minh / Chưa kiểm chứng cam kết** -> Chuyển cấp có thẩm quyền: **Bộ phận Vận hành / Kinh doanh / Tài chính (xác minh thực tế)**
  - Chi tiet: Chua xac minh: identity, financial

### HS007 - Hộ kinh doanh Gia dụng Tây Đô (Miền Nam)
- **[MISSING_EVIDENCE] Thiếu bằng chứng xác minh / Chưa kiểm chứng cam kết** -> Chuyển cấp có thẩm quyền: **Bộ phận Vận hành / Kinh doanh / Tài chính (xác minh thực tế)**
  - Chi tiet: Chua xac minh: pos, warranty

## 4. Kế hoạch phối hợp xác minh với các bộ phận liên quan
| Bo phan | Ma HS | Doi tac | Khu vuc | Trang thai | Nhiem vu xac minh |
|---|---|---|---|---|---|
| Bộ phận Kinh doanh | HS001 | Công ty TNHH Điện máy An Phú | Miền Bắc | Bổ sung | Kiểm tra thực địa khoảng cách và ranh giới địa bàn bảo hộ với điểm bán hiện tại |
| Bộ phận Kinh doanh | HS003 | Siêu thị Gia dụng Sông Hàn | Miền Trung | Bổ sung | Kiểm tra thực địa khoảng cách và ranh giới địa bàn bảo hộ với điểm bán hiện tại |
| Bộ phận Kinh doanh | HS008 | Công ty Thiết bị Nhà bếp Kinh Bắc Plus | Miền Bắc | Bổ sung | Xác minh pháp nhân, mã số thuế và quan hệ sở hữu với đối tác hệ thống |
| Bộ phận Tài chính | HS008 | Công ty Thiết bị Nhà bếp Kinh Bắc Plus | Miền Bắc | Bổ sung | Thẩm định báo cáo tài chính, khả năng thanh toán và điều chỉnh điều khoản công nợ về chuẩn chính sách |
| Bộ phận Tài chính | HS009 | Công ty TNHH Gia dụng Biển Đông | Miền Trung | Bổ sung | Thẩm định báo cáo tài chính, khả năng thanh toán và điều chỉnh điều khoản công nợ về chuẩn chính sách |
| Bộ phận Tài chính | HS004 | Trung tâm Điện máy Hoàng Gia | Miền Nam | Bổ sung | Thẩm định báo cáo tài chính, khả năng thanh toán và điều chỉnh điều khoản công nợ về chuẩn chính sách |
| Bộ phận Vận hành | HS004 | Trung tâm Điện máy Hoàng Gia | Miền Nam | Bổ sung | Kiểm tra thực địa mặt bằng trưng bày, hợp đồng thuê và hình ảnh điểm bán |
| Bộ phận Vận hành | HS004 | Trung tâm Điện máy Hoàng Gia | Miền Nam | Bổ sung | Kiểm tra chứng chỉ, hợp đồng lao động kỹ thuật viên và quy trình bảo hành tại chỗ |
| Bộ phận Vận hành | HS006 | Cửa hàng Điện máy Minh Khai | Miền Trung | Bổ sung | Kiểm tra thực địa mặt bằng trưng bày, hợp đồng thuê và hình ảnh điểm bán |
| Bộ phận Vận hành | HS006 | Cửa hàng Điện máy Minh Khai | Miền Trung | Bổ sung | Kiểm tra chứng chỉ, hợp đồng lao động kỹ thuật viên và quy trình bảo hành tại chỗ |
| Bộ phận Tài chính | HS006 | Cửa hàng Điện máy Minh Khai | Miền Trung | Bổ sung | Thẩm định báo cáo tài chính, khả năng thanh toán và điều chỉnh điều khoản công nợ về chuẩn chính sách |
| Bộ phận Kinh doanh | HS006 | Cửa hàng Điện máy Minh Khai | Miền Trung | Bổ sung | Thu thập bổ sung dữ liệu còn thiếu trong hồ sơ ứng viên (Thiếu Mã số thuế để đối chiếu danh tính pháp nhân, Thiếu diện tích trưng bày (m2), Thiếu thông tin số lượng kỹ thuật viên bảo hành) |
| Bộ phận Kinh doanh | HS002 | Công ty Gia dụng Tân Phát Nam Bộ | Miền Nam | Chưa tiếp tục làm việc | Xác minh pháp nhân, mã số thuế và quan hệ sở hữu với đối tác hệ thống |
| Bộ phận Kinh doanh | HS002 | Công ty Gia dụng Tân Phát Nam Bộ | Miền Nam | Chưa tiếp tục làm việc | Kiểm tra thực địa khoảng cách và ranh giới địa bàn bảo hộ với điểm bán hiện tại |
| Bộ phận Tài chính | HS002 | Công ty Gia dụng Tân Phát Nam Bộ | Miền Nam | Chưa tiếp tục làm việc | Thẩm định báo cáo tài chính, khả năng thanh toán và điều chỉnh điều khoản công nợ về chuẩn chính sách |

## 5. Hồ sơ chi tiết từng ứng viên & Bản nháp trao đổi
### HS001 - Công ty TNHH Điện máy An Phú [Bổ sung | HOLD - Chờ thẩm quyền]
- Khu vuc: Miền Bắc | Dia chi: 68 Trần Thái Tông, Dịch Vọng Hậu, Cầu Giấy, Hà Nội | MST: 0109554433
- Diem thuc chung: **98/100** (Diem tu khai: 98/100)
- **Căn cứ đánh giá:**
  - tax_id: "Mã số thuế: 0109554433"
  - phone: "Điện thoại: 0918223344"
  - email: "long.tran@anphudienmay.vn"
  - representative: "Người đại diện: Trần Hoàng Long"
  - partner_name: "Tên đối tác: Công ty TNHH Điện máy An Phú"
  - region: "Khu vực: Miền Bắc"
  - province: "Tỉnh/Thành: Hà Nội"
  - district: "Quận/Huyện: Cầu Giấy"
  - ward: "Phường/Xã: Dịch Vọng Hậu"
  - pos_address: "Địa chỉ điểm bán: 68 Trần Thái Tông, Dịch Vọng Hậu, Cầu Giấy, Hà Nội"
  - showroom_area_m2: "Diện tích trưng bày: 120 m2"
  - warranty_technicians: "3 kỹ thuật viên"
  - warranty_notes: "Năng lực bảo hành: Có phòng kỹ thuật riêng với 3 kỹ thuật viên chuyên lắp đặt và bảo hành thiết bị gia dụng; tiếp nhận bảo hành tại nhà tron..."
  - monthly_purchase_vnd_million: "Kế hoạch nhập hàng: 420 triệu"
  - requested_credit_days: "Công nợ 30 ngày"
  - requested_credit_limit_vnd_million: "hạn mức công nợ 400 triệu"
  - requested_marketing_support_pct: "hỗ trợ thương mại 4%"
  - Verification (Kinh doanh + Vận hành + Tài chính - 2026-11-05): Đã kiểm tra thực địa showroom 120m2 Cầu Giấy; 3 KTV có chứng chỉ điện lạnh-gia dụng; BCTC đủ hạn mức 400tr.
  - Nearest POS: POS001 (Công ty TNHH Điện máy Thủ Đô, Đống Đa) = 2.894 km
- **Điều kiện chưa đạt / Xung đột:**
  - Điểm bán cách POS001 (Công ty TNHH Điện máy Thủ Đô, Đống Đa) chỉ 2.894 km <= bán kính bảo hộ 5 km
- **Thông tin thiếu / chưa xác định:**
  - Khong co
- **Thông tin cần xác minh:**
  - [Bộ phận Kinh doanh] Kiểm tra thực địa khoảng cách và ranh giới địa bàn bảo hộ với điểm bán hiện tại
- **Bản nháp trao đổi với đối tác:**
  - Tieu de: `[Đại Thành] Đề nghị bổ sung hồ sơ & phối hợp xác minh - Công ty TNHH Điện máy An Phú (HS001)`
```text
Kính gửi Quý đối tác Công ty TNHH Điện máy An Phú (Người đại diện: Trần Hoàng Long),

Phòng Phát triển Kinh doanh - Công ty Thiết bị Gia dụng Đại Thành đã tiếp nhận hồ sơ đăng ký đối tác HS001 tại khu vực Miền Bắc.

Để có đủ cơ sở trình Trưởng phòng Phát triển Kinh doanh và các bộ phận chuyên môn xem xét, kính đề nghị Quý đối tác phối hợp bổ sung/làm rõ các nội dung sau:

1. Các điều kiện chưa đạt hoặc cần điều chỉnh theo chính sách:
- Điểm bán cách POS001 (Công ty TNHH Điện máy Thủ Đô, Đống Đa) chỉ 2.894 km <= bán kính bảo hộ 5 km

2. Thông tin và bằng chứng cần xác minh thêm:
- [Bộ phận Kinh doanh] Kiểm tra thực địa khoảng cách và ranh giới địa bàn bảo hộ với điểm bán hiện tại

Lưu ý: Các cam kết về sản lượng nhập hàng sẽ được ghi nhận cùng kết quả xác minh thực tế năng lực phục vụ khách hàng và chính sách công nợ của Công ty.

Vui lòng phản hồi trong vòng 05 ngày làm việc để chúng tôi tiếp tục xử lý hồ sơ.

Trân trọng,
Phòng Phát triển Kinh doanh - Công ty Thiết bị Gia dụng Đại Thành
```

### HS002 - Công ty Gia dụng Tân Phát Nam Bộ [Chưa tiếp tục làm việc | REJECT - Chưa tiếp tục]
- Khu vuc: Miền Nam | Dia chi: 215 Nguyễn Thị Thập, Tân Hưng, Quận 7, TP.HCM | MST: 0312345678
- Diem thuc chung: **75/100** (Diem tu khai: 90/100)
- **Căn cứ đánh giá:**
  - tax_id: "Mã số thuế: 0312345678"
  - phone: "Điện thoại: 0909887766"
  - email: "bao.nambo@tanphat.vn"
  - representative: "Người đại diện: Phạm Quốc Bảo"
  - partner_name: "Tên đối tác: Công ty Gia dụng Tân Phát Nam Bộ"
  - region: "Khu vực: Miền Nam"
  - province: "Tỉnh/Thành: TP.HCM"
  - district: "Quận/Huyện: Quận 7"
  - ward: "Phường/Xã: Tân Hưng"
  - pos_address: "Địa chỉ điểm bán: 215 Nguyễn Thị Thập, Tân Hưng, Quận 7, TP.HCM"
  - showroom_area_m2: "Diện tích trưng bày: 100 m2"
  - warranty_technicians: "2 kỹ thuật viên"
  - warranty_notes: "Năng lực bảo hành: Có 2 kỹ thuật viên bảo hành chuyên trách tại Quận 7."
  - monthly_purchase_vnd_million: "Kế hoạch nhập hàng: 380 triệu"
  - requested_credit_days: "Công nợ 30 ngày"
  - requested_credit_limit_vnd_million: "hạn mức công nợ 450 triệu"
  - requested_marketing_support_pct: "hỗ trợ thương mại 5%"
  - Verification (Kinh doanh - 2026-11-06): Phát hiện MST trùng hồ sơ đối tác hệ thống DT004; tạm dừng kiểm tra tài chính.
  - Nearest POS: POS005 (Công ty TNHH Tân Phát, Quận 7) = 1.383 km
- **Điều kiện chưa đạt / Xung đột:**
  - Hạn mức công nợ đề nghị (450 triệu > 300 triệu) nhưng chưa có xác minh tài chính đạt chuẩn
  - Trùng Mã số thuế (0312345678) với đối tác hiện tại DT004 (Công ty TNHH Tân Phát)
  - Điểm bán cách POS005 (Công ty TNHH Tân Phát, Quận 7) chỉ 1.383 km <= bán kính bảo hộ 5 km
  - Trùng Quận/Huyện bảo hộ (Quận 7, TP.HCM) với điểm bán POS005 của đối tác Công ty TNHH Tân Phát
- **Thông tin thiếu / chưa xác định:**
  - Khong co
- **Thông tin cần xác minh:**
  - [Bộ phận Kinh doanh] Xác minh pháp nhân, mã số thuế và quan hệ sở hữu với đối tác hệ thống
  - [Bộ phận Kinh doanh] Kiểm tra thực địa khoảng cách và ranh giới địa bàn bảo hộ với điểm bán hiện tại
  - [Bộ phận Tài chính] Thẩm định báo cáo tài chính, khả năng thanh toán và điều chỉnh điều khoản công nợ về chuẩn chính sách
- **Bản nháp trao đổi với đối tác:**
  - Tieu de: `[Đại Thành] Phản hồi hồ sơ đăng ký hợp tác phân phối - Công ty Gia dụng Tân Phát Nam Bộ (HS002)`
```text
Kính gửi Quý đối tác Công ty Gia dụng Tân Phát Nam Bộ (Người đại diện: Phạm Quốc Bảo),

Phòng Phát triển Kinh doanh - Công ty Thiết bị Gia dụng Đại Thành chân thành cảm ơn Quý đơn vị đã quan tâm đến cơ hội hợp tác phân phối sản phẩm thiết bị gia dụng tại khu vực Miền Nam.

Sau khi rà soát hồ sơ HS002 dựa trên chính sách mở rộng mạng lưới và tiêu chí đối tác hiện hành của Công ty, chúng tôi rất tiếc chưa thể tiếp tục triển khai hợp tác ở giai đoạn này với các lý do chính sau:
- Hạn mức công nợ đề nghị (450 triệu > 300 triệu) nhưng chưa có xác minh tài chính đạt chuẩn
- Trùng Mã số thuế (0312345678) với đối tác hiện tại DT004 (Công ty TNHH Tân Phát)
- Điểm bán cách POS005 (Công ty TNHH Tân Phát, Quận 7) chỉ 1.383 km <= bán kính bảo hộ 5 km
- Trùng Quận/Huyện bảo hộ (Quận 7, TP.HCM) với điểm bán POS005 của đối tác Công ty TNHH Tân Phát

Chúng tôi trân trọng sự quan tâm của Quý đối tác và xin phép lưu thông tin để liên hệ khi chính sách khu vực có điều chỉnh phù hợp.

Trân trọng,
Phòng Phát triển Kinh doanh - Công ty Thiết bị Gia dụng Đại Thành
```

### HS003 - Siêu thị Gia dụng Sông Hàn [Bổ sung | HOLD - Chờ thẩm quyền]
- Khu vuc: Miền Trung | Dia chi: 112 Hoàng Diệu, Bình Hiên, Hải Châu, Đà Nẵng | MST: 0401998877
- Diem thuc chung: **90/100** (Diem tu khai: 90/100)
- **Căn cứ đánh giá:**
  - tax_id: "Mã số thuế: 0401998877"
  - phone: "Điện thoại: 0905889900"
  - email: "khoa@songhangiadung.vn"
  - representative: "Người đại diện: Huỳnh Văn Khoa"
  - partner_name: "Tên đối tác: Siêu thị Gia dụng Sông Hàn"
  - region: "Khu vực: Miền Trung"
  - province: "Tỉnh/Thành: Đà Nẵng"
  - district: "Quận/Huyện: Hải Châu"
  - ward: "Phường/Xã: Bình Hiên"
  - pos_address: "Địa chỉ điểm bán: 112 Hoàng Diệu, Bình Hiên, Hải Châu, Đà Nẵng"
  - showroom_area_m2: "Diện tích trưng bày: 95 m2"
  - warranty_technicians: "2 kỹ thuật viên"
  - warranty_notes: "Năng lực bảo hành: Có 2 kỹ thuật viên bảo hành, kho phụ tùng tiêu chuẩn 20 m2."
  - monthly_purchase_vnd_million: "Kế hoạch nhập hàng: 350 triệu"
  - requested_credit_days: "Công nợ 25 ngày"
  - requested_credit_limit_vnd_million: "hạn mức công nợ 350 triệu"
  - requested_marketing_support_pct: "hỗ trợ thương mại 4.5%"
  - Verification (Vận hành + Tài chính - 2026-11-06): Showroom 95m2 tại Hải Châu đạt chuẩn; 2 KTV bảo hành; BCTC hợp lệ. Chưa đối chiếu bảo hộ địa bàn.
  - Nearest POS: POS003 (Công ty CP Gia dụng Miền Trung, Hải Châu) = 1.751 km
- **Điều kiện chưa đạt / Xung đột:**
  - Điểm bán cách POS003 (Công ty CP Gia dụng Miền Trung, Hải Châu) chỉ 1.751 km <= bán kính bảo hộ 5 km
  - Trùng Quận/Huyện bảo hộ (Hải Châu, Đà Nẵng) với điểm bán POS003 của đối tác Công ty CP Gia dụng Miền Trung
- **Thông tin thiếu / chưa xác định:**
  - Khong co
- **Thông tin cần xác minh:**
  - [Bộ phận Kinh doanh] Kiểm tra thực địa khoảng cách và ranh giới địa bàn bảo hộ với điểm bán hiện tại
- **Bản nháp trao đổi với đối tác:**
  - Tieu de: `[Đại Thành] Đề nghị bổ sung hồ sơ & phối hợp xác minh - Siêu thị Gia dụng Sông Hàn (HS003)`
```text
Kính gửi Quý đối tác Siêu thị Gia dụng Sông Hàn (Người đại diện: Huỳnh Văn Khoa),

Phòng Phát triển Kinh doanh - Công ty Thiết bị Gia dụng Đại Thành đã tiếp nhận hồ sơ đăng ký đối tác HS003 tại khu vực Miền Trung.

Để có đủ cơ sở trình Trưởng phòng Phát triển Kinh doanh và các bộ phận chuyên môn xem xét, kính đề nghị Quý đối tác phối hợp bổ sung/làm rõ các nội dung sau:

1. Các điều kiện chưa đạt hoặc cần điều chỉnh theo chính sách:
- Điểm bán cách POS003 (Công ty CP Gia dụng Miền Trung, Hải Châu) chỉ 1.751 km <= bán kính bảo hộ 5 km
- Trùng Quận/Huyện bảo hộ (Hải Châu, Đà Nẵng) với điểm bán POS003 của đối tác Công ty CP Gia dụng Miền Trung

2. Thông tin và bằng chứng cần xác minh thêm:
- [Bộ phận Kinh doanh] Kiểm tra thực địa khoảng cách và ranh giới địa bàn bảo hộ với điểm bán hiện tại

Lưu ý: Các cam kết về sản lượng nhập hàng sẽ được ghi nhận cùng kết quả xác minh thực tế năng lực phục vụ khách hàng và chính sách công nợ của Công ty.

Vui lòng phản hồi trong vòng 05 ngày làm việc để chúng tôi tiếp tục xử lý hồ sơ.

Trân trọng,
Phòng Phát triển Kinh doanh - Công ty Thiết bị Gia dụng Đại Thành
```

### HS004 - Trung tâm Điện máy Hoàng Gia [Bổ sung | HOLD - Chờ thẩm quyền]
- Khu vuc: Miền Nam | Dia chi: 450 Đại lộ Bình Dương, Phú Cường, Thủ Dầu Một, Bình Dương | MST: 3702889911
- Diem thuc chung: **24.9/100** (Diem tu khai: 46/100)
- **Căn cứ đánh giá:**
  - tax_id: "Mã số thuế: 3702889911"
  - phone: "Điện thoại: 0977665544"
  - email: "duc@hoanggiabinhduong.vn"
  - representative: "Người đại diện: Nguyễn Minh Đức"
  - partner_name: "Tên đối tác: Trung tâm Điện máy Hoàng Gia"
  - region: "Khu vực: Miền Nam"
  - province: "Tỉnh/Thành: Bình Dương"
  - district: "Quận/Huyện: Thủ Dầu Một"
  - ward: "Phường/Xã: Phú Cường"
  - pos_address: "Địa chỉ điểm bán: 450 Đại lộ Bình Dương, Phú Cường, Thủ Dầu Một, Bình Dương"
  - showroom_area_m2: "Diện tích trưng bày: 180 m2"
  - warranty_technicians: "Kỹ thuật viên: 0"
  - warranty_notes: "Năng lực bảo hành: Kỹ thuật viên: 0 kỹ thuật viên chính thức hiện hữu (ứng viên cam kết sẽ tuyển thêm sau khi ký hợp đồng)."
  - monthly_purchase_vnd_million: "Kế hoạch nhập hàng: 900 triệu"
  - requested_credit_days: "Công nợ 45 ngày"
  - requested_credit_limit_vnd_million: "hạn mức công nợ 800 triệu"
  - requested_marketing_support_pct: "hỗ trợ thương mại 8%"
  - Verification (Kinh doanh - 2026-11-07): Ứng viên cam kết nhập 900 triệu/tháng nhưng chưa nộp ảnh mặt bằng kho
  - Nearest POS: POS006 (Trung tâm Điện máy Sài Gòn Xanh, Bình Thạnh) = 21.034 km
- **Điều kiện chưa đạt / Xung đột:**
  - Không đạt năng lực bảo hành tối thiểu (0 KTV < 1 KTV)
  - Vượt chính sách số ngày công nợ (45 ngày > 30 ngày)
  - Vượt chính sách hạn mức công nợ (800 triệu > 500 triệu)
  - Vượt chính sách hỗ trợ thương mại (8% > 5.0%)
  - Hạn mức công nợ đề nghị (800 triệu > 300 triệu) nhưng chưa có xác minh tài chính đạt chuẩn
- **Thông tin thiếu / chưa xác định:**
  - Khong co
- **Thông tin cần xác minh:**
  - [Bộ phận Tài chính] Thẩm định báo cáo tài chính, khả năng thanh toán và điều chỉnh điều khoản công nợ về chuẩn chính sách
  - [Bộ phận Vận hành] Kiểm tra thực địa mặt bằng trưng bày, hợp đồng thuê và hình ảnh điểm bán
  - [Bộ phận Vận hành] Kiểm tra chứng chỉ, hợp đồng lao động kỹ thuật viên và quy trình bảo hành tại chỗ
- **Bản nháp trao đổi với đối tác:**
  - Tieu de: `[Đại Thành] Đề nghị bổ sung hồ sơ & phối hợp xác minh - Trung tâm Điện máy Hoàng Gia (HS004)`
```text
Kính gửi Quý đối tác Trung tâm Điện máy Hoàng Gia (Người đại diện: Nguyễn Minh Đức),

Phòng Phát triển Kinh doanh - Công ty Thiết bị Gia dụng Đại Thành đã tiếp nhận hồ sơ đăng ký đối tác HS004 tại khu vực Miền Nam.

Để có đủ cơ sở trình Trưởng phòng Phát triển Kinh doanh và các bộ phận chuyên môn xem xét, kính đề nghị Quý đối tác phối hợp bổ sung/làm rõ các nội dung sau:

1. Các điều kiện chưa đạt hoặc cần điều chỉnh theo chính sách:
- Không đạt năng lực bảo hành tối thiểu (0 KTV < 1 KTV)
- Vượt chính sách số ngày công nợ (45 ngày > 30 ngày)
- Vượt chính sách hạn mức công nợ (800 triệu > 500 triệu)
- Vượt chính sách hỗ trợ thương mại (8% > 5.0%)
- Hạn mức công nợ đề nghị (800 triệu > 300 triệu) nhưng chưa có xác minh tài chính đạt chuẩn

2. Thông tin và bằng chứng cần xác minh thêm:
- [Bộ phận Tài chính] Thẩm định báo cáo tài chính, khả năng thanh toán và điều chỉnh điều khoản công nợ về chuẩn chính sách
- [Bộ phận Vận hành] Kiểm tra thực địa mặt bằng trưng bày, hợp đồng thuê và hình ảnh điểm bán
- [Bộ phận Vận hành] Kiểm tra chứng chỉ, hợp đồng lao động kỹ thuật viên và quy trình bảo hành tại chỗ

Lưu ý: Các cam kết về sản lượng nhập hàng sẽ được ghi nhận cùng kết quả xác minh thực tế năng lực phục vụ khách hàng và chính sách công nợ của Công ty.

Vui lòng phản hồi trong vòng 05 ngày làm việc để chúng tôi tiếp tục xử lý hồ sơ.

Trân trọng,
Phòng Phát triển Kinh doanh - Công ty Thiết bị Gia dụng Đại Thành
```

### HS005 - Công ty TNHH Gia dụng Đất Cảng [Tiếp tục | P2 - Ưu tiên trung bình]
- Khu vuc: Miền Bắc | Dia chi: 75 Võ Nguyên Giáp, Vĩnh Niệm, Lê Chân, Hải Phòng | MST: 0201667788
- Diem thuc chung: **78/100** (Diem tu khai: 78/100)
- **Căn cứ đánh giá:**
  - tax_id: "Mã số thuế: 0201667788"
  - phone: "Điện thoại: 0904556677"
  - email: "tung@datcanggiadung.vn"
  - representative: "Người đại diện: Đỗ Văn Tùng"
  - partner_name: "Tên đối tác: Công ty TNHH Gia dụng Đất Cảng"
  - region: "Khu vực: Miền Bắc"
  - province: "Tỉnh/Thành: Hải Phòng"
  - district: "Quận/Huyện: Lê Chân"
  - ward: "Phường/Xã: Vĩnh Niệm"
  - pos_address: "Địa chỉ điểm bán: 75 Võ Nguyên Giáp, Vĩnh Niệm, Lê Chân, Hải Phòng"
  - showroom_area_m2: "Diện tích trưng bày: 60 m2"
  - warranty_technicians: "1 kỹ thuật viên"
  - warranty_notes: "Năng lực bảo hành: Có 1 kỹ thuật viên bảo hành chính thức có chứng chỉ điện gia dụng."
  - monthly_purchase_vnd_million: "Kế hoạch nhập hàng: 220 triệu"
  - requested_credit_days: "Công nợ 30 ngày"
  - requested_credit_limit_vnd_million: "hạn mức công nợ 500 triệu"
  - requested_marketing_support_pct: "hỗ trợ thương mại 5%"
  - Verification (Kinh doanh + Vận hành + Tài chính - 2026-11-07): Showroom 60m2 tại Lê Chân đạt chuẩn tối thiểu; 1 KTV chuyên trách đã kiểm tra thực tế; hồ sơ tài chính đạt chuẩn 500tr/30 ngày.
  - Nearest POS: POS004 (Công ty TNHH Điện máy Thủ Đô, Ngô Quyền) = 5.825 km
- **Điều kiện chưa đạt / Xung đột:**
  - Khong co
- **Thông tin thiếu / chưa xác định:**
  - Khong co
- **Thông tin cần xác minh:**
  - Da hoan tat xac minh
- **Bản nháp trao đổi với đối tác:**
  - Tieu de: `[Đại Thành] Thông báo kết quả sơ duyệt hồ sơ đối tác - Công ty TNHH Gia dụng Đất Cảng (HS005)`
```text
Kính gửi Quý đối tác Công ty TNHH Gia dụng Đất Cảng (Người đại diện: Đỗ Văn Tùng),

Phòng Phát triển Kinh doanh - Công ty Thiết bị Gia dụng Đại Thành trân trọng cảm ơn Quý đơn vị đã gửi hồ sơ đăng ký hợp tác phân phối tại khu vực Miền Bắc.

Qua đối chiếu thông tin và xác minh bước đầu, hồ sơ HS005 của Quý đối tác đáp ứng các điều kiện cơ bản để chuyển sang bước đàm phán hợp tác (P2 - Ưu tiên trung bình).

Căn cứ ghi nhận:
- tax_id: "Mã số thuế: 0201667788"
- phone: "Điện thoại: 0904556677"
- email: "tung@datcanggiadung.vn"
- representative: "Người đại diện: Đỗ Văn Tùng"

Đề xuất bước tiếp theo:
- Hai bên tiến hành trao đổi chi tiết phụ lục hợp đồng, danh mục sản phẩm và lịch nhập hàng đợt đầu.
- Bộ phận Kinh doanh sẽ liên hệ xác nhận lịch ký hợp đồng trong 02 ngày làm việc.
Trân trọng,
Phòng Phát triển Kinh doanh - Công ty Thiết bị Gia dụng Đại Thành
```

### HS006 - Cửa hàng Điện máy Minh Khai [Bổ sung | P3 - Theo dõi / Bổ sung]
- Khu vuc: Miền Trung | Dia chi: 25 Nguyễn Thị Minh Khai, Hưng Bình, TP Vinh, Nghệ An | MST: 
- Diem thuc chung: **19/100** (Diem tu khai: 40/100)
- **Căn cứ đánh giá:**
  - phone: "Điện thoại: 0915334455"
  - email: "dung.minhkhai@gmail.com"
  - representative: "Người đại diện: Lê Anh Dũng"
  - partner_name: "Tên đối tác: Cửa hàng Điện máy Minh Khai"
  - region: "Khu vực: Miền Trung"
  - province: "Tỉnh/Thành: Nghệ An"
  - district: "Quận/Huyện: TP Vinh"
  - ward: "Phường/Xã: Hưng Bình"
  - pos_address: "Địa chỉ điểm bán: 25 Nguyễn Thị Minh Khai, Hưng Bình, TP Vinh, Nghệ An"
  - monthly_purchase_vnd_million: "Kế hoạch nhập hàng: 260 triệu"
  - requested_credit_days: "Công nợ 30 ngày"
  - requested_credit_limit_vnd_million: "hạn mức công nợ 300 triệu"
  - requested_marketing_support_pct: "hỗ trợ thương mại 4%"
- **Điều kiện chưa đạt / Xung đột:**
  - Không đạt điều kiện bắt buộc: Chưa có Mã số thuế hợp lệ
- **Thông tin thiếu / chưa xác định:**
  - Thiếu Mã số thuế để đối chiếu danh tính pháp nhân
  - Thiếu diện tích trưng bày (m2)
  - Thiếu thông tin số lượng kỹ thuật viên bảo hành
  - Chưa có tọa độ GPS điểm bán (chỉ đối chiếu được theo Quận/Huyện/Phường)
- **Thông tin cần xác minh:**
  - [Bộ phận Vận hành] Kiểm tra thực địa mặt bằng trưng bày, hợp đồng thuê và hình ảnh điểm bán
  - [Bộ phận Vận hành] Kiểm tra chứng chỉ, hợp đồng lao động kỹ thuật viên và quy trình bảo hành tại chỗ
  - [Bộ phận Tài chính] Thẩm định báo cáo tài chính, khả năng thanh toán và điều chỉnh điều khoản công nợ về chuẩn chính sách
  - [Bộ phận Kinh doanh] Thu thập bổ sung dữ liệu còn thiếu trong hồ sơ ứng viên (Thiếu Mã số thuế để đối chiếu danh tính pháp nhân, Thiếu diện tích trưng bày (m2), Thiếu thông tin số lượng kỹ thuật viên bảo hành)
- **Bản nháp trao đổi với đối tác:**
  - Tieu de: `[Đại Thành] Đề nghị bổ sung hồ sơ & phối hợp xác minh - Cửa hàng Điện máy Minh Khai (HS006)`
```text
Kính gửi Quý đối tác Cửa hàng Điện máy Minh Khai (Người đại diện: Lê Anh Dũng),

Phòng Phát triển Kinh doanh - Công ty Thiết bị Gia dụng Đại Thành đã tiếp nhận hồ sơ đăng ký đối tác HS006 tại khu vực Miền Trung.

Để có đủ cơ sở trình Trưởng phòng Phát triển Kinh doanh và các bộ phận chuyên môn xem xét, kính đề nghị Quý đối tác phối hợp bổ sung/làm rõ các nội dung sau:

1. Các điều kiện chưa đạt hoặc cần điều chỉnh theo chính sách:
- Không đạt điều kiện bắt buộc: Chưa có Mã số thuế hợp lệ

2. Thông tin và bằng chứng cần xác minh thêm:
- [Bộ phận Vận hành] Kiểm tra thực địa mặt bằng trưng bày, hợp đồng thuê và hình ảnh điểm bán
- [Bộ phận Vận hành] Kiểm tra chứng chỉ, hợp đồng lao động kỹ thuật viên và quy trình bảo hành tại chỗ
- [Bộ phận Tài chính] Thẩm định báo cáo tài chính, khả năng thanh toán và điều chỉnh điều khoản công nợ về chuẩn chính sách
- [Bộ phận Kinh doanh] Thu thập bổ sung dữ liệu còn thiếu trong hồ sơ ứng viên (Thiếu Mã số thuế để đối chiếu danh tính pháp nhân, Thiếu diện tích trưng bày (m2), Thiếu thông tin số lượng kỹ thuật viên bảo hành)

Lưu ý: Các cam kết về sản lượng nhập hàng sẽ được ghi nhận cùng kết quả xác minh thực tế năng lực phục vụ khách hàng và chính sách công nợ của Công ty.

Vui lòng phản hồi trong vòng 05 ngày làm việc để chúng tôi tiếp tục xử lý hồ sơ.

Trân trọng,
Phòng Phát triển Kinh doanh - Công ty Thiết bị Gia dụng Đại Thành
```

### HS007 - Hộ kinh doanh Gia dụng Tây Đô [Chưa tiếp tục làm việc | REJECT - Chưa tiếp tục]
- Khu vuc: Miền Nam | Dia chi: 14 Đường 3/2, An Khánh, Ninh Kiều, Cần Thơ | MST: 1801445566
- Diem thuc chung: **28.6/100** (Diem tu khai: 37/100)
- **Căn cứ đánh giá:**
  - tax_id: "Mã số thuế: 1801445566"
  - phone: "Điện thoại: 0944112233"
  - email: "taydo.giadung@gmail.com"
  - representative: "Người đại diện: Nguyễn Văn Tèo"
  - partner_name: "Tên đối tác: Hộ kinh doanh Gia dụng Tây Đô"
  - region: "Khu vực: Miền Nam"
  - province: "Tỉnh/Thành: Cần Thơ"
  - district: "Quận/Huyện: Ninh Kiều"
  - ward: "Phường/Xã: An Khánh"
  - pos_address: "Địa chỉ điểm bán: 14 Đường 3/2, An Khánh, Ninh Kiều, Cần Thơ"
  - showroom_area_m2: "Diện tích trưng bày: 25 m2"
  - warranty_technicians: "Kỹ thuật viên: 0"
  - warranty_notes: "Năng lực bảo hành: Kỹ thuật viên: 0 kỹ thuật viên; chưa có dịch vụ bảo hành tại chỗ, chỉ nhận gửi trả về hãng."
  - monthly_purchase_vnd_million: "Kế hoạch nhập hàng: 90 triệu"
  - requested_credit_days: "Công nợ 20 ngày"
  - requested_credit_limit_vnd_million: "hạn mức công nợ 150 triệu"
  - requested_marketing_support_pct: "hỗ trợ thương mại 3%"
  - Verification (Vận hành - 2026-11-08): Thực địa cửa hàng chỉ rộng 25m2 không đạt trưng bày gia dụng; không có nhân sự kỹ thuật bảo hành.
- **Điều kiện chưa đạt / Xung đột:**
  - Không đạt diện tích trưng bày tối thiểu (25 m2 < 40 m2)
  - Không đạt năng lực bảo hành tối thiểu (0 KTV < 1 KTV)
  - Chưa đạt kế hoạch nhập hàng tối thiểu (90 triệu < 150 triệu/tháng)
  - Xác minh thực địa điểm bán KHÔNG ĐẠT (Bộ phận Vận hành)
  - Xác minh năng lực bảo hành KHÔNG ĐẠT (Bộ phận Vận hành)
- **Thông tin thiếu / chưa xác định:**
  - Chưa có tọa độ GPS điểm bán (chỉ đối chiếu được theo Quận/Huyện/Phường)
- **Thông tin cần xác minh:**
  - Da hoan tat xac minh
- **Bản nháp trao đổi với đối tác:**
  - Tieu de: `[Đại Thành] Phản hồi hồ sơ đăng ký hợp tác phân phối - Hộ kinh doanh Gia dụng Tây Đô (HS007)`
```text
Kính gửi Quý đối tác Hộ kinh doanh Gia dụng Tây Đô (Người đại diện: Nguyễn Văn Tèo),

Phòng Phát triển Kinh doanh - Công ty Thiết bị Gia dụng Đại Thành chân thành cảm ơn Quý đơn vị đã quan tâm đến cơ hội hợp tác phân phối sản phẩm thiết bị gia dụng tại khu vực Miền Nam.

Sau khi rà soát hồ sơ HS007 dựa trên chính sách mở rộng mạng lưới và tiêu chí đối tác hiện hành của Công ty, chúng tôi rất tiếc chưa thể tiếp tục triển khai hợp tác ở giai đoạn này với các lý do chính sau:
- Không đạt diện tích trưng bày tối thiểu (25 m2 < 40 m2)
- Không đạt năng lực bảo hành tối thiểu (0 KTV < 1 KTV)
- Chưa đạt kế hoạch nhập hàng tối thiểu (90 triệu < 150 triệu/tháng)
- Xác minh thực địa điểm bán KHÔNG ĐẠT (Bộ phận Vận hành)
- Xác minh năng lực bảo hành KHÔNG ĐẠT (Bộ phận Vận hành)

Chúng tôi trân trọng sự quan tâm của Quý đối tác và xin phép lưu thông tin để liên hệ khi chính sách khu vực có điều chỉnh phù hợp.

Trân trọng,
Phòng Phát triển Kinh doanh - Công ty Thiết bị Gia dụng Đại Thành
```

### HS008 - Công ty Thiết bị Nhà bếp Kinh Bắc Plus [Bổ sung | HOLD - Chờ thẩm quyền]
- Khu vuc: Miền Bắc | Dia chi: 56 Lý Thái Tổ, Đông Ngàn, TP Từ Sơn, Bắc Ninh | MST: 2300991122
- Diem thuc chung: **75/100** (Diem tu khai: 90/100)
- **Căn cứ đánh giá:**
  - tax_id: "Mã số thuế: 2300991122"
  - phone: "Điện thoại: 0987654321"
  - email: "minh@bepkinhbacplus.vn"
  - representative: "Người đại diện: Trần Văn Minh"
  - partner_name: "Tên đối tác: Công ty Thiết bị Nhà bếp Kinh Bắc Plus"
  - region: "Khu vực: Miền Bắc"
  - province: "Tỉnh/Thành: Bắc Ninh"
  - district: "Quận/Huyện: TP Từ Sơn"
  - ward: "Phường/Xã: Đông Ngàn"
  - pos_address: "Địa chỉ điểm bán: 56 Lý Thái Tổ, Đông Ngàn, TP Từ Sơn, Bắc Ninh"
  - showroom_area_m2: "Diện tích trưng bày: 85 m2"
  - warranty_technicians: "2 kỹ thuật viên"
  - warranty_notes: "Năng lực bảo hành: Có 2 kỹ thuật viên lắp đặt bếp từ và máy hút mùi."
  - monthly_purchase_vnd_million: "Kế hoạch nhập hàng: 300 triệu"
  - requested_credit_days: "Công nợ 30 ngày"
  - requested_credit_limit_vnd_million: "hạn mức công nợ 350 triệu"
  - requested_marketing_support_pct: "hỗ trợ thương mại 4.5%"
  - Verification (Vận hành - 2026-11-08): Mặt bằng Từ Sơn 85m2 và 2 KTV đạt; chờ Kinh doanh làm rõ quan hệ với Bếp Kinh Bắc và chờ Tài chính rà soát vốn.
  - Nearest POS: POS002 (Cửa hàng Bếp Kinh Bắc, TP Bắc Ninh) = 14.63 km
- **Điều kiện chưa đạt / Xung đột:**
  - Hạn mức công nợ đề nghị (350 triệu > 300 triệu) nhưng chưa có xác minh tài chính đạt chuẩn
  - Trùng số điện thoại (0987654321) với đối tác hiện tại DT002 (Cửa hàng Bếp Kinh Bắc)
  - Tên đối tác tương đồng (85%) với đối tác hiện tại DT002 (Cửa hàng Bếp Kinh Bắc)
- **Thông tin thiếu / chưa xác định:**
  - Khong co
- **Thông tin cần xác minh:**
  - [Bộ phận Kinh doanh] Xác minh pháp nhân, mã số thuế và quan hệ sở hữu với đối tác hệ thống
  - [Bộ phận Tài chính] Thẩm định báo cáo tài chính, khả năng thanh toán và điều chỉnh điều khoản công nợ về chuẩn chính sách
- **Bản nháp trao đổi với đối tác:**
  - Tieu de: `[Đại Thành] Đề nghị bổ sung hồ sơ & phối hợp xác minh - Công ty Thiết bị Nhà bếp Kinh Bắc Plus (HS008)`
```text
Kính gửi Quý đối tác Công ty Thiết bị Nhà bếp Kinh Bắc Plus (Người đại diện: Trần Văn Minh),

Phòng Phát triển Kinh doanh - Công ty Thiết bị Gia dụng Đại Thành đã tiếp nhận hồ sơ đăng ký đối tác HS008 tại khu vực Miền Bắc.

Để có đủ cơ sở trình Trưởng phòng Phát triển Kinh doanh và các bộ phận chuyên môn xem xét, kính đề nghị Quý đối tác phối hợp bổ sung/làm rõ các nội dung sau:

1. Các điều kiện chưa đạt hoặc cần điều chỉnh theo chính sách:
- Hạn mức công nợ đề nghị (350 triệu > 300 triệu) nhưng chưa có xác minh tài chính đạt chuẩn
- Trùng số điện thoại (0987654321) với đối tác hiện tại DT002 (Cửa hàng Bếp Kinh Bắc)
- Tên đối tác tương đồng (85%) với đối tác hiện tại DT002 (Cửa hàng Bếp Kinh Bắc)

2. Thông tin và bằng chứng cần xác minh thêm:
- [Bộ phận Kinh doanh] Xác minh pháp nhân, mã số thuế và quan hệ sở hữu với đối tác hệ thống
- [Bộ phận Tài chính] Thẩm định báo cáo tài chính, khả năng thanh toán và điều chỉnh điều khoản công nợ về chuẩn chính sách

Lưu ý: Các cam kết về sản lượng nhập hàng sẽ được ghi nhận cùng kết quả xác minh thực tế năng lực phục vụ khách hàng và chính sách công nợ của Công ty.

Vui lòng phản hồi trong vòng 05 ngày làm việc để chúng tôi tiếp tục xử lý hồ sơ.

Trân trọng,
Phòng Phát triển Kinh doanh - Công ty Thiết bị Gia dụng Đại Thành
```

### HS009 - Công ty TNHH Gia dụng Biển Đông [Bổ sung | HOLD - Chờ thẩm quyền]
- Khu vuc: Miền Trung | Dia chi: 190 Lê Hồng Phong, Phước Hòa, TP Nha Trang, Khánh Hòa | MST: 4201778899
- Diem thuc chung: **73/100** (Diem tu khai: 73/100)
- **Căn cứ đánh giá:**
  - tax_id: "Mã số thuế: 4201778899"
  - phone: "Điện thoại: 0905776655"
  - email: "hai@biendonggiadung.vn"
  - representative: "Người đại diện: Trương Công Hải"
  - partner_name: "Tên đối tác: Công ty TNHH Gia dụng Biển Đông"
  - region: "Khu vực: Miền Trung"
  - province: "Tỉnh/Thành: Khánh Hòa"
  - district: "Quận/Huyện: TP Nha Trang"
  - ward: "Phường/Xã: Phước Hòa"
  - pos_address: "Địa chỉ điểm bán: 190 Lê Hồng Phong, Phước Hòa, TP Nha Trang, Khánh Hòa"
  - showroom_area_m2: "Diện tích trưng bày: 110 m2"
  - warranty_technicians: "3 kỹ thuật viên"
  - warranty_notes: "Năng lực bảo hành: Có 3 kỹ thuật viên bảo hành gia dụng và xe giao lắp riêng."
  - monthly_purchase_vnd_million: "Kế hoạch nhập hàng: 450 triệu"
  - requested_credit_days: "Công nợ 35 ngày"
  - requested_credit_limit_vnd_million: "hạn mức công nợ 550 triệu"
  - requested_marketing_support_pct: "hỗ trợ thương mại 6%"
  - Verification (Kinh doanh + Vận hành + Tài chính - 2026-11-09): Mặt bằng 110m2 và 3 KTV đạt chuẩn; tài chính tốt nhưng đang đề nghị vượt trần công nợ 35 ngày / 550 triệu.
  - Nearest POS: POS006 (Trung tâm Điện máy Sài Gòn Xanh, Bình Thạnh) = 314.133 km
- **Điều kiện chưa đạt / Xung đột:**
  - Vượt chính sách số ngày công nợ (35 ngày > 30 ngày)
  - Vượt chính sách hạn mức công nợ (550 triệu > 500 triệu)
  - Vượt chính sách hỗ trợ thương mại (6% > 5.0%)
- **Thông tin thiếu / chưa xác định:**
  - Khong co
- **Thông tin cần xác minh:**
  - [Bộ phận Tài chính] Thẩm định báo cáo tài chính, khả năng thanh toán và điều chỉnh điều khoản công nợ về chuẩn chính sách
- **Bản nháp trao đổi với đối tác:**
  - Tieu de: `[Đại Thành] Đề nghị bổ sung hồ sơ & phối hợp xác minh - Công ty TNHH Gia dụng Biển Đông (HS009)`
```text
Kính gửi Quý đối tác Công ty TNHH Gia dụng Biển Đông (Người đại diện: Trương Công Hải),

Phòng Phát triển Kinh doanh - Công ty Thiết bị Gia dụng Đại Thành đã tiếp nhận hồ sơ đăng ký đối tác HS009 tại khu vực Miền Trung.

Để có đủ cơ sở trình Trưởng phòng Phát triển Kinh doanh và các bộ phận chuyên môn xem xét, kính đề nghị Quý đối tác phối hợp bổ sung/làm rõ các nội dung sau:

1. Các điều kiện chưa đạt hoặc cần điều chỉnh theo chính sách:
- Vượt chính sách số ngày công nợ (35 ngày > 30 ngày)
- Vượt chính sách hạn mức công nợ (550 triệu > 500 triệu)
- Vượt chính sách hỗ trợ thương mại (6% > 5.0%)

2. Thông tin và bằng chứng cần xác minh thêm:
- [Bộ phận Tài chính] Thẩm định báo cáo tài chính, khả năng thanh toán và điều chỉnh điều khoản công nợ về chuẩn chính sách

Lưu ý: Các cam kết về sản lượng nhập hàng sẽ được ghi nhận cùng kết quả xác minh thực tế năng lực phục vụ khách hàng và chính sách công nợ của Công ty.

Vui lòng phản hồi trong vòng 05 ngày làm việc để chúng tôi tiếp tục xử lý hồ sơ.

Trân trọng,
Phòng Phát triển Kinh doanh - Công ty Thiết bị Gia dụng Đại Thành
```

### HS010 - Công ty TNHH Phân phối Gia dụng Đồng Nai [Tiếp tục | P1 - Ưu tiên cao]
- Khu vuc: Miền Nam | Dia chi: 320 Phạm Văn Thuận, Thống Nhất, TP Biên Hòa, Đồng Nai | MST: 3603112233
- Diem thuc chung: **100/100** (Diem tu khai: 100/100)
- **Căn cứ đánh giá:**
  - tax_id: "Mã số thuế: 3603112233"
  - phone: "Điện thoại: 0919778899"
  - email: "thao.le@giadungdongnai.vn"
  - representative: "Người đại diện: Lê Thị Thu Thảo"
  - partner_name: "Tên đối tác: Công ty TNHH Phân phối Gia dụng Đồng Nai"
  - region: "Khu vực: Miền Nam"
  - province: "Tỉnh/Thành: Đồng Nai"
  - district: "Quận/Huyện: TP Biên Hòa"
  - ward: "Phường/Xã: Thống Nhất"
  - pos_address: "Địa chỉ điểm bán: 320 Phạm Văn Thuận, Thống Nhất, TP Biên Hòa, Đồng Nai"
  - showroom_area_m2: "Diện tích trưng bày: 150 m2"
  - warranty_technicians: "4 kỹ thuật viên"
  - warranty_notes: "Năng lực bảo hành: Trạm bảo hành nội bộ với 4 kỹ thuật viên được đào tạo, có kho linh kiện thay thế."
  - monthly_purchase_vnd_million: "Kế hoạch nhập hàng: 500 triệu"
  - requested_credit_days: "Công nợ 30 ngày"
  - requested_credit_limit_vnd_million: "hạn mức công nợ 450 triệu"
  - requested_marketing_support_pct: "hỗ trợ thương mại 4.5%"
  - Verification (Kinh doanh + Vận hành + Tài chính - 2026-11-09): Đã nghiệm thu showroom 150m2 Biên Hòa
  - Nearest POS: POS006 (Trung tâm Điện máy Sài Gòn Xanh, Bình Thạnh) = 22.282 km
- **Điều kiện chưa đạt / Xung đột:**
  - Khong co
- **Thông tin thiếu / chưa xác định:**
  - Khong co
- **Thông tin cần xác minh:**
  - Da hoan tat xac minh
- **Bản nháp trao đổi với đối tác:**
  - Tieu de: `[Đại Thành] Thông báo kết quả sơ duyệt hồ sơ đối tác - Công ty TNHH Phân phối Gia dụng Đồng Nai (HS010)`
```text
Kính gửi Quý đối tác Công ty TNHH Phân phối Gia dụng Đồng Nai (Người đại diện: Lê Thị Thu Thảo),

Phòng Phát triển Kinh doanh - Công ty Thiết bị Gia dụng Đại Thành trân trọng cảm ơn Quý đơn vị đã gửi hồ sơ đăng ký hợp tác phân phối tại khu vực Miền Nam.

Qua đối chiếu thông tin và xác minh bước đầu, hồ sơ HS010 của Quý đối tác đáp ứng các điều kiện cơ bản để chuyển sang bước đàm phán hợp tác (P1 - Ưu tiên cao).

Căn cứ ghi nhận:
- tax_id: "Mã số thuế: 3603112233"
- phone: "Điện thoại: 0919778899"
- email: "thao.le@giadungdongnai.vn"
- representative: "Người đại diện: Lê Thị Thu Thảo"

Đề xuất bước tiếp theo:
- Hai bên tiến hành trao đổi chi tiết phụ lục hợp đồng, danh mục sản phẩm và lịch nhập hàng đợt đầu.
- Bộ phận Kinh doanh sẽ liên hệ xác nhận lịch ký hợp đồng trong 02 ngày làm việc.
Trân trọng,
Phòng Phát triển Kinh doanh - Công ty Thiết bị Gia dụng Đại Thành
```

