module actions

import os

fn test_file_action_paths_reject_root_and_synthetic_entries() {
	assert !valid_action_path('/')
	assert !valid_action_path('/tmp/..')
	assert !valid_action_path('[Other entries / directory data]')
	assert valid_action_path(os.join_path(os.temp_dir(), 'an item'))
}

fn test_native_file_actions_preserve_symlink_target_and_report_errors() {
	$if macos {
		base := os.join_path(os.temp_dir(), 'atlas-actions-${os.getpid()}')
		os.mkdir_all(base) or { panic(err) }
		defer { os.rmdir_all(base) or {} }
		target := os.join_path(base, "keep ü & quote'.txt")
		link := os.join_path(base, 'remove link')
		os.write_file(target, 'preserve this target') or { panic(err) }
		os.symlink(target, link) or { panic(err) }
		remove_entry(link, true) or { panic(err) }
		assert !os.is_link(link)
		assert os.read_file(target) or { '' } == 'preserve this target'
		remove_entry(os.join_path(base, 'missing'), true) or {
			assert err.msg().len > 0
			return
		}
		assert false, 'A missing item must report an error'
	}
}

fn test_unsupported_file_actions_preserve_files() {
	$if !macos {
		path := os.join_path(os.temp_dir(), 'atlas-preserve-${os.getpid()}.txt')
		os.write_file(path, 'keep') or { panic(err) }
		defer { os.rm(path) or {} }
		assert file_menu(path) == -1
		remove_entry(path, true) or {
			assert os.read_file(path) or { '' } == 'keep'
			return
		}
		assert false, 'Unsupported actions must report an error'
	}
}
