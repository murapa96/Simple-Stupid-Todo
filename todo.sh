todo() {
	# Comprobamos si el archivo existe
	if [[ ! -f ~/todo.json ]]; then
		echo '[]' >~/todo.json
	fi

	addTodo() {
		# Comprobamos si el archivo JSON existe y es un array vacío
		if [[ ! -f ~/todo.json || $(jq 'length' ~/todo.json) -eq 0 ]]; then
			echo '[]' >~/todo.json
		fi

		local timestamp=$(date +"%d/%m/%Y")
		local message=""
		local id=$(jq -r 'length' ~/todo.json)

		# Solicitar el recordatorio
		echo -e "\e[32mIngrese el recordatorio:\e[0m"
		read message

		# Solicitar la fecha límite
		echo -e "\e[32mIngrese la fecha límite (en días):\e[0m"
		read num_days

		if [[ "$num_days" =~ ^[0-9]+$ ]]; then
			local deadline=$(date -d "+$num_days days" +"%d/%m/%Y")
		else
			echo -e "\e[31mFormato de número de días no válido. Use un número entero.\e[0m"
			exit 1
		fi

		if [[ -z "$message" ]]; then
			echo -e "\e[31mUso: todo add\e[0m"
		else
			jq --arg timestamp "$timestamp" --arg message "$message" --arg deadline "$deadline" --arg id "$id" '. += [{"id": $id, "date": $timestamp, "message": $message, "deadline": $deadline}]' ~/todo.json >~/todo_tmp.json && mv -i ~/todo_tmp.json ~/todo.json
			echo -e "\e[32mTarea agregada: $message con fecha de vencimiento el $deadline\e[0m"
		fi
	}

	removeTodo() {
		if [[ -z $1 ]]; then
			echo -e "\e[31mUso: todo remove <índice>\e[0m"
		else
			local remove_all=false

			# Opciones permitidas para el comando removeTodo
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
				# Borrar todos los elementos existentes en el archivo JSON
				echo '[]' >~/todo.json
				echo -e "\e[32mTodos los elementos anteriores han sido eliminados.\e[0m"
				return
			fi

			jq --arg id "$1" 'del(.[$id])' ~/todo.json >~/todo_tmp.json && mv ~/todo_tmp.json ~/todo.json
			echo -e "\e[32mTarea eliminada: $1\e[0m"
		fi
	}

	listTodo() {
		# Mostrar tareas pendientes, si no hay ninguna, mostrar un mensaje
		if [[ ! -s ~/todo.json ]]; then
			echo "\e[32mNo hay tareas pendientes.\e[0m"
		else
			# Headers de la tabla
			echo "\e[32mID   Tarea                                        Fecha de creación  Fecha límite\e[0m"
			echo "\e[32m---- -------------------------------------------- ------------------ ------------\e[0m"
			# Mostrar tareas pendientes
			# Si se ha pasado el deadline, mostrar en rojo
			# Si no, mostrar en verde
			jq -r -c '.[]' ~/todo.json | while read -r task; do
				id=$(echo "$task" | jq -r '.id')
				message=$(echo "$task" | jq -r '.message')
				date=$(echo "$task" | jq -r '.date')
				deadline=$(echo "$task" | jq -r '.deadline')

				# Formatear la fecha límite desde "DD/MM/YYYY" a "YYYY-MM-DD"
				formatted_deadline=$(date -d "$(echo "$deadline" | sed 's/\([0-9]\{2\}\)\/\([0-9]\{2\}\)\/\([0-9]\{4\}\)/\3-\2-\1/')" +%F 2>/dev/null)

				if [ $? -eq 0 ]; then
					if [ $(date -d "$formatted_deadline" +%s) -lt $(date +%s) ]; then
						printf "\e[31m%-4s %-45s %-18s %s\e[0m\n" "$id" "$message" "$date" "$deadline"
					else
						printf "\e[32m%-4s %-45s %-18s %s\e[0m\n" "$id" "$message" "$date" "$deadline"
					fi
				else
					echo "Fecha inválida: $deadline"
				fi
			done

		fi
	}

	clearTodo(){
		# Comprobamos si el archivo JSON existe y es un array vacío
		if [[ ! -f ~/todo.json || $(jq 'length' ~/todo.json) -eq 0 ]]; then
			echo '[]' >~/todo.json
		fi

		#Borramos las tareas que ya han pasado su fecha límite
		jq -r -c '.[]' ~/todo.json | while read -r task; do
			id=$(echo "$task" | jq -r '.id')
			message=$(echo "$task" | jq -r '.message')
			date=$(echo "$task" | jq -r '.date')
			deadline=$(echo "$task" | jq -r '.deadline')

			# Formatear la fecha límite desde "DD/MM/YYYY" a "YYYY-MM-DD"
			formatted_deadline=$(date -d "$(echo "$deadline" | sed 's/\([0-9]\{2\}\)\/\([0-9]\{2\}\)\/\([0-9]\{4\}\)/\3-\2-\1/')" +%F 2>/dev/null)

			if [ $? -eq 0 ]; then
				if [ $(date -d "$formatted_deadline" +%s) -lt $(date +%s) ]; then
					jq --arg id "$id" 'del(.[$id])' ~/todo.json >~/todo_tmp.json && mv ~/todo_tmp.json ~/todo.json
					echo -e "\e[32mTarea eliminada: $message\e[0m"
				fi
			else
				echo "Fecha inválida: $deadline"
			fi
		done
	}

	case "$1" in
	"add")
		addTodo "${@:2}"
		;;
	"remove")
		removeTodo "$2"
		;;
	"clar")
		clearTodo
		;;
	"list" | *)
		listTodo
		;;
	esac
}

todo "$@"
