module main

import atlas
import os

fn main() {
	start := if os.args.len > 1 { os.abs_path(os.args[1]) } else { os.home_dir() }
	atlas.run(start)
}
