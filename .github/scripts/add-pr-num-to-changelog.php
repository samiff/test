#!/usr/bin/env php
<?php
/**
 * Adds a PR number to a changelog file.
 * Used by the 'Add PR number to changelogs' GH Actions workflow.
 *
 * The following arguments are expected to be passed to this script:
 * argv[1] - A PR number.
 * argv[2] - A file path being read/modified.
 *
 * @package automattic/jetpack
 */

// phpcs:disable WordPress.PHP.DevelopmentFunctions.error_log_print_r, WordPress.WP.AlternativeFunctions.file_system_read_fclose, WordPress.Security.EscapeOutput.OutputNotEscaped, WordPress.WP.AlternativeFunctions.file_system_read_file_put_contents

if ( count( $argv ) < 3 ) {
	echo 'Invalid arguments length passed to: ' . basename( __FILE__ );
	exit( 1 );
}

$pr_num = $argv[1];
$file   = $argv[2];
$exit   = 0;
try {
	$contents = file( $file );
	if ( ! $contents ) {
		throw new Exception( "Failed to read file: $file" );
	}
	$contents = array_reverse( $contents ); // Reversed since changelog comment is the last non-empty line in file.

	foreach ( $contents as $i => $line ) {
		if ( trim( $line ) !== '' ) { // The last non-empty line in the file.
			if ( ! str_contains( $line, '[PR:' ) ) { // Changelog does not contain the PR number yet.
				$edited_line    = trim( $line );
				$edited_line   .= " [PR:$pr_num]\n";
				$contents[ $i ] = $edited_line;

				$contents = array_slice( $contents, $i ); // Trim the array of empty lines.
				$contents = array_reverse( $contents ); // Un-reverse the array.

				file_put_contents( $file, $contents ); // Overwrite the new file contents.
				break;
			} else {
				break; // Line already contained the '[PR:' string.
			}
		}
	}
} catch ( Exception $e ) {
	echo "Error while reading or writing file: $file";
	$exit = 1;
} finally {
	exit( $exit );
}
