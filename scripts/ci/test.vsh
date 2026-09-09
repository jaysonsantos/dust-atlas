#!/usr/bin/env -S v run

// Run project tests without traversing downloaded V modules.
import os
import scripts.ci.sources

os.setenv('VJOBS', '1', true)
quoted := sources.v_tests().map(os.quoted_path(it)).join(' ')
exit(os.system('${os.quoted_path(@VEXE)} test ${quoted}'))
