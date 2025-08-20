#!/bin/bash

# Nginx Durum Kontrol Scripti
# Bu script Nginx servisinin durumunu kontrol eder ve gerekirse yeniden başlatır

# Renk kodları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Yapılandırma
NGINX_SERVICE="nginx"
LOG_FILE="/var/log/nginx-analytics/status.log"
ALERT_THRESHOLD=3  # Kaç başarısız denemeden sonra uyarı verilecek
MAX_RESTART_ATTEMPTS=5  # Maksimum yeniden başlatma denemesi

# Log fonksiyonu
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}" | tee -a "$LOG_FILE"
}

# Nginx servis durumunu kontrol et
check_nginx_status() {
    if systemctl is-active --quiet "$NGINX_SERVICE"; then
        return 0  # Servis çalışıyor
    else
        return 1  # Servis çalışmıyor
    fi
}

# Nginx process sayısını kontrol et
check_nginx_processes() {
    local process_count=$(ps aux | grep nginx | grep -v grep | wc -l)
    if [ "$process_count" -ge 2 ]; then  # En az master + worker process
        return 0
    else
        return 1
    fi
}

# Nginx port dinleme durumunu kontrol et
check_nginx_ports() {
    if netstat -tlnp 2>/dev/null | grep -q ":80.*nginx" || \
       ss -tlnp 2>/dev/null | grep -q ":80.*nginx"; then
        return 0
    else
        return 1
    fi
}

# HTTP response kontrolü
check_http_response() {
    local response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 http://localhost/ 2>/dev/null)
    if [ "$response" = "200" ]; then
        return 0
    else
        return 1
    fi
}

# Sistem kaynaklarını kontrol et
check_system_resources() {
    local memory_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    local load_average=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    
    # Memory kullanımı %90'dan fazlaysa uyarı
    if (( $(echo "$memory_usage > 90" | bc -l) )); then
        warning "Yüksek memory kullanımı: ${memory_usage}%"
    fi
    
    # Disk kullanımı %90'dan fazlaysa uyarı
    if [ "$disk_usage" -gt 90 ]; then
        warning "Yüksek disk kullanımı: ${disk_usage}%"
    fi
    
    # Load average 5'ten fazlaysa uyarı
    if (( $(echo "$load_average > 5" | bc -l) )); then
        warning "Yüksek load average: $load_average"
    fi
    
    echo "Memory: ${memory_usage}%, Disk: ${disk_usage}%, Load: $load_average"
}

# Nginx log dosyalarını kontrol et
check_nginx_logs() {
    local access_log="/var/log/nginx/nginx-demo-access.log"
    local error_log="/var/log/nginx/nginx-demo-error.log"
    
    # Log dosyalarının boyutunu kontrol et
    if [ -f "$access_log" ]; then
        local access_size=$(du -h "$access_log" | cut -f1)
        log "Access log boyutu: $access_size"
    fi
    
    if [ -f "$error_log" ]; then
        local error_size=$(du -h "$error_log" | cut -f1)
        local error_count=$(wc -l < "$error_log" 2>/dev/null || echo "0")
        log "Error log boyutu: $error_size, Hata sayısı: $error_count"
        
        # Son 10 hatayı göster
        if [ "$error_count" -gt 0 ]; then
            log "Son 10 hata:"
            tail -10 "$error_log" | while read -r line; do
                echo "  $line" | tee -a "$LOG_FILE"
            done
        fi
    fi
}

# Nginx yapılandırmasını test et
test_nginx_config() {
    if nginx -t >/dev/null 2>&1; then
        log "Nginx yapılandırması geçerli"
        return 0
    else
        error "Nginx yapılandırma hatası!"
        nginx -t 2>&1 | tee -a "$LOG_FILE"
        return 1
    fi
}

# Nginx'i yeniden başlat
restart_nginx() {
    log "Nginx yeniden başlatılıyor..."
    
    if systemctl restart "$NGINX_SERVICE"; then
        log "Nginx başarıyla yeniden başlatıldı"
        
        # Yeniden başlatma sonrası durumu kontrol et
        sleep 5
        if check_nginx_status; then
            log "Nginx yeniden başlatma sonrası kontrol: BAŞARILI"
            return 0
        else
            error "Nginx yeniden başlatma sonrası kontrol: BAŞARISIZ"
            return 1
        fi
    else
        error "Nginx yeniden başlatma hatası!"
        return 1
    fi
}

