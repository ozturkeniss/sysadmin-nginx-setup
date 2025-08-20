#!/bin/bash

# Security Monitoring Script
# This script monitors security-related events and generates alerts

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
LOG_DIR="/var/log/nginx-analytics/security"
ALERT_LOG="$LOG_DIR/security-alerts.log"
INTRUSION_LOG="$LOG_DIR/intrusion-detection.log"
FIREWALL_LOG="$LOG_DIR/firewall-events.log"
FAIL2BAN_LOG="$LOG_DIR/fail2ban-status.log"

# Proje dizinleri (hem sistem hem proje klasöründe dosya oluştur)
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_LOGS_DIR="$PROJECT_DIR/logs"
PROJECT_MONITORING_DIR="$PROJECT_DIR/monitoring"
PROJECT_SECURITY_DIR="$PROJECT_MONITORING_DIR/security"

# Alert thresholds
MAX_FAILED_LOGINS=10
MAX_SUSPICIOUS_IPS=5
MAX_SSL_ERRORS=20
MAX_RATE_LIMIT_VIOLATIONS=15

# Log function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$ALERT_LOG"
}

alert() {
    echo -e "${RED}[ALERT] $1${NC}" | tee -a "$ALERT_LOG"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}" | tee -a "$ALERT_LOG"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}" | tee -a "$ALERT_LOG"
}

# Create log directories (both system and project)
mkdir -p "$LOG_DIR"
mkdir -p "$PROJECT_LOGS_DIR"
mkdir -p "$PROJECT_MONITORING_DIR"
mkdir -p "$PROJECT_SECURITY_DIR"

# Monitor failed login attempts
monitor_failed_logins() {
    info "Monitoring failed login attempts..."
    
    local failed_count=$(grep "Failed password" /var/log/auth.log 2>/dev/null | wc -l)
    local recent_failed=$(grep "Failed password" /var/log/auth.log 2>/dev/null | grep "$(date '+%b %d')" | wc -l)
    
    if [ "$recent_failed" -gt "$MAX_FAILED_LOGINS" ]; then
        alert "High number of failed login attempts: $recent_failed (threshold: $MAX_FAILED_LOGINS)"
        
        # Get suspicious IPs
        local suspicious_ips=$(grep "Failed password" /var/log/auth.log 2>/dev/null | grep "$(date '+%b %d')" | awk '{print $11}' | sort | uniq -c | sort -nr | head -5)
        
        echo "Suspicious IPs:" | tee -a "$INTRUSION_LOG"
        echo "$suspicious_ips" | tee -a "$INTRUSION_LOG"
    else
        log "Failed login attempts: $recent_failed (normal range)"
    fi
}

# Monitor firewall events
monitor_firewall() {
    info "Monitoring firewall events..."
    
    if command -v ufw &> /dev/null; then
        local ufw_status=$(ufw status | grep Status | awk '{print $2}')
        
        if [ "$ufw_status" = "active" ]; then
            log "UFW firewall is active"
            
            # Check for blocked connections
            local blocked_connections=$(grep "UFW BLOCK" /var/log/ufw.log 2>/dev/null | grep "$(date '+%b %d')" | wc -l)
            
            if [ "$blocked_connections" -gt 0 ]; then
                warning "Firewall blocked $blocked_connections connections today"
                
                # Log blocked IPs
                local blocked_ips=$(grep "UFW BLOCK" /var/log/ufw.log 2>/dev/null | grep "$(date '+%b %d')" | awk '{print $12}' | sort | uniq -c | sort -nr)
                echo "Blocked IPs:" | tee -a "$FIREWALL_LOG"
                echo "$blocked_ips" | tee -a "$FIREWALL_LOG"
            fi
        else
            alert "UFW firewall is not active!"
        fi
    else
        warning "UFW firewall is not installed"
    fi
}

# Monitor Fail2ban status
monitor_fail2ban() {
    info "Monitoring Fail2ban status..."
    
    if command -v fail2ban-client &> /dev/null; then
        local fail2ban_status=$(systemctl is-active fail2ban 2>/dev/null)
        
        if [ "$fail2ban_status" = "active" ]; then
            log "Fail2ban is active"
            
            # Get banned IPs
            local banned_ips=$(fail2ban-client status 2>/dev/null | grep "Banned IP list" | cut -d: -f2 | tr ',' '\n' | sed 's/ //g' | grep -v "^$")
            
            if [ -n "$banned_ips" ]; then
                local banned_count=$(echo "$banned_ips" | wc -l)
                warning "Fail2ban has $banned_count banned IPs"
                
                echo "Banned IPs:" | tee -a "$FAIL2BAN_LOG"
                echo "$banned_ips" | tee -a "$FAIL2BAN_LOG"
            else
                log "No IPs are currently banned"
            fi
            
            # Check jail status
            local jails=$(fail2ban-client status 2>/dev/null | grep "Jail list" | cut -d: -f2 | tr ',' '\n' | sed 's/ //g' | grep -v "^$")
            
            for jail in $jails; do
                local jail_status=$(fail2ban-client status "$jail" 2>/dev/null | grep "Currently banned" | awk '{print $4}')
                log "Jail $jail: $jail_status banned IPs"
            done
        else
            alert "Fail2ban is not active!"
        fi
    else
        warning "Fail2ban is not installed"
    fi
}

