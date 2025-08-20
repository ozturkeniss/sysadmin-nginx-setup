#!/bin/bash

# Nginx Güvenlik Ayarları Scripti
# Bu script Nginx web sunucusu için temel güvenlik ayarlarını yapar

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
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Root kontrolü
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Bu script root yetkisi gerektirir. 'sudo' ile çalıştırın."
    fi
}

# Sistem kontrolü
check_system() {
    log "Sistem kontrolü yapılıyor..."
    
    if ! command -v apt-get &> /dev/null; then
        error "Bu script sadece Debian/Ubuntu tabanlı sistemlerde çalışır."
    fi
    
    log "Sistem kontrolü tamamlandı."
}

# UFW firewall kurulumu ve yapılandırması
setup_ufw() {
    log "UFW firewall kurulumu ve yapılandırması başlatılıyor..."
    
    # UFW kurulumu
    if ! command -v ufw &> /dev/null; then
        apt-get install -y ufw
        log "UFW kuruldu."
    else
        log "UFW zaten kurulu."
    fi
    
    # UFW'yi sıfırla
    ufw --force reset
    
    # Varsayılan politikaları ayarla
    ufw default deny incoming
    ufw default allow outgoing
    
    # SSH erişimini koru (mevcut bağlantıları koru)
    ufw allow ssh
    log "SSH erişimi etkinleştirildi."
    
    # HTTP ve HTTPS erişimine izin ver
    ufw allow 80/tcp
    ufw allow 443/tcp
    log "HTTP (80) ve HTTPS (443) portları açıldı."
    
    # UFW'yi etkinleştir
    ufw --force enable
    
    # UFW durumunu göster
    log "UFW durumu:"
    ufw status verbose
    
    log "UFW firewall yapılandırması tamamlandı."
}

# Nginx güvenlik ayarları
configure_nginx_security() {
    log "Nginx güvenlik ayarları yapılandırılıyor..."
    
    # Nginx ana yapılandırma dosyasına güvenlik ayarları ekle
    local nginx_conf="/etc/nginx/nginx.conf"
    
    # Yedek al
    cp "$nginx_conf" "${nginx_conf}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Güvenlik ayarlarını ekle
    cat >> "$nginx_conf" << 'EOF'

# Güvenlik ayarları
server_tokens off;  # Nginx versiyon bilgisini gizle
client_max_body_size 10M;  # Maksimum dosya yükleme boyutu
client_body_timeout 10s;  # Client body timeout
client_header_timeout 10s;  # Client header timeout
keepalive_timeout 65;  # Keep-alive timeout
send_timeout 10s;  # Send timeout
add_header X-Frame-Options "SAMEORIGIN" always;  # Clickjacking koruması
add_header X-Content-Type-Options "nosniff" always;  # MIME type sniffing koruması
add_header X-XSS-Protection "1; mode=block" always;  # XSS koruması
add_header Referrer-Policy "no-referrer-when-downgrade" always;  # Referrer policy
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline';" always;  # CSP

# Rate limiting
limit_req_zone $binary_remote_addr zone=login:10m rate=10r/m;
limit_req_zone $binary_remote_addr zone=api:10m rate=30r/m;

# Gzip sıkıştırma
gzip on;
gzip_vary on;
gzip_min_length 1024;
gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;

EOF
    
    log "Nginx güvenlik ayarları eklendi."
}

