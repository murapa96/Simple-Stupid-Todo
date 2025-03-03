#!/bin/bash

# Constants
TODO_FILE="$HOME/todo.json"
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

todo() {
	# Create todo file if it doesn't exist
	if [[ ! -f "$TODO_FILE" ]]; then
		echo '[]' > "$TODO_FILE"
	fi

	# Check if jq is installed
	if ! command -v jq &> /dev/null; then
		echo -e "${RED}Error: jq is not installed. Please install it to use this script.${RESET}"
		echo "On Debian/Ubuntu: sudo apt install jq"
		echo "On CentOS/RHEL: sudo yum install jq"
		echo "On macOS: brew install jq"
		return 1
	fi

	# Display help information
	showHelp() {
		echo -e "${BLUE}Usage:${RESET}"
		echo -e "  todo list              ${GREEN}List all todo items${RESET}"
		echo -e "  todo add               ${GREEN}Add a new todo item${RESET}"
		echo -e "  todo remove <id>       ${GREEN}Remove a todo item by ID${RESET}"
		echo -e "  todo remove -a         ${GREEN}Remove all todo items${RESET}"
		echo -e "  todo clear             ${GREEN}Clear all expired todo items${RESET}"
		echo -e "  todo search <keyword>  ${GREEN}Search todo items by keyword${RESET}"
		echo -e "  todo help              ${GREEN}Show this help message${RESET}"
	}

	# Add a new todo item
	addTodo() {
		# Ensure the JSON file exists and is a valid array
		if [[ ! -f "$TODO_FILE" || $(jq 'length' "$TODO_FILE" 2>/dev/null || echo "error") == "error" ]]; then
			echo '[]' > "$TODO_FILE"
		fi

		local timestamp=$(date +"%d/%m/%Y")
		local message=""
		local category=""
		local priority="medium"
		
		# Get the highest ID and increment by 1 for the new ID
		local highest_id=$(jq -r 'map(.id | tonumber) | max // -1' "$TODO_FILE")
		local id=$((highest_id + 1))

		# Request the todo message
		echo -e "${GREEN}Enter the todo message:${RESET}"
		read message

		if [[ -z "$message" ]]; then
			echo -e "${RED}Error: Message cannot be empty${RESET}"
			return 1
		fi

		# Request the category
		echo -e "${GREEN}Enter category (optional):${RESET}"
		read category

		# Request priority
		echo -e "${GREEN}Enter priority (low, medium, high) [medium]:${RESET}"
		read input_priority
		
		if [[ -n "$input_priority" ]]; then
			case "$input_priority" in
				low|medium|high) priority="$input_priority" ;;
				*) echo -e "${YELLOW}Invalid priority. Using default 'medium'${RESET}"; priority="medium" ;;
			esac
		fi

		# Request deadline
		echo -e "${GREEN}Enter deadline in days:${RESET}"
		read num_days

		if [[ "$num_days" =~ ^[0-9]+$ ]]; then
			local deadline=$(date -d "+$num_days days" +"%d/%m/%Y")
		else
			echo -e "${RED}Invalid day format. Please enter a valid number.${RESET}"
			return 1
		fi

		# Add the new todo to the JSON file
		jq --arg id "$id" \
		   --arg timestamp "$timestamp" \
		   --arg message "$message" \
		   --arg deadline "$deadline" \
		   --arg category "$category" \
		   --arg priority "$priority" \
		   '. += [{"id": ($id|tonumber), "date": $timestamp, "message": $message, "deadline": $deadline, "category": $category, "priority": $priority}]' \
		   "$TODO_FILE" > "${TODO_FILE}.tmp" && mv "${TODO_FILE}.tmp" "$TODO_FILE"

		echo -e "${GREEN}Task added: $message with deadline $deadline (ID: $id)${RESET}"
	}

	# Remove a todo item
	removeTodo() {
		if [[ ! -s "$TODO_FILE" ]]; then
			echo -e "${YELLOW}No todo items to remove.${RESET}"
			return 0
		fi

		local remove_all=false

		# Process options
		while [[ $# -gt 0 ]]; do
			case "$1" in
			"-a")
				remove_all=true
				shift
				;;
			*)
				break
				;;
			esac
		done

		if [[ "$remove_all" == true ]]; then
			# Confirm before deleting all
			echo -e "${YELLOW}Are you sure you want to remove ALL todo items? (y/N)${RESET}"
			read confirm
			if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
				echo '[]' > "$TODO_FILE"
				echo -e "${GREEN}All todo items have been removed.${RESET}"
			else
				echo -e "${BLUE}Operation cancelled.${RESET}"
			fi
			return 0
		fi

		if [[ -z $1 ]]; then
			echo -e "${RED}Error: No ID specified.${RESET}"
			echo -e "${YELLOW}Usage: todo remove <ID>${RESET}"
			return 1
		fi

		if ! [[ $1 =~ ^[0-9]+$ ]]; then
			echo -e "${RED}Error: ID must be a number.${RESET}"
			return 1
		fi

		local id=$1
		local item_exists=$(jq --arg id "$id" 'map(select(.id == ($id|tonumber))) | length' "$TODO_FILE")
		
		if [ "$item_exists" -eq 0 ]; then
			echo -e "${RED}Error: No todo item found with ID $id${RESET}"
			return 1
		fi

		# Get the task message for confirmation
		local message=$(jq -r --arg id "$id" '.[] | select(.id == ($id|tonumber)) | .message' "$TODO_FILE")
		
		# Remove the item
		jq --arg id "$id" 'map(select(.id != ($id|tonumber)))' "$TODO_FILE" > "${TODO_FILE}.tmp" && mv "${TODO_FILE}.tmp" "$TODO_FILE"
		echo -e "${GREEN}Task removed: $message (ID: $id)${RESET}"
	}

	# List all todo items
	listTodo() {
		if [[ ! -s "$TODO_FILE" || $(jq 'length' "$TODO_FILE") -eq 0 ]]; then
			echo -e "${YELLOW}No pending tasks.${RESET}"
			return 0
		fi

		# Headers of the table
		echo -e "${BLUE}ID   Priority Category                 Task                                         Created        Deadline${RESET}"
		echo -e "${BLUE}---- -------- ----------------------- -------------------------------------------- -------------- --------------${RESET}"
		
		# Display tasks
		jq -r -c '.[]' "$TODO_FILE" | while read -r task; do
			id=$(echo "$task" | jq -r '.id')
			message=$(echo "$task" | jq -r '.message')
			date=$(echo "$task" | jq -r '.date')
			deadline=$(echo "$task" | jq -r '.deadline')
			category=$(echo "$task" | jq -r '.category // ""')
			priority=$(echo "$task" | jq -r '.priority // "medium"')

			# Format the deadline from "DD/MM/YYYY" to "YYYY-MM-DD"
			formatted_deadline=$(date -d "$(echo "$deadline" | sed 's/\([0-9]\{2\}\)\/\([0-9]\{2\}\)\/\([0-9]\{4\}\)/\3-\2-\1/')" +%F 2>/dev/null)

			# Color based on priority and deadline
			if [ $? -eq 0 ]; then
				color="${GREEN}" # Default color
				
				if [ $(date -d "$formatted_deadline" +%s) -lt $(date +%s) ]; then
					color="${RED}" # Expired tasks
				else
					case "$priority" in
						"high") color="${RED}" ;;
						"medium") color="${YELLOW}" ;;
						"low") color="${GREEN}" ;;
					esac
				fi
				
				printf "${color}%-4s %-8s %-23s %-44s %-14s %s${RESET}\n" \
					"$id" "$priority" "${category:0:22}" "${message:0:43}" "$date" "$deadline"
			else
				echo -e "${RED}Invalid date format: $deadline${RESET}"
			fi
		done
	}

	# Clear expired tasks
	clearTodo() {
		if [[ ! -s "$TODO_FILE" || $(jq 'length' "$TODO_FILE") -eq 0 ]]; then
			echo -e "${YELLOW}No tasks to clear.${RESET}"
			return 0
		fi

		local count=0
		local today_timestamp=$(date +%s)
		local temp_file="${TODO_FILE}.tmp"
		
		# Create a new array without the expired tasks
		jq --arg today "$(date +%s)" '[.[] | 
			((.deadline | split("/") | .[2] + "-" + .[1] + "-" + .[0]) | strptime("%Y-%m-%d") | mktime) as $deadline_ts |
			if $deadline_ts < ($today|tonumber) then empty else . end]' "$TODO_FILE" > "$temp_file"
		
		# Count the number of removed tasks
		local before_count=$(jq 'length' "$TODO_FILE")
		local after_count=$(jq 'length' "$temp_file")
		local removed=$((before_count - after_count))
		
		mv "$temp_file" "$TODO_FILE"
		
		if [ "$removed" -gt 0 ]; then
			echo -e "${GREEN}Removed $removed expired task(s).${RESET}"
		else
			echo -e "${BLUE}No expired tasks to remove.${RESET}"
		fi
	}

	# Search for tasks by keyword
	searchTodo() {
		if [[ -z "$1" ]]; then
			echo -e "${RED}Error: No search keyword provided.${RESET}"
			echo -e "${YELLOW}Usage: todo search <keyword>${RESET}"
			return 1
		fi

		if [[ ! -s "$TODO_FILE" || $(jq 'length' "$TODO_FILE") -eq 0 ]]; then
			echo -e "${YELLOW}No tasks to search.${RESET}"
			return 0
		fi

		local keyword="$1"
		local results=$(jq -r --arg keyword "$keyword" '[.[] | select(.message | test($keyword; "i") or .category | test($keyword; "i"))]' "$TODO_FILE")
		local count=$(echo "$results" | jq 'length')

		if [ "$count" -eq 0 ]; then
			echo -e "${YELLOW}No tasks found matching: $keyword${RESET}"
			return 0
		fi

		echo -e "${BLUE}Found $count task(s) matching: $keyword${RESET}"
		echo -e "${BLUE}ID   Priority Category                 Task                                         Created        Deadline${RESET}"
		echo -e "${BLUE}---- -------- ----------------------- -------------------------------------------- -------------- --------------${RESET}"
		
		echo "$results" | jq -r -c '.[]' | while read -r task; do
			id=$(echo "$task" | jq -r '.id')
			message=$(echo "$task" | jq -r '.message')
			date=$(echo "$task" | jq -r '.date')
			deadline=$(echo "$task" | jq -r '.deadline')
			category=$(echo "$task" | jq -r '.category // ""')
			priority=$(echo "$task" | jq -r '.priority // "medium"')

			# Format deadline
			formatted_deadline=$(date -d "$(echo "$deadline" | sed 's/\([0-9]\{2\}\)\/\([0-9]\{2\}\)\/\([0-9]\{4\}\)/\3-\2-\1/')" +%F 2>/dev/null)

			# Set color based on priority and expiration
			if [ $? -eq 0 ]; then
				color="${GREEN}" # Default color
				
				if [ $(date -d "$formatted_deadline" +%s) -lt $(date +%s) ]; then
					color="${RED}" # Expired tasks
				else
					case "$priority" in
						"high") color="${RED}" ;;
						"medium") color="${YELLOW}" ;;
						"low") color="${GREEN}" ;;
					esac
				fi
				
				printf "${color}%-4s %-8s %-23s %-44s %-14s %s${RESET}\n" \
					"$id" "$priority" "${category:0:22}" "${message:0:43}" "$date" "$deadline"
			else
				echo -e "${RED}Invalid date format: $deadline${RESET}"
			fi
		done
	}

	# Main command processing
	case "$1" in
		"add")
			addTodo "${@:2}"
			;;
		"remove")
			removeTodo "${@:2}"
			;;
		"clear")
			clearTodo
			;;
		"search")
			searchTodo "$2"
			;;
		"help")
			showHelp
			;;
		"list" | "")
			listTodo
			;;
		*)
			echo -e "${RED}Unknown command: $1${RESET}"
			showHelp
			;;
	esac
}

# Execute the todo function with all passed arguments
todo "$@"
