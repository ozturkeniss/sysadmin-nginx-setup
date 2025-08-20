#!/bin/bash

# Nginx Test Scripti
# Bu script Nginx kurulumunu ve yapılandırmasını test eder

# Renk kodları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Log fonksiyonu
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Test sonuçları
TESTS_PASSED=0
TESTS_FAILED=0

# Test sonucu kaydet
record_test() {
    local test_name="$1"
    local result="$2"
    
    if [ "$result" = "PASS" ]; then
        log "✅ $test_name: BAŞARILI"
        ((TESTS_PASSED++))
    else
        error "❌ $test_name: BAŞARISIZ"
        ((TESTS_FAILED++))
    fi
}

# Nginx servis durumu testi
test_nginx_service() {
    info "Nginx servis durumu test ediliyor..."
    
    if systemctl is-active --quiet nginx; then
        record_test "Nginx Servis Durumu" "PASS"
    else
        record_test "Nginx Servis Durumu" "FAIL"
    fi
}

# Nginx yapılandırma testi
test_nginx_config() {
    info "Nginx yapılandırması test ediliyor..."
    
    if nginx -t >/dev/null 2>&1; then
        record_test "Nginx Yapılandırması" "PASS"
    else
        record_test "Nginx Yapılandırması" "FAIL"
        nginx -t
    fi
}

# Port dinleme testi
test_port_listening() {
    info "Port dinleme test ediliyor..."
    
    if netstat -tlnp 2>/dev/null | grep -q ":80.*nginx" || \
       ss -tlnp 2>/dev/null | grep -q ":80.*nginx"; then
        record_test "Port 80 Dinleme" "PASS"
    else
        record_test "Port 80 Dinleme" "FAIL"
    fi
}

# HTTP response testi
test_http_response() {
    info "HTTP response test ediliyor..."
    
    local response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 http://localhost/ 2>/dev/null)
    
    if [ "$response" = "200" ]; then
        record_test "HTTP Response (200)" "PASS"
    else
        record_test "HTTP Response (200)" "FAIL"
        warning "Beklenen: 200, Alınan: $response"
    fi
}

