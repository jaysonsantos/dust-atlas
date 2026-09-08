module main

#flag darwin @VMODROOT/native/actions.m
#include "@VMODROOT/native/actions.h"

fn C.atlas_context_menu(&char) int
fn C.atlas_remove(&char, int, &char, int) int

fn file_menu(path string) int {
	return C.atlas_context_menu(path.str)
}

fn remove_entry(path string, permanent bool) ! {
	if !valid_action_path(path) { return error('Cannot remove this path') }
	mut message := [1024]char{}
	if C.atlas_remove(path.str, int(permanent), &message[0], message.len) == 0 {
		return error(unsafe { cstring_to_vstring(&message[0]) })
	}
}
