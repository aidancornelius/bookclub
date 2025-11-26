# Bookclub Production Deployment Guide

This guide provides complete instructions for deploying the Bookclub plugin to production using Docker and Nginx.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Initial Setup](#initial-setup)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Backups and Restore](#backups-and-restore)
- [Monitoring](#monitoring)
- [Maintenance](#maintenance)
- [Troubleshooting](#troubleshooting)
- [Security](#security)

## Overview

The production deployment uses:

- **Docker Compose** for orchestrating multiple services
- **PostgreSQL** for the database
- **Redis** for caching and background jobs
- **Nginx** as a reverse proxy with SSL termination
- **Certbot** for automated SSL certificate management
- **Discourse official Docker image** with the Bookclub plugin mounted

This setup is designed for a single-server production deployment. For high-availability or multi-server setups, additional configuration is required.

## Prerequisites

### Server Requirements

- **Operating System**: Ubuntu 22.04 LTS or Debian 11+ (recommended)
- **CPU**: 2+ cores (4+ recommended)
- **RAM**: 4GB minimum (8GB+ recommended)
- **Disk**: 50GB+ SSD storage
- **Network**: Public IP address with ports 80 and 443 accessible

### Software Requirements

Install the following on your production server:

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose (if not included)
sudo apt install docker-compose-plugin

# Verify installation
docker --version
docker compose version
```

### DNS Configuration

Before deploying, ensure your domain's DNS is configured:

1. Create an A record pointing your domain to your server's public IP
2. Wait for DNS propagation (can take up to 48 hours, usually much faster)
3. Verify with: `dig your-domain.com` or `nslookup your-domain.com`

### Email Provider

Discourse requires SMTP for sending emails. Choose a provider:

- **SendGrid** (recommended, generous free tier)
- **Mailgun** (reliable, good deliverability)
- **Amazon SES** (cost-effective at scale)
- **Postmark** (excellent deliverability)

Set up an account and obtain SMTP credentials before deploying.

## Initial Setup

### 1. Clone the Repository

```bash
# SSH into your production server
ssh user@your-server

# Create application directory
sudo mkdir -p /opt/bookclub
sudo chown $USER:$USER /opt/bookclub

# Clone your Bookclub plugin
cd /opt
git clone https://github.com/your-org/bookclub.git
cd bookclub
```

### 2. Configure Environment Variables

```bash
# Copy the example environment file
cd docker
cp .env.example .env

# Edit the configuration
nano .env
```

**Required variables to configure:**

```bash
# Domain configuration
DISCOURSE_HOSTNAME=your-domain.com
DISCOURSE_DEVELOPER_EMAILS=admin@your-domain.com

# Generate secure passwords
POSTGRES_PASSWORD=$(openssl rand -base64 32)
SECRET_KEY_BASE=$(openssl rand -hex 64)

# SMTP configuration (example for SendGrid)
SMTP_ADDRESS=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USER_NAME=apikey
SMTP_PASSWORD=your-sendgrid-api-key
SMTP_ENABLE_START_TLS=true
SMTP_AUTHENTICATION=login

# Plugin path
BOOKCLUB_PLUGIN_PATH=/opt/bookclub
```

Save the file (`Ctrl+X`, `Y`, `Enter` in nano).

**IMPORTANT**: Keep your `.env` file secure. It contains sensitive credentials.

### 3. Configure Nginx

The Nginx configuration uses environment variable substitution. You need to replace placeholders:

```bash
# Replace ${DISCOURSE_HOSTNAME} in Nginx configs
cd nginx/conf.d
sed -i "s/\${DISCOURSE_HOSTNAME}/$DISCOURSE_HOSTNAME/g" discourse.conf
cd ../snippets
sed -i "s/\${DISCOURSE_HOSTNAME}/$DISCOURSE_HOSTNAME/g" ssl-params.conf
```

Alternatively, you can manually edit these files and replace `${DISCOURSE_HOSTNAME}` with your actual domain.

### 4. Initial Deployment

Run the deployment script in initialisation mode:

```bash
cd /opt/bookclub/docker
./deploy.sh --init
```

This script will:

1. Pull Docker images
2. Start all services (PostgreSQL, Redis, Discourse, Nginx, Certbot)
3. Wait for the database to be ready
4. Run database migrations
5. Precompile assets
6. Request an SSL certificate from Let's Encrypt
7. Reload Nginx with the new certificate
8. Prompt you to create an admin user

**Creating the Admin User:**

When prompted, provide:
- Email address (must match one in `DISCOURSE_DEVELOPER_EMAILS`)
- Password (strong password)
- Username

The script will create your admin account and complete the setup.

### 5. Verify Deployment

After the script completes:

```bash
# Check that all containers are running
docker compose -f docker-compose.prod.yml ps

# Should show all services as healthy:
# - bookclub_postgres
# - bookclub_redis
# - bookclub_discourse
# - bookclub_nginx
# - bookclub_certbot

# Check Discourse logs
docker logs bookclub_discourse

# Test the health endpoint
curl https://your-domain.com/srv/status
```

Visit `https://your-domain.com` in your browser. You should see the Discourse homepage.

### 6. Initial Configuration

Log in with your admin credentials and configure:

1. **Site Settings** (`/admin/site_settings`)
   - Set site title, description, logo
   - Configure category settings
   - Enable Bookclub plugin: `bookclub_enabled`

2. **Email Settings** (`/admin/email`)
   - Test email delivery
   - Configure email templates

3. **Security** (`/admin/site_settings/category/security`)
   - Review security settings
   - Configure login methods

4. **Bookclub Configuration**
   - Create publication categories
   - Set up access tiers (groups)
   - Configure pricing (if using Stripe integration)

## Configuration

### Environment Variables

All configuration is managed through the `.env` file. Key variables:

| Variable | Description | Required |
|----------|-------------|----------|
| `DISCOURSE_HOSTNAME` | Your domain name | Yes |
| `DISCOURSE_DEVELOPER_EMAILS` | Admin email addresses | Yes |
| `POSTGRES_PASSWORD` | Database password | Yes |
| `SECRET_KEY_BASE` | Rails secret key | Yes |
| `SMTP_ADDRESS` | SMTP server address | Yes |
| `SMTP_USER_NAME` | SMTP username | Yes |
| `SMTP_PASSWORD` | SMTP password | Yes |
| `BOOKCLUB_PLUGIN_PATH` | Path to plugin | Yes |
| `UNICORN_WORKERS` | Number of workers | No (default: 4) |
| `S3_ENABLED` | Use S3 for uploads | No (default: false) |

See `.env.example` for all available options.

### SSL Certificates

SSL certificates are managed automatically by Certbot:

- Certificates are stored in the `certbot_certs` Docker volume
- Certbot runs a renewal check twice daily
- Certificates auto-renew 30 days before expiry

**Manual certificate renewal:**

```bash
docker compose -f docker-compose.prod.yml run --rm certbot renew
docker exec bookclub_nginx nginx -s reload
```

### S3 Storage (Optional)

To use S3 for uploads and backups:

1. Create an S3 bucket in your AWS account
2. Create an IAM user with S3 access
3. Update `.env`:

```bash
S3_ENABLED=true
S3_BUCKET=your-bucket-name
S3_REGION=us-east-1
S3_ACCESS_KEY_ID=your-access-key
S3_SECRET_ACCESS_KEY=your-secret-key
S3_BACKUP_BUCKET=your-backup-bucket  # Optional, for backups
```

4. Redeploy: `./deploy.sh`

## Deployment

### Regular Updates

To deploy code updates:

```bash
cd /opt/bookclub/docker

# Optional: Create a backup first
./deploy.sh --backup-first

# Or just deploy
./deploy.sh
```

The deployment script:
1. Saves current version for rollback
2. Pulls latest code from git
3. Pulls updated Docker images
4. Runs database migrations
5. Precompiles assets
6. Restarts services
7. Verifies health

### Rollback

If something goes wrong:

```bash
./deploy.sh --rollback
```

This will:
- Restore the previous Docker image version
- Optionally restore the database backup
- Restart all services

### Zero-Downtime Deployments

The current setup has brief downtime during container restart. For zero-downtime:

1. Use multiple Discourse containers behind a load balancer
2. Use blue-green deployment strategy
3. Consider using Kubernetes for orchestration

## Backups and Restore

### Automated Backups

Set up automated daily backups using cron:

```bash
# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * /opt/bookclub/docker/backup.sh --rotate 7 >> /var/log/bookclub-backup.log 2>&1
```

**Backup options:**

```bash
# Create backup and keep last 7
./backup.sh --rotate 7

# Create backup and upload to S3
./backup.sh --s3

# Both
./backup.sh --rotate 7 --s3
```

Backups include:
- PostgreSQL database (compressed SQL dump)
- Uploaded files (if stored locally)
- Backup manifest file

### Manual Backup

```bash
cd /opt/bookclub/docker
./backup.sh
```

Backups are stored in `docker/backups/` by default.

### Restore from Backup

**WARNING**: Restoring will destroy all current data.

```bash
cd /opt/bookclub/docker

# List available backups
ls -lh backups/

# Restore database only
./restore.sh --db backups/discourse-db-20240315_020000.sql.gz

# Restore database and uploads
./restore.sh --db backups/discourse-db-20240315_020000.sql.gz \
             --uploads backups/discourse-uploads-20240315_020000.tar.gz
```

### Off-site Backup Strategy

**Recommended approach:**

1. Enable S3 backups in `.env`:
   ```bash
   S3_BACKUP_BUCKET=bookclub-backups
   ```

2. Configure backup script to upload to S3:
   ```bash
   # In crontab
   0 2 * * * /opt/bookclub/docker/backup.sh --rotate 7 --s3
   ```

3. Configure S3 lifecycle rules to archive old backups to Glacier

4. Keep recent backups locally for fast recovery

## Monitoring

### Health Checks

Run health checks manually:

```bash
cd /opt/bookclub/docker

# Standard health check
./healthcheck.sh

# Quiet mode (only errors)
./healthcheck.sh --quiet

# JSON output
./healthcheck.sh --json
```

### Automated Monitoring

Set up regular health checks with alerts:

```bash
# Edit crontab
crontab -e

# Run health check every 5 minutes
*/5 * * * * /opt/bookclub/docker/healthcheck.sh --quiet --slack-webhook "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
```

**Health check monitors:**
- Docker daemon status
- PostgreSQL connectivity
- Redis connectivity
- Discourse application health
- Nginx proxy status
- Disk space usage
- Memory usage
- SSL certificate expiry

### Logs

**View container logs:**

```bash
# All services
docker compose -f docker-compose.prod.yml logs

# Follow logs in real-time
docker compose -f docker-compose.prod.yml logs -f

# Specific service
docker logs bookclub_discourse
docker logs bookclub_postgres
docker logs bookclub_nginx

# With timestamps
docker logs --timestamps bookclub_discourse

# Last 100 lines
docker logs --tail 100 bookclub_discourse
```

**Discourse application logs:**

```bash
# Rails logs
docker exec bookclub_discourse tail -f /var/www/discourse/log/production.log

# Sidekiq logs
docker exec bookclub_discourse tail -f /var/www/discourse/log/sidekiq.log
```

**Nginx logs:**

```bash
# Access logs
docker exec bookclub_nginx tail -f /var/log/nginx/discourse_access.log

# Error logs
docker exec bookclub_nginx tail -f /var/log/nginx/discourse_error.log
```

### Performance Monitoring

**Resource usage:**

```bash
# All containers
docker stats

# Specific container
docker stats bookclub_discourse
```

**Database performance:**

```bash
# Connect to PostgreSQL
docker exec -it bookclub_postgres psql -U discourse

# View active queries
SELECT pid, now() - pg_stat_activity.query_start AS duration, query
FROM pg_stat_activity
WHERE (now() - pg_stat_activity.query_start) > interval '5 seconds';

# Database size
SELECT pg_size_pretty(pg_database_size('discourse'));
```

## Maintenance

### Regular Maintenance Tasks

**Weekly:**
- Review logs for errors
- Check disk space
- Verify backups are running
- Monitor SSL certificate expiry

**Monthly:**
- Review security updates
- Update Docker images
- Clean up old backups
- Review database size and performance

**Quarterly:**
- Full security audit
- Disaster recovery testing
- Performance optimisation review

### Updating Discourse

```bash
cd /opt/bookclub/docker

# Pull latest Discourse image
docker compose -f docker-compose.prod.yml pull discourse

# Deploy update
./deploy.sh
```

### Updating Bookclub Plugin

```bash
cd /opt/bookclub

# Pull latest code
git pull origin main

# Deploy
cd docker
./deploy.sh
```

### Database Maintenance

**Vacuum database:**

```bash
docker exec bookclub_postgres psql -U discourse -c "VACUUM ANALYZE;"
```

**Reindex:**

```bash
docker exec bookclub_discourse bash -c "cd /var/www/discourse && su discourse -c 'bundle exec rake db:reindex'"
```

### Docker Cleanup

```bash
# Remove unused images
docker image prune -a

# Remove unused volumes (WARNING: be careful)
docker volume prune

# Remove stopped containers
docker container prune
```

## Troubleshooting

### Services Won't Start

**Check Docker:**
```bash
docker info
sudo systemctl status docker
```

**Check compose file:**
```bash
docker compose -f docker-compose.prod.yml config
```

**View detailed errors:**
```bash
docker compose -f docker-compose.prod.yml up
# Without -d to see output
```

### Database Connection Errors

**Check PostgreSQL:**
```bash
docker exec bookclub_postgres pg_isready -U discourse
```

**Reset database connection:**
```bash
docker compose -f docker-compose.prod.yml restart postgres
docker compose -f docker-compose.prod.yml restart discourse
```

### Nginx/SSL Issues

**Test Nginx configuration:**
```bash
docker exec bookclub_nginx nginx -t
```

**Reload Nginx:**
```bash
docker exec bookclub_nginx nginx -s reload
```

**Renew SSL certificate:**
```bash
docker compose -f docker-compose.prod.yml run --rm certbot renew
```

**Check certificate:**
```bash
docker exec bookclub_certbot openssl x509 -in /etc/letsencrypt/live/your-domain.com/cert.pem -noout -dates
```

### Application Errors

**Check Discourse logs:**
```bash
docker logs --tail 100 bookclub_discourse
```

**Rails console for debugging:**
```bash
docker exec -it bookclub_discourse bash -c "cd /var/www/discourse && su discourse -c 'bundle exec rails console'"
```

**Restart Sidekiq:**
```bash
docker exec bookclub_discourse sv restart sidekiq
```

### Performance Issues

**Check resource usage:**
```bash
docker stats

# Server resources
htop  # or top
df -h
free -h
```

**Increase worker count:**

Edit `.env`:
```bash
UNICORN_WORKERS=8  # Increase based on CPU cores
```

Redeploy:
```bash
./deploy.sh
```

### Out of Disk Space

**Find large files:**
```bash
du -h /var/lib/docker | sort -h | tail -20
```

**Clean up Docker:**
```bash
docker system prune -a --volumes
```

**Check PostgreSQL size:**
```bash
docker exec bookclub_postgres psql -U discourse -c "
  SELECT pg_size_pretty(pg_database_size('discourse'));"
```

## Security

### Security Best Practices

1. **Keep software updated**
   - Regular security updates for OS
   - Update Docker images
   - Update Discourse and plugins

2. **Firewall configuration**
   ```bash
   # Allow only necessary ports
   sudo ufw allow 22/tcp    # SSH
   sudo ufw allow 80/tcp    # HTTP
   sudo ufw allow 443/tcp   # HTTPS
   sudo ufw enable
   ```

3. **SSH hardening**
   - Use key-based authentication
   - Disable password authentication
   - Change default SSH port
   - Use fail2ban for brute-force protection

4. **Database security**
   - Use strong passwords
   - Don't expose PostgreSQL port
   - Regular backups with encryption

5. **Application security**
   - Keep SECRET_KEY_BASE secure
   - Use strong SMTP credentials
   - Enable 2FA for admin accounts
   - Regular security audits

6. **Monitoring**
   - Set up log monitoring
   - Configure alerts for suspicious activity
   - Regular security scans

### Security Checklist

- [ ] Firewall configured and enabled
- [ ] SSH key-based authentication only
- [ ] Strong passwords for all services
- [ ] SSL certificate valid and auto-renewing
- [ ] Backups tested and working
- [ ] Monitoring and alerts configured
- [ ] Security headers enabled in Nginx
- [ ] Admin accounts use 2FA
- [ ] Regular updates scheduled
- [ ] Incident response plan documented

### Incident Response

If you suspect a security breach:

1. **Immediate actions:**
   - Take affected services offline
   - Preserve logs for analysis
   - Notify relevant stakeholders

2. **Investigation:**
   - Review access logs
   - Check for unauthorised database access
   - Scan for malware

3. **Recovery:**
   - Restore from known-good backup
   - Update all passwords and keys
   - Apply security patches

4. **Post-incident:**
   - Document the incident
   - Update security procedures
   - Improve monitoring

## Additional Resources

- [Discourse Admin Guide](https://meta.discourse.org/c/howto/admins/19)
- [Discourse Docker Guide](https://meta.discourse.org/t/beginners-guide-to-install-discourse-on-ubuntu-using-docker/14727)
- [Bookclub Plugin Documentation](../README.md)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)

## Support

For issues specific to:
- **Discourse**: [Discourse Meta](https://meta.discourse.org)
- **Bookclub Plugin**: [GitHub Issues](https://github.com/your-org/bookclub/issues)
- **Docker**: [Docker Forums](https://forums.docker.com)

## Contributing

If you improve this deployment setup:
1. Test thoroughly in a staging environment
2. Document your changes
3. Submit a pull request
4. Update this documentation

---

Last updated: 2025-11-26