# Site yapılandırmasına güvenlik ekle
configure_site_security() {
    log "Site güvenlik yapılandırması yapılıyor..."
    
    local site_conf="/etc/nginx/sites-available/nginx-demo"
    
    if [ -f "$site_conf" ]; then
        # Yedek al
        cp "$site_conf" "${site_conf}.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Güvenlik ayarlarını ekle
        cat >> "$site_conf" << 'EOF'

    # Güvenlik başlıkları
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline';" always;
    
    # Rate limiting
    location /login {
        limit_req zone=login burst=5 nodelay;
    }
    
    location /api/ {
        limit_req zone=api burst=10 nodelay;
    }
    
    # Zararlı dosya uzantılarını engelle
    location ~* \.(php|php3|php4|php5|phtml|pl|py|jsp|asp|sh|cgi)$ {
        deny all;
        return 404;
    }
    
    # Gizli dosyaları engelle
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
    
    # Backup dosyalarını engelle
    location ~ ~$ {
        deny all;
        access_log off;
        log_not_found off;
    }
    
    # HTTP metodlarını kısıtla
    if ($request_method !~ ^(GET|HEAD|POST|OPTIONS)$) {
        return 444;
    }
    
    # User-Agent kontrolü
    if ($http_user_agent ~* (curl|wget|python|bot|spider|crawler)) {
        return 403;
    }

EOF
        
        log "Site güvenlik ayarları eklendi."
    else
        warning "Site yapılandırma dosyası bulunamadı: $site_conf"
    fi
}

# ModSecurity kurulumu (opsiyonel)
install_modsecurity() {
    log "ModSecurity kurulumu başlatılıyor..."
    
    # ModSecurity paketlerini kur
    apt-get install -y libapache2-mod-security2 modsecurity-crs
    
    if [ $? -eq 0 ]; then
        log "ModSecurity başarıyla kuruldu."
        
        # ModSecurity yapılandırması
        local modsec_conf="/etc/nginx/modsecurity/modsecurity.conf"
        if [ -f "$modsec_conf" ]; then
            # Yedek al
            cp "$modsec_conf" "${modsec_conf}.backup.$(date +%Y%m%d_%H%M%S)"
            
            # ModSecurity ayarlarını güncelle
            sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine On/' "$modsec_conf"
            sed -i 's/SecResponseBodyAccess On/SecResponseBodyAccess Off/' "$modsec_conf"
            
            log "ModSecurity yapılandırması güncellendi."
        fi
    else
        warning "ModSecurity kurulumu başarısız oldu."
    fi
}

# Fail2ban kurulumu ve yapılandırması
setup_fail2ban() {
    log "Fail2ban kurulumu ve yapılandırması başlatılıyor..."
    
    # Fail2ban kurulumu
    if ! command -v fail2ban-client &> /dev/null; then
        apt-get install -y fail2ban
        log "Fail2ban kuruldu."
    else
        log "Fail2ban zaten kurulu."
    fi
    
    # Fail2ban yapılandırması
    local jail_local="/etc/fail2ban/jail.local"
    
    cat > "$jail_local" << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
backend = auto

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
logpath = /var/log/nginx/error.log
maxretry = 3

[nginx-botsearch]
enabled = true
filter = nginx-botsearch
logpath = /var/log/nginx/access.log
maxretry = 5

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
logpath = /var/log/nginx/error.log
maxretry = 3

[nginx-badbots]
enabled = true
filter = nginx-badbots
logpath = /var/log/nginx/access.log
maxretry = 2
EOF
    
    # Fail2ban servisini yeniden başlat
    systemctl restart fail2ban
    systemctl enable fail2ban
    
    log "Fail2ban yapılandırması tamamlandı."
}

# SSL/TLS sertifikası oluştur (self-signed)
setup_ssl() {
    log "SSL/TLS sertifikası oluşturuluyor..."
    
    local ssl_dir="/etc/nginx/ssl"
    mkdir -p "$ssl_dir"
    
    # Self-signed sertifika oluştur
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$ssl_dir/nginx.key" \
        -out "$ssl_dir/nginx.crt" \
        -subj "/C=TR/ST=Istanbul/L=Istanbul/O=NginxDemo/OU=IT/CN=localhost"
    
    # Sertifika izinlerini ayarla
    chmod 600 "$ssl_dir/nginx.key"
    chmod 644 "$ssl_dir/nginx.crt"
    chown root:root "$ssl_dir/nginx.key" "$ssl_dir/nginx.crt"
    
    log "SSL sertifikası oluşturuldu: $ssl_dir/"
}