# Ana kontrol fonksiyonu
perform_health_check() {
    local status_ok=true
    local issues=()
    
    log "=== Nginx Sağlık Kontrolü Başlatılıyor ==="
    
    # 1. Servis durumu kontrolü
    if check_nginx_status; then
        log "✅ Nginx servis durumu: ÇALIŞIYOR"
    else
        error "❌ Nginx servis durumu: ÇALIŞMIYOR"
        status_ok=false
        issues+=("servis_durumu")
    fi
    
    # 2. Process kontrolü
    if check_nginx_processes; then
        log "✅ Nginx process kontrolü: BAŞARILI"
    else
        warning "⚠️ Nginx process kontrolü: BAŞARISIZ"
        status_ok=false
        issues+=("process_kontrolu")
    fi
    
    # 3. Port dinleme kontrolü
    if check_nginx_ports; then
        log "✅ Port dinleme kontrolü: BAŞARILI"
    else
        warning "⚠️ Port dinleme kontrolü: BAŞARISIZ"
        status_ok=false
        issues+=("port_kontrolu")
    fi
    
    # 4. HTTP response kontrolü
    if check_http_response; then
        log "✅ HTTP response kontrolü: BAŞARILI"
    else
        warning "⚠️ HTTP response kontrolü: BAŞARISIZ"
        status_ok=false
        issues+=("http_kontrolu")
    fi
    
    # 5. Yapılandırma testi
    if test_nginx_config; then
        log "✅ Nginx yapılandırma testi: BAŞARILI"
    else
        error "❌ Nginx yapılandırma testi: BAŞARISIZ"
        status_ok=false
        issues+=("yapilandirma")
    fi
    
    # 6. Sistem kaynakları kontrolü
    log "📊 Sistem kaynakları:"
    check_system_resources | tee -a "$LOG_FILE"
    
    # 7. Log dosyaları kontrolü
    log "📋 Log dosyaları kontrolü:"
    check_nginx_logs
    
    # Sonuç değerlendirmesi
    if [ "$status_ok" = true ]; then
        log "🎉 Tüm kontroller başarılı! Nginx sağlıklı çalışıyor."
        return 0
    else
        warning "⚠️ Bazı kontroller başarısız: ${issues[*]}"
        
        # Kritik sorunlar varsa yeniden başlatmayı dene
        if [[ " ${issues[*]} " =~ " servis_durumu " ]] || [[ " ${issues[*]} " =~ " yapilandirma " ]]; then
            warning "Kritik sorun tespit edildi. Nginx yeniden başlatılıyor..."
            if restart_nginx; then
                log "✅ Sorun çözüldü"
                return 0
            else
                error "❌ Sorun çözülemedi"
                return 1
            fi
        fi
        
        return 1
    fi
}

# Uzaktan erişim kontrolü (opsiyonel)
check_remote_access() {
    local local_ip=$(hostname -I | awk '{print $1}')
    if [ -n "$local_ip" ]; then
        log "🌐 Yerel IP adresi: $local_ip"
        log "Web sitesi: http://$local_ip"
    fi
}

# Ana fonksiyon
main() {
    # Log dizinini oluştur
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Log dosyası boyutunu kontrol et (10MB'dan büyükse temizle)
    if [ -f "$LOG_FILE" ] && [ "$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)" -gt 10485760 ]; then
        mv "$LOG_FILE" "${LOG_FILE}.old"
        log "Eski log dosyası yedeklendi"
    fi
    
    # Sağlık kontrolü yap
    if perform_health_check; then
        log "=== Sağlık Kontrolü Tamamlandı: BAŞARILI ==="
    else
        error "=== Sağlık Kontrolü Tamamlandı: SORUN VAR ==="
    fi
    
    # Uzaktan erişim bilgisi
    check_remote_access
    
    # Eski log dosyalarını temizle (7 günden eski)
    find "$(dirname "$LOG_FILE")" -name "*.log.old" -mtime +7 -delete 2>/dev/null || true
    
    log "=== Durum Kontrolü Tamamlandı ==="
}

# Script çalıştırılıyor
main "$@"
