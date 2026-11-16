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

# 4. Xử lý PPA không tương thích và cập nhật danh sách gói APT
# Chỉ vô hiệu hóa PPA rodsmith/refind nếu nó đang được cấu hình.
# Không gỡ rEFInd đã cài và không đụng đến các repository khác.
REFIND_PPA="ppa:rodsmith/refind"
REFIND_PATTERN="ppa.launchpadcontent.net/rodsmith/refind"

if grep -Rqs "$REFIND_PATTERN" /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
    log_info "Phát hiện PPA rodsmith/refind. Đang vô hiệu hóa nguồn PPA không tương thích..."

    REFIND_REMOVED=false

    if command -v add-apt-repository >/dev/null 2>&1; then
        if $SUDO add-apt-repository -y --remove "$REFIND_PPA"; then
            REFIND_REMOVED=true
        fi
    fi

    # Dự phòng: vô hiệu hóa đúng dòng/stanza PPA nếu lệnh remove không thành công.
    # Dùng python3 -c thay vì heredoc để tương thích khi script chạy qua /dev/fd.
    if [ "$REFIND_REMOVED" != true ]; then
        while IFS= read -r -d '' SOURCE_FILE; do
            $SUDO python3 -c "
import pathlib, re, sys
p = pathlib.Path(sys.argv[1])
pattern = sys.argv[2]
data = p.read_text()
if p.suffix == '.list':
    lines = []
    for line in data.splitlines():
        if pattern in line and not line.lstrip().startswith('#'):
            line = '# disabled by FViewer installer: ' + line
        lines.append(line)
    result = '\\n'.join(lines) + ('\\n' if data.endswith('\\n') else '')
else:
    blocks = re.split(r'(?m)(?=^\\S)', data)
    for i, block in enumerate(blocks):
