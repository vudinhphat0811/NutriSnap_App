# NutriSnap - Developer & Agent Guidelines

## 1. Công Nghệ & Giới Hạn Cốt Lõi (Strict Technology Rules)
- **Frontend**: Flutter / Dart 100%.
- **Backend**: C# .NET 8 Web API 100%.
- **Quy tắc**: Tuyệt đối không thêm ngôn ngữ khác (Python, Node.js, v.v.).

---

## 2. Quy Tắc Thiết Kế UI/UX & Xử Lý Tràn Chữ (Text Overflow & Responsive Layout Guidelines)

Khi phát triển ứng dụng di động trên màn hình có bề ngang hẹp (360px - 410px), các trường hợp văn bản bị tràn (`RenderFlex overflowed`) hoặc bị cắt cụt dấu ba chấm (`...`) thường xảy ra khi đưa quá nhiều thông tin động vào cùng 1 dòng (`Row`).

Dưới đây là **5 giải pháp chuẩn** cần áp dụng theo từng ngữ cảnh:

### 🌟 Giải Pháp 1: Tách cấu trúc 2 tầng (Two-Tier Hierarchy - Khuyên Dùng Nhất)
**Khi nào dùng:** Khi có tiêu đề danh mục dài đi kèm tên biến động (như tên món ăn, tên nguyên liệu) và các badge/nút phụ.
- **Tầng 1 (Dòng trên):** Tiêu đề chính + Badge / Nguồn dữ liệu (ví dụ: `🍴 Matching Recipes` và badge `TheMealDB`).
- **Tầng 2 (Dòng dưới):** Hiển thị dữ liệu biến động dưới dạng Subtitle hoặc Chip Tag riêng biệt (ví dụ: `Nguyên liệu: [🥩 Thịt heo nạc]`).
- **Ưu điểm:** Cực kỳ thoáng đãng, dữ liệu không bao giờ bị cắt ngắn cụt lủn, nhìn rất chuyên nghiệp.

### 🛡️ Giải Pháp 2: Luôn bọc Text trong `Expanded` hoặc `Flexible` khi nằm trong `Row`
- Mọi `Text` nằm trong `Row` có nguy cơ dài phải được bọc trong `Expanded` hoặc `Flexible`.
- Sử dụng `overflow: TextOverflow.ellipsis` để tránh vỡ màn hình vàng-đen.
- **Lưu ý:** Không lồng các `Row` không có ràng buộc kích thước (`unconstrained Row`) bên trong `Row` khác.

### 🔀 Giải Pháp 3: Sử dụng `Wrap` thay cho `Row` cho các Badge / Tags
- Khi hiển thị danh sách các nhãn, thẻ filter, nguyên liệu: dùng `Wrap(spacing: 8, runSpacing: 6, children: [...])`.
- Khi màn hình hẹp hoặc text dài, các phần tử tự động rớt xuống dòng tiếp theo mà không làm vỡ bố cục.

### 📖 Giải Pháp 4: Cho phép đa dòng tự nhiên (`maxLines: 2` hoặc không giới hạn)
- Với các văn bản quan trọng người dùng bắt buộc phải đọc hết (như tên món ăn, mô tả calo, hướng dẫn nấu), không ép `maxLines: 1`.
- Đặt `maxLines: 2` kết hợp `overflow: TextOverflow.ellipsis` và `crossAxisAlignment: CrossAxisAlignment.start` cho `Row`.

### ✂️ Giải Pháp 5: Tối ưu hóa chuỗi dịch thuật (Microcopy Optimization)
- Viết chuỗi văn bản súc tích, ngắn gọn, tự nhiên:
  - ❌ Tránh: `"Matching Recipe Suggestions ("Thịt heo nạc")"` (quá dài, > 45 ký tự)
  - ✅ Nên dùng: `"Món ngon từ:"` / `"Recipes for:"` hoặc tách riêng tên nguyên liệu ra hàng dưới.

### 💡 Giải Pháp 6: Hiệu ứng chữ chạy LED (MarqueeText / LED Running Banner)
- **Khi nào dùng:** Khi bố cục bắt buộc cố định 1 dòng nhưng tên món ăn, tên nguyên liệu hoặc tiêu đề dài hơn không gian chứa và người dùng cần đọc trọn vẹn.
- **Cách dùng:** Sử dụng widget `MarqueeText(text: ...)` nằm tại [`lib/widgets/marquee_text.dart`](file:///c:/Users/PHAT/Downloads/NutriSnap_App/frontend/lib/widgets/marquee_text.dart).
- **Ưu điểm:** Nếu chữ ngắn thì đứng yên tĩnh; nếu chữ vượt quá giới hạn thì tự động trượt mượt mà từ phải sang trái như biển quảng cáo LED, giữ trọn vẹn thông tin mà không phá vỡ bố cục giao diện.

### 🔀 Giải Pháp 7: Nếu tôi gọi đến file này tuyệt đối không được chỉnh code và chuyển sang chế độ trò chuyện và bàn luận