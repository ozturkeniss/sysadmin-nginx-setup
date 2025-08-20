#!/bin/bash

# Günlük Nginx Rapor Scripti
# Bu script her gün çalışarak detaylı günlük rapor oluşturur

# Renk kodları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Log dosyaları ve dizinler
ACCESS_LOG="/var/log/nginx/nginx-demo-access.log"
ERROR_LOG="/var/log/nginx/nginx-demo-error.log"
ANALYTICS_DIR="/var/log/nginx-analytics"
REPORTS_DIR="/var/log/nginx-analytics/daily-reports"

# Proje dizinleri (hem sistem hem proje klasöründe dosya oluştur)
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_LOGS_DIR="$PROJECT_DIR/logs"
PROJECT_MONITORING_DIR="$PROJECT_DIR/monitoring"
PROJECT_REPORTS_DIR="$PROJECT_MONITORING_DIR/daily-reports"

# Log fonksiyonu
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# Dizin kontrolü (hem sistem hem proje klasörü)
if [ ! -d "$REPORTS_DIR" ]; then
    mkdir -p "$REPORTS_DIR"
fi

if [ ! -d "$PROJECT_LOGS_DIR" ]; then
    mkdir -p "$PROJECT_LOGS_DIR"
fi

if [ ! -d "$PROJECT_MONITORING_DIR" ]; then
    mkdir -p "$PROJECT_MONITORING_DIR"
fi

if [ ! -d "$PROJECT_REPORTS_DIR" ]; then
    mkdir -p "$PROJECT_REPORTS_DIR"
fi

# Dünün tarihi
YESTERDAY=$(date -d 'yesterday' '+%d/%b/%Y')
YESTERDAY_FILE=$(date -d 'yesterday' '+%Y%m%d')

# Günlük istatistikler
generate_daily_stats() {
    log "Günlük istatistikler hesaplanıyor..."
    
    if [ ! -f "$ACCESS_LOG" ]; then
        log "Access log dosyası bulunamadı"
        return 1
    fi
    
    # Dünkü toplam istekler
    DAILY_REQUESTS=$(grep "$YESTERDAY" "$ACCESS_LOG" 2>/dev/null | wc -l || echo "0")
    
    # Dünkü unique ziyaretçiler
    DAILY_UNIQUE_VISITORS=$(grep "$YESTERDAY" "$ACCESS_LOG" 2>/dev/null | awk '{print $1}' | sort | uniq | wc -l || echo "0")
    
    # Dünkü en popüler sayfalar
    DAILY_TOP_PAGES=$(grep "$YESTERDAY" "$ACCESS_LOG" 2>/dev/null | awk '{print $7}' | sort | uniq -c | sort -nr | head -10)
    
    # Dünkü HTTP durum kodları
    DAILY_STATUS_CODES=$(grep "$YESTERDAY" "$ACCESS_LOG" 2>/dev/null | awk '{print $9}' | sort | uniq -c | sort -nr)
    
    # Dünkü en aktif IP'ler
    DAILY_TOP_IPS=$(grep "$YESTERDAY" "$ACCESS_LOG" 2>/dev/null | awk '{print $1}' | sort | uniq -c | sort -nr | head -10)
    
    # Dünkü hatalar
    DAILY_ERRORS=$(grep "$YESTERDAY" "$ERROR_LOG" 2>/dev/null | wc -l || echo "0")
    
    # Dünkü kritik hatalar
    DAILY_CRITICAL_ERRORS=$(grep "$YESTERDAY" "$ERROR_LOG" 2>/dev/null | grep -E "(500|502|503|504)" | wc -l || echo "0")
    
    # Saatlik dağılım
    HOURLY_DISTRIBUTION=$(grep "$YESTERDAY" "$ACCESS_LOG" 2>/dev/null | awk '{print $4}' | cut -d: -f2 | sort | uniq -c | sort -k2 -n)
    
    # User-Agent dağılımı
    DAILY_USER_AGENTS=$(grep "$YESTERDAY" "$ACCESS_LOG" 2>/dev/null | awk -F'"' '{print $6}' | sort | uniq -c | sort -nr | head -10)
    
    # Referrer analizi
    DAILY_REFERRERS=$(grep "$YESTERDAY" "$ACCESS_LOG" 2>/dev/null | awk -F'"' '{print $4}' | grep -v "-" | sort | uniq -c | sort -nr | head -10)
    
    # Dosya boyutu analizi
    DAILY_BYTES=$(grep "$YESTERDAY" "$ACCESS_LOG" 2>/dev/null | awk '{sum+=$10} END {print sum/1024/1024 " MB"}' 2>/dev/null || echo "0 MB")
    
    # Ortalama response time (eğer log formatında varsa)
    DAILY_AVG_RESPONSE=$(grep "$YESTERDAY" "$ACCESS_LOG" 2>/dev/null | awk '{sum+=$11} END {if(NR>0) print sum/NR " ms"; else print "N/A"}' 2>/dev/null || echo "N/A")
}