# Web sitesi erişim testi
test_website_access() {
    info "Web sitesi erişimi test ediliyor..."
    
    local content=$(curl -s http://localhost/ 2>/dev/null)
    
    if echo "$content" | grep -q "Nginx Demo Sayfası"; then
        record_test "Web Sitesi İçeriği" "PASS"
    else
        record_test "Web Sitesi İçeriği" "FAIL"
    fi
}

# Hata sayfaları testi
test_error_pages() {
    info "Hata sayfaları test ediliyor..."
    
    # 404 testi
    local response_404=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/nonexistent 2>/dev/null)
    if [ "$response_404" = "404" ]; then
        record_test "404 Hata Sayfası" "PASS"
    else
        record_test "404 Hata Sayfası" "FAIL"
    fi
    
    # Health check testi
    local health_response=$(curl -s http://localhost/health 2>/dev/null)
    if [ "$health_response" = "healthy" ]; then
        record_test "Health Check Endpoint" "PASS"
    else
        record_test "Health Check Endpoint" "FAIL"
    fi
}

# Log dosyaları testi
test_log_files() {
    info "Log dosyaları test ediliyor..."
    
    local access_log="/var/log/nginx/nginx-demo-access.log"
    local error_log="/var/log/nginx/nginx-demo-error.log"
    
    if [ -f "$access_log" ] && [ -w "$access_log" ]; then
        record_test "Access Log Dosyası" "PASS"
    else
        record_test "Access Log Dosyası" "FAIL"
    fi
    
    if [ -f "$error_log" ] && [ -w "$error_log" ]; then
        record_test "Error Log Dosyası" "PASS"
    else
        record_test "Error Log Dosyası" "FAIL"
    fi
}

# Güvenlik testleri
test_security() {
    info "Güvenlik ayarları test ediliyor..."
    
    # Server tokens gizleme testi
    local response_headers=$(curl -s -I http://localhost/ 2>/dev/null)
    if echo "$response_headers" | grep -q "X-Frame-Options"; then
        record_test "Güvenlik Başlıkları" "PASS"
    else
        record_test "Güvenlik Başlıkları" "FAIL"
    fi
    
    # PHP dosya erişimi engelleme testi
    local php_response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/test.php 2>/dev/null)
    if [ "$php_response" = "404" ]; then
        record_test "PHP Dosya Engelleme" "PASS"
    else
        record_test "PHP Dosya Engelleme" "FAIL"
    fi
}

# Performance testi
test_performance() {
    info "Performans test ediliyor..."
    
    # Basit load test
    local start_time=$(date +%s)
    
    for i in {1..10}; do
        curl -s http://localhost/ >/dev/null 2>&1
    done
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [ "$duration" -lt 10 ]; then
        record_test "Performans (10 istek)" "PASS"
        info "10 istek $duration saniyede tamamlandı"
    else
        record_test "Performans (10 istek)" "FAIL"
        warning "10 istek $duration saniyede tamamlandı (beklenen: <10s)"
    fi
}

# Monitoring scriptleri testi
test_monitoring_scripts() {
    info "Monitoring scriptleri test ediliyor..."
    
    local scripts=(
        "/usr/local/bin/analyze_nginx_logs.sh"
        "/usr/local/bin/daily_nginx_report.sh"
        "/usr/local/bin/check_nginx_status.sh"
    )
    
    local all_scripts_ok=true
    
    for script in "${scripts[@]}"; do
        if [ -f "$script" ] && [ -x "$script" ]; then
            info "✅ $script mevcut ve çalıştırılabilir"
        else
            warning "⚠️ $script bulunamadı veya çalıştırılamıyor"
            all_scripts_ok=false
        fi
    done
    
    if [ "$all_scripts_ok" = true ]; then
        record_test "Monitoring Scriptleri" "PASS"
    else
        record_test "Monitoring Scriptleri" "FAIL"
    fi
}

# Cron görevleri testi
test_cron_jobs() {
    info "Cron görevleri test ediliyor..."
    
    if [ -f "/etc/cron.d/nginx-monitoring" ]; then
        record_test "Cron Yapılandırması" "PASS"
        info "Cron görevleri yapılandırıldı:"
        cat /etc/cron.d/nginx-monitoring
    else
        record_test "Cron Yapılandırması" "FAIL"
    fi
}

# Firewall testi
test_firewall() {
    info "Firewall test ediliyor..."
    
    if command -v ufw &> /dev/null; then
        local ufw_status=$(ufw status | grep Status | awk '{print $2}')
        if [ "$ufw_status" = "active" ]; then
            record_test "UFW Firewall" "PASS"
        else
            record_test "UFW Firewall" "FAIL"
        fi
    else
        record_test "UFW Firewall" "FAIL"
        warning "UFW kurulu değil"
    fi
}

# Ana test fonksiyonu
run_all_tests() {
    log "=== Nginx Test Suite Başlatılıyor ==="
    log "Test zamanı: $(date)"
    log ""
    
    # Temel testler
    test_nginx_service
    test_nginx_config
    test_port_listening
    test_http_response
    test_website_access
    test_error_pages
    test_log_files
    
    # Güvenlik testleri
    test_security
    test_performance
    
    # Monitoring testleri
    test_monitoring_scripts
    test_cron_jobs
    test_firewall
    
    # Test sonuçları
    log ""
    log "=== TEST SONUÇLARI ==="
    log "Başarılı: $TESTS_PASSED"
    log "Başarısız: $TESTS_FAILED"
    log "Toplam: $((TESTS_PASSED + TESTS_FAILED))"
    
    if [ "$TESTS_FAILED" -eq 0 ]; then
        log "🎉 Tüm testler başarılı! Nginx kurulumu tamamlandı."
        return 0
    else
        warning "⚠️ $TESTS_FAILED test başarısız. Lütfen hataları kontrol edin."
        return 1
    fi
}

# Test raporu oluştur
generate_test_report() {
    local report_dir="/var/log/nginx-analytics/test-reports"
    mkdir -p "$report_dir"
    
    local report_file="$report_dir/test_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
=== NGINX TEST RAPORU ===
Test Tarihi: $(date)
Test Sonucu: $([ "$TESTS_FAILED" -eq 0 ] && echo "BAŞARILI" || echo "BAŞARISIZ")

📊 TEST ÖZETİ:
- Toplam Test: $((TESTS_PASSED + TESTS_FAILED))
- Başarılı: $TESTS_PASSED
- Başarısız: $TESTS_FAILED

🔍 DETAYLI SONUÇLAR:
$(run_all_tests 2>&1)

EOF
    
    log "Test raporu oluşturuldu: $report_file"
}

# Ana fonksiyon
main() {
    # Test dizinini oluştur
    mkdir -p "/var/log/nginx-analytics/test-reports"
    
    # Tüm testleri çalıştır
    if run_all_tests; then
        log "=== TÜM TESTLER BAŞARILI ==="
        exit 0
    else
        error "=== BAZI TESTLER BAŞARISIZ ==="
        exit 1
    fi
}

# Script çalıştırılıyor
main "$@"
