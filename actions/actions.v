module actions

import os

// valid_action_path rejects the filesystem root and synthetic treemap entries.
pub fn valid_action_path(path string) bool {
	return os.is_abs_path(path) && os.norm_path(path) != '/'
}
