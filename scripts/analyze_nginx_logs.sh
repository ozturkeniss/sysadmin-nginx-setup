#!/bin/bash

# Nginx Log Analizi Scripti
# Bu script Nginx access ve error loglarını analiz eder

# Renk kodları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Log dosyaları
ACCESS_LOG="/var/log/nginx/nginx-demo-access.log"
ERROR_LOG="/var/log/nginx/nginx-demo-error.log"
ANALYTICS_DIR="/var/log/nginx-analytics"

# Proje dizinleri (hem sistem hem proje klasöründe dosya oluştur)
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_LOGS_DIR="$PROJECT_DIR/logs"
PROJECT_MONITORING_DIR="$PROJECT_DIR/monitoring"

# Log fonksiyonu
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# Dizin kontrolü (hem sistem hem proje klasörü)
if [ ! -d "$ANALYTICS_DIR" ]; then
    mkdir -p "$ANALYTICS_DIR"
fi

if [ ! -d "$PROJECT_LOGS_DIR" ]; then
    mkdir -p "$PROJECT_LOGS_DIR"
fi

if [ ! -d "$PROJECT_MONITORING_DIR" ]; then
    mkdir -p "$PROJECT_MONITORING_DIR"
fi

# Access log analizi
analyze_access_logs() {
    log "Access log analizi başlatılıyor..."
    
    if [ ! -f "$ACCESS_LOG" ]; then
        log "Access log dosyası bulunamadı: $ACCESS_LOG"
        return 1
    fi
    
    # Toplam istek sayısı
    TOTAL_REQUESTS=$(wc -l < "$ACCESS_LOG" 2>/dev/null || echo "0")
    
    # Son 1 saatteki istekler
    HOUR_AGO=$(date -d '1 hour ago' '+%d/%b/%Y:%H')
    HOURLY_REQUESTS=$(grep "$HOUR_AGO" "$ACCESS_LOG" 2>/dev/null | wc -l || echo "0")
    
    # En popüler IP adresleri
    TOP_IPS=$(awk '{print $1}' "$ACCESS_LOG" 2>/dev/null | sort | uniq -c | sort -nr | head -10)
    
    # En popüler sayfalar
    TOP_PAGES=$(awk '{print $7}' "$ACCESS_LOG" 2>/dev/null | sort | uniq -c | sort -nr | head -10)
    
    # HTTP durum kodları
    STATUS_CODES=$(awk '{print $9}' "$ACCESS_LOG" 2>/dev/null | sort | uniq -c | sort -nr)
    
    # User-Agent analizi
    TOP_USER_AGENTS=$(awk -F'"' '{print $6}' "$ACCESS_LOG" 2>/dev/null | sort | uniq -c | sort -nr | head -5)
    
    # Rapor oluştur (hem sistem hem proje klasöründe)
    TIMESTAMP=$(date +%Y%m%d_%H%M)
    REPORT_CONTENT="=== Nginx Access Log Analizi ===
Analiz Zamanı: $(date)
Log Dosyası: $ACCESS_LOG

📊 GENEL İSTATİSTİKLER:
- Toplam İstek Sayısı: $TOTAL_REQUESTS
- Son 1 Saatteki İstekler: $HOURLY_REQUESTS

🌐 EN POPÜLER IP ADRESLERİ:
$TOP_IPS

📄 EN POPÜLER SAYFALAR:
$TOP_PAGES

🔢 HTTP DURUM KODLARI:
$STATUS_CODES

🤖 EN POPÜLER USER-AGENT'LAR:
$TOP_USER_AGENTS
"
    
    # Sistem dizininde oluştur
    echo "$REPORT_CONTENT" > "$ANALYTICS_DIR/access_analysis_$TIMESTAMP.txt"
    
    # Proje klasöründe de oluştur
    echo "$REPORT_CONTENT" > "$PROJECT_LOGS_DIR/access_analysis_$TIMESTAMP.txt"
    echo "$REPORT_CONTENT" > "$PROJECT_MONITORING_DIR/access_analysis_$TIMESTAMP.txt"
    
    log "Access log analizi tamamlandı."
}

