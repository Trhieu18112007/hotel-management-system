/**
 * MODULE KẾT NỐI API - RENAISSANCE RIVERSIDE HOTEL SAIGON
 * Dành cho tích hợp với Backend của Thành viên 3
 */

const API_CONFIG = {
    BASE_URL: 'http://localhost:8080/api', // Đổi port theo server của Thành viên 3 (VD: 3000, 5000, 8080)
    USE_MOCK: true // Đổi thành false khi ghép nối thật với Backend của Thành viên 3
};

// Dữ liệu khởi tạo chuẩn 5 sao khi chạy chế độ Mock
const INITIAL_MOCK_DATA = {
    rooms: [
        { id: 'R1001', number: '1801', type: 'Deluxe River View', price: 4200000, floor: 18, status: 'AVAILABLE' },
        { id: 'R1002', number: '1905', type: 'Executive Studio', price: 6500000, floor: 19, status: 'OCCUPIED' },
        { id: 'R1003', number: '2008', type: 'R-Club Premier Room', price: 5400000, floor: 20, status: 'RESERVED' },
        { id: 'R1004', number: '2101', type: 'Presidential Suite', price: 18500000, floor: 21, status: 'OCCUPIED' },
        { id: 'R1005', number: '1804', type: 'Deluxe City View', price: 3600000, floor: 18, status: 'AVAILABLE' },
        { id: 'R1006', number: '1702', type: 'Deluxe River View', price: 4200000, floor: 17, status: 'MAINTENANCE' }
    ],
    customers: [
        { id: 'C001', name: 'Nguyễn Minh Hoàng', phone: '0908123456', cccd: '079098001234', email: 'hoang.nm@luxurycorp.vn', tier: 'Marriott Bonvoy Titanium' },
        { id: 'C002', name: 'Trần Ngọc Bảo Trâm', phone: '0919888999', cccd: '079199005678', email: 'tram.tran@saigoncapital.com', tier: 'Marriott Bonvoy Gold' },
        { id: 'C003', name: 'Alexander Wright', phone: '0933445566', cccd: 'B98127361', email: 'a.wright@globalinvest.uk', tier: 'Marriott Bonvoy Ambassador' }
    ],
    bookings: [
        {
            id: 'BK-261101',
            customerId: 'C001',
            customerName: 'Nguyễn Minh Hoàng',
            roomId: 'R1002',
            roomNumber: '1905',
            roomType: 'Executive Studio',
            checkIn: '2026-11-12',
            checkOut: '2026-11-15',
            totalPrice: 19500000,
            status: 'CHECKED_IN' // RESERVED | CHECKED_IN | CHECKED_OUT
        },
        {
            id: 'BK-261102',
            customerId: 'C002',
            customerName: 'Trần Ngọc Bảo Trâm',
            roomId: 'R1003',
            roomNumber: '2008',
            roomType: 'R-Club Premier Room',
            checkIn: '2026-11-14',
            checkOut: '2026-11-16',
            totalPrice: 10800000,
            status: 'RESERVED'
        },
        {
            id: 'BK-261103',
            customerId: 'C003',
            customerName: 'Alexander Wright',
            roomId: 'R1004',
            roomNumber: '2101',
            roomType: 'Presidential Suite',
            checkIn: '2026-11-13',
            checkOut: '2026-11-17',
            totalPrice: 74000000,
            status: 'CHECKED_IN'
        }
    ]
};

class HotelApiService {
    constructor() {
        if (!localStorage.getItem('RRHS_DB')) {
            localStorage.setItem('RRHS_DB', JSON.stringify(INITIAL_MOCK_DATA));
        }
    }

    getLocalDB() {
        return JSON.parse(localStorage.getItem('RRHS_DB'));
    }

    saveLocalDB(db) {
        localStorage.setItem('RRHS_DB', JSON.stringify(db));
    }

    async request(endpoint, method = 'GET', body = null) {
        const headers = { 'Content-Type': 'application/json' };
        const token = localStorage.getItem('RRHS_TOKEN');
        if (token) headers['Authorization'] = `Bearer ${token}`;

        const config = { method, headers };
        if (body) config.body = JSON.stringify(body);

        const response = await fetch(`${API_CONFIG.BASE_URL}${endpoint}`, config);
        if (!response.ok) throw new Error(`API Error: ${response.status}`);
        return await response.json();
    }

