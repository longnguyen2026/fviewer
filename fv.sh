#!/usr/bin/env bash
# ==============================================================================
# Script: install-fviewer.sh
# Mô tả: Tự động tải và cài đặt FViewer (.deb) cho Linux Mint và Kubuntu
# Tác giả: longnguyen2026
# ==============================================================================

set -euo pipefail

# URL tải file .deb (Mặc định lấy từ GitHub Releases, có thể ghi đè bằng biến môi trường)
FVIEWER_URL="${FVIEWER_URL:-https://github.com/longnguyen2026/fviewer/releases/latest/download/fviewer_0.1.1_amd64.deb}"
TEMP_DEB="/tmp/fviewer_latest_amd64.deb"

# Màu hiển thị terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# 1. Kiểm tra quyền thực thi (root hoặc sudo)
if [ "$(id -u)" -ne 0 ]; then
    SUDO="sudo"
else
    SUDO=""
fi

log_info "Bắt đầu quá trình triển khai FViewer cho hệ thống..."

# 2. Đảm bảo có curl hoặc wget
if ! command -v curl &>/dev/null && ! command -v wget &>/dev/null; then
    log_info "Đang cài đặt curl..."
    $SUDO apt-get update -y
    $SUDO apt-get install -y curl
fi

# 3. Tải gói fviewer .deb
log_info "Đang tải FViewer từ: ${FVIEWER_URL}"
if command -v curl &>/dev/null; then
    curl -fL --progress-bar "${FVIEWER_URL}" -o "${TEMP_DEB}"
else
    wget --show-progress -qO "${TEMP_DEB}" "${FVIEWER_URL}"
fi

if [ ! -s "${TEMP_DEB}" ]; then
    log_error "File tải về rỗng hoặc liên kết không khả dụng!"
    exit 1
fi

# 4. Cài đặt package và giải quyết thư viện phụ thuộc (dependencies)
log_info "Đang cập nhật danh sách gói APT..."

# Một repository bên thứ ba có thể không hỗ trợ phiên bản Ubuntu hiện tại.
# Không để lỗi repository không liên quan làm dừng toàn bộ quá trình cài FViewer.
if ! $SUDO apt-get update -y; then
    log_error "apt-get update có cảnh báo/lỗi repository. Tiếp tục thử cài FViewer..."
fi

log_info "Đang cài đặt FViewer vào hệ thống..."

# Cài trực tiếp file .deb bằng APT để APT tự xử lý dependencies.
if ! $SUDO apt-get install -y "${TEMP_DEB}"; then
    log_error "Cài bằng APT chưa thành công. Thử cài package và sửa dependencies..."

    # dpkg có thể báo thiếu dependencies; đây là bước trung gian có chủ đích.
    $SUDO dpkg -i "${TEMP_DEB}" || true

    if ! $SUDO apt-get install -f -y; then
        log_error "Không thể tự động khắc phục dependencies."
        log_error "Giữ lại file cài đặt tại: ${TEMP_DEB}"
        exit 1
    fi
fi

# Xác nhận package đã được cài ở trạng thái đã giải nén và cấu hình.
if ! dpkg-query -W -f='${Status}' fviewer 2>/dev/null | grep -q "install ok installed"; then
    log_error "Không tìm thấy package fviewer ở trạng thái đã cài đặt."
    log_error "Giữ lại file cài đặt tại: ${TEMP_DEB}"
    exit 1
fi

# 5. Cập nhật cache ứng dụng desktop cho Mint (Cinnamon/MATE/XFCE) và Kubuntu (KDE)
log_info "Làm mới cơ sở dữ liệu desktop entry và mime..."
if command -v update-desktop-database &>/dev/null; then
    $SUDO update-desktop-database -q || true
fi

# 6. Dọn dẹp file tạm
rm -f "${TEMP_DEB}"

log_success "FViewer đã được cài đặt thành công trên hệ thống!"
