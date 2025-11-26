# Bookclub Production Deployment

Quick reference for production deployment files and scripts.

## Directory Structure

```
docker/
├── docker-compose.prod.yml    # Production Docker Compose configuration
├── deploy.sh                   # Main deployment script
├── backup.sh                   # Database and file backup script
├── restore.sh                  # Restore from backup script
├── healthcheck.sh              # Health monitoring script
├── .env.example                # Environment variables template
├── nginx/                      # Nginx reverse proxy configuration
│   ├── nginx.conf              # Main Nginx config
│   ├── conf.d/
│   │   └── discourse.conf      # Discourse server configuration
│   └── snippets/
│       ├── ssl-params.conf     # SSL/TLS parameters
│       ├── security-headers.conf
│       └── proxy-params.conf
└── backups/                    # Backup storage directory
```

## Quick Start

### Initial Deployment

```bash
# 1. Copy and configure environment
cd /opt/bookclub/docker
cp .env.example .env
nano .env  # Fill in required values

# 2. Run initial deployment
./deploy.sh --init
```

### Regular Updates

```bash
# Deploy latest code
./deploy.sh

# Deploy with backup first
./deploy.sh --backup-first
```

### Rollback

```bash
./deploy.sh --rollback
```

## Daily Operations

### Backups

```bash
# Manual backup
./backup.sh

# Backup with rotation (keep last 7)
./backup.sh --rotate 7

# Backup and upload to S3
./backup.sh --s3
```

### Health Checks

```bash
# Run health check
./healthcheck.sh

# Quiet mode (errors only)
./healthcheck.sh --quiet

# JSON output
./healthcheck.sh --json
```

### Restore

```bash
# Restore database
./restore.sh --db backups/discourse-db-TIMESTAMP.sql.gz

# Restore database and files
./restore.sh --db backups/discourse-db-TIMESTAMP.sql.gz \
             --uploads backups/discourse-uploads-TIMESTAMP.tar.gz
```

## Container Management

```bash
# View running containers
docker compose -f docker-compose.prod.yml ps

# View logs
docker compose -f docker-compose.prod.yml logs -f

# Restart services
docker compose -f docker-compose.prod.yml restart

# Stop all services
docker compose -f docker-compose.prod.yml down

# Start all services
docker compose -f docker-compose.prod.yml up -d
```

## Configuration Files

### Required Environment Variables

See `.env.example` for all options. Minimum required:

- `DISCOURSE_HOSTNAME`: Your domain name
- `DISCOURSE_DEVELOPER_EMAILS`: Admin email addresses
- `POSTGRES_PASSWORD`: Database password
- `SECRET_KEY_BASE`: Rails secret (generate with: `openssl rand -hex 64`)
- `SMTP_ADDRESS`, `SMTP_USER_NAME`, `SMTP_PASSWORD`: Email configuration
- `BOOKCLUB_PLUGIN_PATH`: Absolute path to plugin

### Nginx Configuration

Nginx configuration is in `nginx/conf.d/discourse.conf`. Key features:

- Automatic HTTP to HTTPS redirect
- SSL/TLS configuration via Let's Encrypt
- Static file caching
- Proxy to Discourse application
- Security headers
- Rate limiting

## Automated Tasks

### Cron Jobs

Add to crontab (`crontab -e`):

```bash
# Daily backup at 2 AM
0 2 * * * /opt/bookclub/docker/backup.sh --rotate 7 --s3

# Health check every 5 minutes
*/5 * * * * /opt/bookclub/docker/healthcheck.sh --quiet --slack-webhook "YOUR_WEBHOOK_URL"
```

### SSL Certificate Renewal

Certbot automatically renews certificates. Manual renewal:

```bash
docker compose -f docker-compose.prod.yml run --rm certbot renew
docker exec bookclub_nginx nginx -s reload
```

## Troubleshooting

### Services Won't Start

```bash
# Check Docker
docker info

# Check logs
docker compose -f docker-compose.prod.yml logs

# Validate configuration
docker compose -f docker-compose.prod.yml config
```

### Database Issues

```bash
# Check PostgreSQL
docker exec bookclub_postgres pg_isready -U discourse

# Connect to database
docker exec -it bookclub_postgres psql -U discourse
```

### Nginx/SSL Issues

```bash
# Test Nginx config
docker exec bookclub_nginx nginx -t

# Reload Nginx
docker exec bookclub_nginx nginx -s reload

# Check certificate
docker exec bookclub_certbot openssl x509 -in /etc/letsencrypt/live/YOUR_DOMAIN/cert.pem -noout -dates
```

### Application Errors

```bash
# Discourse logs
docker logs --tail 100 bookclub_discourse

# Rails console
docker exec -it bookclub_discourse bash -c "cd /var/www/discourse && su discourse -c 'bundle exec rails console'"

# Restart Sidekiq
docker exec bookclub_discourse sv restart sidekiq
```

## Monitoring

### Health Check Endpoints

- Application: `https://your-domain.com/srv/status`
- Load balancer: `https://your-domain.com/health`

### Metrics

```bash
# Container stats
docker stats

# Disk usage
df -h

# Database size
docker exec bookclub_postgres psql -U discourse -c "SELECT pg_size_pretty(pg_database_size('discourse'));"
```

## Security

### Firewall

```bash
sudo ufw allow 22/tcp   # SSH
sudo ufw allow 80/tcp   # HTTP
sudo ufw allow 443/tcp  # HTTPS
sudo ufw enable
```

### Updates

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Update Docker images
docker compose -f docker-compose.prod.yml pull
./deploy.sh
```

## Additional Documentation

- **[PRODUCTION_DEPLOYMENT.md](../PRODUCTION_DEPLOYMENT.md)**: Complete deployment guide
- **[.env.example](.env.example)**: Environment variables reference
- **[Docker Setup](README.md)**: Development setup documentation

## Support

For issues:
- Check logs: `docker compose logs`
- Run health check: `./healthcheck.sh`
- Review [PRODUCTION_DEPLOYMENT.md](../PRODUCTION_DEPLOYMENT.md)
- Contact: See main README for support channels

## Version

This production setup is designed for:
- Discourse: latest (or pinned version in `.env`)
- Bookclub Plugin: 0.1.0
- Docker: 20.10+
- Docker Compose: 2.0+
