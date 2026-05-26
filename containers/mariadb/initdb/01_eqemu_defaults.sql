-- Pre-seed db_version so world skips the crash-prone bot update dump cycle.
-- Only runs on a completely fresh (empty) database — MariaDB ignores this on restarts.
-- World's UpdateManifest will still apply all non-bot migrations normally.

CREATE TABLE IF NOT EXISTS `db_version` (
  `version`        int(11) NOT NULL DEFAULT '0',
  `bots_version`   int(11) NOT NULL DEFAULT '0',
  `custom_version` int(11) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT IGNORE INTO `db_version` (`version`, `bots_version`, `custom_version`)
  VALUES (0, 9054, 0);
