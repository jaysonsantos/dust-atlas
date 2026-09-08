module main

$if !macos {
	fn file_menu(path string) int {
		return -1
	}

	fn remove_entry(path string, permanent bool) ! {
		return error('Trash and deletion are available on macOS only.')
	}
}
