# Nginx Log Analysis System

## Overview

The Logs directory contains automatically generated analysis reports from Nginx web server logs. These reports provide detailed insights into web traffic patterns, error analysis, and performance metrics for system administrators and DevOps teams.

## Generated Log Files

### Access Log Analysis
- **Purpose**: Analyzes web traffic patterns and visitor behavior
- **Source**: Nginx access logs (`/var/log/nginx/nginx-demo-access.log`)
- **Content**: Request statistics, IP analysis, page popularity, HTTP status codes, user-agent analysis
- **Format**: Plain text with structured data presentation

### Error Log Analysis
- **Purpose**: Monitors server errors and identifies issues
- **Source**: Nginx error logs (`/var/log/nginx/nginx-demo-error.log`)
- **Content**: Error counts, critical error detection, error type classification, hourly distribution
- **Format**: Plain text with error categorization

### Performance Analysis
- **Purpose**: Tracks system resource utilization and Nginx performance
- **Source**: System metrics and Nginx process information
- **Content**: Process count, memory usage, CPU utilization, disk usage, response times
- **Format**: Plain text with performance metrics

## File Naming Convention

```
{analysis_type}_{YYYYMMDD}_{HHMM}.txt
```

**Examples:**
- `access_analysis_20250821_0146.txt`
- `error_analysis_20250821_0146.txt`
- `performance_20250821_0146.txt`

## Report Structure

### Access Analysis Report
```
=== Nginx Access Log Analizi ===
Analiz Zamanı: [Timestamp]
Log Dosyası: [Log Path]

📊 GENEL İSTATİSTİKLER:
- Toplam İstek Sayısı: [Count]
- Son 1 Saatteki İstekler: [Count]

🌐 EN POPÜLER IP ADRESLERİ:
[IP Address] [Count]

📄 EN POPÜLER SAYFALAR:
[Page Path] [Count]

🔢 HTTP DURUM KODLARI:
[Status Code] [Count]

🤖 EN POPÜLER USER-AGENT'LAR:
[User Agent] [Count]
```

### Error Analysis Report
```
=== Nginx Error Log Analizi ===
Analiz Zamanı: [Timestamp]
Log Dosyası: [Log Path]

❌ HATA İSTATİSTİKLERİ:
- Son 1 Saatteki Hatalar: [Count]
- Kritik Hatalar (5xx): [Count]

🚨 HATA TÜRLERİ:
[Error Type] [Count]
```

### Performance Report
```
=== Nginx Performans Analizi ===
Analiz Zamanı: [Timestamp]

⚡ PERFORMANS METRİKLERİ:
- Nginx Process Sayısı: [Count]
- Memory Kullanımı: [Memory Usage]
- CPU Kullanımı: [CPU Usage]
- Log Disk Kullanımı: [Disk Usage]
```

## Data Sources

### Nginx Access Logs
- **Format**: Standard Nginx access log format
- **Fields**: IP address, timestamp, request method, URI, status code, response size, user-agent, referrer
- **Analysis**: Traffic patterns, visitor behavior, content popularity

### Nginx Error Logs
- **Format**: Nginx error log format
- **Fields**: Timestamp, error level, error message, client IP, request details
- **Analysis**: Error frequency, critical issues, performance problems

### System Metrics
- **Process Information**: Nginx worker processes, memory usage, CPU utilization
- **Resource Monitoring**: Disk space, network connections, system load
- **Performance Data**: Response times, throughput, error rates

## Analysis Frequency

- **Real-time**: Reports generated on-demand when scripts are executed
- **Scheduled**: Automated analysis via cron jobs (recommended: hourly)
- **Manual**: Scripts can be run manually for immediate analysis

## Data Retention

- **Current Reports**: 7 days retention
- **Automatic Cleanup**: Old reports automatically removed
- **Storage Optimization**: Efficient log parsing and minimal disk usage

## Integration

### Scripts
- `analyze_nginx_logs.sh`: Main log analysis script
- `daily_nginx_report.sh`: Comprehensive daily reporting
- `check_nginx_status.sh`: Health monitoring and status checks

### Monitoring
- **Real-time Analysis**: Immediate log processing and report generation
- **Historical Data**: Trend analysis and pattern recognition
- **Alert System**: Critical error detection and notification

## Usage

### Manual Analysis
```bash
# Run complete log analysis
sudo ./scripts/analyze_nginx_logs.sh

# Check specific log files
sudo tail -f /var/log/nginx/nginx-demo-access.log
sudo tail -f /var/log/nginx/nginx-demo-error.log
```

### Automated Monitoring
```bash
# Set up hourly analysis
0 * * * * /path/to/scripts/analyze_nginx_logs.sh

# Set up daily comprehensive reports
0 0 * * * /path/to/scripts/daily_nginx_report.sh
```

## Customization

### Log Formats
- Modify Nginx configuration for custom log formats
- Adjust analysis scripts for specific data extraction
- Configure custom metrics and thresholds

### Report Content
- Add custom analysis fields
- Modify report templates and formatting
- Include business-specific metrics

### Retention Policies
- Adjust cleanup schedules
- Configure storage limits
- Implement archival strategies

## Troubleshooting

### Common Issues
1. **Missing Log Files**: Verify Nginx log configuration and file permissions
2. **Permission Errors**: Ensure scripts have appropriate execution permissions
3. **Disk Space**: Monitor log directory size and implement rotation
4. **Analysis Failures**: Check log file formats and script compatibility

### Debug Information
- Enable verbose logging in analysis scripts
- Check system logs for execution errors
- Verify Nginx service status and configuration

## Performance Considerations

- **Efficient Parsing**: Optimized log parsing algorithms
- **Resource Usage**: Minimal CPU and memory footprint
- **Scalability**: Handle large log files and high traffic volumes
- **Caching**: Implement result caching for repeated analysis

## Security

- **Access Control**: Restrict log file access to authorized users
- **Data Privacy**: Implement log anonymization for sensitive information
- **Audit Trail**: Maintain analysis execution logs
- **Encryption**: Secure storage for sensitive log data