    // 1. ĐĂNG NHẬP
    async login(username, password) {
        if (!API_CONFIG.USE_MOCK) {
            return await this.request('/auth/login', 'POST', { username, password });
        }
        if (username && password) {
            const user = { username, role: 'Front Desk Manager', hotel: 'Renaissance Riverside Hotel Saigon' };
            localStorage.setItem('RRHS_TOKEN', 'mock-jwt-token-5star');
            return { success: true, user };
        }
        throw new Error('Thông tin đăng nhập không hợp lệ');
    }

    // 2. QUẢN LÝ PHÒNG
    async getRooms() {
        if (!API_CONFIG.USE_MOCK) return await this.request('/rooms');
        return this.getLocalDB().rooms;
    }

    async saveRoom(roomData) {
        if (!API_CONFIG.USE_MOCK) {
            return roomData.id
                ? await this.request(`/rooms/${roomData.id}`, 'PUT', roomData)
                : await this.request('/rooms', 'POST', roomData);
        }
        const db = this.getLocalDB();
        if (roomData.id) {
            const idx = db.rooms.findIndex(r => r.id === roomData.id);
            if (idx > -1) db.rooms[idx] = { ...db.rooms[idx], ...roomData };
        } else {
            roomData.id = 'R' + Math.floor(1000 + Math.random() * 9000);
            db.rooms.push(roomData);
        }
        this.saveLocalDB(db);
        return roomData;
    }

    async deleteRoom(id) {
        if (!API_CONFIG.USE_MOCK) return await this.request(`/rooms/${id}`, 'DELETE');
        const db = this.getLocalDB();
        db.rooms = db.rooms.filter(r => r.id !== id);
        this.saveLocalDB(db);
        return { deleted: true };
    }

    // 3. QUẢN LÝ KHÁCH HÀNG
    async getCustomers() {
        if (!API_CONFIG.USE_MOCK) return await this.request('/customers');
        return this.getLocalDB().customers;
    }

    async saveCustomer(customerData) {
        if (!API_CONFIG.USE_MOCK) {
            return customerData.id
                ? await this.request(`/customers/${customerData.id}`, 'PUT', customerData)
                : await this.request('/customers', 'POST', customerData);
        }
        const db = this.getLocalDB();
        if (customerData.id) {
            const idx = db.customers.findIndex(c => c.id === customerData.id);
            if (idx > -1) db.customers[idx] = { ...db.customers[idx], ...customerData };
        } else {
            customerData.id = 'C00' + (db.customers.length + 1);
            db.customers.push(customerData);
        }
        this.saveLocalDB(db);
        return customerData;
    }

    // 4. ĐẶT PHÒNG & NHẬN/TRẢ PHÒNG
    async getBookings() {
        if (!API_CONFIG.USE_MOCK) return await this.request('/bookings');
        return this.getLocalDB().bookings;
    }

    async createBooking(bookingPayload) {
        if (!API_CONFIG.USE_MOCK) return await this.request('/bookings', 'POST', bookingPayload);
        const db = this.getLocalDB();
        const customer = db.customers.find(c => c.id === bookingPayload.customerId);
        const room = db.rooms.find(r => r.id === bookingPayload.roomId);

        const newBooking = {
            id: 'BK-' + Math.floor(100000 + Math.random() * 900000),
            customerId: customer.id,
            customerName: customer.name,
            roomId: room.id,
            roomNumber: room.number,
            roomType: room.type,
            checkIn: bookingPayload.checkIn,
            checkOut: bookingPayload.checkOut,
            totalPrice: bookingPayload.totalPrice,
            status: 'RESERVED'
        };

        room.status = 'RESERVED';
        db.bookings.unshift(newBooking);
        this.saveLocalDB(db);
        return newBooking;
    }

    async processCheckIn(bookingId) {
        if (!API_CONFIG.USE_MOCK) return await this.request(`/bookings/${bookingId}/checkin`, 'PUT');
        const db = this.getLocalDB();
        const bk = db.bookings.find(b => b.id === bookingId);
        if (bk) {
            bk.status = 'CHECKED_IN';
            const room = db.rooms.find(r => r.id === bk.roomId);
            if (room) room.status = 'OCCUPIED';
            this.saveLocalDB(db);
        }
        return bk;
    }

    async processCheckOut(bookingId) {
        if (!API_CONFIG.USE_MOCK) return await this.request(`/bookings/${bookingId}/checkout`, 'PUT');
        const db = this.getLocalDB();
        const bk = db.bookings.find(b => b.id === bookingId);
        if (bk) {
            bk.status = 'CHECKED_OUT';
            const room = db.rooms.find(r => r.id === bk.roomId);
            if (room) room.status = 'AVAILABLE';
            this.saveLocalDB(db);
        }
        return bk;
    }
}

window.apiService = new HotelApiService();
