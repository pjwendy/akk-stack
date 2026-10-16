#!/bin/bash
set -e

cd /home/eqemu/server

# Create root-level symlinks so eqlaunch can find binaries via ./zone etc.
for bin in eqlaunch loginserver queryserv shared_memory ucs world zone; do
    ln -sf bin/$bin $bin 2>/dev/null || true
done

# Wait for MariaDB to be ready before starting anything
echo "[startup] Waiting for MariaDB..."
until mysqladmin ping -h mariadb -u eqemu -pIB4sa6WrqKgJHAwpk5Oh --silent 2>/dev/null; do
    sleep 2
done
echo "[startup] MariaDB ready"

# Create mysqldump credentials file in /tmp (Windows bind mount can't do 600 perms)
mkdir -p backups
cat > /tmp/login.my.cnf << 'MYCNF'
[client]
host=mariadb
port=3306
user=eqemu
password=IB4sa6WrqKgJHAwpk5Oh
protocol=TCP
MYCNF
chmod 600 /tmp/login.my.cnf

# Wrapper mysqldump so world's relative-path --defaults-extra-file resolves to /tmp
sudo tee /usr/local/bin/mysqldump > /dev/null << 'WRAPPER'
#!/bin/bash
args=()
for arg in "$@"; do
    if [[ "$arg" == "--defaults-extra-file=login.my.cnf" ]]; then
        args+=("--defaults-extra-file=/tmp/login.my.cnf")
    else
        args+=("$arg")
    fi
done
exec /usr/bin/mysqldump "${args[@]}"
WRAPPER
sudo chmod +x /usr/local/bin/mysqldump

# Watchdog: restart loginserver automatically if it exits
(while true; do
    ./bin/loginserver >> logs/loginserver.log 2>&1
    echo "[watchdog] loginserver exited, restarting in 5s..." >> logs/loginserver.log
    sleep 5
done) &

sleep 2

# Watchdog: restart world automatically if it exits
(while true; do
    ./bin/world >> logs/world.log 2>&1
    echo "[watchdog] world exited, restarting in 5s..." >> logs/world.log
    sleep 5
done) &

sleep 3

# eqlaunch manages zone processes — restarts them automatically if they exit
nohup ./bin/eqlaunch zone >> logs/eqlaunch_zone.log 2>&1 &

# Background: idempotent bot/rules bootstrap — runs every start, safe to re-run
(
  DB="mysql -h mariadb -u eqemu -pIB4sa6WrqKgJHAwpk5Oh peq"

  echo "[bootstrap] Waiting for db_version table..."
  until $DB -e "SELECT 1 FROM db_version LIMIT 1;" >/dev/null 2>&1; do
    sleep 3
  done

  # Pin bots_version immediately so world skips the crash-prone dump+update cycle
  $DB -e "UPDATE db_version SET bots_version=9054 WHERE bots_version < 9054;" 2>/dev/null

  # Apply bot tables bootstrap if core table is absent (fresh DB scenario)
  if ! $DB -e "DESCRIBE bot_data;" >/dev/null 2>&1; then
    echo "[bootstrap] Applying bot_tables_bootstrap.sql..."
    $DB < /home/eqemu/code/utils/sql/bot_tables_bootstrap.sql
  fi

  # Ensure the two tables added by incremental updates 9046/9052 exist
  $DB -e "
    CREATE TABLE IF NOT EXISTS \`bot_blocked_buffs\` (
      \`bot_id\`      int(10) unsigned NOT NULL DEFAULT '0',
      \`spell_id\`    int(10) unsigned NOT NULL DEFAULT '0',
      \`blocked\`     tinyint(3) unsigned NOT NULL DEFAULT '0',
      \`blocked_pet\` tinyint(3) unsigned NOT NULL DEFAULT '0',
      PRIMARY KEY (\`bot_id\`, \`spell_id\`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8;

    CREATE TABLE IF NOT EXISTS \`bot_settings\` (
      \`character_id\`  int(10) unsigned NOT NULL DEFAULT '0',
      \`bot_id\`        int(10) unsigned NOT NULL DEFAULT '0',
      \`stance\`        tinyint(3) unsigned NOT NULL DEFAULT '0',
      \`setting_id\`    smallint(5) unsigned NOT NULL DEFAULT '0',
      \`setting_type\`  tinyint(3) unsigned NOT NULL DEFAULT '0',
      \`value\`         int(11) NOT NULL DEFAULT '0',
      \`category_name\` varchar(64) NOT NULL DEFAULT '',
      \`setting_name\`  varchar(64) NOT NULL DEFAULT '',
      PRIMARY KEY (\`character_id\`, \`bot_id\`, \`stance\`, \`setting_id\`, \`setting_type\`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
  " 2>/dev/null

  # Enable bots in rules
  $DB -e "
    INSERT INTO rule_values (rule_name, rule_value, notes)
      VALUES ('Bots:Enabled', 'true', '')
      ON DUPLICATE KEY UPDATE rule_value='true';
  " 2>/dev/null

  # Enable expansion 19 (Rain of Fear) — DB has full zone/spawn data through exp 19.
  # World:ExpansionSettings bitmask 1048575 = 2^20-1, enables bits 0-19 (all expansions).
  $DB -e "
    INSERT INTO rule_values (rule_name, rule_value, notes)
      VALUES ('Expansion:CurrentExpansion', '19', 'Rain of Fear — max expansion with DB content')
      ON DUPLICATE KEY UPDATE rule_value='19';
    INSERT INTO rule_values (rule_name, rule_value, notes)
      VALUES ('World:ExpansionSettings', '1048575', 'All expansions 0-19 enabled')
      ON DUPLICATE KEY UPDATE rule_value='1048575';
    INSERT INTO rule_values (rule_name, rule_value, notes)
      VALUES ('World:CharacterSelectExpansionSettings', '1048575', 'All expansions 0-19 enabled')
      ON DUPLICATE KEY UPDATE rule_value='1048575';
  " 2>/dev/null

  # Restore GM status for known GM accounts if they exist
  $DB -e "
    UPDATE account SET status=255 WHERE name IN ('bifar','eboola') AND status < 255;
  " 2>/dev/null

  echo "[bootstrap] Done."
) >> logs/bootstrap.log 2>&1 &

echo "[startup] EQEmu server started"