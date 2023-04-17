# Backups

This script has the intention to backup files and databases from servers

Is triggered by a cronjob, and the period to retain the backups are configurable with a minimum time setted by the cronjob configuration.

## Usage

- -h Displays help
- -c Configures the crontab
- -t Tests the configuration runing the backup function
- -r Remove old backup files

## Exampl

```bash
./backup.sh -c -t -r
```

## Notes

. Don't forget to create the .env file using the envsample structure

. If you don't know how to configure a crontab timer, use [https://crontab.guru/](https://crontab.guru/)
