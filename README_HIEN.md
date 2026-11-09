# Phần của Hiền — Database nhà hàng và nghiệp vụ SQL

Bộ bàn giao dùng SQL Server 2016 SP1 trở lên (CREATE OR ALTER), ghép với database `QL_KhachSan_NhaHang` . Giữ nguyên 6 bảng khách sạn, tên cột và chuỗi Unicode của bộ nguồn. Năm bảng mới khớp ERD đã cung cấp.

## File và thứ tự chạy trong SSMS

Chạy trên database phát triển/thử nghiệm. Các file tạo bảng và dữ liệu mẫu chỉ chạy một lần; `03_logic.sql` có thể chạy lại nếu cấu trúc type DanhSachMon chưa thay đổi.

1. File: `01_hotel_tables.sql`.
2. File: `01b_hotel_sample_data.sql` (trước khi tạo trigger).
3. `02_restaurant_tables.sql`: 5 bảng, PK, FK, UNIQUE, NOT NULL, CHECK và index.
4. `02b_restaurant_sample_data.sql`: 8 món, 3 phiếu gọi món, 3 hóa đơn và chi tiết.
5. `03_logic.sql`: 3 view, 2 trigger, type danh sách món và 5 procedure.
6. `04_queries.sql`: SELECT, INSERT, UPDATE, DELETE, JOIN, GROUP BY, HAVING, ORDER BY và doanh thu. Ví dụ sửa dữ liệu tự rollback.
7. `05_tests.sql`: 9 ca kiểm thử, mỗi ca tự rollback; lỗi ngoài dự kiến được THROW.
8. File: `01c_hotel_check.sql` để kiểm tra lại phần khách sạn.

Không cần chạy file reset để ghép phần Hiền. File reset của T xóa toàn bộ database, chỉ dùng khi chủ động làm lại dữ liệu thử nghiệm. Nếu đã có trigger từ lần trước thì cần môi trường sạch trước khi nạp lại 01b.

## Thiết kế

- MON_AN: mã identity, tên duy nhất, giá dương, loại món bắt buộc, trạng thái Còn bán hoặc Ngừng bán.
- PHIEU_GOI_MON: tham chiếu phiếu thuê và nhân viên; lưu ngày gọi.
- CHI_TIET_GOI_MON: PK ghép (MaGoiMon, MaMon), số lượng dương; DonGia chụp tại lúc gọi.
- HOA_DON: MaPhieu UNIQUE, mỗi phiếu thuê tối đa một hóa đơn; nhân viên lập, ngày lập, tổng tiền và trạng thái.
- CHI_TIET_HOA_DON: dòng Phòng hoặc Món; ThanhTien là cột tính toán lưu trữ từ số lượng và đơn giá, không nhập trực tiếp.

Tiền dùng DECIMAL, không dùng FLOAT. Không xóa dây chuyền các giao dịch. Trigger tổng tiền hỗ trợ INSERT, UPDATE, DELETE nhiều dòng và cập nhật cả hóa đơn cũ lẫn mới khi chuyển MaHD. Chi tiết hóa đơn đã thanh toán bị chặn sửa.

## View và trigger

| Đối tượng | Công dụng |
|---|---|
| vw_TrangThaiPhong | Phòng, loại phòng, giá hiện tại, trạng thái |
| vw_HoaDon | Khách, nhân viên, số phòng, tiền phòng, tiền món, tổng hóa đơn |
| vw_DoanhThu | Tổng hóa đơn đã thanh toán theo ngày lập hóa đơn |
| trg_TrangThaiPhong | Đồng bộ trạng thái khi thêm, sửa hoặc xóa phiếu thuê; không ghi đè Bảo trì khi trả phòng |
| trg_TongTienHoaDon | Cộng lại tổng khi thay đổi chi tiết; bảo vệ hóa đơn đã thanh toán |

## Quy ước nghiệp vụ

Đặt theo loại phòng, nhận phòng mới gán số phòng. Đơn phải còn Đã đặt; ngày hiện tại nằm trong [NgayNhan, NgayTra); phòng Trống và đúng loại. Không hỗ trợ nhận sớm hoặc gia hạn trong bộ procedure này.

Sức chứa loại phòng loại trừ phòng Bảo trì. Đơn Đã đặt và đơn Đã nhận còn phiếu thuê được tính theo khoảng giao nhau. Đặt cho hôm nay còn tính phiếu thuê quá hạn chưa trả. Phương pháp đếm tất cả đơn giao nhau là cách bảo thủ theo README của nhóm: có thể từ chối một khoảng dài dù những đơn giao nhau không chiếm phòng cùng lúc. Khách quá hạn có thể ảnh hưởng đặt tương lai; nhóm cần quy trình gia hạn riêng nếu triển khai thực tế.