# Güvenlik testleri
run_security_tests() {
    log "Güvenlik testleri çalıştırılıyor..."
    
    # Nginx yapılandırma testi
    if nginx -t; then
        log "✅ Nginx yapılandırması geçerli"
    else
        error "❌ Nginx yapılandırma hatası!"
    fi
    
    # UFW durumu kontrolü
    if ufw status | grep -q "Status: active"; then
        log "✅ UFW firewall aktif"
    else
        warning "⚠️ UFW firewall aktif değil"
    fi
    
    # Fail2ban durumu kontrolü
    if systemctl is-active --quiet fail2ban; then
        log "✅ Fail2ban servisi çalışıyor"
    else
        warning "⚠️ Fail2ban servisi çalışmıyor"
    fi
    
    # SSL sertifikası kontrolü
    if [ -f "/etc/nginx/ssl/nginx.crt" ] && [ -f "/etc/nginx/ssl/nginx.key" ]; then
        log "✅ SSL sertifikaları mevcut"
    else
        warning "⚠️ SSL sertifikaları bulunamadı"
    fi
    
    log "Güvenlik testleri tamamlandı."
}

# Güvenlik raporu oluştur
generate_security_report() {
    log "Güvenlik raporu oluşturuluyor..."
    
    local report_dir="/var/log/nginx-analytics/security-reports"
    mkdir -p "$report_dir"
    
    local report_file="$report_dir/security_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
=== NGINX GÜVENLİK RAPORU ===
Oluşturulma: $(date)

🔒 GÜVENLİK AYARLARI:

1. FIREWALL (UFW):
$(ufw status verbose)

2. NGINX GÜVENLİK AYARLARI:
- Server tokens: $(grep -c "server_tokens off" /etc/nginx/nginx.conf || echo "0") ayar bulundu
- Security headers: $(grep -c "add_header.*Security" /etc/nginx/nginx.conf || echo "0") güvenlik başlığı
- Rate limiting: $(grep -c "limit_req" /etc/nginx/sites-available/nginx-demo || echo "0") rate limit kuralı

3. FAIL2BAN:
$(fail2ban-client status 2>/dev/null || echo "Fail2ban durumu alınamadı")

4. SSL/TLS:
$(ls -la /etc/nginx/ssl/ 2>/dev/null || echo "SSL dizini bulunamadı")

5. SİSTEM GÜVENLİK:
- Kernel version: $(uname -r)
- OpenSSL version: $(openssl version 2>/dev/null || echo "OpenSSL bulunamadı")
- UFW version: $(ufw version 2>/dev/null | head -1 || echo "UFW versiyonu alınamadı")

6. GÜVENLİK ÖNERİLERİ:
- Düzenli güvenlik güncellemeleri yapın
- Log dosyalarını düzenli kontrol edin
- Başarısız giriş denemelerini izleyin
- SSL sertifikalarını yenileyin
- Güvenlik duvarı kurallarını gözden geçirin

EOF
    
    log "Güvenlik raporu oluşturuldu: $report_file"
}

# Ana fonksiyon
main() {
    log "=== Nginx Güvenlik Ayarları Başlatılıyor ==="
    
    check_root
    check_system
    
    # Güvenlik ayarlarını yap
    setup_ufw
    configure_nginx_security
    configure_site_security
    setup_fail2ban
    setup_ssl
    
    # Güvenlik testleri
    run_security_tests
    
    # Güvenlik raporu oluştur
    generate_security_report
    
    # Nginx'i yeniden yükle
    if nginx -t; then
        systemctl reload nginx
        log "Nginx güvenlik ayarları ile yeniden yüklendi."
    else
        error "Nginx yapılandırma hatası! Güvenlik ayarları uygulanamadı."
    fi
    
    log "=== Güvenlik Ayarları Tamamlandı! ==="
    log "Önemli güvenlik özellikleri:"
    log "- UFW firewall etkin"
    log "- Fail2ban intrusion prevention"
    log "- Nginx güvenlik başlıkları"
    log "- Rate limiting"
    log "- SSL/TLS sertifikası"
    log "- Zararlı dosya uzantıları engellendi"
    log ""
    log "Güvenlik raporu: /var/log/nginx-analytics/security-reports/"
}

# Script çalıştırılıyor
main "$@"
