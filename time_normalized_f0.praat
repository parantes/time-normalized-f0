# Name     : time_normalized_F0.praat
# Version  : 1.0
# Author   : Pablo Arantes <pabloarantes@gmail.com>
# Created  : 2010-04-18
# Modified : 2018-04-11
#
# Purpose:
# --------
# The script will generate a normalized F0 contour from a raw F0 curve.
# Time normalization is achieved by taking a user-defined number of 
# evenly spaced F0 values for each interval defined in a TextGrid.
# Usually an interval will span a segment, a syllable or even whole words
# depending on the problem at hand.
#
# Input:
# ------
# One or more Pitch files and corresponding TextGrids with at least
# one interval tier containing non-empty intervals.
#
# Output:
# -------
# Tab-separated text file report containing time normalized F0 values and
# metadata for each F0 value: file name, interval number with 
# reference to non-empty intervals, sample number, normalization time
# step for each interval and timestamp of sampled points.
#
#
# Copyright (C) 2010-2018 Pablo Arantes
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# A copy of the GNU General Public License is available at
# <http://www.gnu.org/licenses/>.


## TODO:
# - Documentation (script comments and wiki)
# - Error messages
# 	* No non-empty intervals in user-selected analysis tier
#         (check number of rows in intervals table)
# - Add choice of column separator in GUI menu (like in duration.praat)


form Time normalized F0 contours
	comment * and ? can be used to specify a pattern that all file names must have in order to be selected
	comment Leave * and all TextGrids in Pitch folder will be selected
	sentence Pattern *
	sentence Pitch_folder D:\teste\
	sentence Grid_folder D:\teste\
	sentence Report_folder D:\teste\
	sentence Report tnf0.txt
	natural Tier 2
	comment Apply smoothing to Pitch files:
	boolean Smooth 1
	comment Choose bandwidth frequency (in Hertz)
	real Bandwidth 4.0
	comment Choose method for interpolating unvoiced parts
	optionmenu Interpolation: 1
		button Quadratic
		button Linear
		button None
	comment If you select no interpolation, choose a string to represent --undefined-- Pitch values
	sentence Unvoiced NA
	comment Interval Range
	positive left_Range 1
	positive right_Range 5
	comment Samples per interval
	comment (you can specify a number for each interval; use commas to separate values;
	comment if just one is provided it will be used for all intervals)
	sentence Samples 10, 5, 10, 10, 10
endform

# Number of samples per interval is stored in Table 'samples'
# Variable samples holds the Table object ID
call str_to_table "," samples 'samples$'
nsamples = Object_'samples'.nrow

# Check preconditions
# End interval value has to be greater than start interval
if right_Range < left_Range
	exit End interval in "Range" has to be greater than the start one.
endif

# Interval range has to have the same length of samples array if that array has more than one element
range = (right_Range - left_Range) + 1
if (nsamples <> 1) and (nsamples <> range)
	exit Number of intervals specified in "Samples" field does not match those provided in "Range".
endif

report$ = report_folder$ + report$
filedelete 'report$'
header$ = "file'tab$'position'tab$'label'tab$'sample'tab$'f0'tab$'step'tab$'time'newline$'"
header$ > 'report$'

list = Create Strings as file list... list 'grid_folder$''pattern$'.TextGrid
files = Get number of strings
if files < 1
	exit There are no TextGrid files at 'grid_folder$'
endif

for file to files
	select list
	grid$ = Get string... file
	pitch$ = grid$ - ".TextGrid" + ".Pitch"
	file$ = grid$ - ".TextGrid"
	grid = Read from file... 'grid_folder$''grid$'
	if fileReadable("'pitch_folder$''pitch$'")
		pitch = Read from file... 'pitch_folder$''pitch$'
	else
		exit Could not find 'pitch$' at 'pitch_folder$'.
	endif

	if smooth = 1
		raw = pitch
		select raw
		smoothed = Smooth... bandwidth
		pitch = smoothed
		select raw
		Remove
	endif

	if interpolation < 3
		temp_pitch = pitch
		select temp_pitch
		# Min and max F0 are necessary in order to synthesize a Pitch from a PitchTier
		min_f0 = Get minimum... 0 0 Hertz Parabolic
		max_f0 = Get maximum... 0 0 Hertz Parabolic
		# Just to be safe min and max F0 values are rounded down and up to the nearest 10 Hz
		min_f0 = floor(min_f0/10)*10
		max_f0 = ceiling(max_f0/10)*10
		# Quadratic interpolation of unvoiced intervals is only available in PitchTier
		# Linear interpolation is done for free just by converting a PitchTier back to Pitch.
		# PitchTier to Pitch conversion is also useful because of constant extrapolation, i.e.,
		# extrapolation of values before and after the first and last points in the original Pitch.
		pitch_tier = Down to PitchTier
		if interpolation = 1
			Interpolate quadratically... 4 Semitones
		endif
		pitch = To Pitch... 0.01 min_f0 max_f0
		select temp_pitch
		plus pitch_tier
		Remove
	endif

	select grid
	test = Is interval tier... tier
	if test = 0
		exit Tier 'tier' in TextGrid 'file$' is not an interval tier.
	endif
	sel = Extract one tier... tier
	tab = Down to Table... no 6 no no
	# Check if user-defined start and end intervals are within the available
	# intervals in the working TextGrid tier
	intervals = Object_'tab'.nrow
	if (left_Range > intervals) or (right_Range > intervals)
		exit Start or end interval is out of range in tier 'tier'.
	endif
	i = left_Range
	n = right_Range
	# 'sample' goes from 1 to the total number of f0 values taken in each file:
	# number of non-empty intervals in range * samples per interval
	sample = 1
	isam = 1
	for i to n
		label$ = object$[tab, i, 2]
		# Interval start time
		start = object[tab, i, 1]
		# Interval end time
		end = object[tab, i, 3]
		if nsamples = 1
			samp = object[samples, 1, 1]
		else
			samp = object[samples, i, 1]
		endif
		isam += 1
		step = (end - start) / samp
		# Take the sample from the midpoint of each window 
		time = start + (step / 2)
		for j to samp
			select pitch
			value = Get value at time... time Hertz Linear
			if value = undefined
				value$ = unvoiced$
			else
				value$ = "'value:2'"
			endif
			line$ = "'file$''tab$''i''tab$''label$''tab$''sample''tab$''value$''tab$''step:3''tab$''time:3''newline$'"
			line$ >> 'report$'
			time += step
			sample += 1
		endfor
	endfor
	select grid
	plus sel
	plus tab
	plus pitch
	Remove
endfor
select list
plus samples
Remove

procedure str_to_table .sep$ .table$ .str$
# String to Table conversion
# Return a Table object whose elements are values in a string variable
#
# Parameters
# .sep$ [string]: character used to separate values (do not use only space)
# .table$ [string]: name of variable used to store numeric ID of String object
# .str$ [string]: string object holding the values. When calling the procedure
#                 this parameter has to be enclosed in single quotes
#
# Example of usage
# keys$ = "5, 10, 4, 78"
# call str_to_table "," tab 'keys$'
# select tab
# Edit

	# Eliminate spaces in string input
	.str$ = replace_regex$(.str$, "\s+", "", 0)
	.str$ = replace_regex$(.str$, .sep$, newline$, 0)
	.str$ = "values" + newline$ + .str$
	.str$ > str_to_table_temp.txt
	'.table$' = Read Table from tab-separated file... str_to_table_temp.txt
	filedelete str_to_list_temp.txt
endproc