# Monitor SSL/TLS security
monitor_ssl_security() {
    info "Monitoring SSL/TLS security..."
    
    local ssl_cert="/etc/nginx/ssl/nginx.crt"
    local ssl_key="/etc/nginx/ssl/nginx.key"
    
    if [ -f "$ssl_cert" ] && [ -f "$ssl_key" ]; then
        log "SSL certificates found"
        
        # Check certificate expiration
        local cert_expiry=$(openssl x509 -in "$ssl_cert" -noout -enddate 2>/dev/null | cut -d= -f2)
        local days_until_expiry=$(( ($(date -d "$cert_expiry" +%s) - $(date +%s)) / 86400 ))
        
        if [ "$days_until_expiry" -lt 30 ]; then
            alert "SSL certificate expires in $days_until_expiry days!"
        elif [ "$days_until_expiry" -lt 90 ]; then
            warning "SSL certificate expires in $days_until_expiry days"
        else
            log "SSL certificate expires in $days_until_expiry days (OK)"
        fi
        
        # Check for SSL errors in Nginx logs
        local ssl_errors=$(grep "SSL" /var/log/nginx/nginx-demo-error.log 2>/dev/null | grep "$(date '+%b %d')" | wc -l)
        
        if [ "$ssl_errors" -gt "$MAX_SSL_ERRORS" ]; then
            alert "High number of SSL errors: $ssl_errors (threshold: $MAX_SSL_ERRORS)"
        fi
    else
        warning "SSL certificates not found"
    fi
}

# Monitor suspicious network activity
monitor_network_activity() {
    info "Monitoring network activity..."
    
    # Check for unusual connections
    local established_connections=$(ss -tuln | grep ESTABLISHED | wc -l)
    local listening_ports=$(ss -tuln | grep LISTEN | wc -l)
    
    log "Active connections: $established_connections, Listening ports: $listening_ports"
    
    # Check for unusual listening ports
    local unusual_ports=$(ss -tuln | grep LISTEN | awk '{print $5}' | cut -d: -f2 | grep -E "^(8080|8081|9000|3000|5000|8000)$" | wc -l)
    
    if [ "$unusual_ports" -gt 0 ]; then
        warning "Unusual ports are listening: $unusual_ports"
        ss -tuln | grep LISTEN | grep -E ":(8080|8081|9000|3000|5000|8000)" | tee -a "$LOG_DIR/network-activity.log"
    fi
    
    # Check for rate limiting violations
    local rate_limit_violations=$(grep "rate limiting" /var/log/nginx/nginx-demo-error.log 2>/dev/null | grep "$(date '+%b %d')" | wc -l)
    
    if [ "$rate_limit_violations" -gt "$MAX_RATE_LIMIT_VIOLATIONS" ]; then
        alert "High number of rate limit violations: $rate_limit_violations (threshold: $MAX_RATE_LIMIT_VIOLATIONS)"
    fi
}

# Generate security summary
generate_security_summary() {
    info "Generating security summary..."
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local summary_file="$LOG_DIR/security-summary_$timestamp.txt"
    
    # Güvenlik özeti içeriğini oluştur
    local summary_content="=== SECURITY MONITORING SUMMARY ===
Generated: $(date)

🔒 SECURITY STATUS:

1. FAILED LOGIN ATTEMPTS:
$(grep "Failed password" /var/log/auth.log 2>/dev/null | grep "$(date '+%b %d')" | wc -l) attempts today

2. FIREWALL STATUS:
$(ufw status 2>/dev/null | grep Status || echo "UFW not available")

3. FAIL2BAN STATUS:
$(fail2ban-client status 2>/dev/null | grep "Jail list" || echo "Fail2ban not available")

4. SSL/TLS STATUS:
$(if [ -f "/etc/nginx/ssl/nginx.crt" ]; then echo "SSL certificates found"; else echo "SSL certificates not found"; fi)

5. NETWORK ACTIVITY:
$(ss -tuln | grep LISTEN | wc -l) listening ports
$(ss -tuln | grep ESTABLISHED | wc -l) active connections

6. RECENT ALERTS:
$(tail -10 "$ALERT_LOG" 2>/dev/null || echo "No alerts found")
"
    
    # Hem sistem hem proje klasöründe oluştur
    echo "$summary_content" > "$summary_file"
    echo "$summary_content" > "$PROJECT_SECURITY_DIR/security-summary_$timestamp.txt"
    
    log "Security summary generated: $summary_file"
    log "Security summary also created in project directory: $PROJECT_SECURITY_DIR/security-summary_$timestamp.txt"
}

# Main monitoring function
main() {
    log "=== Security Monitoring Started ==="
    
    # Run all monitoring functions
    monitor_failed_logins
    monitor_firewall
    monitor_fail2ban
    monitor_ssl_security
    monitor_network_activity
    
    # Generate summary
    generate_security_summary
    
    log "=== Security Monitoring Completed ==="
    
    # Clean up old logs (keep last 30 days) - both system and project directories
    find "$LOG_DIR" -name "*.log" -mtime +30 -delete 2>/dev/null || true
    find "$LOG_DIR" -name "*.txt" -mtime +30 -delete 2>/dev/null || true
    find "$PROJECT_SECURITY_DIR" -name "*.log" -mtime +30 -delete 2>/dev/null || true
    find "$PROJECT_SECURITY_DIR" -name "*.txt" -mtime +30 -delete 2>/dev/null || true
}

# Run the script
main "$@"
