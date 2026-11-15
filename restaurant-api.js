/* =====================================================================
 * js/restaurant-api.js  —  Lớp kết nối API backend của Khang (phần Đăng)
 * Dùng chung cho: menu.html, order.html, invoice.html, checkout.html
 *
 * Mọi chuyện "tên cột DB" nằm trong 3 hàm chuẩn hóa ở mục SCHEMA bên dưới.
 * Nếu bảng của Hiền đặt tên cột khác, chỉ cần sửa đúng ở đó.
 * ===================================================================== */
(function () {
    // Đổi nếu backend chạy cổng/host khác (hoặc đặt window.API_BASE trước khi nạp file này)
    const API_BASE = window.API_BASE || 'http://localhost:3000/api';

    async function request(path, options = {}) {
        let res;
        try {
            res = await fetch(API_BASE + path, {
                headers: { 'Content-Type': 'application/json' },
                ...options,
                body: options.body !== undefined ? JSON.stringify(options.body) : undefined
            });
        } catch (e) {
            throw new Error('Không kết nối được máy chủ (' + API_BASE + '). Hãy kiểm tra backend đã chạy chưa!');
        }
        let data = null;
        try { data = await res.json(); } catch (_) { /* phản hồi không có body */ }
        if (!res.ok) throw new Error((data && data.error) || ('Lỗi máy chủ (' + res.status + ')'));
        return data;
    }

    // ------------------------- SCHEMA (chuẩn hóa dữ liệu) -------------------------
    function normDish(r) {
        const st = r.TrangThai;
        let available = true;
        if (typeof st === 'boolean' || typeof st === 'number') available = !!st;
        else if (typeof st === 'string') available = !/hết|ngừng|không|unavail/i.test(st);
        return {
            id: r.MaMon,
            name: r.TenMon || r.TenMonAn || '',
            category: r.LoaiMon || r.PhanLoai || r.NhomMon || 'Món Chính',
            price: Number(r.DonGia != null ? r.DonGia : (r.Gia || 0)),
            status: available ? 'AVAILABLE' : 'UNAVAILABLE'
        };
    }
    function dishPayload(d) {
        return { TenMon: d.name, LoaiMon: d.category, DonGia: d.price, TrangThai: d.status === 'AVAILABLE' ? 'Còn bán' : 'Ngừng bán' };
    }
    const isPaidText = (s) => /đã thanh toán|da thanh toan|paid/i.test(String(s || ''));
    function normInvoiceRow(r) {
        return {
            maPhieu: r.MaPhieu,
            maHD: r.MaHD || null,
            customerName: r.HoTen,
            roomNumber: r.SoPhong,
            roomType: r.TenLoai,
            start: r.NgayNhanThucTe,
            end: r.NgayTraThucTe,
            roomTotal: Number(r.TienPhong || 0),
            foodTotal: Number(r.TienNhaHang || 0),
            foodCount: Number(r.SoLuotGoi || 0),
            stayStatus: r.TrangThaiPhieu,          // 'Đang thuê' | 'Đã trả'
            paid: !!r.MaHD && isPaidText(r.TrangThaiHD)
        };
    }
    function normDetailLine(r) {
        const qty = Number(r.SoLuong || 0), price = Number(r.DonGia || 0);
        return { time: r.NgayGoi, name: r.TenMon, quantity: qty, price: price,
                 total: Number(r.ThanhTien != null ? r.ThanhTien : qty * price) };
    }
    // -------------------------------------------------------------------------------

    // Mã nhân viên đang đăng nhập (do trang đăng nhập của Tài lưu). Không có thì backend tự chọn nhân viên hợp lệ.
    function getStaffId() {
        for (const store of [window.localStorage, window.sessionStorage]) {
            for (const key of ['nhanVien', 'currentUser', 'user', 'staff']) {
                try {
                    const o = JSON.parse(store.getItem(key) || 'null');
                    const id = o && (o.MaNV || o.maNV || o.id);
                    if (id && !isNaN(Number(id))) return Number(id);
                } catch (_) { /* bỏ qua */ }
            }
        }
        return undefined;
    }

    const fmtDate = (v) => v ? new Date(v).toLocaleString('vi-VN') : '-';
    const esc = (v) => String(v == null ? '' : v).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
    const fmtMoney = (n) => Number(n || 0).toLocaleString('vi-VN') + ' ₫';

    window.restaurantApi = {
        API_BASE, fmtDate, fmtMoney, esc,

        // ---- Thực đơn (menu.html, order.html)
        async getMenu() { return (await request('/mon-an')).map(normDish); },
        createDish(d)   { return request('/mon-an', { method: 'POST', body: dishPayload(d) }); },
        updateDish(d)   { return request('/mon-an/' + encodeURIComponent(d.id), { method: 'PUT', body: dishPayload(d) }); },
        deleteDish(id)  { return request('/mon-an/' + encodeURIComponent(id), { method: 'DELETE' }); },

        // ---- Gọi món (order.html): phòng đang có khách = phiếu thuê 'Đang thuê'
        async getStayingGuests() {
            const rows = await request('/phieu-thue');
            return rows.filter(r => r.TrangThai === 'Đang thuê').map(r => ({
                maPhieu: r.MaPhieu, roomNumber: r.SoPhong, customerName: r.HoTen, roomType: r.TenLoai
            }));
        },
        // Một lần gọi sp_GoiMon cho cả giỏ món (route nằm trong restaurant.routes.js)
        orderDishes(maPhieu, cart) {
            return request('/goi-mon-nhieu', { method: 'POST', body: {
                MaPhieu: maPhieu, MaNV: getStaffId(),
                Mon: cart.map(i => ({ MaMon: i.id, SoLuong: i.quantity }))
            } });
        },

        // ---- Hóa đơn (invoice.html, checkout.html)
        async getInvoiceSummary() { return (await request('/hoa-don/tong-hop')).map(normInvoiceRow); },
        async getInvoiceDetail(maPhieu) { return (await request('/hoa-don/phieu/' + encodeURIComponent(maPhieu) + '/chi-tiet')).map(normDetailLine); },
        traPhong(maPhieu)  { return request('/tra-phong-hd', { method: 'POST', body: { MaPhieu: maPhieu, MaNV: getStaffId() } }); },
        thanhToan(maHD, phuongThuc) { return request('/thanh-toan', { method: 'POST', body: { MaHD: maHD, PhuongThuc: phuongThuc } }); }
    };
})();
