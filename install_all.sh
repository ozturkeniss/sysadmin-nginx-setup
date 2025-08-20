#!/bin/bash

# Nginx Web Sunucusu Kurulum ve Yönetim Projesi
# Ana Kurulum Scripti

set -e  # Hata durumunda scripti durdur

# Renk kodları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
    
    # Sistem güncellemesi
    log "Sistem güncelleniyor..."
    apt-get update
    apt-get upgrade -y
    
    log "Sistem kontrolü tamamlandı."
}

# Nginx kurulumu
install_nginx() {
    log "Nginx kurulumu başlatılıyor..."
    
    if ! command -v nginx &> /dev/null; then
        apt-get install -y nginx
        log "Nginx başarıyla kuruldu."
    else
        log "Nginx zaten kurulu."
    fi
    
    # Nginx servisini başlat
    systemctl enable nginx
    systemctl start nginx
    
    log "Nginx servisi başlatıldı ve otomatik başlatma etkinleştirildi."
}

# Web sitesi kurulumu
setup_website() {
    log "Web sitesi kurulumu başlatılıyor..."
    
    # Web sitesi dizini oluştur
    mkdir -p /var/www/nginx-demo
    
    # Basit HTML sayfası oluştur
    cat > /var/www/nginx-demo/index.html << 'EOF'
<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Nginx Demo Sayfası</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .container {
            background: white;
            padding: 2rem;
            border-radius: 15px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.1);
            text-align: center;
            max-width: 600px;
        }
        h1 {
            color: #333;
            margin-bottom: 1rem;
        }
        p {
            color: #666;
            line-height: 1.6;
        }
        .status {
            background: #e8f5e8;
            color: #2d5a2d;
            padding: 1rem;
            border-radius: 8px;
            margin: 1rem 0;
            border-left: 4px solid #4caf50;
        }
        .timestamp {
            color: #999;
            font-size: 0.9rem;
            margin-top: 2rem;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Nginx Web Sunucusu</h1>
        <p>Bu sayfa, Linux üzerinde kurulan Nginx web sunucusunda çalışmaktadır.</p>
        
        <div class="status">
            <strong>✅ Sunucu Durumu:</strong> Çalışıyor<br>
            <strong>🌐 Sunucu Yazılımı:</strong> Nginx<br>
            <strong>🐧 İşletim Sistemi:</strong> Linux
        </div>
        
        <p>Bu proje, sistem yöneticiliği becerilerini geliştirmek için oluşturulmuştur.</p>
        
        <div class="timestamp">
            Sayfa yüklenme zamanı: <span id="timestamp"></span>
        </div>
    </div>
    
    <script>
        document.getElementById('timestamp').textContent = new Date().toLocaleString('tr-TR');
    </script>
</body>
</html>
EOF
    
    # Dosya izinlerini ayarla
    chown -R www-data:www-data /var/www/nginx-demo
    chmod -R 755 /var/www/nginx-demo
    
    log "Web sitesi başarıyla kuruldu."
}

# Nginx yapılandırması
configure_nginx() {
    log "Nginx yapılandırması yapılıyor..."
    
    # Yedek al
    cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup
    
    # Yeni site yapılandırması
    cat > /etc/nginx/sites-available/nginx-demo << 'EOF'
server {
    listen 80;
    server_name _;
    root /var/www/nginx-demo;
    index index.html index.htm;
    
    # Log dosyaları
    access_log /var/log/nginx/nginx-demo-access.log;
    error_log /var/log/nginx/nginx-demo-error.log;
    
    # Gzip sıkıştırma
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;
    
    # Güvenlik başlıkları
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    # Statik dosyalar için cache
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Hata sayfaları
    error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;
}
EOF
    
    # Site'i etkinleştir
    ln -sf /etc/nginx/sites-available/nginx-demo /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # Nginx yapılandırmasını test et
    if nginx -t; then
        systemctl reload nginx
        log "Nginx yapılandırması başarıyla güncellendi."
    else
        error "Nginx yapılandırma hatası!"
    fi
}

# Monitoring kurulumu
setup_monitoring() {
    log "Monitoring ve log analizi kurulumu başlatılıyor..."
    
    # Gerekli paketleri kur
    apt-get install -y bc curl
    
    # Monitoring scriptlerini kopyala
    cp scripts/* /usr/local/bin/
    chmod +x /usr/local/bin/*
    
    # Log dizinini oluştur
    mkdir -p /var/log/nginx-analytics
    
    # Cron görevlerini ekle
    cat > /etc/cron.d/nginx-monitoring << 'EOF'
# Nginx log analizi - her saat
0 * * * * root /usr/local/bin/analyze_nginx_logs.sh > /var/log/nginx-analytics/hourly.log 2>&1

# Günlük rapor - her gün saat 00:01
1 0 * * * root /usr/local/bin/daily_nginx_report.sh > /var/log/nginx-analytics/daily.log 2>&1

# Sistem durumu kontrolü - her 5 dakika
*/5 * * * * root /usr/local/bin/check_nginx_status.sh > /var/log/nginx-analytics/status.log 2>&1
EOF
    
    log "Monitoring kurulumu tamamlandı."
}

# Güvenlik ayarları
setup_security() {
    log "Güvenlik ayarları yapılıyor..."
    
    # UFW firewall kurulumu
    apt-get install -y ufw
    
    # SSH erişimini koru (mevcut bağlantıları koru)
    ufw allow ssh
    
    # HTTP ve HTTPS erişimine izin ver
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    # UFW'yi etkinleştir
    ufw --force enable
    
    # Nginx güvenlik ayarları
    cat >> /etc/nginx/nginx.conf << 'EOF'

# Güvenlik ayarları
server_tokens off;
client_max_body_size 10M;
client_body_timeout 10s;
client_header_timeout 10s;
keepalive_timeout 65;
send_timeout 10s;
EOF
    
    # Nginx yapılandırmasını yeniden yükle
    systemctl reload nginx
    
    log "Güvenlik ayarları tamamlandı."
}

# Ana fonksiyon
main() {
    log "=== Nginx Web Sunucusu Kurulum ve Yönetim Projesi ==="
    log "Kurulum başlatılıyor..."
    
    check_root
    check_system
    install_nginx
    setup_website
    configure_nginx
    setup_monitoring
    setup_security
    
    log "=== Kurulum Tamamlandı! ==="
    log "Web sitesi: http://$(hostname -I | awk '{print $1}')"
    log "Nginx durumu: $(systemctl is-active nginx)"
    log "Firewall durumu: $(ufw status | grep Status | awk '{print $2}')"
    log ""
    log "Monitoring scriptleri /usr/local/bin/ dizininde kuruldu."
    log "Cron görevleri /etc/cron.d/nginx-monitoring dosyasında yapılandırıldı."
    log "Log dosyaları /var/log/nginx-analytics/ dizininde toplanacak."
}

# Script çalıştırılıyor
main "$@"