# HTML rapor oluştur
generate_html_report() {
    log "HTML rapor oluşturuluyor..."
    
    # HTML içeriğini oluştur
    HTML_CONTENT="<!DOCTYPE html>
<html lang=\"tr\">
<head>
    <meta charset=\"UTF-8\">
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
    <title>Nginx Günlük Rapor - $YESTERDAY</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 20px;
            background: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
            text-align: center;
            border-bottom: 3px solid #4CAF50;
            padding-bottom: 10px;
        }
        .summary {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin: 30px 0;
        }
        .stat-card {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 8px;
            text-align: center;
            border-left: 4px solid #4CAF50;
        }
        .stat-number {
            font-size: 2em;
            font-weight: bold;
            color: #4CAF50;
        }
        .stat-label {
            color: #666;
            margin-top: 5px;
        }
        .section {
            margin: 30px 0;
            padding: 20px;
            background: #f8f9fa;
            border-radius: 8px;
        }
        .section h3 {
            color: #333;
            margin-top: 0;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 15px 0;
        }
        th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        th {
            background: #4CAF50;
            color: white;
        }
        tr:nth-child(even) {
            background: #f2f2f2;
        }
        .error {
            color: #f44336;
        }
        .success {
            color: #4CAF50;
        }
        .warning {
            color: #ff9800;
        }
    </style>
</head>
<body>
    <div class=\"container\">
        <h1>🚀 Nginx Günlük Rapor</h1>
        <p style=\"text-align: center; color: #666;\">Rapor Tarihi: $YESTERDAY | Oluşturulma: $(date)</p>
        
        <div class=\"summary\">
            <div class="stat-card">
                <div class="stat-number">$DAILY_REQUESTS</div>
                <div class="stat-label">Toplam İstek</div>
            </div>
            <div class="stat-card">
                <div class="stat-number">$DAILY_UNIQUE_VISITORS</div>
                <div class="stat-label">Benzersiz Ziyaretçi</div>
            </div>
            <div class="stat-card">
                <div class="stat-number">$DAILY_ERRORS</div>
                <div class="stat-label">Toplam Hata</div>
            </div>
            <div class="stat-card">
                <div class="stat-number">$DAILY_CRITICAL_ERRORS</div>
                <div class="stat-label">Kritik Hata</div>
            </div>
        </div>
        
        <div class="section">
            <h3>📊 En Popüler Sayfalar</h3>
            <table>
                <thead>
                    <tr><th>Sayfa</th><th>İstek Sayısı</th></tr>
                </thead>
                <tbody>
                    $(echo "$DAILY_TOP_PAGES" | awk '{print "<tr><td>" $2 "</td><td>" $1 "</td></tr>"}')
                </tbody>
            </table>
        </div>
        
        <div class="section">
            <h3>🌐 En Aktif IP Adresleri</h3>
            <table>
                <thead>
                    <tr><th>IP Adresi</th><th>İstek Sayısı</th></tr>
                </thead>
                <tbody>
                    $(echo "$DAILY_TOP_IPS" | awk '{print "<tr><td>" $2 "</td><td>" $1 "</td></tr>"}')
                </tbody>
            </table>
        </div>
        
        <div class="section">
            <h3>🔢 HTTP Durum Kodları</h3>
            <table>
                <thead>
                    <tr><th>Durum Kodu</th><th>Sayı</th></tr>
                </thead>
                <tbody>
                    $(echo "$DAILY_STATUS_CODES" | awk '{print "<tr><td>" $2 "</td><td>" $1 "</td></tr>"}')
                </tbody>
            </table>
        </div>
        
        <div class="section">
            <h3>⏰ Saatlik Dağılım</h3>
            <table>
                <thead>
                    <tr><th>Saat</th><th>İstek Sayısı</th></tr>
                </thead>
                <tbody>
                    $(echo "$HOURLY_DISTRIBUTION" | awk '{print "<tr><td>" $2 ":00</td><td>" $1 "</td></tr>"}')
                </tbody>
            </table>
        </div>
        
        <div class="section">
            <h3>🤖 User-Agent Dağılımı</h3>
            <table>
                <thead>
                    <tr><th>User-Agent</th><th>Sayı</th></tr>
                </thead>
                <tbody>
                    $(echo "$DAILY_USER_AGENTS" | awk '{print "<tr><td>" $2 "</td><td>" $1 "</td></tr>"}')
                </tbody>
            </table>
        </div>
        
        <div class="section">
            <h3>📈 Performans Metrikleri</h3>
            <table>
                <tr><td>Toplam Transfer Edilen Veri</td><td>$DAILY_BYTES</td></tr>
                <tr><td>Ortalama Response Time</td><td>$DAILY_AVG_RESPONSE</td></tr>
            </table>
        </div>
        
        <div class="section">
            <h3>🔗 Referrer Analizi</h3>
            <table>
                <thead>
                    <tr><th>Referrer</th><th>Sayı</th></tr>
                </thead>
                <tbody>
                    $(echo "$DAILY_REFERRERS" | awk '{print "<tr><td>" $2 "</td><td>" $1 "</td></tr>"}')
                </tbody>
            </table>
        </div>
        
        <div style=\"text-align: center; margin-top: 40px; color: #666;\">
            <p>Bu rapor otomatik olarak oluşturulmuştur.</p>
            <p>Nginx Monitoring Sistemi</p>
        </div>
    </div>
