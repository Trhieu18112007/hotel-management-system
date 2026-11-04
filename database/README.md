# Database – Quản lý Khách sạn & Nhà hàng (phần của T)

DBMS: **SQL Server**. Database: `QL_KhachSan_NhaHang`, collation `Vietnamese_CI_AS`.

## 1. Thứ tự chạy script (SSMS)
| # | File | Người phụ trách |
|---|------|-----------------|
| 0 | `00_reset_database.sql` (chỉ khi cần làm lại từ đầu) | T |
| 1 | `01_hotel_tables.sql` – tạo DB + 6 bảng khách sạn | T |
| 2 | `01b_hotel_sample_data.sql` – dữ liệu mẫu khách sạn | T |
| 3 | `02_restaurant_tables.sql` + dữ liệu mẫu nhà hàng | Hiền |
| 4 | `03_logic.sql` – view, trigger, procedure | Hiền |
| 5 | `01c_hotel_check.sql` – kiểm tra liên kết (chạy được bất cứ lúc nào) | T |

> `02_restaurant_tables.sql` phải chạy SAU `01` vì PHIEU_GOI_MON, HOA_DON tham chiếu NHAN_VIEN và PHIEU_THUE_PHONG.
> Dữ liệu mẫu 01b phải nạp TRƯỚC khi tạo trigger (03), vì trạng thái phòng đã được đặt sẵn cho khớp phiếu thuê.

## 2. Mật khẩu đăng nhập mẫu
Cột `MatKhauHash` đang là `CHO_BCRYPT`. Khang tạo hash bằng bcrypt rồi cập nhật:
```bash
npm i bcryptjs
node -e "console.log(require('bcryptjs').hashSync('123456',10))"
```
```sql
UPDATE NHAN_VIEN SET MatKhauHash = '<chuỗi hash vừa tạo>';
```
Tài khoản mẫu: `admin` (Quản lý), `letan1`, `letan2` (Lễ tân), `bep1` (Bếp).

## 3. Quy ước bắt buộc cho cả nhóm (chuỗi phải giữ NGUYÊN, có dấu)
| Bảng | Giá trị TrangThai |
|---|---|
| PHONG | `N'Trống'`, `N'Đang thuê'`, `N'Bảo trì'` |
| DAT_PHONG | `N'Đã đặt'`, `N'Đã nhận'`, `N'Đã hủy'` |
| PHIEU_THUE_PHONG | `N'Đang thuê'`, `N'Đã trả'` |
| NHAN_VIEN.VaiTro | `N'Quản lý'`, `N'Lễ tân'`, `N'Bếp'` |

Backend/procedure luôn truyền chuỗi Unicode (`sql.NVarChar`, tiền tố `N'...'`), nếu không sẽ mất dấu.

## 4. Lưu ý thiết kế dành cho Hiền (procedure/trigger) và Khang (API)
1. **Đặt phòng theo LOẠI, nhận phòng mới gán SỐ PHÒNG.** Vì vậy phòng không có trạng thái "Đã đặt".
2. **`PHIEU_THUE_PHONG.GiaThue`** là giá/đêm chụp lúc nhận phòng. `sp_NhanPhong` phải điền cột này từ `LOAI_PHONG.GiaMotDem`; `sp_TraPhong` tính tiền phòng bằng **GiaThue**, không lấy lại giá hiện tại của loại phòng.
3. **`sp_NhanPhong`** (trong 1 transaction): đơn phải `Đã đặt`; phòng phải `Trống` và cùng loại với đơn; INSERT phiếu (`TrangThai = N'Đang thuê'`, `NgayTraThucTe = NULL`); UPDATE đơn sang `Đã nhận`.
4. **`sp_TraPhong`**: UPDATE phiếu phải đặt **đồng thời** `NgayTraThucTe = GETDATE()` và `TrangThai = N'Đã trả'` (CHECK `CK_PTP_TrangThai` bắt buộc hai cột khớp nhau, nếu chỉ sửa một cột sẽ báo lỗi).
5. **Trigger trạng thái phòng**: chỉ đổi phòng về `Trống` khi phòng đang `Đang thuê` (đừng ghi đè phòng `Bảo trì`):
   `UPDATE PHONG SET TrangThai = N'Trống' WHERE MaPhong IN (SELECT MaPhong FROM inserted WHERE TrangThai = N'Đã trả') AND TrangThai = N'Đang thuê';`
6. **Kiểm tra còn phòng khi đặt** (`sp_DatPhong`), khoảng `[@NgayNhan, @NgayTra)`:
   - Số phòng của loại (trừ phòng `Bảo trì`) **>** số đơn cùng loại đang chiếm chỗ trong khoảng đó, gồm đơn `Đã đặt` và đơn `Đã nhận` có phiếu chưa trả, điều kiện trùng: `d.NgayNhan < @NgayTra AND d.NgayTra > @NgayNhan`.
   - Nên dùng `SET TRANSACTION ISOLATION LEVEL SERIALIZABLE` hoặc `WITH (UPDLOCK, HOLDLOCK)` để 2 người đặt cùng lúc không vượt số phòng.
   - `NgayNhan >= CAST(GETDATE() AS DATE)` kiểm tra trong procedure (không đặt trong CHECK).
7. **Xóa dữ liệu**: FK mặc định là NO ACTION nên khách/phòng/loại phòng đã có dữ liệu liên quan sẽ không xóa được (đúng ý muốn). API hãy bắt lỗi và báo "không thể xóa vì còn dữ liệu liên quan"; nếu cần ẩn khách thì dùng cột trạng thái, không xóa.
8. `HOA_DON.MaPhieu` phải **UNIQUE** (mỗi phiếu thuê một hóa đơn). `PHIEU_GOI_MON.MaNV` tham chiếu `NHAN_VIEN(MaNV)`.

