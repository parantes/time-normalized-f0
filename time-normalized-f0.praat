# Name    : time-normalized-f0.praat
# Author  : Pablo Arantes <pabloarantes@protonmail.com>
# Version : 2.0
#
# See CHANGELOG.md for a complete version history.
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
# GUI parameters:
# ---------------
# - Pattern: Wildcard characters '*' and '?' can be used to specify a
#   pattern that all file names must have in order to be selected.
#	Use '*' and all files in the folder will be selected.
# - Pitch folder and Grid folder: path of folders where Pitch and
#   TextGrid files are stored. They can be the same or different folders.
# - Report folder: Path of the folder and name of the file (with extension)
#   of the report outputted by the script.
# - Tier: number of the TextGrid tier to be analyzed.
# - Smoothing: choose whether or not smoothing should be applied to F0 contours.
# - Bandwidth: how much smoothing should be applied (the greater the number,
#   the smoother the contour).
# - Interpolation: Which kind of interpolation apply in voiceless intervals.
#   Options are quadratic, linear or no interpolation.
# - Unvoiced: the user can select what string will be used when the script
#   samples an unvoiced part of the F0 contour. The default value is `NA`,
#   which is the string used by R to represent missing values.
# - Interval range: indices of the first and last intervals in the specified
#   tier to be sampled. The value on the right field has to be equal or greater
#   than the value on the left field.
# - Samples: number of samples taken in each surveyed interval. Each interval
#   can have a different number. If just one value is provided, that number
#   will be used for all intervals.



# Copyright (C) 2010-2021 Pablo Arantes
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# A copy of the GNU General Public License is available at
# <http://www.gnu.org/licenses/>.

form Time-normalized F0 contours
	comment See source code comments for more information on the fields below.
	sentence Pattern *
	sentence Pitch_folder /path/to/folder/
	sentence Grid_folder /path/to/folder/
	sentence Report /path/to/folder/my_report.txt
	natural Tier 1
	boolean Smooth 1
	real Bandwidth 4.0
	optionmenu Interpolation: 1
		button Quadratic
		button Linear
		button None
	sentence Unvoiced NA
	optionmenu Transformation: 1
		button None
		button Semitones re 1 Hz
		button Semitones re 100 Hz
		button Semitones re 200 Hz
		button Semitones re minimum f0
		button OctaveMedian
		button Z-score
	positive left_Range 1
	positive right_Range 5
	sentence Samples 5 5 5 5 5
endform

# -------------------
# Check preconditions
# -------------------

# Praat version
if praatVersion < 6138
	exitScript: "The script needs at least version 6.1.38 of Praat.", newline$, "Your version is ", praatVersion$, ". Upgrade and run the script again."
endif

# End interval value has to be greater than start interval
if right_Range < left_Range
	exit End interval in "Range" has to be greater than the start one.
endif