</body>
</html>"
    
    # HTML raporu hem sistem hem proje klasöründe oluştur
    echo "$HTML_CONTENT" > "$REPORTS_DIR/daily_report_$YESTERDAY_FILE.html"
    echo "$HTML_CONTENT" > "$PROJECT_REPORTS_DIR/daily_report_$YESTERDAY_FILE.html"
    
    log "HTML rapor oluşturuldu: $REPORTS_DIR/daily_report_$YESTERDAY_FILE.html"
    log "HTML rapor proje klasöründe de oluşturuldu: $PROJECT_REPORTS_DIR/daily_report_$YESTERDAY_FILE.html"
}

# Text rapor oluştur
generate_text_report() {
    log "Text rapor oluşturuluyor..."
    
    # Text rapor içeriğini oluştur
    TEXT_CONTENT="=== NGINX GÜNLÜK RAPOR ===
Tarih: $YESTERDAY
Oluşturulma: $(date)

📊 GENEL İSTATİSTİKLER:
- Toplam İstek: $DAILY_REQUESTS
- Benzersiz Ziyaretçi: $DAILY_UNIQUE_VISITORS
- Toplam Hata: $DAILY_ERRORS
- Kritik Hata (5xx): $DAILY_CRITICAL_ERRORS
- Transfer Edilen Veri: $DAILY_BYTES
- Ortalama Response Time: $DAILY_AVG_RESPONSE

📄 EN POPÜLER SAYFALAR:
$DAILY_TOP_PAGES

🌐 EN AKTİF IP ADRESLERİ:
$DAILY_TOP_IPS

🔢 HTTP DURUM KODLARI:
$DAILY_STATUS_CODES

⏰ SAATLİK DAĞILIM:
$HOURLY_DISTRIBUTION

🤖 USER-AGENT DAĞILIMI:
$DAILY_USER_AGENTS

🔗 REFERRER ANALİZİ:
$DAILY_REFERRERS
"
    
    # Text raporu hem sistem hem proje klasöründe oluştur
    echo "$TEXT_CONTENT" > "$REPORTS_DIR/daily_report_$YESTERDAY_FILE.txt"
    echo "$TEXT_CONTENT" > "$PROJECT_REPORTS_DIR/daily_report_$YESTERDAY_FILE.txt"
    
    log "Text rapor oluşturuldu: $REPORTS_DIR/daily_report_$YESTERDAY_FILE.txt"
    log "Text rapor proje klasöründe de oluşturuldu: $PROJECT_REPORTS_DIR/daily_report_$YESTERDAY_FILE.txt"
}

# E-posta raporu gönder (opsiyonel)
send_email_report() {
    # Bu kısım e-posta sunucusu kurulu olan sistemlerde kullanılabilir
    # Şimdilik sadece log olarak kaydediyoruz
    log "E-posta raporu gönderimi atlandı (e-posta sunucusu gerekli)"
}

# Ana fonksiyon
main() {
    log "=== Günlük Nginx Raporu Oluşturuluyor ==="
    log "Rapor tarihi: $YESTERDAY"
    
    generate_daily_stats
    generate_html_report
    generate_text_report
    send_email_report
    
    log "=== Günlük rapor tamamlandı ==="
    log "HTML rapor: $REPORTS_DIR/daily_report_$YESTERDAY_FILE.html"
    log "Text rapor: $REPORTS_DIR/daily_report_$YESTERDAY_FILE.txt"
    log "Proje klasöründe de oluşturuldu: $PROJECT_REPORTS_DIR/"
    
    # Eski raporları temizle (30 günden eski) - hem sistem hem proje klasöründe
    find "$REPORTS_DIR" -name "*.html" -mtime +30 -delete 2>/dev/null || true
    find "$REPORTS_DIR" -name "*.txt" -mtime +30 -delete 2>/dev/null || true
    find "$PROJECT_REPORTS_DIR" -name "*.html" -mtime +30 -delete 2>/dev/null || true
    find "$PROJECT_REPORTS_DIR" -name "*.txt" -mtime +30 -delete 2>/dev/null || true
}

# Script çalıştırılıyor
main "$@"
