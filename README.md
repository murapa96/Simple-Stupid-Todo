# Stupid Simple Todo

## Description

A simple, command-line todo application written in Bash. It stores todo items in a JSON file and provides basic task management functionality. Despite being "stupid simple", it's quite powerful for everyday task tracking.

## Features

- Add tasks with deadlines, priorities, and categories
- List all tasks with color-coding based on priority and status
- Remove tasks by ID or clear all tasks
- Auto-clean expired tasks
- Search tasks by keyword
- Color-coded output for better visibility

## Requirements

- Bash shell
- [jq](https://stedolan.github.io/jq/) - A lightweight command-line JSON processor

## Usage

```bash
$ ./todo.sh [command] [options]
```

### Available Commands:

#### List Tasks
```bash
$ ./todo.sh list
# or simply
$ ./todo.sh
```
Lists all the todo items with color-coding based on priority and status.

#### Add Task
```bash
$ ./todo.sh add
```
Starts an interactive wizard to add a new todo item with:
- Message (required)
- Category (optional)
- Priority (low, medium, high)
- Deadline (in number of days)

#### Remove Task
```bash
$ ./todo.sh remove <id>
```
Removes a specific todo item by its ID.

```bash
$ ./todo.sh remove -a
```
Removes all todo items (with confirmation).

#### Clear Expired Tasks
```bash
$ ./todo.sh clear
```
Removes all todo items that are past their deadline.

#### Search Tasks
```bash
$ ./todo.sh search <keyword>
```
Searches todo items by keyword in message or category.

#### Help
```bash
$ ./todo.sh help
```
Displays help information.

## Installation

```bash
$ git clone https://github.com/yourusername/stupid-todo.git
$ cd stupid-todo
$ chmod +x todo.sh
$ ./todo.sh
```

For easier access, you may want to:

1. Create a symbolic link in a directory in your PATH:
   ```bash
   $ ln -s "$(pwd)/todo.sh" ~/bin/todo
   ```
   (Make sure ~/bin is in your PATH)

2. Or add an alias in your .bashrc or .zshrc:
   ```bash
   alias todo='path/to/stupid-todo/todo.sh'
   ```

## License

Apache License 2.0

Copyright 2023 Pablo Ramos Muras

Licensed under the Apache License, Version 2.0. See the LICENSE file for details.