# Interval range has to have the same length of samples array if that array has more than one element
samples$# = splitByWhitespace$#(samples$)
nsamples = size(samples$#)
range = (right_Range - left_Range) + 1
if (nsamples <> 1) and (nsamples <> range)
	exitScript: "Number of intervals specified in 'Samples' field does not match those provided in 'Range'."
endif

# Ensure Pitch and Grid folders end with a separator character
if not(endsWith(pitch_folder$, "/") or endsWith(pitch_folder$, "\"))
	pitch_folder$ = pitch_folder$ + "/"
endif

if not(endsWith(grid_folder$, "/") or endsWith(grid_folder$, "\"))
	grid_folder$ = grid_folder$ + "/"
endif

# Ensure there is at lest one file matching the criteria in the TextGrid folder
files$# = fileNames$#(grid_folder$ + pattern$ + ".TextGrid")
nfiles = size(files$#)
if nfiles < 1
	exitScript: "There are no TextGrid files at ", grid_folder$, "."
endif

# ----------------------
# Initialize report file
# ----------------------

deleteFile: report$
writeFileLine: report$, "file", tab$, "position", tab$, "label", tab$, "sample", tab$, "f0" , tab$, "step", tab$, "time"

# ----------------------
# Initialize Info window
# ----------------------

if transformation = 5
	writeInfoLine: "file", tab$, "min_f0"
elsif transformation = 6
	writeInfoLine: "file", tab$, "median_f0"
elsif transformation = 7
	writeInfoLine: "file", tab$, "mean_f0", tab$, "sd_f0"
endif


# --------------------------------------
# Loop over all TextGrid and Pitch pairs
# --------------------------------------

for file to nfiles
	# Load TextGrid and matching Pitch objects
	grid = Read from file: grid_folder$ + files$#[file]
	file$ = selected$("TextGrid")
	if fileReadable(pitch_folder$ + file$ + ".Pitch")
		pitch = Read from file: pitch_folder$ + file$ + ".Pitch"
	else
		exitScript: "Could not find ", file$, ".Pitch at ", pitch_folder$, "."
	endif

	# Apply smoothing if selected 
	if smooth = 1
		raw = pitch
		selectObject: raw
		smoothed = Smooth: bandwidth
		pitch = smoothed
		removeObject: raw
	endif

	# Apply interpolation if selected
	if interpolation < 3
		temp_pitch = pitch
		selectObject: temp_pitch
		# Min and max F0 are necessary in order to synthesize a Pitch from a PitchTier
		min_f0 = Get minimum: 0, 0, "Hertz", "Parabolic"
		max_f0 = Get maximum: 0, 0, "Hertz", "Parabolic"
		pitch_step = object[temp_pitch].dx
		# Just to be safe, min and max F0 values are rounded down and up to the nearest 10 Hz
		min_f0 = floor(min_f0 / 10) * 10
		max_f0 = ceiling(max_f0 / 10) * 10
		# Quadratic interpolation of unvoiced intervals is only available in PitchTier
		# Linear interpolation is done for free just by converting a PitchTier back to Pitch.
		# PitchTier to Pitch conversion is also useful because of constant extrapolation, i.e.,
		# extrapolation of values before and after the first and last points in the original Pitch.
		pitch_tier = Down to PitchTier
		if interpolation = 1
			Interpolate quadratically: 4, "Semitones"
		endif
		pitch = To Pitch: pitch_step, min_f0, max_f0
		removeObject: temp_pitch, pitch_tier
	endif

	# Query Pitch object for some values
	selectObject: pitch
	if transformation = 5
		min_f0 = Get minimum: 0, 0, "Hertz", "Parabolic"
		appendInfoLine: file$, tab$, fixed$(min_f0, 2)
	elsif transformation = 6
		median_f0 = Get quantile: 0.0, 0.0, 0.50, "Hertz"
		appendInfoLine: file$, tab$, fixed$(median_f0, 2)
	elsif transformation = 7
		mean_f0 = Get mean: 0.0, 0.0, "Hertz"
		sd_f0 = Get standard deviation: 0.0, 0.0, "Hertz"
		appendInfoLine: file$, tab$, fixed$(mean_f0, 2), tab$, fixed$(sd_f0, 2)
	endif

	# Extract user-selected tier from TextGrid and tabulate non-empty intervals
	selectObject: grid
	test = Is interval tier: tier
	if test = 0
		exitScript: "Tier ", tier, " in TextGrid ", file$, " is not an interval tier."
	endif
	sel = Extract one tier: tier
	tab = Down to Table: "no", 6, "no", "no"
	intervals = object[tab].nrow

	# Check if user-defined start and end intervals are within the available
	# intervals in the working TextGrid tier
	if intervals = 0
		exitScript: "There are no filled intervals in tier ", tier, "."
	elsif (intervals < right_Range)
		exitScript: "End interval is out of range in tier ", tier, "."
	endif

	# -----------------------------------
	# Loop over each interval in TextGrid
	# -----------------------------------
	
	# 'sample' is a counter and goes from 1 to the total number of f0 values 
	# taken in each Pitch object:
	# number intervals in range * samples per interval
	sample = 1
	for interval from left_Range to right_Range
		# Interval label
		label$ = object$[tab, interval, 2]
		# Interval start time
		start = object[tab, interval, 1]
		# Interval end time
		end = object[tab, interval, 3]
		if nsamples = 1
			samp = number(samples$#[1])
		else
			samp = number(samples$#[interval])
		endif

		# Divide the current interval into the set number of equally spaced
		# subintervals and list the center of each
		times# = between_count# (start, end, samp)

		# Intersample interval
		step = (end - start) / samp

		# Get f0 sample values for each subinterval
		selectObject: pitch
		values# = List values at times: times#, "Hertz", "linear"

		# -------------------------- 
		# Loop over each subinterval
		# -------------------------- 
		for subint to samp
			value = values#[subint]
			if value = undefined
				value$ = unvoiced$
			else
				if transformation = 2 
					value = log2(value / 1) * 12
				elsif transformation = 3
					value = log2(value / 100) * 12
				elsif transformation = 4
					value = log2(value / 200) * 12
				elsif transformation = 5
					value = log2(value / min_f0) * 12
				elsif transformation = 6
					value = log2(value / median_f0)
				elsif transformation = 7
					value = (value - mean_f0) / sd_f0
				endif
				value$ = fixed$(value, 2)
			endif
			appendFileLine: report$, file$, tab$, interval, tab$, label$, tab$, sample, tab$, value$, tab$, fixed$(step, 3), tab$, fixed$(times#[subint], 3)
			sample += 1
		endfor
	endfor
	removeObject: grid, sel, tab, pitch
endfor

if transformation < 5
	writeInfoLine: "Finished on ", date$()
endif