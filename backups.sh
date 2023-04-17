#!/bin/bash
# Created by: Ignacio Cabrera - 2023-04-17

# This script has the intention to backup files and databases from servers
# Is triggered by a cronjob, and the period to retain the backups are configurable with a minimum
# time setted by the cronjob configuration.

# Define backup_directory
now=$(date +%s)
backup_dir="${DESTINATION_DIRECTORY}${now}/"

# Handle Ctrl+C (interruption)
trap ctrl_c INT
function ctrl_c() {
	echo "** Trapped CTRL-C"
	/usr/bin/rm temp_cron 2>/dev/null
	/usr/bin/rm -rf "${backup_dir}" 2>/dev/null
	exit 1
}

function backup() {
	# Create backup directory
	/usr/bin/mkdir -p $backup_dir 2>/dev/null

	# Backup databases
	backupDB &
	task_pid=$!
	spinner $task_pid

	# Backup files
	backupFiles &
	task_pid=$!
	spinner $task_pid

	# Compress the backup
	/usr/bin/tar -czvf ${now}.tar.gz ${backup_dir} 2>&1 >/dev/null

	# Remove clean the directory
	/usr/bin/rm -rf $backup_dir 2>/dev/null
}

function backupDB() {
	# If environment database variable is setted, backup the database
	if [ ! -z ${DB_NAME+x} ]; then
		echo "Backup database"
		sql_file="${backup_dir}${DB_NAME}.sql"
		/usr/bin/mysqldump -h $SERVER_IP --port $DB_PORT -u$DB_USERNAME -p$DB_PASSWORD --databases $DB_NAME >"$sql_file"
		echo -e "\nSaved database in $sql_file"
	fi
}

function backupFiles() {
	# If environment backup variable is setted, backup files
	if [ ! -z ${DIRECTORIES+x} ]; then
		# Create the destination folder
		/usr/bin/mkdir "${backup_dir}files" 2>/dev/null

		echo "Backup directories"
		# Set the delimiter to comma
		IFS=,
		items_arr=($DIRECTORIES)
		# Loop over directories defined in .env file
		for item in "${items_arr[@]}"; do
			echo "Copying $item"
			last_dir=$(basename $item)
			/usr/bin/scp -q -r -i $SSH_KEY_PATH "$SERVER_USER@$SERVER_IP:$item" "${backup_dir}files/${last_dir}" 2>&1 >/dev/null | grep -v "Warning: Pe/usr/bin/rmanently added" >&2
		done

		# Reset the delimiter
		unset IFS
	fi
}

# Help function
function help() {
	echo "Usage: "
	echo -e "-h\tDisplays help"
	echo -e "-c\tConfigures the crontab"
	echo -e "-t\tTests the configuration runing the backup function"
	echo -e "-r\tRemove old backup files"
}

# Autoconfigure cronjob
function configure_cronjob() {
	echo "The crontab configuration is: $BACKUP_PERIOD"
	script_path="$PWD$0"
	existing_entry=$(/usr/bin/crontab -l | grep -F "$script_path")
	if [ -z "$existing_entry" ]; then
		# Add the cron entry to a temporary file
		(
			/usr/bin/crontab -l
			echo "$BACKUP_PERIOD $script_path"
		) >temp_cron

		# Install the new crontab from the temporary file
		/usr/bin/crontab temp_cron

		# Remove the temporary file
		/usr/bin/rm temp_cron

		echo "Cron entry added successfully."
	else
		echo "Cron entry already exists."
	fi

	echo -e "$BACKUP_PERIOD $script_path\n"
	echo "You can modify it using the command:"
	echo -e "\tsudo /usr/bin/crontab -e -u $USER"
}

# Displays the description
function description() {
	echo -e "\nWelcome to BACKUPPER +\n"
	echo "This script has the intention to backup files and databases from servers"
	echo -e "Is triggered by a cronjob and the period to retain the backups are configurable with a minimum time setted by the cronjob configuration.\n"
	echo "Firstly you have to configure the .env file following the envsample fo/usr/bin/rmat"
	echo -e "Then, you have to run this script and forget about worries\n"
	echo -e "By: Ignacio Cabrera\n\n"
}

# Remove old backups passed the period defined in .env file
function remove_old_backups() {
	for f in $(/usr/bin/ls $backup_dir*.tar.gz); do
		result="${f/"$backup_dir"/}"
		result="${result/.tar.gz/}"
		difference_seconds=$((now - result))
		difference_days=$(echo "scale=2; $difference_seconds / 86400" | /usr/bin/bc)

		if [ "$(echo "$difference_days >= $RETENTION_PERIOD" | /usr/bin/bc)" -eq 1 ]; then
			/usr/bin/rm -rf $f
			echo "Removed $f"
		fi
	done
}

# Spinner animation
function spinner() {
	spinnerStr="/-\|"
	# Save the PROMPT_COMMAND variable and unset it
	oldPromptCmd="$PROMPT_COMMAND"
	unset PROMPT_COMMAND
	# Loop until the task completes
	while /usr/bin/ps -p $1 >/dev/null; do
		for i in $(seq 0 3); do
			# Get the next character in the spinner sequence
			echo -ne "\r[${spinnerStr:i:1}] Processing..."
			# Wait for a short time
			/usr/bin/sleep 0.2
		done
	done
	# Restore the PROMPT_COMMAND variable
	export PROMPT_COMMAND="$oldPromptCmd"
	# Print the "Done!" message without the percentage symbol
	echo -ne "\r[+] Done!          \n"
}

# Main function
function main() {

	# Clear the screen
	/usr/bin/clear

	# Display the description
	description

	# If no arguments, display help
	if [ "$#" -eq 0 ]; then
		help
		exit 1
	fi

	# Load environment variables
	source .env

	# Loop over the arguments
	while getopts ":hctr" opt; do
		case $opt in
		h)
			help
			;;
		c)
			configure_cronjob
			;;
		t)
			backup
			;;
		r)
			remove_old_backups
			;;
		\?)
			echo "Invalid option -$OPTARG" >&2
			help
			exit 1
			;;
		esac
	done
}

main "$@"