# Error log analizi
analyze_error_logs() {
    log "Error log analizi başlatılıyor..."
    
    if [ ! -f "$ERROR_LOG" ]; then
        log "Error log dosyası bulunamadı: $ERROR_LOG"
        return 1
    fi
    
    # Son 1 saatteki hatalar
    HOUR_AGO=$(date -d '1 hour ago' '+%Y/%m/%d %H')
    HOURLY_ERRORS=$(grep "$HOUR_AGO" "$ERROR_LOG" 2>/dev/null | wc -l || echo "0")
    
    # Hata türleri
    ERROR_TYPES=$(grep "$HOUR_AGO" "$ERROR_LOG" 2>/dev/null | awk '{print $5}' | sort | uniq -c | sort -nr)
    
    # Kritik hatalar (500, 502, 503, 504)
    CRITICAL_ERRORS=$(grep "$HOUR_AGO" "$ERROR_LOG" 2>/dev/null | grep -E "(500|502|503|504)" | wc -l || echo "0")
    
    # Rapor oluştur (hem sistem hem proje klasöründe)
    TIMESTAMP=$(date +%Y%m%d_%H%M)
    REPORT_CONTENT="=== Nginx Error Log Analizi ===
Analiz Zamanı: $(date)
Log Dosyası: $ERROR_LOG

❌ HATA İSTATİSTİKLERİ:
- Son 1 Saatteki Hatalar: $HOURLY_ERRORS
- Kritik Hatalar (5xx): $CRITICAL_ERRORS

🚨 HATA TÜRLERİ:
$ERROR_TYPES
"
    
    # Sistem dizininde oluştur
    echo "$REPORT_CONTENT" > "$ANALYTICS_DIR/error_analysis_$TIMESTAMP.txt"
    
    # Proje klasöründe de oluştur
    echo "$REPORT_CONTENT" > "$PROJECT_LOGS_DIR/error_analysis_$TIMESTAMP.txt"
    echo "$REPORT_CONTENT" > "$PROJECT_MONITORING_DIR/error_analysis_$TIMESTAMP.txt"
    
    log "Error log analizi tamamlandı."
}

# Performans analizi
analyze_performance() {
    log "Performans analizi başlatılıyor..."
    
    # Nginx process durumu
    NGINX_PROCESSES=$(ps aux | grep nginx | grep -v grep | wc -l)
    
    # Memory kullanımı
    NGINX_MEMORY=$(ps aux | grep nginx | grep -v grep | awk '{sum+=$6} END {print sum/1024 " MB"}' 2>/dev/null || echo "N/A")
    
    # CPU kullanımı
    NGINX_CPU=$(ps aux | grep nginx | grep -v grep | awk '{sum+=$3} END {print sum "%"}' 2>/dev/null || echo "N/A")
    
    # Disk kullanımı
    DISK_USAGE=$(df -h /var/log/nginx | tail -1 | awk '{print $5}')
    
    # Rapor oluştur (hem sistem hem proje klasöründe)
    TIMESTAMP=$(date +%Y%m%d_%H%M)
    REPORT_CONTENT="=== Nginx Performans Analizi ===
Analiz Zamanı: $(date)

⚡ PERFORMANS METRİKLERİ:
- Nginx Process Sayısı: $NGINX_PROCESSES
- Memory Kullanımı: $NGINX_MEMORY
- CPU Kullanımı: $NGINX_CPU
- Log Disk Kullanımı: $DISK_USAGE
"
    
    # Sistem dizininde oluştur
    echo "$REPORT_CONTENT" > "$ANALYTICS_DIR/performance_$TIMESTAMP.txt"
    
    # Proje klasöründe de oluştur
    echo "$REPORT_CONTENT" > "$PROJECT_LOGS_DIR/performance_$TIMESTAMP.txt"
    echo "$REPORT_CONTENT" > "$PROJECT_MONITORING_DIR/performance_$TIMESTAMP.txt"
    
    log "Performans analizi tamamlandı."
}

# Ana fonksiyon
main() {
    log "=== Nginx Log Analizi Başlatılıyor ==="
    
    analyze_access_logs
    analyze_error_logs
    analyze_performance
    
    log "=== Tüm analizler tamamlandı ==="
    log "Raporlar hem $ANALYTICS_DIR hem de proje klasöründe oluşturuldu."
    
    # Eski raporları temizle (7 günden eski) - hem sistem hem proje klasöründe
    find "$ANALYTICS_DIR" -name "*.txt" -mtime +7 -delete 2>/dev/null || true
    find "$PROJECT_LOGS_DIR" -name "*.txt" -mtime +7 -delete 2>/dev/null || true
    find "$PROJECT_MONITORING_DIR" -name "*.txt" -mtime +7 -delete 2>/dev/null || true
}

# Script çalıştırılıyor
main "$@"