## 5. Từ điển dữ liệu (dán vào báo cáo)
**NHAN_VIEN**: MaNV (PK, identity) · HoTen NVARCHAR(100) NOT NULL · TenDangNhap VARCHAR(50) UNIQUE · MatKhauHash VARCHAR(255) · VaiTro CHECK 3 giá trị · SDT 10–11 số · TrangThai BIT mặc định 1.

**KHACH_HANG**: MaKH (PK) · HoTen · CCCD VARCHAR(12) UNIQUE, CHECK 9 hoặc 12 chữ số · SDT CHECK 10–11 số, bắt đầu bằng 0 · Email CHECK dạng `x@y.z` hoặc NULL · DiaChi · NgayTao mặc định `GETDATE()`.

**LOAI_PHONG**: MaLoai (PK) · TenLoai UNIQUE · GiaMotDem CHECK > 0 · SoNguoiToiDa CHECK > 0 · MoTa.

**PHONG**: MaPhong (PK) · SoPhong UNIQUE · MaLoai (FK → LOAI_PHONG) · Tang CHECK > 0 · TrangThai CHECK 3 giá trị, mặc định `Trống`.

**DAT_PHONG**: MaDat (PK) · MaKH (FK → KHACH_HANG) · MaLoai (FK → LOAI_PHONG) · NgayDat mặc định `GETDATE()` · NgayNhan, NgayTra (CHECK NgayTra > NgayNhan) · TrangThai CHECK 3 giá trị, mặc định `Đã đặt`.

**PHIEU_THUE_PHONG**: MaPhieu (PK) · MaDat (FK → DAT_PHONG, UNIQUE) · MaPhong (FK → PHONG) · NgayNhanThucTe · NgayTraThucTe (NULL khi chưa trả) · GiaThue CHECK > 0 · TrangThai; CHECK trạng thái khớp ngày trả; unique index có lọc: mỗi phòng tối đa 1 phiếu `Đang thuê`.

**Chỉ mục**: IX_KH_SDT, IX_KH_HoTen, IX_PHONG_MaLoai, IX_PHONG_TrangThai, IX_DP_MaKH, IX_DP_Loai_Ngay, IX_PTP_MaPhong, UX_PTP_Phong_DangThue.

## 6. Giải thích chuẩn hóa (cho phần báo cáo / vấn đáp)
- **1NF**: mọi thuộc tính nguyên tố, không có nhóm lặp. Món ăn trong một lần gọi tách ra CHI_TIET_GOI_MON; các dòng hóa đơn tách ra CHI_TIET_HOA_DON; mỗi bảng có khóa chính.
- **2NF**: không có thuộc tính phụ thuộc một phần vào khóa. Ví dụ CHI_TIET_GOI_MON có khóa (MaGoiMon, MaMon), `SoLuong` phụ thuộc cả hai; tên món nằm ở MON_AN, không lặp ở chi tiết.
- **3NF**: không có phụ thuộc bắc cầu. `GiaMotDem` và `SoNguoiToiDa` phụ thuộc loại phòng, không phụ thuộc số phòng, nên tách LOAI_PHONG khỏi PHONG (đổi giá chỉ sửa một dòng). Thông tin khách chỉ lưu ở KHACH_HANG, các bảng khác tham chiếu bằng MaKH.
- **Cột lặp có chủ đích**: `GiaThue` (PHIEU_THUE_PHONG), `DonGia` (CHI_TIET_GOI_MON), `TongTien` (HOA_DON) lưu lại giá/tổng tại thời điểm giao dịch để lịch sử không đổi khi giá hiện hành thay đổi. Đây là quyết định nghiệp vụ, không phải vi phạm chuẩn hóa.

## 7. Cấu trúc GitHub và quy trình nhánh
```
hotel-restaurant/
├── database/   (các file .sql + README.md này)
├── backend/
├── frontend/
├── docs/       (ERD.png, báo cáo, ảnh test, Postman collection)
├── .gitignore
└── README.md
```
`.gitignore`:
```
node_modules/
.env
*.log
.vscode/
```
Lệnh thiết lập (T làm một lần):
```bash
git init
git add .
git commit -m "init: cấu trúc dự án + database khách sạn"
git branch -M main
git remote add origin https://github.com/<user>/hotel-restaurant.git
git push -u origin main
# tạo nhánh cho từng người
git checkout -b db-hien && git push -u origin db-hien
git checkout main && git checkout -b backend-khang && git push -u origin backend-khang
git checkout main && git checkout -b frontend-tai && git push -u origin frontend-tai
git checkout main && git checkout -b frontend-dang && git push -u origin frontend-dang
```
Quy tắc: không ai push thẳng vào `main`; mỗi người tạo Pull Request, T review rồi merge. Commit message có tiền tố `db:`, `api:`, `ui:`, `docs:`, `fix:`. Mỗi lần merge xong, mọi người `git pull origin main`. Bật Settings → Branches → Branch protection cho `main` (yêu cầu Pull Request).

## 8. Checklist bàn giao của T
- [ ] ERD xuất PNG/PDF từ `ERD_hotel_restaurant.mermaid` (dán vào https://mermaid.live → Actions → PNG/SVG), đưa vào `docs/`
- [ ] Chạy `00 → 01 → 01b` không lỗi
- [ ] `01c_hotel_check.sql`: Phần A trả 0 dòng, Phần B toàn PASS (chụp ảnh đưa vào báo cáo)
- [ ] Hiền xác nhận đã đọc mục 4
- [ ] Repo GitHub đã mời cả nhóm, đã bảo vệ nhánh `main`
- [ ] Sau khi có 02 và 03: chạy lại đủ thứ tự trên một server sạch để chắc chắn tích hợp được
