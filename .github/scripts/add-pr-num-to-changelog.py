#!/usr/bin/env python3

import sys

if len(sys.argv) < 3:
    # argv[1] - Should be PR number.
    # argv[2] - Should be the file being read/modified.
    print(f'Invalid arguments length passed to: { __file__ }')
    sys.exit(1)

with open(sys.argv[2], 'r+') as file:
    file_contents = file.readlines()
    # Reverse list of contents as chaneglog comments should be last non-empty line.
    file_contents = file_contents[::-1]

    for i, line in enumerate(file_contents):
        if line != '\n':  # This should be the first non-empty line.
            if '[PR:' not in line:
                edited_line = file_contents[i].strip()
                edited_line += f' [PR:{ sys.argv[1]}]\n'
                file_contents[i] = edited_line

                file_contents = file_contents[i::]  # Trim the list.
                file_contents = file_contents[::-1]  # Un-reverse the list.

                file.seek(0)
                file.writelines(file_contents)
                file.truncate()
                break
            else:
                break  # Line already contains '[PR:' string.