Cả 5 procedure dùng transaction, XACT_ABORT, TRY/CATCH và khóa ứng dụng QLKS_NghiepVu để tuần tự hóa nghiệp vụ. Chọn cách này cho bài tập nhóm để tránh hai yêu cầu cùng giành phòng hoặc gọi món đúng lúc trả phòng. Lỗi sẽ rollback toàn bộ transaction hiện hành, kể cả transaction do bên gọi mở; backend nên gọi từng procedure độc lập.

Trả phòng đặt đồng thời NgayTraThucTe và trạng thái Đã trả, lập hóa đơn chưa thanh toán, sao chép toàn bộ món đã gọi. Tiền phòng lấy GiaThue, số đêm bằng chênh lệch ngày lịch và tối thiểu một đêm; không làm tròn theo khối 24 giờ. Chưa tính VAT, giảm giá, đặt cọc hoặc phụ thu. Chỉ thanh toán sau khi trả phòng. Không gọi món sau khi đã lập hóa đơn.

Doanh thu hiện tính theo ngày lập hóa đơn đã thanh toán vì ERD không có NgayThanhToan. Đây không phải thống kê dòng tiền theo ngày thực thu. Nếu thanh toán sang ngày khác, doanh thu vẫn thuộc ngày lập hóa đơn.

Backend phải dùng tài khoản chỉ có SELECT trên view và EXECUTE procedure; không cấp sửa trực tiếp các bảng giao dịch. Hai trigger không thay thế toàn bộ kiểm tra của procedure. Nếu cấp quyền sửa bảng tùy ý, người dùng có thể bỏ qua quy trình lập hóa đơn và khóa nghiệp vụ.

## Giao diện dành cho Khang

| Procedure | Tham số vào | Tham số OUTPUT |
|---|---|---|
| dbo.sp_DatPhong | @MaKH INT, @MaLoai INT, @NgayNhan DATE, @NgayTra DATE | @MaDat INT |
| dbo.sp_NhanPhong | @MaDat INT, @MaPhong INT | @MaPhieu INT |
| dbo.sp_GoiMon | @MaPhieu INT, @MaNV INT, @Mon dbo.DanhSachMon READONLY | @MaGoiMon INT |
| dbo.sp_TraPhong | @MaPhieu INT, @MaNV INT | @MaHD INT |
| dbo.sp_ThanhToanHoaDon | @MaHD INT | Không có |

Lấy mã mới từ OUTPUT, không dùng RETURN. @Mon có 2 cột MaMon INT và SoLuong INT, mỗi mã món chỉ một dòng, số lượng > 0. Ví dụ T-SQL (cần thay mã phiếu, nhân viên và món cho đúng dữ liệu):

```sql
DECLARE @mon dbo.DanhSachMon, @goi INT;
INSERT @mon(MaMon,SoLuong) VALUES(1,2),(5,1);
EXEC dbo.sp_GoiMon @MaPhieu=3,@MaNV=2,@Mon=@mon,@MaGoiMon=@goi OUTPUT;
SELECT @goi AS MaGoiMon;
```

Với Node mssql, tạo `new sql.Table('dbo.DanhSachMon')`, thêm hai cột `sql.Int`, thêm các dòng rồi truyền `.input('Mon', table)`. Các mã khác dùng sql.Int, ngày dùng sql.Date và tham số ra dùng `.output('MaGoiMon', sql.Int)`. API cần xác thực người gọi và gắn MaNV từ phiên đăng nhập, không tin MaNV tùy ý từ trình duyệt. Việc kiểm tra VaiTro trong SQL chỉ áp dụng cho nhân viên lập hóa đơn; phân quyền đặt phòng/nhận phòng/gọi món do backend xử lý.

Lỗi nghiệp vụ dùng THROW 51001–51110. Backend bắt lỗi, trả thông báo phù hợp; lỗi khóa 51100 có thể thử lại. Deadlock 1205 từ các thao tác trực tiếp ngoài procedure cũng cần thử lại ở backend. Không gửi nguyên lỗi hạ tầng hoặc thông tin đăng nhập cho giao diện.

## Kiểm thử và kết quả

Xem `KET_QUA_KIEM_TRA.md`. Cú pháp đã được kiểm tra bằng bộ phân tích T-SQL. Ngày 09/11/2026, đã chạy thành công 9 ca kiểm thử trong `05_tests.sql` trên SQL Server .\SQLEXPRESS, database `QL_KhachSan_NhaHang`. Ảnh chụp tab Messages hiển thị đầy đủ PASS 01–09 và thông báo Query executed successfully. Hai truy vấn kiểm tra hóa đơn sai tổng và phòng sai trạng thái trả về 0 dòng. Kiểm thử hai giao dịch đặt phòng đồng thời chưa thực hiện.

