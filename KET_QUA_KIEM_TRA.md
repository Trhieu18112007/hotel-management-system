# Kết quả kiểm tra phần của Hiền

## Đã thực hiện

Ngày 09/11/2026: đọc bảng phân công, README, ERD và DDL/dữ liệu khách sạn để đối chiếu tên bảng, cột, FK, giá và trạng thái.

Kiểm tra cú pháp 5 file SQL bằng Microsoft ScriptDom TSql110Parser: 0 lỗi mỗi file. Khi kiểm tra đã đổi riêng chuỗi CREATE OR ALTER thành CREATE trong bộ nhớ vì parser SQL Server 2012 không hỗ trợ cú pháp mới này; file bàn giao giữ CREATE OR ALTER và yêu cầu SQL Server 2016 SP1 trở lên. Kiểm tra cú pháp không xác nhận tên đối tượng, kiểu dữ liệu, transaction hoặc kết quả nghiệp vụ thực tế.

Ngày 09/11/2026, người thực hiện đã chạy `05_tests.sql` trong SSMS trên SQL Server .\SQLEXPRESS (phiên bản hiển thị 17.0.1000), database `QL_KhachSan_NhaHang`. Ảnh chụp tab Messages ghi nhận đầy đủ PASS 01 đến PASS 09, thời gian hoàn tất 16:10:49 (UTC+07:00) và thông báo Query executed successfully. Kết quả dưới đây được xác nhận từ ảnh chụp thực thi do người thực hiện cung cấp.

## Kết quả 9 ca kiểm thử trong 05_tests.sql

| Ca | Nội dung | Kết quả kỳ vọng | Trạng thái |
|---|---|---|---|
| 01 | 5 procedure xuyên suốt; giá phòng/món thay đổi; 3 view; trigger thêm/sửa/xóa nhiều dòng | 123000 tiền phòng + 40000 tiền món; doanh thu tăng 163000 khi thanh toán; cuối ca rollback | Đạt |
| 02 | Trả phòng đang Bảo trì | Giữ nguyên Bảo trì | Đạt |
| 03 | Đặt ngày quá khứ | Lỗi 51101, rollback | Đạt |
| 04 | Hai đơn trùng ngày cho loại chỉ có một phòng | Lỗi 51103, rollback | Đạt |
| 05 | Nhận phòng với mã không tồn tại | Lỗi 51104 | Đạt |
| 06 | Gọi món Ngừng bán | Lỗi 51107; không tạo phiếu dở dang | Đạt |
| 07 | Lỗi tràn số phát sinh sau khi cập nhật trả phòng và tạo hóa đơn | Lỗi 8115; khôi phục phiếu, phòng và hóa đơn | Đạt |
| 08 | Thanh toán hóa đơn đã thanh toán | Lỗi 51110 | Đạt |
| 09 | Sửa chi tiết hóa đơn đã thanh toán | Lỗi 51003 | Đạt |

Ảnh chụp Results xác nhận hai truy vấn bất biến ở giữa script đều trả về 0 dòng: không phát hiện hóa đơn sai tổng hoặc phòng sai trạng thái. Script giả định không có người khác đồng thời sửa dữ liệu khi chạy kiểm thử; các ca rollback không hoàn lại bộ đếm IDENTITY.

## Dữ liệu mẫu dự kiến sau 02b

- 8 món, 3 phiếu gọi món, 5 dòng gọi món.
- 3 hóa đơn, 6 dòng chi tiết hóa đơn.
- Phiếu thuê 1: hóa đơn 1730000, đã thanh toán.
- Phiếu thuê 2: hóa đơn 2220000, đã thanh toán.
- Phiếu thuê 6: hóa đơn 1400000, chưa thanh toán.
- Doanh thu đã thanh toán: 3950000; tổng cả ba hóa đơn: 5350000.

Ảnh chụp kết quả truy vấn xác nhận ba hóa đơn lần lượt là 1730000, 2220000 và 1400000, tổng doanh thu đã thanh toán là 3950000; phù hợp với giá trị đối chiếu của dữ liệu mẫu. Tổng cả ba hóa đơn tính từ các giá trị hiển thị là 5350000.

## Kiểm thử đồng thời cần thực hiện thêm trên SSMS

Mở hai cửa sổ kết nối cùng database thử nghiệm. Tạo riêng một loại chỉ có một phòng. Ở cửa sổ A, BEGIN TRAN rồi gọi sp_DatPhong cho hôm nay–ngày mai, giữ transaction mở. Ở B, gọi cùng procedure cho cùng khoảng ngày. B phải chờ; COMMIT ở A trong vòng 10 giây thì B phải trả lỗi hết phòng 51103. Nếu A giữ khóa quá 10 giây thì B trả lỗi 51100. Dọn dữ liệu thử sau khi kiểm tra. Ca này chưa được chạy.

Đã có ảnh chụp Messages của 05_tests.sql, kết quả truy vấn và view, cùng kết quả Results của 01c_hotel_check.sql. Giữ các ảnh này làm minh chứng bàn giao. Kiểm thử đồng thời vẫn ở trạng thái Chưa chạy; chỉ cập nhật sau khi thực hiện và quan sát kết quả thực tế.

