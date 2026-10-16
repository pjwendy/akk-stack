FROM crazymax/fail2ban:latest

COPY jail.local /etc/fail2ban/jail.local
COPY entrypoint.sh /f2b-entrypoint.sh
RUN chmod +x /f2b-entrypoint.sh

ENTRYPOINT ["/f2b-entrypoint.sh"]
CMD ["fail2ban-server", "-f", "-x", "-v", "start"]