#!/bin/php
<?php

	// Check if the file has been passed as an argument
	if ($argc !== 2) {
		die("Usage: php {$argv[0]} <file_path>\n");
	}

	$filename = $argv[1];

	// Check if the file exists and is readable
	if (!file_exists($filename) || !is_readable($filename)) {
		die("The file does not exist or cannot be read: $filename\n");
	}

	// Load the content of the file
	$content = file_get_contents($filename);
	if ($content === false) {
		die("Failed to read the file: $filename\n");
	}

	const MIN_CONSECUTIVE = 5; // Minimum number of consecutive 0xff bytes to consider it a block
	$length = strlen($content);
	$currentOffset = null;
	$currentLength = 0;

	for ($i = 0; $i < $length; $i++) {
		if (ord($content[$i]) === 0xff) {
			// Start counting the block if it hasn't started yet
			if ($currentOffset === null) {
				$currentOffset = $i;
			}
			$currentLength++;
		} else {
			// If we find a byte that is not 0xff and we were counting a sequence
			if ($currentLength >= MIN_CONSECUTIVE) {
				printf("Block found - Offset: 0x%04X, Size: %d bytes\n", $currentOffset, $currentLength);
			}
			// Reset variables for the next sequence
			$currentOffset = null;
			$currentLength = 0;
		}
	}

	// If we reach the end of the file and there is a pending block
	if ($currentLength >= MIN_CONSECUTIVE) {
		printf("Block found - Offset: 0x%04X, Size: %d bytes\n", $currentOffset, $currentLength);
	}

?>
